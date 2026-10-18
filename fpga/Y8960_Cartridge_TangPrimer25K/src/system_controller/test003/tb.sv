// --------------------------------------------------------------------
//	system_controller I/O register test (doc/spec/system_controller.md)
//		40h enabler / 41h device select / 42h function select
//		43h-47h Config ROM Reader/Writer
// --------------------------------------------------------------------

module tb ();
	localparam		CLK_PERIOD			= 23280;	//	42.95MHz
	localparam		CLK_SERIAL_PERIOD	= 5820;		//	171.8MHz

	reg				clk;
	reg				clk_serial;
	reg				reset_n;

	reg				bus_cs;
	reg		[3:0]	bus_address;
	reg				bus_valid;
	reg				bus_write;
	reg		[7:0]	bus_wdata;
	wire			bus_ready;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;

	wire			rom_bus_address;
	wire			rom_bus_valid;
	wire			rom_bus_write;
	wire	[7:0]	rom_bus_wdata;
	wire			init_rom_bus_address;
	wire			init_rom_bus_valid;
	wire			init_rom_bus_write;
	wire	[7:0]	init_rom_bus_wdata;
	wire			spi_bus_ready;
	wire	[7:0]	spi_bus_rdata;
	wire			spi_bus_rdata_en;
	wire	[7:0]	init_rom_stream_rdata;
	wire			init_rom_stream_valid;
	wire			init_rom_stream_ready;
	wire			init_rom_stream_stop;

	wire			sram_ready;
	wire	[18:0]	init_sram_bus_address;
	wire			init_sram_bus_valid;
	wire			init_sram_bus_write;
	wire			init_sram_bus_burst;
	wire	[7:0]	init_sram_bus_wdata;
	wire	[7:0]	sram_rdata;
	wire			sram_rdata_en;
	wire			sram_initialize;
	wire			wait_n;

	wire			flash_spi_clk;
	wire			flash_spi_cs_n;
	wire	[3:0]	flash_spi_io;
	wire			sram_sclk;
	wire			sram_ce_n;
	wire	[3:0]	sram_sio;
	integer			errors;
	integer			i;

	pullup( flash_spi_io[2] );
	pullup( flash_spi_io[3] );

	system_controller #(
		.device_id				( 8'h02					)
	) u_dut (
		.clk					( clk					),
		.reset_n				( reset_n				),
		.bus_cs					( bus_cs				),
		.bus_address			( bus_address			),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_en			( bus_rdata_en			),
		.rom_bus_address		( rom_bus_address		),
		.rom_bus_valid			( rom_bus_valid			),
		.rom_bus_ready			( spi_bus_ready & ~sram_initialize	),
		.rom_bus_write			( rom_bus_write			),
		.rom_bus_wdata			( rom_bus_wdata			),
		.rom_bus_rdata			( spi_bus_rdata			),
		.rom_bus_rdata_en		( spi_bus_rdata_en & ~sram_initialize	),
		.init_rom_bus_address	( init_rom_bus_address	),
		.init_rom_bus_valid		( init_rom_bus_valid	),
		.init_rom_bus_ready		( spi_bus_ready			),
		.init_rom_bus_write		( init_rom_bus_write	),
		.init_rom_bus_wdata		( init_rom_bus_wdata	),
		.init_rom_stream_rdata	( init_rom_stream_rdata	),
		.init_rom_stream_valid	( init_rom_stream_valid	),
		.init_rom_stream_ready	( init_rom_stream_ready	),
		.init_rom_stream_stop	( init_rom_stream_stop	),
		.sram_ready				( sram_ready			),
		.init_sram_bus_address	( init_sram_bus_address	),
		.init_sram_bus_valid	( init_sram_bus_valid	),
		.init_sram_bus_ready	( sram_ready			),
		.init_sram_bus_write	( init_sram_bus_write	),
		.init_sram_bus_burst	( init_sram_bus_burst	),
		.init_sram_bus_wdata	( init_sram_bus_wdata	),
		.sram_initialize		( sram_initialize		),
		.wait_n					( wait_n				)
	);

	ip_spi_rom u_spi_rom (
		.reset_n				( reset_n				),
		.clk					( clk					),
		.clk_serial				( clk_serial			),
		.bus_cs					( 1'b1					),
		.bus_address			( sram_initialize ? init_rom_bus_address : rom_bus_address	),
		.bus_write				( sram_initialize ? init_rom_bus_write   : rom_bus_write	),
		.bus_valid				( sram_initialize ? init_rom_bus_valid   : rom_bus_valid	),
		.bus_ready				( spi_bus_ready			),
		.bus_wdata				( sram_initialize ? init_rom_bus_wdata   : rom_bus_wdata	),
		.bus_rdata				( spi_bus_rdata			),
		.bus_rdata_en			( spi_bus_rdata_en		),
		.stream_rdata			( init_rom_stream_rdata	),
		.stream_valid			( init_rom_stream_valid	),
		.stream_ready			( init_rom_stream_ready	),
		.stream_stop			( init_rom_stream_stop	),
		.srom_cs_n				( flash_spi_cs_n		),
		.srom_clk				( flash_spi_clk			),
		.srom_hold_n			( flash_spi_io[3]		),
		.srom_wp_n				( flash_spi_io[2]		),
		.srom_do				( flash_spi_io[1]		),
		.srom_di				( flash_spi_io[0]		)
	);

	ssram u_ssram (
		.n_reset				( reset_n				),
		.clk					( clk					),
		.clk_serial				( clk_serial			),
		.bus_cs					( 1'b1					),
		.bus_address			( init_sram_bus_address	),
		.bus_write				( init_sram_bus_write	),
		.bus_burst				( sram_initialize & init_sram_bus_burst	),
		.bus_valid				( sram_initialize & init_sram_bus_valid	),
		.bus_wdata				( init_sram_bus_wdata	),
		.bus_ready				( sram_ready			),
		.bus_rdata				( sram_rdata			),
		.bus_rdata_en			( sram_rdata_en			),
		.sram_sclk				( sram_sclk				),
		.sram_ce_n				( sram_ce_n				),
		.sram_sio				( sram_sio				)
	);

	sfrom_test_model u_flash (
		.spi_clk				( flash_spi_clk			),
		.spi_cs_n				( flash_spi_cs_n		),
		.spi_io					( flash_spi_io			)
	);

	ssram_test_model #(
		.VERBOSE				( 0						)
	) u_sram_model (
		.sclk					( sram_sclk				),
		.cs_n					( sram_ce_n				),
		.sio					( sram_sio				)
	);

	//	SPI frame monitor (real Flash semantics): commands are latched at CS# rising,
	//	so every frame must be a whole number of bytes and CS# high time >= 50ns.
	integer			mon_bits;
	reg		[63:0]	mon_shift;
	time			mon_cs_rise;
	initial begin
		mon_bits	= 0;
		mon_shift	= 0;
		mon_cs_rise	= 0;
	end
	always @( negedge flash_spi_cs_n ) begin
		if( mon_cs_rise != 0 && ($time - mon_cs_rise) < 50000 ) begin
			$display( "[ERROR] SPI: CS# high time %0t < 50ns", $time - mon_cs_rise );
			errors = errors + 1;
		end
		mon_bits	= 0;
		mon_shift	= 0;
	end
	always @( posedge flash_spi_clk ) begin
		if( !flash_spi_cs_n ) begin
			mon_bits	= mon_bits + 1;
			mon_shift	= { mon_shift[62:0], flash_spi_io[0] };
		end
	end
	always @( posedge flash_spi_cs_n ) begin
		mon_cs_rise = $time;
		if( (mon_bits % 8) != 0 ) begin
			$display( "[ERROR] SPI: frame of %0d bits (not byte aligned)", mon_bits );
			errors = errors + 1;
		end
		else if( mon_bits != 0 && mon_bits <= 64 ) begin
			$display( "[SPI] frame %0d bytes: %h", mon_bits / 8, mon_shift );
		end
		else if( mon_bits != 0 ) begin
			$display( "[SPI] frame %0d bytes (long)", mon_bits / 8 );
		end
	end

	always #(CLK_PERIOD/2)			clk <= ~clk;
	always #(CLK_SERIAL_PERIOD/2)	clk_serial <= ~clk_serial;

	//	One I/O access. Returns rdata_en/rdata of the cycle following the handshake.
	task io_access( input write, input [7:0] port, input [7:0] wdata, output en, output [7:0] rdata );
		integer	timeout;
		begin
			@( negedge clk );
			bus_cs		= 1'b1;
			bus_valid	= 1'b1;
			bus_write	= write;
			bus_address	= port[3:0];
			bus_wdata	= wdata;
			timeout		= 0;
			while( !bus_ready ) begin
				@( negedge clk );
				timeout = timeout + 1;
				if( timeout > 2_000_000 ) begin
					$display( "[ERROR] bus_ready timeout (port %02Xh)", port );
					$display( "[RESULT] FAILED" );
					$finish;
				end
			end
			@( posedge clk );
			#1;
			bus_cs		= 1'b0;
			bus_valid	= 1'b0;
			bus_write	= 1'b0;
			en			= bus_rdata_en;
			rdata		= bus_rdata;
			@( posedge clk );
			#1;
			if( bus_rdata_en !== 1'b0 ) begin
				$display( "[ERROR] bus_rdata_en held after the access (port %02Xh)", port );
				errors = errors + 1;
			end
		end
	endtask

	task io_write( input [7:0] port, input [7:0] wdata );
		reg			en;
		reg	[7:0]	rdata;
		begin
			io_access( 1'b1, port, wdata, en, rdata );
			if( en !== 1'b0 ) begin
				$display( "[ERROR] write %02Xh: bus_rdata_en asserted", port );
				errors = errors + 1;
			end
		end
	endtask

	task expect_read( input [7:0] port, input [7:0] expected, input [8*40-1:0] label );
		reg			en;
		reg	[7:0]	rdata;
		begin
			io_access( 1'b0, port, 8'h00, en, rdata );
			if( en !== 1'b1 || rdata !== expected ) begin
				$display( "[ERROR] %0s: read %02Xh -> en=%b data=%02Xh, expected %02Xh", label, port, en, rdata, expected );
				errors = errors + 1;
			end
		end
	endtask

	task expect_no_response( input [7:0] port, input [8*40-1:0] label );
		reg			en;
		reg	[7:0]	rdata;
		begin
			io_access( 1'b0, port, 8'h00, en, rdata );
			if( en !== 1'b0 ) begin
				$display( "[ERROR] %0s: read %02Xh must not respond (data=%02Xh)", label, port, rdata );
				errors = errors + 1;
			end
		end
	endtask

	task expect_all_silent( input [8*40-1:0] label );
		integer	p;
		begin
			for( p = 8'h40; p <= 8'h4F; p = p + 1 ) begin
				expect_no_response( p[7:0], label );
			end
		end
	endtask

	task set_rom_address( input [23:0] address );
		begin
			io_write( 8'h43, address[ 7: 0] );
			io_write( 8'h44, address[15: 8] );
			io_write( 8'h45, address[23:16] );
		end
	endtask

	task rom_read( input [23:0] address, input [7:0] expected, input [8*40-1:0] label );
		begin
			set_rom_address( address );
			io_write( 8'h46, 8'h00 );
			expect_read( 8'h47, expected, label );
		end
	endtask

	//	MSX side completion check of write/erase: poll BUSY (bit0) with the
	//	read status command (46h=04h).
	task rom_wait_ready( input [8*40-1:0] label );
		reg			en;
		reg	[7:0]	rdata;
		integer		tries;
		integer		busy_count;
		begin
			tries = 0;
			busy_count = 0;
			rdata = 8'h01;
			while( rdata[0] !== 1'b0 && tries < 10000 ) begin
				io_write( 8'h46, 8'h04 );
				io_access( 1'b0, 8'h47, 8'h00, en, rdata );
				if( rdata[0] === 1'b1 ) busy_count = busy_count + 1;
				tries = tries + 1;
			end
			if( rdata[0] !== 1'b0 ) begin
				$display( "[ERROR] %0s: BUSY timeout (status %02Xh)", label, rdata );
				errors = errors + 1;
			end
			else if( busy_count == 0 ) begin
				$display( "[ERROR] %0s: BUSY was never observed", label );
				errors = errors + 1;
			end
			else begin
				$display( "[INFO] %0s: BUSY observed %0d time(s)", label, busy_count );
			end
		end
	endtask

	task rom_poll( input [23:0] address, input [7:0] expected, input [8*40-1:0] label );
		reg			en;
		reg	[7:0]	rdata;
		integer		tries;
		begin
			set_rom_address( address );
			tries = 0;
			rdata = ~expected;
			while( rdata !== expected && tries < 200 ) begin
				io_write( 8'h46, 8'h00 );
				io_access( 1'b0, 8'h47, 8'h00, en, rdata );
				tries = tries + 1;
			end
			if( rdata !== expected ) begin
				$display( "[ERROR] %0s: polling timeout, read %02Xh, expected %02Xh", label, rdata, expected );
				errors = errors + 1;
			end
			else begin
				$display( "[INFO] %0s: completed after %0d read(s)", label, tries );
			end
		end
	endtask

	integer	stage_errors;
	integer	p;

	task stage_begin;
		stage_errors = errors;
	endtask

	task stage_end( input [8*64-1:0] label );
		if( errors == stage_errors ) $display( "[PASS] %0s", label );
	endtask

	initial begin
		clk			= 1'b0;
		clk_serial	= 1'b0;
		reset_n		= 1'b0;
		errors		= 0;
		bus_cs		= 1'b0;
		bus_valid	= 1'b0;
		bus_write	= 1'b0;
		bus_address	= 4'd0;
		bus_wdata	= 8'd0;

		#1;
		u_flash.memory[ 24'h123456 ] = 8'hA5;
		u_flash.memory[ 24'h123457 ] = 8'h3C;
		u_flash.memory[ 24'h7F0000 ] = 8'h81;
		u_flash.memory[ 24'h1FFFFF ] = 8'h77;
		u_flash.memory[ 24'h210000 ] = 8'h88;
		u_flash.memory[ 24'h20FFF0 ] = 8'h00;

		repeat( 20 ) @( posedge clk );
		reset_n = 1'b1;
		while( wait_n !== 1'b1 ) @( posedge clk );
		repeat( 200 ) @( posedge clk );

		//	---- disabled ----
		stage_begin;
		expect_all_silent( "after reset" );
		io_write( 8'h40, 8'h40 );
		expect_all_silent( "enabler=40h" );
		io_write( 8'h41, 8'h02 );
		io_write( 8'h42, 8'h01 );
		expect_all_silent( "41h/42h written while disabled" );
		stage_end( "disabled: 40h-4Fh do not respond" );

		//	---- enabled, no device ----
		stage_begin;
		io_write( 8'h40, 8'h80 );
		expect_read( 8'h40, 8'h7F, "enabled" );
		for( p = 8'h41; p <= 8'h4F; p = p + 1 ) expect_no_response( p[7:0], "enabled, no devsel" );
		io_write( 8'h41, 8'h01 );
		expect_read( 8'h40, 8'h7F, "devsel=01h" );
		for( p = 8'h41; p <= 8'h4F; p = p + 1 ) expect_no_response( p[7:0], "devsel=01h" );
		io_write( 8'h41, 8'hFF );
		expect_no_response( 8'h41, "devsel=FFh" );
		stage_end( "enabled: 40h=7Fh, other device IDs do not respond" );

		//	---- device selected ----
		stage_begin;
		io_write( 8'h41, 8'h02 );
		expect_read( 8'h41, 8'hFD, "devsel=02h" );
		expect_read( 8'h42, 8'hFF, "function not selected" );
		for( p = 8'h43; p <= 8'h4F; p = p + 1 ) expect_no_response( p[7:0], "function not selected" );
		io_write( 8'h42, 8'h02 );
		expect_read( 8'h42, 8'hFF, "function=02h" );
		for( p = 8'h43; p <= 8'h4F; p = p + 1 ) expect_no_response( p[7:0], "function=02h" );
		io_write( 8'h42, 8'h01 );
		expect_read( 8'h42, 8'hFE, "function=01h" );
		stage_end( "devsel=02h: 41h=FDh, 42h=FEh/FFh" );

		//	---- Config ROM Reader/Writer registers ----
		stage_begin;
		set_rom_address( 24'h563412 );
		expect_read( 8'h43, 8'h12, "address L" );
		expect_read( 8'h44, 8'h34, "address M" );
		expect_read( 8'h45, 8'h56, "address H" );
		for( p = 8'h48; p <= 8'h4F; p = p + 1 ) expect_no_response( p[7:0], "reserved" );
		stage_end( "function=01h: address registers, 48h-4Fh silent" );

		//	---- ROM read ----
		stage_begin;
		rom_read( 24'h123456, 8'hA5, "ROM read 123456h" );
		rom_read( 24'h123457, 8'h3C, "ROM read 123457h" );
		rom_read( 24'h7F0000, 8'h81, "ROM read 7F0000h" );
		stage_end( "ROM read command" );

		//	---- ROM write / sector erase ----
		stage_begin;
		set_rom_address( 24'h200010 );
		io_write( 8'h47, 8'h5A );
		io_write( 8'h46, 8'h01 );
		rom_wait_ready( "ROM write" );
		rom_read( 24'h200010, 8'h5A, "ROM read after write" );
		if( u_flash.memory[ 24'h200010 ] !== 8'h5A ) begin
			$display( "[ERROR] ROM write: memory[200010h] = %02Xh", u_flash.memory[ 24'h200010 ] );
			errors = errors + 1;
		end
		rom_read( 24'h200000, 8'hFF, "ROM write must not touch page top" );
		set_rom_address( 24'h200000 );
		io_write( 8'h46, 8'h02 );
		rom_wait_ready( "sector erase" );
		rom_read( 24'h200010, 8'hFF, "ROM read after erase" );
		if( u_flash.memory[ 24'h200010 ] !== 8'hFF ) begin
			$display( "[ERROR] sector erase: memory[200010h] = %02Xh", u_flash.memory[ 24'h200010 ] );
			errors = errors + 1;
		end
		rom_read( 24'h20FFF0, 8'hFF, "ROM read after erase (block end)" );
		if( u_flash.memory[ 24'h1FFFFF ] !== 8'h77 || u_flash.memory[ 24'h210000 ] !== 8'h88 ) begin
			$display( "[ERROR] block erase touched outside 200000h-20FFFFh" );
			errors = errors + 1;
		end
		io_write( 8'h46, 8'h05 );
		expect_read( 8'h42, 8'hFE, "reserved command ignored" );
		rom_read( 24'h123456, 8'hA5, "ROM read after status commands" );
		stage_end( "ROM write / sector(64KB block) erase commands" );

		//	---- deselect / disable ----
		stage_begin;
		io_write( 8'h41, 8'h03 );
		for( p = 8'h41; p <= 8'h4F; p = p + 1 ) expect_no_response( p[7:0], "devsel=03h" );
		io_write( 8'h41, 8'h02 );
		expect_read( 8'h42, 8'hFF, "function cleared by deselect" );
		io_write( 8'h42, 8'h01 );
		expect_read( 8'h42, 8'hFE, "function reselected" );
		io_write( 8'h40, 8'h00 );
		expect_all_silent( "disabled again" );
		io_write( 8'h40, 8'h80 );
		expect_read( 8'h40, 8'h7F, "re-enabled" );
		expect_no_response( 8'h41, "devsel cleared by disable" );
		stage_end( "deselect / disable" );

		if( errors == 0 ) begin
			$display( "[RESULT] ALL TESTS PASSED" );
		end
		else begin
			$display( "[RESULT] %0d ERROR(S)", errors );
		end
		$finish;
	end
endmodule