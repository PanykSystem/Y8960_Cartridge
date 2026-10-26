// -----------------------------------------------------------------------------
//	Y8960UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
using System;
using System.IO;
using System.Text;

namespace Y8960UpdWin
{
	// Update images: +0 signature (32 bytes), +32 version (16 bytes), +48 payload
	internal sealed class ConfigImage
	{
		public const int SignatureSize = 32;
		public const int VersionSize = 16;
		public const int HeaderSize = SignatureSize + VersionSize;
		public const int MaxDataSize = 0x7D0000;
		public const int VersionBlockAddress = 0x7D0000;
		public const int VersionBlockSize = 0x10000;
		public const int VersionAddress = 0x7DFF00;
		public const int BiosAddress = 0x7E0000;
		public const int BiosDataSize = 0x20000;
		public const int BiosVersionAddress = 0x7DFF10;

		private static readonly byte[] ConfigSignature = MakeSignature( "Y8960_TP25K_CARTRIDGE" );
		private static readonly byte[] BiosSignature = MakeSignature( "Y8960_BIOS_IMAGE" );

		public byte[] Data { get; private set; }
		public byte[] VersionBytes { get; private set; }
		public string VersionText { get { return DecodeVersion( VersionBytes ); } }

		private ConfigImage() { }

		public static ConfigImage Load( string path, bool bios, out string error )
		{
			error = null;
			byte[] image;
			try {
				image = File.ReadAllBytes( path );
			}
			catch( IOException ) {
				error = "Cannot open the file.";
				return null;
			}
			catch( UnauthorizedAccessException ) {
				error = "Cannot open the file.";
				return null;
			}
			return Parse( image, bios, out error );
		}

		public static ConfigImage Parse( byte[] image, bool bios, out string error )
		{
			error = null;
			byte[] signature = bios ? BiosSignature : ConfigSignature;
			string invalidImage = bios ? "This file is not a valid Y8960 BIOS image."
				: "This file is not a valid Y8960 Config image.";
			if( image == null || image.Length < SignatureSize ) {
				error = invalidImage;
				return null;
			}
			for( int i = 0; i < SignatureSize; i++ ) {
				if( image[ i ] != signature[ i ] ) {
					error = invalidImage;
					return null;
				}
			}
			int dataSize = image.Length - HeaderSize;
			if( bios ? dataSize != BiosDataSize : dataSize < 1 || dataSize > MaxDataSize ) {
				error = "Invalid data size.";
				return null;
			}

			var result = new ConfigImage();
			result.VersionBytes = new byte[ VersionSize ];
			Array.Copy( image, SignatureSize, result.VersionBytes, 0, VersionSize );
			result.Data = new byte[ dataSize ];
			Array.Copy( image, HeaderSize, result.Data, 0, dataSize );
			return result;
		}

		// 64KB image for 7D0000h-7DFFFFh: all FFh except the version string at 7DFF00h.
		public byte[] CreateVersionBlock( ConfigImage bios )
		{
			if( bios == null ) {
				throw new ArgumentNullException( nameof( bios ) );
			}
			var block = new byte[ VersionBlockSize ];
			for( int i = 0; i < block.Length; i++ ) {
				block[ i ] = 0xFF;
			}
			Array.Copy( VersionBytes, 0, block, VersionAddress - VersionBlockAddress, VersionSize );
			Array.Copy( bios.VersionBytes, 0, block, BiosVersionAddress - VersionBlockAddress, VersionSize );
			return block;
		}

		public static string DecodeVersion( byte[] bytes )
		{
			var sb = new StringBuilder();
			foreach( byte b in bytes ) {
				if( b == 0x00 ) {
					break;
				}
				sb.Append( ( b >= 0x20 && b < 0x7F ) ? (char)b : '?' );
			}
			return sb.ToString();
		}

		private static byte[] MakeSignature( string text )
		{
			var result = new byte[ SignatureSize ];
			byte[] ascii = Encoding.ASCII.GetBytes( text );
			Array.Copy( ascii, result, ascii.Length );
			return result;
		}
	}
}
