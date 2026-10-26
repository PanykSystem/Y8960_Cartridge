// -----------------------------------------------------------------------------
//	Y8960UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
using System;
using System.Windows.Forms;

namespace Y8960UpdWin
{
	internal static class Program
	{
		[STAThread]
		private static void Main()
		{
			Application.EnableVisualStyles();
			Application.SetCompatibleTextRenderingDefault( false );

			string cliPath = ProgrammerLocator.Find();
			if( cliPath == null ) {
				cliPath = ProgrammerPathForm.Ask( null, null );
				if( cliPath == null ) {
					return;
				}
			}

			Application.Run( new WizardForm( cliPath ) );
		}
	}
}
