// -----------------------------------------------------------------------------
//	Test of scc_bank.v (MSX -> SCC mapper -> SerialSRAM path)
//	Copyright (C)2026 Takayuki Hara (HRA!)
// -----------------------------------------------------------------------------
//	msx_slot + y8960_address_decode + scc + scc_bank + sram_arbiter + ssram
//	+ ssram_test_model. The Z80 bus model samples /WAIT at the falling edge
//	of T2 and Tw, as the real Z80 does.
//	An ADPCM-like requester reads 40000h-7FFFFh concurrently.
// -----------------------------------------------------------------------------

module tb ();
	localparam	clk_serial_base	= 1_000_000_000_000.0 / 171_818_160;	//	ps
	localparam	cpu_clk_base	= 1_000_000_000_000.0 / 3_579_545;		//	ps

	reg				clk_171m;
	reg				clk_42m;
	reg		[1:0]	ff_div;
	reg				cpu_clk;
	reg		[3:0]	ff_enable_cnt;
	reg				ff_enable;
	int				error_count;

	//	slot
	reg				slot_reset_n;
	reg		[15:0]	slot_a;
	wire	[7:0]	slot_d;
	reg				slot_sltsl_n;
	reg				slot_mereq_n;
	reg				slot_ioreq_n;
	reg				slot_wr_n;
	reg				slot_rd_n;
	wire			slot_intr;
	wire			slot_busdir;
	reg		[7:0]	ff_slot_wdata;
	reg				ff_slot_drive;

	//	SRAM
	wire			sram_ce_n;
	wire			sram_sclk;
	wire	[3:0]	sram_sio;

	//	internal
	wire			w_reset_n;
	wire	[15:0]	w_bus_address;
	wire			w_bus_io;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire			w_bus_ready;
	wire	[7:0]	w_bus_wdata;
	wire	[7:0]	w_bus_rdata;
	wire			w_bus_rdata_en;
	wire			w_mixer_reg_en;
	wire			w_bus_ssg_cs;
	wire			w_bus_opll_cs;
	wire			w_bus_opl2_cs;
	reg		[2:0]	mio_seen;
	reg				checking_mio;
	wire			w_bus_scc_cs;
	wire			w_bus_scc_ready;
	wire	[7:0]	w_bus_scc_rdata;
	wire			w_bus_scc_rdata_en;
	wire			w_scc_memory_cs;
	wire	[5:0]	w_scc_ma;
	wire	[7:0]	w_bus_scc_bank_rdata;
	wire			w_bus_scc_bank_rdata_en;
	wire			w_scc_bank_wait_n;
	wire	[17:0]	w_cpu_address;
	wire			w_cpu_valid;
	wire			w_cpu_ready;
	wire			w_cpu_write;
	wire	[7:0]	w_cpu_wdata;
	wire	[7:0]	w_cpu_rdata;
	wire			w_cpu_rdata_en;
	reg		[17:0]	adpcm_address;
	reg				adpcm_valid;
	wire			adpcm_ready;
	wire	[7:0]	adpcm_rdata;
	wire			adpcm_rdata_en;
	wire	[18:0]	w_sram_address;
	wire			w_sram_valid;
	wire			w_sram_ready;
	wire			w_sram_write;
	wire	[7:0]	w_sram_wdata;
	wire	[7:0]	w_sram_rdata;
	wire			w_sram_rdata_en;
	wire			slot_wait;

	assign slot_d		= ff_slot_drive ? ff_slot_wdata : 8'hZZ;
	reg				no_wait;					//	1: /WAIT is not connected (slot_wait = 0)
	assign slot_wait	= ~w_scc_bank_wait_n & ~no_wait;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	msx_slot u_msx_slot (
		.clk					( clk_42m					),
		.slot_enable			( 1'b1					),
		.reset_n				( w_reset_n					),
		.p_slot_reset_n			( slot_reset_n				),
		.p_slot_sltsl_n			( slot_sltsl_n				),
		.p_slot_memreq_n		( slot_mereq_n				),
		.p_slot_ioreq_n			( slot_ioreq_n				),
		.p_slot_wr_n			( slot_wr_n					),
		.p_slot_rd_n			( slot_rd_n					),
		.p_slot_address			( slot_a					),
		.p_slot_data			( slot_d					),
		.p_slot_int				( slot_intr					),
		.p_slot_data_dir		( slot_busdir				),
		.int_n					( 1'b1						),
		.bus_address			( w_bus_address				),
		.bus_io					( w_bus_io					),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_ready				),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_rdata				),
		.bus_rdata_en			( w_bus_rdata_en			),
		.mixer_reg_en			( w_mixer_reg_en			),
		.ssg_volume				(							),
		.opll_volume			(							),
		.opl2_volume			(							),
		.scc_volume				(							),
		.master_volume			(							)
	);

	assign w_mixer_reg_en = 1'b1;

	y8960_address_decode u_address_decode (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.bus_address			( w_bus_address				),
		.bus_io					( w_bus_io					),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_ready				),
		.bus_wdata				( w_bus_wdata				),
		.bus_timer_cs			(							),
		.bus_opll_cs			( w_bus_opll_cs				),
		.bus_opl2_cs			( w_bus_opl2_cs				),
		.bus_ssg_cs				( w_bus_ssg_cs				),
		.bus_scc_cs				( w_bus_scc_cs				),
		.bus_sysctrl_cs			(							),
		.bus_timer_ready		( 1'b0						),
		.bus_opll_ready			( 1'b1						),
		.bus_opl2_ready			( 1'b1						),
		.bus_ssg_ready			( 1'b1						),
		.bus_scc_ready			( w_bus_scc_ready			),
		.bus_sysctrl_ready		( 1'b0						),
		.memory_io_en			( w_mixer_reg_en			),
		.led					(							)
	);

	assign w_bus_rdata		= w_bus_scc_rdata & w_bus_scc_bank_rdata;
	assign w_bus_rdata_en	= w_bus_scc_rdata_en | w_bus_scc_bank_rdata_en;

	scc u_scc (
		.reset_n				( w_reset_n					),
		.clk					( clk_42m					),
		.enable					( ff_enable					),
		.bus_cs					( w_bus_scc_cs				),
		.bus_address			( w_bus_address				),
		.bus_write				( w_bus_write				),
		.bus_ready				( w_bus_scc_ready			),
		.bus_valid				( w_bus_valid				),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_scc_rdata			),
		.bus_rdata_en			( w_bus_scc_rdata_en		),
		.scc_memory_cs			( w_scc_memory_cs			),
		.scc_ma					( w_scc_ma					),
		.sound_l_out			(							),
		.sound_r_out			(							)
	);

	scc_bank u_scc_bank (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.bus_cs					( w_bus_scc_cs				),
		.bus_address			( w_bus_address				),
		.bus_io					( w_bus_io					),
		.bus_valid				( w_bus_valid				),
		.bus_write				( w_bus_write				),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_scc_bank_rdata		),
		.bus_rdata_en			( w_bus_scc_bank_rdata_en	),
		.wait_n					( w_scc_bank_wait_n			),
		.scc_memory_cs_n		( w_scc_memory_cs			),
		.scc_ma					( w_scc_ma					),
		.cpu_address			( w_cpu_address				),
		.cpu_valid				( w_cpu_valid				),
		.cpu_ready				( w_cpu_ready				),
		.cpu_write				( w_cpu_write				),
		.cpu_wdata				( w_cpu_wdata				),
		.cpu_rdata				( w_cpu_rdata				),
		.cpu_rdata_en			( w_cpu_rdata_en			)
	);

	sram_arbiter u_sram_arbiter (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.cpu_address			( w_cpu_address				),
		.cpu_valid				( w_cpu_valid				),
		.cpu_ready				( w_cpu_ready				),
		.cpu_write				( w_cpu_write				),
		.cpu_wdata				( w_cpu_wdata				),
		.cpu_rdata				( w_cpu_rdata				),
		.cpu_rdata_en			( w_cpu_rdata_en			),
		.adpcm_address			( adpcm_address				),
		.adpcm_valid			( adpcm_valid				),
		.adpcm_ready			( adpcm_ready				),
		.adpcm_write			( 1'b0						),
		.adpcm_wdata			( 8'h00						),
		.adpcm_rdata			( adpcm_rdata				),
		.adpcm_rdata_en			( adpcm_rdata_en			),
		.ssram_address			( w_sram_address			),
		.ssram_valid			( w_sram_valid				),
		.ssram_ready			( w_sram_ready				),
		.ssram_write			( w_sram_write				),
		.ssram_wdata			( w_sram_wdata				),
		.ssram_rdata			( w_sram_rdata				),
		.ssram_rdata_en			( w_sram_rdata_en			)
	);

	ssram u_ssram (
		.n_reset				( w_reset_n					),
		.clk					( clk_42m					),
		.clk_serial				( clk_171m					),
		.bus_cs					( 1'b1						),
		.bus_address			( w_sram_address			),
		.bus_write				( w_sram_write				),
		.bus_burst				( 1'b0						),
		.bus_valid				( w_sram_valid				),
		.bus_wdata				( w_sram_wdata				),
		.bus_ready				( w_sram_ready				),
		.bus_rdata				( w_sram_rdata				),
		.bus_rdata_en			( w_sram_rdata_en			),
		.sram_sclk				( sram_sclk					),
		.sram_ce_n				( sram_ce_n					),
		.sram_sio				( sram_sio					)
	);

	ssram_test_model #(
		.VERBOSE				( 0							)
	) u_model (
		.sclk					( sram_sclk					),
		.cs_n					( sram_ce_n					),
		.sio					( sram_sio					)
	);

	// --------------------------------------------------------------------
	//	Clocks
	// --------------------------------------------------------------------
	always #(clk_serial_base/2) begin
		clk_171m <= ~clk_171m;
	end

	always @( posedge clk_171m ) begin
		ff_div	<= ff_div + 2'd1;
		if( ff_div[0] ) begin
			clk_42m <= ~clk_42m;
		end
	end

	always @( posedge clk_42m ) begin
		if( ff_enable_cnt == 4'd11 ) begin
			ff_enable_cnt	<= 4'd0;
			ff_enable		<= 1'b1;
		end
		else begin
			ff_enable_cnt	<= ff_enable_cnt + 4'd1;
			ff_enable		<= 1'b0;
		end
	end

	always #(cpu_clk_base/2) begin
		cpu_clk <= ~cpu_clk;
	end

	// --------------------------------------------------------------------
	//	SRAM pattern
	// --------------------------------------------------------------------
	function [7:0] f_pattern( input [18:0] a );
		f_pattern = a[7:0] ^ { a[15:12], a[11:8] } ^ { a[18:16], 5'b10101 };
	endfunction

	// --------------------------------------------------------------------
	//	SRAM access counter (CPU side)
	// --------------------------------------------------------------------
	int				cpu_access_count;
	int				cpu_write_count;
	always @( posedge clk_42m ) begin
		if( checking_mio ) begin
			mio_seen <= mio_seen | { w_bus_ssg_cs, w_bus_opll_cs, w_bus_opl2_cs };
			if( w_bus_scc_cs ) begin
				$display( "[ERROR] MMIO write selected SCC/SRAM: %04X", w_bus_address );
				error_count = error_count + 1;
			end
		end
	end
	always @( posedge clk_42m ) begin
		if( w_cpu_valid && w_cpu_ready ) begin
			cpu_access_count	<= cpu_access_count + 1;
			if( w_cpu_write ) begin
				cpu_write_count	<= cpu_write_count + 1;
			end
		end
	end

	//	The CPU side must never write the ROM area (00000h-1FFFFh)
	always @( posedge clk_42m ) begin
		if( w_cpu_valid && w_cpu_ready && w_cpu_write && !w_cpu_address[17] ) begin
			$display( "[ERROR] CPU write to the ROM area: %05X", w_cpu_address );
			error_count = error_count + 1;
		end
	end

	// --------------------------------------------------------------------
	//	ADPCM-like concurrent reader (40000h-7FFFFh)
	// --------------------------------------------------------------------
	reg				adpcm_enable;
	reg				ff_adpcm_wait_data;
	int				adpcm_read_count;
	int				adpcm_seed;

	always @( posedge clk_42m ) begin
		if( !w_reset_n || !adpcm_enable ) begin
			adpcm_valid			<= 1'b0;
			ff_adpcm_wait_data	<= 1'b0;
		end
		else if( adpcm_valid ) begin
			if( adpcm_ready ) begin
				adpcm_valid			<= 1'b0;
				ff_adpcm_wait_data	<= 1'b1;
			end
		end
		else if( ff_adpcm_wait_data ) begin
			if( adpcm_rdata_en ) begin
				ff_adpcm_wait_data	<= 1'b0;
				adpcm_read_count	<= adpcm_read_count + 1;
				if( adpcm_rdata != f_pattern( { 1'b1, adpcm_address } ) ) begin
					$display( "[ERROR] ADPCM read [%05X] = %02X, expected %02X", { 1'b1, adpcm_address }, adpcm_rdata, f_pattern( { 1'b1, adpcm_address } ) );
					error_count = error_count + 1;
				end
			end
		end
		else begin
			adpcm_address	<= $random( adpcm_seed );
			adpcm_valid		<= 1'b1;
		end
	end

	always @( posedge clk_42m ) begin
		if( w_cpu_rdata_en && adpcm_rdata_en ) begin
			$display( "[ERROR] cpu_rdata_en and adpcm_rdata_en are asserted at the same time" );
			error_count = error_count + 1;
		end
	end

	// --------------------------------------------------------------------
	//	Z80 bus cycles
	// --------------------------------------------------------------------
	task mem_read(
		input	[15:0]	address,
		output	[7:0]	rdata,
		output	int		waits
	);
		@( posedge cpu_clk );						//	T1
		#30ns slot_a = address;
		@( negedge cpu_clk );
		slot_sltsl_n	= 1'b0;
		slot_mereq_n	= 1'b0;
		slot_rd_n		= 1'b0;
		@( posedge cpu_clk );						//	T2
		@( negedge cpu_clk );
		waits = 0;
		while( slot_wait ) begin					//	Tw
			@( posedge cpu_clk );
			@( negedge cpu_clk );
			waits = waits + 1;
		end
		@( posedge cpu_clk );						//	T3
		rdata = slot_d;
		@( negedge cpu_clk );
		slot_sltsl_n	= 1'b1;
		slot_mereq_n	= 1'b1;
		slot_rd_n		= 1'b1;
	endtask

	task mem_write(
		input	[15:0]	address,
		input	[7:0]	wdata,
		output	int		waits
	);
		@( posedge cpu_clk );						//	T1
		#30ns slot_a = address;
		@( negedge cpu_clk );
		slot_sltsl_n	= 1'b0;
		slot_mereq_n	= 1'b0;
		ff_slot_wdata	= wdata;
		ff_slot_drive	= 1'b1;
		@( posedge cpu_clk );						//	T2
		@( negedge cpu_clk );
		slot_wr_n		= 1'b0;						//	/WR and /WAIT sampling at the same edge
		waits = 0;
		while( slot_wait ) begin					//	Tw
			@( posedge cpu_clk );
			@( negedge cpu_clk );
			waits = waits + 1;
		end
		@( posedge cpu_clk );						//	T3
		@( negedge cpu_clk );
		slot_wr_n		= 1'b1;
		slot_sltsl_n	= 1'b1;
		slot_mereq_n	= 1'b1;
		#20ns ff_slot_drive = 1'b0;
	endtask

	task io_cycle(
		input	[7:0]	port,
		input			write
	);
		@( posedge cpu_clk );						//	T1
		#30ns slot_a = { 8'h00, port };
		@( posedge cpu_clk );						//	T2
		slot_ioreq_n	= 1'b0;
		if( write ) begin
			ff_slot_wdata	= 8'h5A;
			ff_slot_drive	= 1'b1;
			slot_wr_n		= 1'b0;
		end
		else begin
			slot_rd_n		= 1'b0;
		end
		@( posedge cpu_clk );						//	TW (automatic I/O wait)
		@( posedge cpu_clk );						//	T3
		@( negedge cpu_clk );
		slot_ioreq_n	= 1'b1;
		slot_rd_n		= 1'b1;
		slot_wr_n		= 1'b1;
		#20ns ff_slot_drive = 1'b0;
	endtask

	//	The cartridge must not drive the data bus in a write cycle, nor in an
	//	I/O cycle of a port that it does not decode (here 98h).
	int				late_response_count;
	always @( posedge clk_42m ) begin
		if( w_cpu_rdata_en && u_scc_bank.ff_rd_issued && slot_rd_n ) begin
			late_response_count = late_response_count + 1;
		end
	end
	always @( posedge clk_42m ) begin
		if( slot_busdir && (!slot_wr_n || (!slot_ioreq_n && slot_a[7:0] == 8'h98)) ) begin
			$display( "[ERROR] data bus is driven in a foreign cycle (ioreq_n=%b wr_n=%b a=%04X) at %t", slot_ioreq_n, slot_wr_n, slot_a, $realtime );
			error_count = error_count + 1;
		end
	end

	task write_reg( input [15:0] address, input [7:0] wdata );
		int waits;
		mem_write( address, wdata, waits );
		repeat( 2 ) @( posedge cpu_clk );
	endtask

	task check_read(
		input	[15:0]	address,
		input	[18:0]	sram_address,
		input	string	name
	);
		logic	[7:0]	rdata;
		int				waits;
		mem_read( address, rdata, waits );
		if( rdata !== u_model.mem[sram_address] ) begin
			$display( "[ERROR] %s: read %04X (SRAM %05X) = %02X, expected %02X (wait %0d)", name, address, sram_address, rdata, u_model.mem[sram_address], waits );
			error_count = error_count + 1;
		end
		else if( waits == 0 ) begin
			$display( "[ERROR] %s: read %04X was not waited", name, address );
			error_count = error_count + 1;
		end
	endtask

	task check_sram( input [18:0] sram_address, input [7:0] expected, input string name );
		if( u_model.mem[sram_address] !== expected ) begin
			$display( "[ERROR] %s: SRAM[%05X] = %02X, expected %02X", name, sram_address, u_model.mem[sram_address], expected );
			error_count = error_count + 1;
		end
	endtask

	task wait_idle();
		//	wait until all posted writes are written
		repeat( 200 ) @( posedge clk_42m );
	endtask

	task check_mio_bank( input bit ram_mode, input [5:0] bank );
		int count, waits;
		reg [7:0] saved_sram [0:15];
		reg [17:0] address;
		write_reg( 16'h4FFB, 8'h01 );
		write_reg( 16'h4FFD, { 2'b00, bank } );
		write_reg( 16'h4FFB, { 7'd0, ram_mode } );
		wait_idle();
		$display( "[TEST] MMIO RAM Mode=%0d BANK1=#%0d", ram_mode, bank );

		//	The address immediately below MMIO must retain its memory/SCC function.
		mem_write( 16'h7FEF, 8'h00, waits );
		wait_idle();
		if( ram_mode && bank == 6'd63 ) begin
			if( u_scc.u_ikascc.IKASCC_SYNC_MODE.u_player_main.test !== 8'h00 ) begin
				$display( "[ERROR] 7FEFh did not reach SCC mode register" );
				error_count++;
			end
		end
		else if( ram_mode && bank[4] ) begin
			check_sram( { 1'b0, bank[4:0], 13'h1FEF }, 8'h00, "7FEFh RAM boundary" );
		end

		for( int offset = 0; offset < 16; offset++ ) begin
			address = { bank[4:0], 13'h1FF0 } + offset;
			saved_sram[offset] = u_model.mem[address];
		end
		count = cpu_access_count;
		mio_seen = 3'b000;
		checking_mio = 1'b1;
		for( int offset = 0; offset < 16; offset++ ) begin
			mem_write( 16'h7FF0 + offset, 8'h20 + offset, waits );
			if( waits != 0 ) begin
				$display( "[ERROR] MMIO write waited: 7FF%01X", offset );
				error_count++;
			end
		end
		checking_mio = 1'b0;
		wait_idle();
		if( cpu_access_count != count || mio_seen !== 3'b111 ) begin
			$display( "[ERROR] MMIO SRAM accesses=%0d, sound selects=%03b", cpu_access_count - count, mio_seen );
			error_count++;
		end
		if( u_msx_slot.ff_ssg_volume !== 8'h27 || u_msx_slot.ff_opll_volume !== 8'h28 ||
			u_msx_slot.ff_opl2_volume !== 8'h29 || u_msx_slot.ff_scc_volume !== 8'h2A ||
			u_msx_slot.ff_master_volume !== 8'h2E ) begin
			$display( "[ERROR] MMIO volume registers did not update" );
			error_count++;
		end
		if( u_address_decode.ff_opll_io_en !== 1'b0 || u_address_decode.ff_timer_io_en !== 1'b0 ||
			u_address_decode.ff_ssg_io_en !== 1'b1 || u_address_decode.ff_opl2_io_en !== 1'b1 ) begin
			$display( "[ERROR] MMIO I/O enablers did not update" );
			error_count++;
		end
		if( ram_mode && bank == 6'd63 &&
			u_scc.u_ikascc.IKASCC_SYNC_MODE.u_player_main.test !== 8'h00 ) begin
			$display( "[ERROR] MMIO writes changed SCC mode register" );
			error_count++;
		end
		for( int offset = 0; offset < 16; offset++ ) begin
			address = { bank[4:0], 13'h1FF0 } + offset;
			check_sram( { 1'b0, address }, saved_sram[offset], "MMIO preserves SRAM" );
		end
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		logic	[7:0]	rdata;
		int				waits;
		int				max_waits;
		int				count;
		int				i;

		clk_171m		= 0;
		clk_42m			= 0;
		ff_div			= 0;
		cpu_clk			= 0;
		ff_enable_cnt	= 0;
		ff_enable		= 0;
		error_count		= 0;
		slot_reset_n	= 0;
		slot_a			= 0;
		slot_sltsl_n	= 1;
		slot_mereq_n	= 1;
		slot_ioreq_n	= 1;
		slot_wr_n		= 1;
		slot_rd_n		= 1;
		ff_slot_wdata	= 0;
		ff_slot_drive	= 0;
		adpcm_enable	= 0;
		no_wait			= 0;
		adpcm_address	= 0;
		adpcm_read_count	= 0;
		adpcm_seed		= 1;
		cpu_access_count	= 0;
		cpu_write_count		= 0;
		checking_mio		= 0;
		mio_seen			= 0;

		for( i = 0; i < 512 * 1024; i++ ) begin
			u_model.mem[i] = f_pattern( i );
		end

		#1us;
		slot_reset_n	= 1;
		//	SerialSRAM power-up and SQI mode entry
		wait( u_ssram.ff_init_s2 );
		repeat( 20 ) @( posedge clk_42m );

		// ----------------------------------------------------------------
		$display( "[TEST] Compatible mode: default banks 0-3" );
		check_read( 16'h4000, 19'h00000, "bank0" );
		check_read( 16'h5FFF, 19'h01FFF, "bank0" );
		check_read( 16'h6123, 19'h02123, "bank1" );
		check_read( 16'h8000, 19'h04000, "bank2" );
		check_read( 16'hBFFF, 19'h07FFF, "bank3" );

		// ----------------------------------------------------------------
		$display( "[TEST] Compatible mode: bank switch and ROM protection" );
		count = cpu_write_count;
		write_reg( 16'h5000, 8'h05 );		//	BANK0 = #5
		write_reg( 16'h7000, 8'h1F );		//	BANK1 = #31 (RAM area, but compatible mode)
		write_reg( 16'h9000, 8'h10 );		//	BANK2 = #16
		write_reg( 16'hB000, 8'h0F );		//	BANK3 = #15
		check_read( 16'h4010, 19'h0A010, "bank0=#5" );
		check_read( 16'h7FFE, 19'h3FFFE, "bank1=#31" );
		check_read( 16'h8001, 19'h20001, "bank2=#16" );
		check_read( 16'hA002, 19'h1E002, "bank3=#15" );
		mem_write( 16'h6000, 8'hAA, waits );
		mem_write( 16'h8001, 8'hBB, waits );
		wait_idle();
		if( cpu_write_count != count ) begin
			$display( "[ERROR] SRAM was written in compatible mode" );
			error_count = error_count + 1;
		end
		check_sram( 19'h3E000, f_pattern( 19'h3E000 ), "compatible mode write" );
		check_sram( 19'h20001, f_pattern( 19'h20001 ), "compatible mode write" );

		// ----------------------------------------------------------------
		$display( "[TEST] SCC register window and outside of 4000h-BFFFh" );
		write_reg( 16'h9000, 8'h3F );		//	BANK2 = 3Fh: SCC registers at 9800h-9FFFh
		count = cpu_access_count;
		mem_read( 16'h9800, rdata, waits );
		max_waits = waits;
		mem_write( 16'h9800, 8'h12, waits );
		mem_read( 16'h0000, rdata, waits );
		max_waits = max_waits + waits;
		mem_read( 16'hC000, rdata, waits );
		max_waits = max_waits + waits;
		wait_idle();
		if( cpu_access_count != count || max_waits != 0 ) begin
			$display( "[ERROR] SRAM was accessed (%0d) or waited (%0d)", cpu_access_count - count, max_waits );
			error_count = error_count + 1;
		end
		//	BANK#63 outside of the SCC register window is unconnected.
		count = cpu_access_count;
		mem_read( 16'h9000, rdata, waits );
		wait_idle();
		if( cpu_access_count != count || waits != 0 || (rdata !== 8'hzz && rdata !== 8'hFF) ) begin
			$display( "[ERROR] bank2=3Fh, 9000h is not unconnected: access %0d, wait %0d, read %02X", cpu_access_count - count, waits, rdata );
			error_count = error_count + 1;
		end
		write_reg( 16'h9000, 8'h02 );		//	BANK2 = #2

		// ----------------------------------------------------------------
		$display( "[TEST] RAM mode (Y8960 mode)" );
		adpcm_enable	= 1;
		write_reg( 16'h4FFB, 8'h01 );		//	RAM mode
		write_reg( 16'h4FFD, 8'h11 );		//	BANK1 = #17
		write_reg( 16'h4FFE, 8'h03 );		//	BANK2 = #3
		write_reg( 16'h4FFF, 8'h1E );		//	BANK3 = #30
		write_reg( 16'h4FFC, 8'h00 );		//	BANK0 = #0
		check_read( 16'h6000, 19'h22000, "bank1=#17" );
		check_read( 16'h8000, 19'h06000, "bank2=#3" );
		check_read( 16'hBFFF, 19'h3DFFF, "bank3=#30" );

		//	single write and read back
		mem_write( 16'h6000, 8'hA5, waits );
		check_read( 16'h6000, 19'h22000, "read after write" );
		check_sram( 19'h22000, 8'hA5, "single write" );

		//	back-to-back writes (posted)
		max_waits = 0;
		for( i = 0; i < 16; i++ ) begin
			mem_write( 16'h6100 + i, 8'h30 + i, waits );
			if( waits > max_waits ) max_waits = waits;
		end
		$display( "[INFO] back-to-back writes: max wait = %0d", max_waits );
		check_read( 16'h610F, 19'h2210F, "read after back-to-back writes" );
		for( i = 0; i < 16; i++ ) begin
			check_sram( 19'h22100 + i, 8'h30 + i, "back-to-back write" );
		end

		//	write then read different address immediately
		mem_write( 16'hA000, 8'h5A, waits );
		check_read( 16'hA000, 19'h3C000, "bank3 read after write" );
		check_sram( 19'h3C000, 8'h5A, "bank3 write" );

		//	ROM banks are not writable in RAM mode
		count = cpu_write_count;
		mem_write( 16'h8000, 8'h77, waits );
		mem_write( 16'h4000, 8'h66, waits );
		wait_idle();
		if( cpu_write_count != count ) begin
			$display( "[ERROR] ROM banks were written in RAM mode" );
			error_count = error_count + 1;
		end
		check_sram( 19'h06000, f_pattern( 19'h06000 ), "ROM bank write" );
		check_sram( 19'h00000, f_pattern( 19'h00000 ), "ROM bank write" );

		//	BANK0 is read only even if a RAM bank is selected
		count = cpu_write_count;
		write_reg( 16'h4FFC, 8'h12 );		//	BANK0 = #18 (RAM bank)
		check_read( 16'h4123, 19'h24123, "bank0=#18" );
		mem_write( 16'h4123, 8'h99, waits );
		write_reg( 16'h4FFE, 8'h03 );		//	register write through BANK0 page
		wait_idle();
		if( cpu_write_count != count ) begin
			$display( "[ERROR] BANK0 page was written in RAM mode" );
			error_count = error_count + 1;
		end
		check_sram( 19'h24123, f_pattern( 19'h24123 ), "BANK0 write" );
		check_sram( 19'h25FFE, f_pattern( 19'h25FFE ), "BANK0 register write" );
		write_reg( 16'h4FFC, 8'h00 );		//	BANK0 = #0

		//	mixed sequence
		max_waits = 0;
		for( i = 0; i < 64; i++ ) begin
			mem_write( 16'h7000 + i * 3, i ^ 8'hC3, waits );
			mem_read( 16'h7000 + i * 3, rdata, waits );
			if( waits > max_waits ) max_waits = waits;
			if( rdata !== (i ^ 8'hC3) ) begin
				$display( "[ERROR] mixed: read %04X = %02X, expected %02X", 16'h7000 + i * 3, rdata, i ^ 8'hC3 );
				error_count = error_count + 1;
			end
		end
		$display( "[INFO] read with ADPCM traffic: max wait = %0d T-states", max_waits );

		//	no /WAIT (RAM mode, BANK1 = #17): late SerialSRAM read responses
		//	must be discarded instead of being driven in following cycles.
		no_wait = 1;
		late_response_count = 0;
		for( i = 0; i < 64; i++ ) begin
			mem_write( 16'h6000 + i, i, waits );
			mem_write( 16'h6100 + i, i, waits );
			mem_read( 16'h6000 + i, rdata, waits );
			io_cycle( 8'h98, 1'b0 );
			io_cycle( 8'h98, 1'b1 );
			mem_write( 16'h6200 + i, i, waits );
		end
		no_wait = 0;
		wait_idle();
		$display( "[INFO] no /WAIT sequence finished: late responses = %0d", late_response_count );

		//	no /WAIT, SerialSRAM blocked (as during the boot copy): the response
		//	arrives in the middle of a following I/O read/write cycle.
		no_wait = 1;
		for( i = 0; i < 8; i++ ) begin
			force u_scc_bank.cpu_ready = 1'b0;
			mem_read( 16'h6000 + i, rdata, waits );
			fork
				io_cycle( 8'h98, i[0] );
				begin
					wait( !slot_ioreq_n );
					release u_scc_bank.cpu_ready;
				end
			join
		end
		no_wait = 0;
		wait_idle();
		$display( "[INFO] no /WAIT with blocked SerialSRAM finished" );

		wait_idle();
		adpcm_enable	= 0;
		wait_idle();
		$display( "[INFO] ADPCM reads during the test: %0d", adpcm_read_count );
		if( adpcm_read_count < 100 ) begin
			$display( "[ERROR] ADPCM requester was starved" );
			error_count = error_count + 1;
		end

		for( int mode = 0; mode < 2; mode++ ) begin
			for( int bank = 0; bank < 64; bank++ ) begin
				check_mio_bank( mode != 0, bank );
			end
		end

		if( error_count == 0 ) begin
			$display( "[RESULT] ALL TESTS PASSED" );
		end
		else begin
			$display( "[RESULT] %0d ERROR(S)", error_count );
		end
		$finish;
	end

	initial begin
		#20ms;
		$display( "[ERROR] timeout" );
		$finish;
	end
endmodule
