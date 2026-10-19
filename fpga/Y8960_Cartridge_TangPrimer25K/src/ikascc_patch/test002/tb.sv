// -----------------------------------------------------------------------------
//	Test of scc.v stereo panning (9900h-9904h: SCC Ch.A-E PAN)
//	Copyright (C)2026 Takayuki Hara (HRA!)
// -----------------------------------------------------------------------------

module tb ();
	localparam	clk_base	= 1_000_000_000_000.0 / 42_954_540;	//	ps

	reg				clk;
	reg				reset_n;
	reg		[3:0]	ff_enable_cnt;
	reg				enable;
	reg				bus_cs;
	reg		[15:0]	bus_address;
	reg				bus_write;
	reg				bus_valid;
	reg		[7:0]	bus_wdata;
	wire			bus_ready;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	wire			scc_memory_cs;
	wire	[5:0]	scc_ma;
	wire	[10:0]	sound_l_out;
	wire	[10:0]	sound_r_out;
	int				error_count;

	scc u_dut (
		.reset_n				( reset_n				),
		.clk					( clk					),
		.enable					( enable				),
		.bus_cs					( bus_cs				),
		.bus_address			( bus_address			),
		.bus_write				( bus_write				),
		.bus_ready				( bus_ready				),
		.bus_valid				( bus_valid				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_en			( bus_rdata_en			),
		.scc_memory_cs			( scc_memory_cs			),
		.scc_ma					( scc_ma				),
		.sound_l_out			( sound_l_out			),
		.sound_r_out			( sound_r_out			)
	);

	always #(clk_base/2) clk = ~clk;

	always @( posedge clk ) begin
		if( ff_enable_cnt == 4'd11 ) begin
			ff_enable_cnt	<= 4'd0;
			enable			<= 1'b1;
		end
		else begin
			ff_enable_cnt	<= ff_enable_cnt + 4'd1;
			enable			<= 1'b0;
		end
	end

	// --------------------------------------------------------------------
	task write_mem( input [15:0] address, input [7:0] data );
		@( posedge clk );
		bus_address	<= address;
		bus_wdata	<= data;
		bus_write	<= 1'b1;
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		repeat( 36 ) @( posedge clk );
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		bus_write	<= 1'b0;
		repeat( 36 ) @( posedge clk );
	endtask

	task read_mem( input [15:0] address, output [7:0] data );
		@( posedge clk );
		bus_address	<= address;
		bus_write	<= 1'b0;
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		repeat( 36 ) @( posedge clk );
		#1;
		data		= bus_rdata;
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		repeat( 36 ) @( posedge clk );
	endtask

	task check_mem( input string name, input [15:0] address, input [7:0] expected );
		reg		[7:0]	data;
		read_mem( address, data );
		if( data == expected ) begin
			$display( "OK   : %s [%04X]=%02X", name, address, data );
		end
		else begin
			$display( "ERROR: %s [%04X] expected %02X, actual %02X", name, address, expected, data );
			error_count++;
		end
	endtask

	task check_pan( input string name, input [7:0] a, input [7:0] b, input [7:0] c, input [7:0] d, input [7:0] e );
		if( u_dut.ff_pan_a == a && u_dut.ff_pan_b == b && u_dut.ff_pan_c == c && u_dut.ff_pan_d == d && u_dut.ff_pan_e == e ) begin
			$display( "OK   : %s PAN=%0d,%0d,%0d,%0d,%0d", name, a, b, c, d, e );
		end
		else begin
			$display( "ERROR: %s PAN expected %0d,%0d,%0d,%0d,%0d actual %0d,%0d,%0d,%0d,%0d", name,
				a, b, c, d, e, u_dut.ff_pan_a, u_dut.ff_pan_b, u_dut.ff_pan_c, u_dut.ff_pan_d, u_dut.ff_pan_e );
			error_count++;
		end
	endtask

	task check_sound( input string name, input signed [7:0] sa, input signed [7:0] sb, input signed [7:0] sc,
			input signed [7:0] sd, input signed [7:0] se, input signed [10:0] expected_l, input signed [10:0] expected_r );
		force u_dut.w_sound_ch = { se, sd, sc, sb, sa };
		repeat( 40 ) @( posedge clk );
		#1;
		if( $signed( sound_l_out ) == expected_l && $signed( sound_r_out ) == expected_r ) begin
			$display( "OK   : %s L=%0d R=%0d", name, $signed( sound_l_out ), $signed( sound_r_out ) );
		end
		else begin
			$display( "ERROR: %s expected L=%0d R=%0d, actual L=%0d R=%0d", name,
				expected_l, expected_r, $signed( sound_l_out ), $signed( sound_r_out ) );
			error_count++;
		end
		release u_dut.w_sound_ch;
	endtask

	// --------------------------------------------------------------------
	initial begin
		clk				= 1'b0;
		reset_n			= 1'b0;
		ff_enable_cnt	= 4'd0;
		enable			= 1'b0;
		bus_cs			= 1'b0;
		bus_address		= 16'h0000;
		bus_write		= 1'b0;
		bus_valid		= 1'b0;
		bus_wdata		= 8'h00;
		error_count		= 0;

		repeat( 30 ) @( posedge clk );
		reset_n			= 1'b1;
		repeat( 30 ) @( posedge clk );

		check_pan( "reset default", 128, 128, 128, 128, 128 );

		//	SCC register window is closed: PAN must not change.
		write_mem( 16'h9900, 8'd1 );
		check_pan( "write while bank2 != 3Fh", 128, 128, 128, 128, 128 );

		//	Open SCC register window, initialize wave RAM Ch.A [00h-05h]
		write_mem( 16'h9000, 8'h3F );
		write_mem( 16'h9800, 8'h11 );
		write_mem( 16'h9801, 8'h22 );
		write_mem( 16'h9802, 8'h33 );
		write_mem( 16'h9803, 8'h44 );
		write_mem( 16'h9804, 8'h55 );
		write_mem( 16'h9805, 8'h66 );

		//	PAN registers
		write_mem( 16'h9900, 8'd1 );
		write_mem( 16'h9901, 8'd255 );
		write_mem( 16'h9902, 8'd64 );
		write_mem( 16'h9903, 8'd200 );
		write_mem( 16'h9904, 8'd128 );
		check_pan( "PAN write", 1, 255, 64, 200, 128 );

		//	PAN writes must not reach wave RAM 9800h-9804h
		check_mem( "wave RAM A[0] kept", 16'h9800, 8'h11 );
		check_mem( "wave RAM A[1] kept", 16'h9801, 8'h22 );
		check_mem( "wave RAM A[2] kept", 16'h9802, 8'h33 );
		check_mem( "wave RAM A[3] kept", 16'h9803, 8'h44 );
		check_mem( "wave RAM A[4] kept", 16'h9804, 8'h55 );

		//	9905h is not a PAN register: original mirror behavior is kept.
		write_mem( 16'h9905, 8'h77 );
		check_mem( "9905h mirrors 9805h", 16'h9805, 8'h77 );
		check_pan( "9905h does not change PAN", 1, 255, 64, 200, 128 );

		//	Panning
		write_mem( 16'h9902, 8'd1 );
		write_mem( 16'h9903, 8'd255 );
		check_sound( "A left, B right", 8'sd100, -8'sd50, 8'sd0, 8'sd0, 8'sd0, 11'sd100, -11'sd50 );
		check_sound( "C left, D right", 8'sd0, 8'sd0, 8'sd127, -8'sd128, 8'sd0, 11'sd127, -11'sd128 );
		//	center: 100 * 181 / 256 = 70.7 -> 70
		check_sound( "E center", 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd100, 11'sd70, 11'sd70 );

		write_mem( 16'h9900, 8'd128 );
		write_mem( 16'h9901, 8'd128 );
		write_mem( 16'h9902, 8'd128 );
		write_mem( 16'h9903, 8'd128 );
		write_mem( 16'h9904, 8'd128 );
		//	5 * 127 * 181 / 256 = 448.9 -> 448
		check_sound( "all center max", 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 11'sd448, 11'sd448 );
		//	5 * -128 * 181 / 256 = -452.5 -> -453
		check_sound( "all center min", -8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128, -11'sd453, -11'sd453 );

		write_mem( 16'h9900, 8'd1 );
		write_mem( 16'h9901, 8'd1 );
		write_mem( 16'h9902, 8'd1 );
		write_mem( 16'h9903, 8'd1 );
		write_mem( 16'h9904, 8'd1 );
		check_sound( "all left min", -8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128, -11'sd640, 11'sd0 );

		//	Real IKASCC output: Ch.A only, PAN = left
		for( int i = 0; i < 32; i++ ) begin
			write_mem( 16'h9800 + i, 8'h40 );
		end
		write_mem( 16'h9880, 8'h10 );
		write_mem( 16'h9881, 8'h00 );
		write_mem( 16'h988A, 8'h0F );
		write_mem( 16'h988F, 8'h01 );
		repeat( 2000 ) @( posedge clk );
		#1;
		if( $signed( sound_l_out ) > 0 && $signed( sound_r_out ) == 0 ) begin
			$display( "OK   : real Ch.A left L=%0d R=%0d", $signed( sound_l_out ), $signed( sound_r_out ) );
		end
		else begin
			$display( "ERROR: real Ch.A left L=%0d R=%0d", $signed( sound_l_out ), $signed( sound_r_out ) );
			error_count++;
		end
		write_mem( 16'h9900, 8'd255 );
		repeat( 100 ) @( posedge clk );
		#1;
		if( $signed( sound_l_out ) == 0 && $signed( sound_r_out ) > 0 ) begin
			$display( "OK   : real Ch.A right L=%0d R=%0d", $signed( sound_l_out ), $signed( sound_r_out ) );
		end
		else begin
			$display( "ERROR: real Ch.A right L=%0d R=%0d", $signed( sound_l_out ), $signed( sound_r_out ) );
			error_count++;
		end
		write_mem( 16'h9900, 8'd1 );

		//	RAM Mode = 1: PAN registers are not available (spec: RAM Mode=0 only),
		//	and the write must not reach wave RAM 9800h either.
		write_mem( 16'h9800, 8'h40 );
		write_mem( 16'h4FFB, 8'h01 );
		write_mem( 16'h4FFE, 8'h3F );
		write_mem( 16'h9900, 8'd200 );
		write_mem( 16'h9904, 8'd200 );
		check_pan( "write in RAM Mode=1 ignored", 1, 1, 1, 1, 1 );
		write_mem( 16'h4FFB, 8'h00 );
		check_mem( "RAM Mode=1 PAN write did not reach 9800h", 16'h9800, 8'h40 );
		write_mem( 16'h9904, 8'd200 );
		check_pan( "write after back to RAM Mode=0", 1, 1, 1, 1, 200 );
		write_mem( 16'h9904, 8'd1 );

		//	Close SCC register window: PAN must not change.
		write_mem( 16'h9000, 8'h00 );
		write_mem( 16'h9900, 8'd255 );
		check_pan( "write after window closed", 1, 1, 1, 1, 1 );

		if( error_count == 0 ) begin
			$display( "OK   : all tests passed" );
		end
		else begin
			$display( "ERROR: %0d test(s) failed", error_count );
		end
		$finish;
	end
endmodule
