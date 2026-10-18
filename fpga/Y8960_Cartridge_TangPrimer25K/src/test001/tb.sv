// -----------------------------------------------------------------------------
//	Top-level System Controller detection test
//	Copyright (C)2026 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------
//	Description:
//		MSX slot -> address decoder -> System Controller -> MSX data bus
// -----------------------------------------------------------------------------

module tb ();
	localparam	clk_base	= 1_000_000_000_000.0/28_636_360;	//	ps
	int				test_no;
	int				i, j;
	reg				clk;
	reg				clk_14m;
	reg				clk_50m;
	//	slot
	reg				slot_reset_n;
	reg		[15:0]	slot_a;
	wire	[7:0]	slot_d;
	reg				slot_sltsl_n;
	reg				slot_mereq_n;
	reg				slot_ioreq_n;
	reg				slot_wr_n;
	reg				slot_rd_n;
	wire			slot_wait;
	wire			slot_intr;
	wire			slot_busdir;
	//	audio
	wire			audio_mclk;
	wire			audio_bclk;
	wire			audio_lrclk;
	wire			audio_sdata;
	//	flash ROM
	wire			flash_spi_clk;
	wire			flash_spi_cs_n;
	wire	[3:0]	flash_spi_io;
	//	SRAM
	wire			sram_ce_n;
	wire			sram_sclk;
	wire	[3:0]	sram_sio;
	//	DIP S/W
	reg		[1:0]	dipsw;
	//	LED
	wire	[3:0]	led;

	//	task signals
	localparam	cpu_clk_base	= 1_000_000_000_000.0/3_579_545;	//	ps
	string			s_state;
	reg				p_slot_clk;
	reg		[7:0]	ff_slot_data;

	assign slot_d = !slot_wr_n ? ff_slot_data : 8'hZZ;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	y8960cartridge_tangprimer25k u_dut (
		.clk_28m				( clk					),
		.clk_50m				( clk					),
		.slot_reset_n			( slot_reset_n			),
		.slot_a					( slot_a				),
		.slot_d					( slot_d				),
		.slot_sltsl_n			( slot_sltsl_n			),
		.slot_mereq_n			( slot_mereq_n			),
		.slot_ioreq_n			( slot_ioreq_n			),
		.slot_wr_n				( slot_wr_n				),
		.slot_rd_n				( slot_rd_n				),
		.slot_wait				( slot_wait				),
		.slot_intr				( slot_intr				),
		.slot_busdir			( slot_busdir			),
		.audio_mclk				( audio_mclk			),
		.audio_bclk				( audio_bclk			),
		.audio_lrclk			( audio_lrclk			),
		.audio_sdata			( audio_sdata			),
		.flash_spi_clk			( flash_spi_clk			),
		.flash_spi_cs_n			( flash_spi_cs_n		),
		.flash_spi_io			( flash_spi_io			),
		.sram_ce_n				( sram_ce_n				),
		.sram_sclk				( sram_sclk				),
		.sram_sio				( sram_sio				),
		.dipsw					( dipsw					),
		.led					( led					)
	);

	// --------------------------------------------------------------------
	//	Serial Flash ROM test model
	// --------------------------------------------------------------------
	sfrom_test_model u_sfrom (
		.spi_clk				( flash_spi_clk			),
		.spi_cs_n				( flash_spi_cs_n		),
		.spi_io					( flash_spi_io			)
	);

	// --------------------------------------------------------------------
	//	Serial SRAM test model
	// --------------------------------------------------------------------
	ssram_test_model u_ssram (
		.sclk					( sram_sclk				),
		.cs_n					( sram_ce_n				),
		.sio					( sram_sio				)
	);

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Task
	// --------------------------------------------------------------------
	task write_io(
		input	[15:0]	address,
		input	[7:0]	wdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns slot_a = address;
			end
			//	/IORQ
			begin
				slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#135ns slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#145ns slot_ioreq_n = 1'b1;
			end
			//	/WR
			begin
				slot_wr_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#125ns slot_wr_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#120ns slot_wr_n = 1'b1;
			end
			//	others
			begin
				ff_slot_data	= wdata;
			end
		join
	endtask

	// --------------------------------------------------------------------
	task write_io_ex(
		input	[7:0]	address,
		input	[7:0]	wdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns slot_a = address;
			end
			//	/IORQ
			begin
				slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#175ns slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#185ns slot_ioreq_n = 1'b1;
			end
			//	/WR
			begin
				slot_wr_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#165ns slot_wr_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#150ns slot_wr_n = 1'b1;
			end
			//	others
			begin
				ff_slot_data	= wdata;
			end
		join
	endtask

	// --------------------------------------------------------------------
	task read_io(
		input	[15:0]	address,
		output	[7:0]	rdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns slot_a = address;
			end
			//	/IORQ
			begin
				slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#135ns slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#145ns slot_ioreq_n = 1'b1;
			end
			//	/RD
			begin
				slot_rd_n = 1'b1;
				//	T1
				@( negedge slot_ioreq_n );
				#10ns slot_rd_n = 1'b0;
				@( posedge slot_ioreq_n );
				rdata = slot_d;
				slot_rd_n = 1'b1;
			end
		join
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	task check_isolated;
		if( slot_wait !== 1'b0 || slot_intr !== 1'b0 ||
			slot_busdir !== 1'b0 || u_dut.w_bus_valid !== 1'b0 ||
			(slot_wr_n && slot_d !== 8'hZZ) ) begin
			$fatal( 1, "Disconnected slot drives or accepts a bus cycle" );
		end
	endtask

	initial begin
		logic			time_out;
		logic	[7:0]	data;
		integer			errors;

		test_no = -1;
		errors = 0;
		clk = 1;
		slot_reset_n = 0;
		slot_a = 0;
		slot_sltsl_n = 1;
		slot_mereq_n = 1;
		slot_ioreq_n = 1;
		slot_wr_n = 1;
		slot_rd_n = 1;
		p_slot_clk = 0;
		ff_slot_data = 0;
		dipsw = 2'b10;

		@( negedge clk );
		@( negedge clk );

		slot_reset_n = 1;

		@( posedge clk );
		@( posedge clk );

		repeat( 100 ) @( posedge clk );
		force u_dut.w_int_n = 1'b0;
		check_isolated();
		release u_dut.w_int_n;
		write_io( 16'h8040, 8'h80 );
		read_io( 16'h0040, data );
		if( data !== 8'hZZ || u_dut.u_system_controller.ff_enable !== 1'b0 ) begin
			$fatal( 1, "DIP OFF did not block I/O reads/writes" );
		end
		slot_a = 16'h4000;
		slot_sltsl_n = 0;
		slot_mereq_n = 0;
		slot_rd_n = 0;
		repeat( 20 ) @( negedge u_dut.clk_42m );
		check_isolated();
		if( u_dut.w_cpu_valid !== 1'b0 ) $fatal( 1, "DIP OFF issued a memory read" );
		slot_rd_n = 1;
		slot_a = 16'h5000;
		ff_slot_data = 8'h05;
		slot_wr_n = 0;
		repeat( 20 ) @( negedge u_dut.clk_42m );
		check_isolated();
		slot_wr_n = 1;
		slot_sltsl_n = 1;
		slot_mereq_n = 1;

		// Reject switch bounce, and never connect halfway through a read.
		for( j = 0; j < 3; j = j + 1 ) begin
			dipsw[1] = 0;
			repeat( 100 ) @( negedge u_dut.clk_42m );
			dipsw[1] = 1;
			repeat( 100 ) @( negedge u_dut.clk_42m );
			check_isolated();
		end
		slot_a = 16'h0098;
		slot_ioreq_n = 0;
		slot_rd_n = 0;
		dipsw[1] = 0;
		#2ms;
		if( !u_dut.ff_slot_connect_request || u_dut.ff_slot_connected ) begin
			$fatal( 1, "Connection did not wait for the active read to end" );
		end
		check_isolated();
		slot_ioreq_n = 1;
		slot_rd_n = 1;
		repeat( 10 ) @( negedge u_dut.clk_42m );
		if( !u_dut.ff_slot_connected || u_dut.w_bus_valid ) begin
			$fatal( 1, "Idle connection failed or generated a phantom access" );
		end
		if( slot_wait !== 1'b1 || u_dut.w_wait_n !== 1'b0 ) begin
			$fatal( 1, "Connected slot did not wait for the running boot copy" );
		end
		force u_dut.w_int_n = 1'b0;
		#1ns;
		if( slot_intr !== 1'b1 ) $fatal( 1, "Connected interrupt was blocked" );
		release u_dut.w_int_n;
		$display( "[PASS] DIP OFF isolation, debounce, idle-only connection and boot WAIT" );

		// Z80 immediate I/O places A on A15-A8; only A7-A0 select the port.
		write_io( 16'h8040, 8'h80 );
		read_io( 16'h8040, data );
		if( data !== 8'h7F ) begin
			$display( "[ERROR] 40h = %02X, expected 7F (enable=%b, rdata_en=%b, busdir=%b)",
				data, u_dut.u_system_controller.ff_enable,
				u_dut.w_bus_sysctrl_rdata_en, slot_busdir );
			errors = errors + 1;
		end
		write_io( 8'h41, 8'h02 );
		read_io( 8'h41, data );
		if( data !== 8'hFD ) begin
			$display( "[ERROR] 41h = %02X, expected FD", data );
			errors = errors + 1;
		end
		write_io( 8'h42, 8'h01 );
		read_io( 8'h42, data );
		if( data !== 8'hFE ) begin
			$display( "[ERROR] 42h = %02X, expected FE", data );
			errors = errors + 1;
		end
		write_io( 8'h40, 8'h00 );
		read_io( 8'h40, data );
		if( data !== 8'hZZ ) begin
			$display( "[ERROR] disabled 40h drives %02X", data );
			errors = errors + 1;
		end
		for( i = 0; i < 4; i = i + 1 ) begin
			read_io( 16'h0040 + i, data );
			if( data !== 8'hZZ ) begin
				$display( "[ERROR] disabled port %04X drives %02X", 16'h0040 + i, data );
				errors = errors + 1;
			end
		end
		read_io( 16'h0098, data );
		if( data !== 8'hZZ ) begin
			$display( "[ERROR] foreign port 98h drives %02X", data );
			errors = errors + 1;
		end

		// Disconnect a driven read and reject subsequent writes without resetting
		// the controller or starting another boot copy.
		write_io( 16'h0040, 8'h80 );
		slot_a = 16'h0040;
		slot_ioreq_n = 0;
		slot_rd_n = 0;
		repeat( 10 ) @( negedge u_dut.clk_42m );
		if( slot_d !== 8'h7F || !slot_busdir ) $fatal( 1, "Read did not start" );
		dipsw[1] = 1;
		#2ms;
		check_isolated();
		if( u_dut.u_msx_slot.ff_rdata_en ) $fatal( 1, "Disconnect retained read enable" );
		slot_ioreq_n = 1;
		slot_rd_n = 1;
		write_io( 16'h0040, 8'h00 );
		if( u_dut.u_system_controller.ff_enable !== 1'b1 ) begin
			$fatal( 1, "DIP OFF write changed the controller state" );
		end
		slot_a = 16'h0040;
		ff_slot_data = 8'h00;
		slot_ioreq_n = 0;
		slot_wr_n = 0;
		dipsw[1] = 0;
		#2ms;
		check_isolated();
		if( !u_dut.ff_slot_connect_request || u_dut.ff_slot_connected ) begin
			$fatal( 1, "Connection did not wait for the active write to end" );
		end
		slot_ioreq_n = 1;
		slot_wr_n = 1;
		repeat( 10 ) @( negedge u_dut.clk_42m );
		read_io( 16'h0040, data );
		if( data !== 8'h7F ) $fatal( 1, "Reconnect lost the controller state" );
		$display( "[PASS] Disconnect during read, output release and idle-only write reconnection" );
		wait( u_dut.w_wait_n === 1'b1 );
		repeat( 20 ) @( negedge u_dut.clk_42m );
		if( slot_wait !== 1'b0 ) $fatal( 1, "Boot copy did not release WAIT" );
		slot_a = 16'h4000;
		slot_sltsl_n = 0;
		slot_mereq_n = 0;
		slot_rd_n = 0;
		repeat( 100 ) @( negedge u_dut.clk_42m );
		if( slot_d !== 8'hFF || slot_busdir !== 1'b1 || slot_wait !== 1'b0 ) begin
			$fatal( 1, "Connected ROM read failed after boot copy" );
		end
		slot_sltsl_n = 1;
		slot_mereq_n = 1;
		slot_rd_n = 1;
		$display( "[PASS] Boot copy completed without reset and connected ROM read succeeded" );
		if( errors == 0 ) begin
			$display( "[RESULT] System Controller detection through MSX slot: PASS" );
		end
		else begin
			$fatal( 1, "System Controller detection: %0d errors", errors );
		end
		$finish;
	end

	initial begin
		#40ms;
		$fatal( 1, "Top-level bus test timed out" );
	end
endmodule
