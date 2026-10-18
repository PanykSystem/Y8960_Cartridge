// -----------------------------------------------------------------------------
//	Test of dual_ssg.v
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
//		Pulse wave modulation
// -----------------------------------------------------------------------------

module tb ();
	localparam	clk_base	= 1_000_000_000/85.90908;	//	ps
	int				test_no;
	int				i, j;
	reg		[4:0]	ff_divider;
	reg				ff_enable;
	reg				clk;
	reg				reset_n;
	reg				enable;
	reg				bus_cs;
	reg				bus_valid;
	reg				bus_write;
	reg		[1:0]	bus_address;
	wire			bus_ready;
	reg		[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	reg		[7:0]	ssg_ioa0 = 8'd0;
	wire	[7:0]	ssg_iob0;
	reg		[7:0]	ssg_ioa1 = 8'd0;
	wire	[7:0]	ssg_iob1;
	reg				keyboard_type = 1'b0;
	reg				cmt_read = 1'b0;
	wire			kana_led;
	wire	[12:0]	sound_out_l;
	wire	[12:0]	sound_out_r;
	integer			error_count;
	reg		[1:0]	mode = 2'b11;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_divider	<= 5'd0;
			ff_enable	<= 1'b0;
		end
		else if( ff_divider == 5'd23 ) begin
			ff_divider	<= 5'd0;
			ff_enable	<= 1'b1;
		end
		else begin
			ff_divider	<= ff_divider + 5'd1;
			ff_enable	<= 1'b0;
		end
	end

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	dual_ssg #(
		.BUILTIN			( 1					)
	) u_dual_ssg (
		.clk				( clk				),
		.reset_n			( reset_n			),
		.enable				( ff_enable			),
		.bus_cs				( bus_cs			),
		.bus_valid			( bus_valid			),
		.bus_write			( bus_write			),
		.bus_address		( bus_address		),
		.bus_ready			( bus_ready			),
		.bus_wdata			( bus_wdata			),
		.bus_rdata			( bus_rdata			),
		.bus_rdata_en		( bus_rdata_en		),
		.ssg_ioa0			( ssg_ioa0			),
		.ssg_iob0			( ssg_iob0			),
		.ssg_ioa1			( ssg_ioa1			),
		.ssg_iob1			( ssg_iob1			),
		.sound_l_out		( sound_out_l		),
		.sound_r_out		( sound_out_r		),
		.mode				( mode				)
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
		input	[1:0]	address,
		input	[7:0]	value,
		output			time_out
	);
		int		counter;

		bus_cs			<= 1'b1;
		bus_address		<= address;
		bus_wdata		<= value;
		bus_write		<= 1'b1;
		bus_valid		<= 1'b1;
		counter			= 0;
		time_out		= 1'b0;

		while( ~bus_ready ) begin
			counter		<= counter + 1;
			if( counter > 100 ) begin
				time_out	<= 1'b1;
				break;
			end
			@( posedge clk );
		end
		@( posedge clk );

		bus_cs			<= 1'b0;
		bus_address		<= 8'd0;
		bus_wdata		<= 8'd0;
		bus_write		<= 1'b0;
		bus_valid		<= 1'b0;
		@( posedge clk );
	endtask

	// --------------------------------------------------------------------
	task read_io(
		input	[1:0]	address,
		output	[7:0]	value,
		output			time_out
	);
		int		counter;
	
		bus_cs			= 1'b1;
		bus_address		= address;
		bus_wdata		= 8'd0;
		bus_write		= 1'b0;
		bus_valid		= 1'b1;
		counter			= 0;
		time_out		= 1'b0;

		while( !bus_rdata_en ) begin
			@( posedge clk );
			#1;
			counter = counter + 1;
			if( counter > 100 ) begin
				time_out = 1'b1;
				break;
			end
		end
		value			= bus_rdata;
		bus_valid		= 1'b0;
		bus_cs			= 1'b0;
		bus_address		= 2'd0;
		bus_wdata		= 8'd0;
		bus_write		= 1'b0;
		@( posedge clk );
	endtask

	// --------------------------------------------------------------------
	task check(
		input string	name,
		input			condition
	);
		if( condition ) begin
			$display( "OK   : %s", name );
		end
		else begin
			$display( "ERROR: %s", name );
			error_count = error_count + 1;
		end
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		logic			time_out;
		logic	[7:0]	data;

		test_no			= -1;
		error_count		= 0;
		reset_n			= 0;
		clk				= 1;
		bus_cs			= 0;
		bus_address		= 0;
		bus_write		= 0;
		bus_valid		= 0;
		bus_wdata		= 0;

		@( negedge clk );
		@( negedge clk );
		@( posedge clk );

		reset_n			= 1;
		@( posedge clk );

		check( "SSG1 Ch.A PAN reset", u_dual_ssg.ssg_core0.ff_ssg_ch_a_pan == 8'd128 );
		check( "SSG1 Ch.B PAN reset", u_dual_ssg.ssg_core0.ff_ssg_ch_b_pan == 8'd128 );
		check( "SSG1 Ch.C PAN reset", u_dual_ssg.ssg_core0.ff_ssg_ch_c_pan == 8'd128 );
		check( "SSG2 Ch.A PAN reset", u_dual_ssg.ssg_core1.ff_ssg_ch_a_pan == 8'd128 );
		check( "SSG2 Ch.B PAN reset", u_dual_ssg.ssg_core1.ff_ssg_ch_b_pan == 8'd128 );
		check( "SSG2 Ch.C PAN reset", u_dual_ssg.ssg_core1.ff_ssg_ch_c_pan == 8'd128 );

		write_io( 2'd0, 8'h28, time_out );
		check( "SSG1 Ch.A PAN address write", !time_out );
		write_io( 2'd1, 8'd0, time_out );
		check( "SSG1 Ch.A PAN 0 write", !time_out && u_dual_ssg.ssg_core0.ff_ssg_ch_a_pan == 8'd0 );

		write_io( 2'd0, 8'h29, time_out );
		write_io( 2'd1, 8'd128, time_out );
		check( "SSG1 Ch.B PAN 128 write", !time_out && u_dual_ssg.ssg_core0.ff_ssg_ch_b_pan == 8'd128 );

		write_io( 2'd0, 8'h2A, time_out );
		write_io( 2'd1, 8'd255, time_out );
		check( "SSG1 Ch.C PAN 255 write", !time_out && u_dual_ssg.ssg_core0.ff_ssg_ch_c_pan == 8'd255 );

		write_io( 2'd0, 8'h2C, time_out );
		write_io( 2'd1, 8'd1, time_out );
		check( "SSG2 Ch.A PAN 1 write", !time_out && u_dual_ssg.ssg_core1.ff_ssg_ch_a_pan == 8'd1 );

		write_io( 2'd0, 8'h2D, time_out );
		write_io( 2'd1, 8'd64, time_out );
		check( "SSG2 Ch.B PAN 64 write", !time_out && u_dual_ssg.ssg_core1.ff_ssg_ch_b_pan == 8'd64 );

		write_io( 2'd0, 8'h2E, time_out );
		write_io( 2'd1, 8'd192, time_out );
		check( "SSG2 Ch.C PAN 192 write", !time_out && u_dual_ssg.ssg_core1.ff_ssg_ch_c_pan == 8'd192 );

		write_io( 2'd0, 8'h28, time_out );
		read_io( 2'd2, data, time_out );
		check( $sformatf( "SSG1 Ch.A PAN read (data=%02h timeout=%0d)", data, time_out ), !time_out && data == 8'd0 );
		write_io( 2'd0, 8'h29, time_out );
		read_io( 2'd2, data, time_out );
		check( $sformatf( "SSG1 Ch.B PAN read (data=%02h timeout=%0d)", data, time_out ), !time_out && data == 8'd128 );
		write_io( 2'd0, 8'h2A, time_out );
		read_io( 2'd2, data, time_out );
		check( $sformatf( "SSG1 Ch.C PAN read (data=%02h timeout=%0d)", data, time_out ), !time_out && data == 8'd255 );
		write_io( 2'd0, 8'h2C, time_out );
		read_io( 2'd2, data, time_out );
		check( $sformatf( "SSG2 Ch.A PAN read (data=%02h timeout=%0d)", data, time_out ), !time_out && data == 8'd1 );
		write_io( 2'd0, 8'h2D, time_out );
		read_io( 2'd2, data, time_out );
		check( $sformatf( "SSG2 Ch.B PAN read (data=%02h timeout=%0d)", data, time_out ), !time_out && data == 8'd64 );
		write_io( 2'd0, 8'h2E, time_out );
		read_io( 2'd2, data, time_out );
		check( $sformatf( "SSG2 Ch.C PAN read (data=%02h timeout=%0d)", data, time_out ), !time_out && data == 8'd192 );

		force u_dual_ssg.ssg_core0.w_out_level = 10'd1023;
		force u_dual_ssg.ssg_core0.ff_ssg_state = 5'd3;
		@( posedge clk );
		#1;
		check( "SSG1 Ch.A PAN 0 left gain", u_dual_ssg.ssg_core0.w_out_level_l == 11'd1023 );
		check( "SSG1 Ch.A PAN 0 right gain", u_dual_ssg.ssg_core0.w_out_level_r == 11'd0 );

		force u_dual_ssg.ssg_core0.ff_ssg_state = 5'd2;
		@( posedge clk );
		#1;
		check( "SSG1 Ch.B PAN 128 left gain", u_dual_ssg.ssg_core0.w_out_level_l == 11'd723 );
		check( "SSG1 Ch.B PAN 128 right gain", u_dual_ssg.ssg_core0.w_out_level_r == 11'd723 );

		force u_dual_ssg.ssg_core0.ff_ssg_state = 5'd1;
		@( posedge clk );
		#1;
		check( "SSG1 Ch.C PAN 255 left gain", u_dual_ssg.ssg_core0.w_out_level_l == 11'd0 );
		check( "SSG1 Ch.C PAN 255 right gain", u_dual_ssg.ssg_core0.w_out_level_r == 11'd1023 );

		force u_dual_ssg.ssg_core1.w_out_level = 10'd1023;
		force u_dual_ssg.ssg_core1.ff_ssg_state = 5'd3;
		@( posedge clk );
		#1;
		check( "SSG2 Ch.A PAN 1 left gain", u_dual_ssg.ssg_core1.w_out_level_l == 11'd1023 );
		check( "SSG2 Ch.A PAN 1 right gain", u_dual_ssg.ssg_core1.w_out_level_r == 11'd0 );

		// ----------------------------------------------------------------
		//	Channel volume registers (20h-22h / 24h-26h)
		// ----------------------------------------------------------------
		check( "SSG1 Ch.A volume reset", u_dual_ssg.ssg_core0.ff_ssg_ch_a_gain == 8'd128 );
		check( "SSG1 Ch.B volume reset", u_dual_ssg.ssg_core0.ff_ssg_ch_b_gain == 8'd128 );
		check( "SSG1 Ch.C volume reset", u_dual_ssg.ssg_core0.ff_ssg_ch_c_gain == 8'd128 );
		check( "SSG2 Ch.A volume reset", u_dual_ssg.ssg_core1.ff_ssg_ch_a_gain == 8'd128 );
		check( "SSG2 Ch.B volume reset", u_dual_ssg.ssg_core1.ff_ssg_ch_b_gain == 8'd128 );
		check( "SSG2 Ch.C volume reset", u_dual_ssg.ssg_core1.ff_ssg_ch_c_gain == 8'd128 );

		write_io( 2'd0, 8'h20, time_out );
		write_io( 2'd1, 8'd64, time_out );
		check( "SSG1 Ch.A volume 64 write", !time_out && u_dual_ssg.ssg_core0.ff_ssg_ch_a_gain == 8'd64 );
		write_io( 2'd0, 8'h20, time_out );
		read_io( 2'd2, data, time_out );
		check( $sformatf( "SSG1 Ch.A volume read (data=%02h timeout=%0d)", data, time_out ), !time_out && data == 8'd64 );

		write_io( 2'd0, 8'h24, time_out );
		write_io( 2'd1, 8'd0, time_out );
		check( "SSG2 Ch.A volume 0 write", !time_out && u_dual_ssg.ssg_core1.ff_ssg_ch_a_gain == 8'd0 );

		//	SSG1 Ch.A: PAN=0 (full left), volume=64 -> half level on the left
		force u_dual_ssg.ssg_core0.ff_ssg_state = 5'd3;
		@( posedge clk );
		#1;
		check( "SSG1 Ch.A volume 64 left gain", u_dual_ssg.ssg_core0.w_out_level_l == 11'd511 );
		check( "SSG1 Ch.A volume 64 right gain", u_dual_ssg.ssg_core0.w_out_level_r == 11'd0 );

		//	SSG2 Ch.A: volume=0 -> muted
		@( posedge clk );
		#1;
		check( "SSG2 Ch.A volume 0 left gain", u_dual_ssg.ssg_core1.w_out_level_l == 11'd0 );
		check( "SSG2 Ch.A volume 0 right gain", u_dual_ssg.ssg_core1.w_out_level_r == 11'd0 );
		release u_dual_ssg.ssg_core0.ff_ssg_state;
		release u_dual_ssg.ssg_core0.w_out_level;
		release u_dual_ssg.ssg_core1.ff_ssg_state;
		release u_dual_ssg.ssg_core1.w_out_level;

		if( error_count == 0 ) begin
			$display( "PASS: dual SSG PAN/volume registers and stereo gains" );
		end
		else begin
			$fatal( 1, "FAIL: %0d dual SSG PAN/volume errors", error_count );
		end
		$finish;
	end
endmodule
