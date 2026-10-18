// --------------------------------------------------------------------
//	system_controller boot copy test
//		SPI ROM 7E0000h-7FFFFFh -> SerialSRAM 00000h-1FFFFh
// --------------------------------------------------------------------

module tb ();
	localparam		CLK_PERIOD			= 23280;	//	42.95MHz
	localparam		CLK_SERIAL_PERIOD	= 5820;		//	171.8MHz
	localparam		BOOT_SIZE			= 128 * 1024;
	localparam		ROM_BASE			= 24'h7E0000;

	reg				clk;
	reg				clk_serial;
	reg				reset_n;

	wire			bus_ready;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;

	wire			rom_bus_address;
	wire			rom_bus_valid;
	wire			rom_bus_ready;
	wire			rom_bus_write;
	wire	[7:0]	rom_bus_wdata;
	wire	[7:0]	rom_bus_rdata;
	wire			rom_bus_rdata_en;
	wire			init_rom_bus_address;
	wire			init_rom_bus_valid;
	wire			init_rom_bus_write;
	wire	[7:0]	init_rom_bus_wdata;
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
	reg		[18:0]	tb_sram_address;
	reg				tb_sram_valid;
	reg				tb_sram_write;
	reg		[7:0]	tb_sram_wdata;
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
		.bus_cs					( 1'b0					),
		.bus_address			( 4'd0					),
		.bus_valid				( 1'b0					),
		.bus_ready				( bus_ready				),
		.bus_write				( 1'b0					),
		.bus_wdata				( 8'd0					),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_en			( bus_rdata_en			),
		.rom_bus_address		( rom_bus_address		),
		.rom_bus_valid			( rom_bus_valid			),
		.rom_bus_ready			( 1'b0					),
		.rom_bus_write			( rom_bus_write			),
		.rom_bus_wdata			( rom_bus_wdata			),
		.rom_bus_rdata			( 8'hFF					),
		.rom_bus_rdata_en		( 1'b0					),
		.init_rom_bus_address	( init_rom_bus_address	),
		.init_rom_bus_valid		( init_rom_bus_valid	),
		.init_rom_bus_ready		( rom_bus_ready			),
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
		.bus_address			( init_rom_bus_address	),
		.bus_write				( init_rom_bus_write	),
		.bus_valid				( init_rom_bus_valid	),
		.bus_ready				( rom_bus_ready			),
		.bus_wdata				( init_rom_bus_wdata	),
		.bus_rdata				( rom_bus_rdata			),
		.bus_rdata_en			( rom_bus_rdata_en		),
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
		.bus_address			( sram_initialize ? init_sram_bus_address : tb_sram_address	),
		.bus_write				( sram_initialize ? init_sram_bus_write   : tb_sram_write		),
		.bus_burst				( sram_initialize & init_sram_bus_burst							),
		.bus_valid				( sram_initialize ? init_sram_bus_valid   : tb_sram_valid		),
		.bus_wdata				( sram_initialize ? init_sram_bus_wdata   : tb_sram_wdata		),
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

	always #(CLK_PERIOD/2)			clk <= ~clk;
	always #(CLK_SERIAL_PERIOD/2)	clk_serial <= ~clk_serial;

	function [7:0] rom_pattern( input [16:0] offset, input [7:0] seed );
		rom_pattern = ( offset[7:0] ^ offset[15:8] ^ { 7'd0, offset[16] } ^ seed ) + offset[10:3];
	endfunction

	task fill_flash( input [7:0] seed );
		begin
			for( i = 0; i < BOOT_SIZE; i = i + 1 ) begin
				u_flash.memory[ ROM_BASE + i ] = rom_pattern( i, seed );
			end
			u_flash.memory[ ROM_BASE - 1 ] = 8'h5A;
		end
	endtask

	task check_copy( input [7:0] seed, input [8*16-1:0] label );
		integer mismatches;
		begin
			mismatches = 0;
			for( i = 0; i < BOOT_SIZE; i = i + 1 ) begin
				if( u_sram_model.mem[i] !== rom_pattern( i, seed ) ) begin
					if( mismatches < 8 ) begin
						$display( "[ERROR] %0s: SRAM[%05X] = %02X, expected %02X", label, i, u_sram_model.mem[i], rom_pattern( i, seed ) );
					end
					mismatches = mismatches + 1;
				end
			end
			if( u_sram_model.mem[ BOOT_SIZE ] !== 8'hA5 ) begin
				$display( "[ERROR] %0s: SRAM[20000] overwritten (%02X)", label, u_sram_model.mem[ BOOT_SIZE ] );
				mismatches = mismatches + 1;
			end
			if( u_sram_model.mem[ 19'h40000 ] !== 8'hC3 ) begin
				$display( "[ERROR] %0s: SRAM[40000] overwritten (%02X)", label, u_sram_model.mem[ 19'h40000 ] );
				mismatches = mismatches + 1;
			end
			if( mismatches == 0 ) begin
				$display( "[PASS] %0s: 128KB copied correctly", label );
			end
			errors = errors + mismatches;
		end
	endtask

	task run_boot( input [7:0] seed, input [8*16-1:0] label );
		time t_start;
		begin
			fill_flash( seed );
			reset_n = 1'b0;
			repeat( 20 ) @( posedge clk );
			if( wait_n !== 1'b0 || sram_initialize !== 1'b1 ) begin
				$display( "[ERROR] %0s: wait_n/sram_initialize must be 0/1 during reset", label );
				errors = errors + 1;
			end
			reset_n = 1'b1;
			t_start = $time;
			while( wait_n !== 1'b1 ) begin
				@( posedge clk );
				if( wait_n !== 1'b1 && sram_initialize !== 1'b1 ) begin
					$display( "[ERROR] %0s: sram_initialize deasserted during copy", label );
					errors = errors + 1;
				end
				if( ($time - t_start) > 64'd500_000_000_000 ) begin
					$display( "[ERROR] %0s: boot copy timeout", label );
					$display( "[RESULT] FAILED" );
					$finish;
				end
			end
			$display( "[INFO] %0s: boot copy finished in %0t ns", label, ($time - t_start) / 1000 );
			if( sram_initialize !== 1'b0 ) begin
				$display( "[ERROR] %0s: sram_initialize still asserted", label );
				errors = errors + 1;
			end
			repeat( 200 ) @( posedge clk );
			if( flash_spi_cs_n !== 1'b1 ) begin
				$display( "[ERROR] %0s: SPI ROM CS is still active after copy", label );
				errors = errors + 1;
			end
			check_copy( seed, label );
		end
	endtask

	task sram_access( input write, input [18:0] address, input [7:0] wdata, output [7:0] rdata );
		begin
			@( posedge clk );
			while( !sram_ready ) @( posedge clk );
			tb_sram_address	<= address;
			tb_sram_write	<= write;
			tb_sram_wdata	<= wdata;
			tb_sram_valid	<= 1'b1;
			@( posedge clk );
			tb_sram_valid	<= 1'b0;
			if( write ) begin
				while( !sram_ready ) @( posedge clk );
				rdata = 8'hXX;
			end
			else begin
				while( !sram_rdata_en ) @( posedge clk );
				rdata = sram_rdata;
				if( sram_ready !== 1'b1 ) begin
					$display( "[ERROR] SRAM ready must return with rdata_en" );
					errors = errors + 1;
				end
			end
		end
	endtask

	task check_sram_read( input [18:0] address, input [7:0] expected, input [8*16-1:0] label );
		reg		[7:0]	rdata;
		begin
			sram_access( 1'b0, address, 8'h00, rdata );
			if( rdata !== expected ) begin
				$display( "[ERROR] %0s: SRAM read [%05X] = %02X, expected %02X", label, address, rdata, expected );
				errors = errors + 1;
			end
		end
	endtask

	task check_sram_rw( input [7:0] seed, input [8*16-1:0] label );
		reg		[7:0]	rdata;
		integer			start_errors;
		begin
			start_errors = errors;
			check_sram_read( 19'h00000, rom_pattern( 17'h00000, seed ), label );
			check_sram_read( 19'h1FFFF, rom_pattern( 17'h1FFFF, seed ), label );
			check_sram_read( 19'h20000, 8'hA5, label );
			sram_access( 1'b1, 19'h20001, 8'h96, rdata );
			sram_access( 1'b1, 19'h40001, 8'h69, rdata );
			check_sram_read( 19'h20001, 8'h96, label );
			check_sram_read( 19'h40001, 8'h69, label );
			check_sram_read( 19'h12345, rom_pattern( 17'h12345, seed ), label );
			if( errors == start_errors ) begin
				$display( "[PASS] %0s: SerialSRAM single read/write after boot", label );
			end
		end
	endtask
	initial begin
		clk = 1'b0;
		clk_serial = 1'b0;
		reset_n = 1'b0;
		errors = 0;
		tb_sram_address = 19'd0;
		tb_sram_valid = 1'b0;
		tb_sram_write = 1'b0;
		tb_sram_wdata = 8'd0;

		#1;
		u_sram_model.mem[ BOOT_SIZE ] = 8'hA5;
		u_sram_model.mem[ 19'h40000 ] = 8'hC3;

		run_boot( 8'h00, "power-on boot" );
		check_sram_rw( 8'h00, "power-on boot" );
		u_sram_model.mem[ BOOT_SIZE ] = 8'hA5;
		u_sram_model.mem[ 19'h40000 ] = 8'hC3;
		run_boot( 8'h3C, "MSX reset boot" );
		check_sram_rw( 8'h3C, "MSX reset boot" );

		if( errors == 0 ) begin
			$display( "[RESULT] ALL TESTS PASSED" );
		end
		else begin
			$display( "[RESULT] %0d ERROR(S)", errors );
		end
		$finish;
	end
endmodule
