using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Y8960UpdWin
{
	internal static class Tests
	{
		private static int _checks;

		[STAThread]
		private static int Main( string[] args )
		{
			// The test executable doubles as a fake programmer_cli. Never accesses USB.
			if( args.Length > 0 ) {
				File.AppendAllText( Environment.GetEnvironmentVariable( "Y8960_TEST_LOG" ),
					string.Join( "|", args ) + Environment.NewLine );
				Console.WriteLine( args[ 0 ] == "--scan"
					? Environment.GetEnvironmentVariable( "Y8960_TEST_SCAN" ) ?? RealScan
					: "Erasing 100%\nProgramming 100%\nVerifying 100%" );
				if( args[ 0 ] != "--scan" ) {
					int fileIndex = Array.IndexOf( args, "--fsFile" );
					if( fileIndex >= 0 ) {
						int operationIndex = Array.IndexOf( args, "--run" );
						if( operationIndex < 0 || operationIndex + 1 >= args.Length || args[ operationIndex + 1 ] != "54" ) {
							Console.WriteLine( "Error: Expected bitstream operation 54" );
							return 2;
						}
						File.Copy( args[ fileIndex + 1 ],
							Path.Combine( Path.GetDirectoryName( Environment.GetEnvironmentVariable( "Y8960_TEST_LOG" ) ),
								Path.GetFileName( args[ fileIndex + 1 ] ) ), true );
					}
					string fail = Environment.GetEnvironmentVariable( "Y8960_TEST_FAIL" );
					if( fileIndex >= 0 && Path.GetFileName( args[ fileIndex + 1 ] ) == fail ) {
						if( fail == "config.bin" ) {
							Console.WriteLine( "Error: Program and Verify Flash Failed!" );
							return 0;
						}
						Console.WriteLine( "Error: Verify failed" );
						return 1;
					}
					if( fileIndex < 0 && fail == "reprogram" ) {
						Console.WriteLine( "Error: Reprogram failed" );
						return 1;
					}
				}
				return 0;
			}

			string dir = Path.Combine( Path.GetTempPath(), "Y8960UpdWinTests", Guid.NewGuid().ToString( "N" ) );
			Directory.CreateDirectory( dir );
			try {
				TestImages();
				TestRepositoryImages();
				TestScan();
				TestProgress();
				string fake = Path.Combine( dir, "programmer_cli.exe" );
				File.Copy( Assembly.GetExecutingAssembly().Location, fake );
				TestWizard( fake, dir );
				foreach( string failure in new[] { "config.bin", "bios.bin", "version.bin", "reprogram", "scan" } ) {
					string scenario = Path.Combine( dir, "failure-" + failure );
					Directory.CreateDirectory( scenario );
					TestWizard( fake, scenario, failure );
				}
				Console.WriteLine( "PASS: " + _checks + " checks (fake CLI only; no hardware access)." );
				return 0;
			}
			catch( Exception ex ) {
				Console.Error.WriteLine( ex );
				return 1;
			}
			finally {
				Environment.SetEnvironmentVariable( "Y8960_TEST_LOG", null );
				Environment.SetEnvironmentVariable( "Y8960_TEST_FAIL", null );
				Environment.SetEnvironmentVariable( "Y8960_TEST_SCAN", null );
				Directory.Delete( dir, true );
			}
		}

		private static void Check( bool condition, string name )
		{
			if( !condition ) {
				throw new InvalidOperationException( name );
			}
			_checks++;
		}

		private static byte[] Image( bool bios, int size, string version )
		{
			var image = new byte[ ConfigImage.HeaderSize + size ];
			Encoding.ASCII.GetBytes( bios ? "Y8960_BIOS_IMAGE" : "Y8960_TP25K_CARTRIDGE" ).CopyTo( image, 0 );
			Encoding.ASCII.GetBytes( version ).CopyTo( image, ConfigImage.SignatureSize );
			for( int i = ConfigImage.HeaderSize; i < image.Length; i++ ) {
				image[ i ] = (byte)i;
			}
			return image;
		}

		private static void TestImages()
		{
			string error;
			var config = ConfigImage.Parse( Image( false, 16, "CFG-v1" ), false, out error );
			var bios = ConfigImage.Parse( Image( true, ConfigImage.BiosDataSize, "BIOS-v2" ), true, out error );
			Check( config != null && bios != null, "Both image signatures" );
			Check( config.Data[ 0 ] == 48 && config.Data.Length == 16, "Header is removed" );
			Check( config.VersionText == "CFG-v1" && bios.VersionText == "BIOS-v2", "Version strings" );
			Check( ConfigImage.Parse( Image( true, ConfigImage.BiosDataSize, "" ), false, out error ) == null, "Reject swapped BIOS" );
			Check( ConfigImage.Parse( Image( false, 16, "" ), true, out error ) == null, "Reject swapped Config" );
			var wrong = Image( false, 16, "" );
			wrong[ 25 ] = 1;
			Check( ConfigImage.Parse( wrong, false, out error ) == null, "Check full 32-byte signature" );
			foreach( int size in new[] { 0, 31, 32, 47, 48 } ) {
				Check( ConfigImage.Parse( new byte[ size ], false, out error ) == null, "Reject short file " + size );
			}
			Check( ConfigImage.Parse( Image( false, 0, "" ), false, out error ) == null, "Reject empty Config" );
			Check( ConfigImage.Parse( Image( false, 1, "" ), false, out error ) != null, "Minimum Config size" );
			Check( ConfigImage.Parse( Image( false, ConfigImage.MaxDataSize, "" ), false, out error ) != null, "Maximum Config size" );
			Check( ConfigImage.Parse( Image( false, ConfigImage.MaxDataSize + 1, "" ), false, out error ) == null, "Protect version block" );
			Check( ConfigImage.Parse( Image( true, ConfigImage.BiosDataSize - 1, "" ), true, out error ) == null, "Reject short BIOS" );
			Check( ConfigImage.Parse( Image( true, ConfigImage.BiosDataSize + 1, "" ), true, out error ) == null, "Reject oversized BIOS" );
			byte[] block = config.CreateVersionBlock( bios );
			Check( block.Length == 0x10000, "Version erase block size" );
			Check( block.Skip( 0xFF00 ).Take( 16 ).SequenceEqual( config.VersionBytes ), "Config version at 7DFF00" );
			Check( block.Skip( 0xFF10 ).Take( 16 ).SequenceEqual( bios.VersionBytes ), "BIOS version at 7DFF10" );
			Check( block.Where( ( b, i ) => i < 0xFF00 || i >= 0xFF20 ).All( b => b == 0xFF ), "Unused version bytes erased" );
			Check( ConfigImage.BiosAddress + ConfigImage.BiosDataSize == 0x800000, "BIOS flash boundary" );
		}

		private const string RealScan = "Scanning!\n Target Cable: Gowin USB Cable(FT2CH)/0/None/null@2.5MHz\nDevice Info:\n \tFamily: GW5AR  \n"
			+ "\tName: GW5A-25A GW5A-25B GW5AS-25A GW5AS-25B GW5AR-25A GW5AR-25B  (One of them)  \n\tID: 0x0001281B  \n 1 device(s) found!\n Cost 0.09 second(s)";

		private static void TestScan()
		{
			string reason;
			foreach( string text in new[] { "", "No devices", "GW2AR-18C", "GW5A-25", "GW5A-25A GW2AR-18C",
					"Name: GW5A-25A GW5A-25B  (One of them)\n 2 device(s) found!", "GW5A-25B GW5AS-25A\n 1 device(s) found!" } ) {
				Check( !ProgrammerCli.IsTargetDevice( new CliResult { ExitCode = 0, Output = text }, out reason ),
					"Reject ambiguous/incorrect device: " + text );
			}

			Check( ProgrammerCli.IsTargetDevice( new CliResult { ExitCode = 0, Output = "Device: GW5A-25A" }, out reason ), "Target FPGA" );
			Check( ProgrammerCli.IsTargetDevice( new CliResult { ExitCode = 0, Output = RealScan }, out reason ), "Real TangPrimer25K scan output" );
			Check( !ProgrammerCli.IsTargetDevice( new CliResult { ExitCode = 1, Output = "GW5A-25A" }, out reason ), "Scan exit code" );
			Check( !new CliResult { ExitCode = 0, Output = "Verify failed" }.Succeeded, "Detect textual verify error" );
			Check( !new CliResult { ExitCode = 0, Output = "Error: No gao bridge files found for this development board" }.Succeeded,
				"Detect bridge error even with exit code zero" );
		}

		private static void TestRepositoryImages()
		{
			string root = Path.GetFullPath( Path.Combine( AppDomain.CurrentDomain.BaseDirectory, @"..\..\..\..\.." ) );
			string error;
			Check( ConfigImage.Load( Path.Combine( root, @"tool\config\Y8960CFG.BIN" ), false, out error ) != null,
				"Repository Config file: " + error );
			Check( ConfigImage.Load( Path.Combine( root, @"tool\bios\MSXSSE.ROM" ), true, out error ) != null,
				"Repository BIOS file: " + error );
		}

		private static void TestProgress()
		{
			var progress = new ProgressModel();
			progress.BeginStep( 0, 75, 1 );
			progress.OnLine( "Programming 50%" );
			double first = progress.Current;
			progress.OnLine( "Programming 10%" );
			Check( progress.Current >= first, "Monotonic progress" );
			progress.Complete( 75 );
			progress.BeginStep( 75, 13, 0.1 );
			Check( progress.Current >= 75 && progress.Current <= 88, "BIOS progress interval" );
		}

		private static T Field<T>( object instance, string name )
		{
			return (T)instance.GetType().GetField( name, BindingFlags.Instance | BindingFlags.NonPublic ).GetValue( instance );
		}

		private static void Invoke( object instance, string name, params object[] args )
		{
			instance.GetType().GetMethod( name, BindingFlags.Instance | BindingFlags.NonPublic ).Invoke( instance, args );
		}

		private static void TestWizard( string fake, string dir, string failure = null )
		{
			Environment.SetEnvironmentVariable( "Y8960_TEST_LOG", Path.Combine( dir, "cli.log" ) );
			Environment.SetEnvironmentVariable( "Y8960_TEST_FAIL", failure );
			Environment.SetEnvironmentVariable( "Y8960_TEST_SCAN", null );
			string config = Path.Combine( dir, "input-config.bin" );
			string bios = Path.Combine( dir, "input-bios.bin" );
			File.WriteAllBytes( config, Image( false, 16, "CFG-v1" ) );
			File.WriteAllBytes( bios, Image( true, ConfigImage.BiosDataSize, "BIOS-v2" ) );
			Application.EnableVisualStyles();
			string notification = null;
			using( var form = new WizardForm( fake, ( text, icon ) => notification = text ) ) {
				form.Show();
				Field<TextBox>( form, "_filePath" ).Text = config;
				Field<TextBox>( form, "_biosPath" ).Text = bios;
				Invoke( form, "OnNext", null, EventArgs.Empty );
				Check( Field<int>( form, "_page" ) == 1, "Both files accepted by wizard" );
				Invoke( form, "OnNext", null, EventArgs.Empty );
				PumpUntil( () => !Field<bool>( form, "_busy" ) );
				Check( Field<int>( form, "_page" ) == 2, "Connection scan advances wizard" );
				if( failure == "scan" ) {
					Environment.SetEnvironmentVariable( "Y8960_TEST_SCAN", "GW2AR-18C" );
				}
				Invoke( form, "OnStart", null, EventArgs.Empty );
				PumpUntil( () => !Field<bool>( form, "_busy" ) );
				string[] lines = File.ReadAllLines( Path.Combine( dir, "cli.log" ) );
				if( failure != null && failure != "reprogram" ) {
					Check( !string.IsNullOrEmpty( notification ), "Failure notification: " + failure );
					Check( !Field<bool>( form, "_completed" ), "Failure not reported as success: " + failure );
					if( failure == "config.bin" ) {
						Check( Field<TextBox>( form, "_log" ).Text.Contains( "exit code = 0" ),
							"Wizard stops on textual programming failure with exit code zero" );
					}
					int expectedCount = failure == "scan" ? 2 : failure == "config.bin" ? 3 : failure == "bios.bin" ? 4 : 5;
					Check( lines.Length == expectedCount, "Stop after failed step: " + failure );
					Check( !lines.Any( l => l.EndsWith( "|--run|1", StringComparison.Ordinal ) ), "No reboot after failure" );
					if( failure == "config.bin" || failure == "bios.bin" || failure == "scan" ) {
						Check( !lines.Any( l => l.Contains( "version.bin|--spiaddr" ) ), "Do not update versions on payload failure" );
					}
					Check( Field<Label>( form, "_result" ).Text == ( failure == "scan"
						? "Y8960 Cartridge is not detected." : "Verify error." ), "Explicit failure message" );
					return;
				}
				Check( Field<bool>( form, "_completed" ), "Wizard completed" );
				Check( failure == "reprogram" ? notification != null : notification == null, "Reprogram warning" );
				Check( lines.Length == 6 && lines[ 0 ] == "--scan" && lines[ 1 ] == "--scan", "Rescan before writing" );
				CheckWrite( lines[ 2 ], "config.bin", "0x000000" );
				CheckWrite( lines[ 3 ], "bios.bin", "0x7E0000" );
				CheckWrite( lines[ 4 ], "version.bin", "0x7D0000" );
				Check( lines[ 5 ] == "--device|GW5A-25A|--frequency|2.5MHz|--run|1", "Reprogram last" );
				Check( File.ReadAllBytes( Path.Combine( dir, "config.bin" ) ).SequenceEqual( File.ReadAllBytes( config ).Skip( 48 ) ), "Config payload sent" );
				Check( File.ReadAllBytes( Path.Combine( dir, "bios.bin" ) ).SequenceEqual( File.ReadAllBytes( bios ).Skip( 48 ) ), "BIOS payload sent" );
				byte[] versions = File.ReadAllBytes( Path.Combine( dir, "version.bin" ) );
				Check( Encoding.ASCII.GetString( versions, 0xFF00, 6 ) == "CFG-v1"
					&& Encoding.ASCII.GetString( versions, 0xFF10, 7 ) == "BIOS-v2", "Both versions sent" );
			}
		}

		private static void CheckWrite( string line, string file, string address )
		{
			Check( line.StartsWith( "--device|GW5A-25A|--frequency|2.5MHz|--run|54|--fsFile|", StringComparison.Ordinal )
				&& line.Contains( file + "|--spiaddr|" + address ), "Write command for " + file );
		}

		private static void PumpUntil( Func<bool> done )
		{
			var timeout = System.Diagnostics.Stopwatch.StartNew();
			while( !done() ) {
				if( timeout.Elapsed.TotalSeconds > 30 ) {
					throw new TimeoutException( "Wizard operation timed out" );
				}
				Application.DoEvents();
				Thread.Sleep( 10 );
			}
			Application.DoEvents();
		}
	}
}
