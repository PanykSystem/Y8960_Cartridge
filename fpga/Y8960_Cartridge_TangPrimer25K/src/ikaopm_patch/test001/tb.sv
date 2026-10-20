// --------------------------------------------------------------------
//	IKAOPM Wrapper (opm.v) testbench
// --------------------------------------------------------------------
`timescale 1ns/1ps

module tb ();
	localparam		clk_base	= 1_000_000_000 / 42_954_540;

	reg				clk = 1'b0;
	reg				reset_n;
	reg				enable;
	reg		[3:0]	ff_div;
	reg				bus_cs;
	reg				bus_io;
	reg				bus_address;
	reg				bus_write;
	reg				bus_valid;
	wire			bus_ready;
	reg		[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	wire			wait_n;
	wire			intr_n;
	wire	[15:0]	sound_l_out;
	wire	[15:0]	sound_r_out;
	integer			error_count;
	reg				ff_wait_seen;

	opm u_opm (
		.clk			( clk			),
		.reset_n		( reset_n		),
		.enable			( enable		),
		.bus_cs			( bus_cs		),
		.bus_io			( bus_io		),
		.bus_address	( bus_address	),
		.bus_write		( bus_write		),
		.bus_valid		( bus_valid		),
		.bus_ready		( bus_ready		),
		.bus_wdata		( bus_wdata		),
		.bus_rdata		( bus_rdata		),
		.bus_rdata_en	( bus_rdata_en	),
		.wait_n			( wait_n		),
		.intr_n			( intr_n		),
		.sound_l_out	( sound_l_out	),
		.sound_r_out	( sound_r_out	)
	);

	always #(clk_base/2) begin
		clk <= ~clk;
	end

	//	phiM = clk / 12
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_div	<= 4'd0;
			enable	<= 1'b0;
		end
		else begin
			ff_div	<= (ff_div == 4'd11) ? 4'd0 : ff_div + 4'd1;
			enable	<= (ff_div == 4'd11);
		end
	end

	always @( posedge clk ) begin
		if( !wait_n ) begin
			ff_wait_seen <= 1'b1;
		end
	end

	task check( input string name, input bit ok );
		if( ok ) begin
			$display( "[OK]    %s", name );
		end
		else begin
			$display( "[ERROR] %s", name );
			error_count++;
		end
	endtask

	//	Local bus access: holds the request until bus_ready.
	task bus_access(
		input			io,
		input			address,
		input			write,
		input	[7:0]	wdata,
		output	[7:0]	rdata,
		output			rdata_en
	);
		@( posedge clk );
		bus_cs		<= 1'b1;
		bus_io		<= io;
		bus_address	<= address;
		bus_write	<= write;
		bus_wdata	<= wdata;
		bus_valid	<= 1'b1;
		@( posedge clk );
		while( !bus_ready ) begin
			@( posedge clk );
		end
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		@( posedge clk );
		rdata		= bus_rdata;
		rdata_en	= bus_rdata_en;
	endtask

	task io_write( input [7:0] register, input [7:0] data );
		reg		[7:0]	rdata;
		reg				rdata_en;
		bus_access( 1'b1, 1'b0, 1'b1, register, rdata, rdata_en );
		bus_access( 1'b1, 1'b1, 1'b1, data, rdata, rdata_en );
	endtask

	task mio_write( input [7:0] register, input [7:0] data );
		reg		[7:0]	rdata;
		reg				rdata_en;
		//	7FFBh: address[0] = 1, 7FFCh: address[0] = 0
		bus_access( 1'b0, 1'b1, 1'b1, register, rdata, rdata_en );
		bus_access( 1'b0, 1'b0, 1'b1, data, rdata, rdata_en );
	endtask

	task read_status( output [7:0] status, output status_en );
		bus_access( 1'b1, 1'b1, 1'b0, 8'h00, status, status_en );
	endtask

	task wait_not_busy( input integer limit_us );
		reg		[7:0]	status;
		reg				status_en;
		integer			i;
		for( i = 0; i < limit_us; i++ ) begin
			read_status( status, status_en );
			if( !status[7] ) begin
				return;
			end
			#1us;
		end
		$display( "[ERROR] busy did not clear" );
		error_count++;
	endtask

	initial begin
		reg		[7:0]	status;
		reg				status_en;
		integer			max_l;
		integer			max_r;
		integer			i;

		error_count	= 0;
		ff_wait_seen = 1'b0;
		reset_n		= 1'b0;
		bus_cs		= 1'b0;
		bus_io		= 1'b0;
		bus_address	= 1'b0;
		bus_write	= 1'b0;
		bus_valid	= 1'b0;
		bus_wdata	= 8'h00;
		repeat( 50 ) @( posedge clk );
		reset_n		= 1'b1;

		// --------------------------------------------------------------------
		//	Status read
		// --------------------------------------------------------------------
		read_status( status, status_en );
		check( "status read enabled after reset", status_en === 1'b1 );
		check( "busy after reset (hold-off)", status[7] === 1'b1 );
		wait_not_busy( 200 );
		read_status( status, status_en );
		check( "status idle", status_en === 1'b1 && status === 8'h00 );

		bus_access( 1'b1, 1'b0, 1'b0, 8'h00, status, status_en );
		check( "7Eh read returns no data", status_en === 1'b0 );
		bus_access( 1'b0, 1'b0, 1'b0, 8'h00, status, status_en );
		check( "7FFCh read returns no data", status_en === 1'b0 );

		io_write( 8'h01, 8'h00 );
		read_status( status, status_en );
		check( "busy right after data write", status[7] === 1'b1 );
		wait_not_busy( 200 );

		// --------------------------------------------------------------------
		//	Queue full -> /WAIT
		// --------------------------------------------------------------------
		ff_wait_seen = 1'b0;
		for( i = 0; i < 12; i++ ) begin
			io_write( 8'h0F, 8'h00 );
		end
		check( "/WAIT asserted while queue full", ff_wait_seen === 1'b1 );
		wait_not_busy( 2000 );
		check( "/WAIT released", wait_n === 1'b1 );
		check( "queue drained", u_opm.ff_queue_count == 5'd0 );

		// --------------------------------------------------------------------
		//	Timer A -> IRQ
		// --------------------------------------------------------------------
		check( "IRQ inactive", intr_n === 1'b1 );
		io_write( 8'h10, 8'hFF );			//	Timer A = 3FFh
		io_write( 8'h11, 8'h03 );
		io_write( 8'h14, 8'h15 );			//	reset flag A, IRQ enable A, load A
		wait_not_busy( 200 );
		for( i = 0; i < 200 && intr_n === 1'b1; i++ ) begin
			#1us;
		end
		check( "IRQ asserted by timer A", intr_n === 1'b0 );
		read_status( status, status_en );
		check( "status timer A flag", status[0] === 1'b1 );
		io_write( 8'h14, 8'h10 );			//	reset flag A, stop timer
		wait_not_busy( 200 );
		#2us;
		check( "IRQ cleared", intr_n === 1'b1 );
		read_status( status, status_en );
		check( "status timer A flag cleared", status[0] === 1'b0 );

		// --------------------------------------------------------------------
		//	Key on (mixture of I/O and MMIO writes)
		// --------------------------------------------------------------------
		io_write ( 8'h28, 8'h4A );			//	ch0 KC
		mio_write( 8'h40, 8'h01 );			//	DT1/MUL
		mio_write( 8'h48, 8'h01 );
		mio_write( 8'h50, 8'h01 );
		mio_write( 8'h58, 8'h01 );
		io_write ( 8'h60, 8'h7F );			//	TL: M1,C1,M2 off
		io_write ( 8'h68, 8'h7F );
		io_write ( 8'h70, 8'h7F );
		io_write ( 8'h78, 8'h00 );			//	C2 full
		for( i = 0; i < 4; i++ ) begin
			mio_write( 8'h80 + i * 8, 8'h1F );	//	AR
			mio_write( 8'hA0 + i * 8, 8'h00 );	//	D1R
			mio_write( 8'hC0 + i * 8, 8'h00 );	//	D2R
			mio_write( 8'hE0 + i * 8, 8'h0F );	//	D1L/RR
		end
		io_write ( 8'h20, 8'hC7 );			//	L/R on, FB=0, CON=7
		io_write ( 8'h08, 8'h78 );			//	key on ch0
		wait_not_busy( 2000 );

		max_l = 0;
		max_r = 0;
		for( i = 0; i < 20000; i++ ) begin
			@( posedge clk );
			if( $signed( sound_l_out ) > max_l ) max_l = $signed( sound_l_out );
			if( $signed( sound_r_out ) > max_r ) max_r = $signed( sound_r_out );
			repeat( 5 ) @( posedge clk );
		end
		$display( "max L=%0d, max R=%0d", max_l, max_r );
		check( "sound L output", max_l > 1000 );
		check( "sound R output", max_r > 1000 );

		io_write( 8'h20, 8'h47 );			//	L only
		wait_not_busy( 200 );
		#100us;
		max_l = 0;
		max_r = 0;
		for( i = 0; i < 20000; i++ ) begin
			@( posedge clk );
			if( $signed( sound_l_out ) > max_l ) max_l = $signed( sound_l_out );
			if( $signed( sound_r_out ) > max_r ) max_r = $signed( sound_r_out );
			repeat( 5 ) @( posedge clk );
		end
		$display( "max L=%0d, max R=%0d", max_l, max_r );
		check( "L only: L output", max_l > 1000 );
		check( "L only: R silent", max_r == 0 );

		if( error_count == 0 ) begin
			$display( "[RESULT] ALL TESTS PASSED" );
		end
		else begin
			$display( "[RESULT] %0d ERROR(S)", error_count );
		end
		$finish;
	end
endmodule
