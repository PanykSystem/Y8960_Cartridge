module tb ();
	localparam real CLK_PERIOD = 1_000_000_000_000.0 / 42_954_540.0;

	reg				clk;
	reg				reset_n;
	reg		[3:0]	enable_count;
	reg				enable_run;
	wire			enable;
	reg				bus_cs;
	reg				bus_address;
	reg				bus_write;
	reg				bus_valid;
	wire			bus_ready;
	reg		[7:0]	bus_wdata;
	wire signed [15:0]	sound_l_out;
	wire signed [15:0]	sound_r_out;
	integer			max_l;
	integer			max_r;
	integer			sample_l;
	integer			sample_r;
	integer			channel;

	assign enable = enable_run && (enable_count == 4'd0);

	always #(CLK_PERIOD / 2) clk = ~clk;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			enable_count <= 4'd0;
		end
		else if( enable_count == 4'd11 ) begin
			enable_count <= 4'd0;
		end
		else begin
			enable_count <= enable_count + 4'd1;
		end
	end

	opllex u_dut (
		.clk			( clk			),
		.reset_n		( reset_n		),
		.enable			( enable		),
		.bus_cs			( bus_cs		),
		.bus_address	( bus_address	),
		.bus_write		( bus_write		),
		.bus_valid		( bus_valid		),
		.bus_ready		( bus_ready		),
		.bus_wdata		( bus_wdata		),
		.sound_l_out	( sound_l_out	),
		.sound_r_out	( sound_r_out	)
	);

	task bus_write_data(
		input			address,
		input	[7:0]	data
	);
		integer timeout;
		begin
			@( negedge clk );
			bus_cs		= 1'b1;
			bus_address	= address;
			bus_write	= 1'b1;
			bus_valid	= 1'b1;
			bus_wdata	= data;
			timeout		= 0;
			while( !bus_ready && timeout < 10000 ) begin
				@( posedge clk );
				timeout = timeout + 1;
			end
			assert( timeout < 10000 );
			@( negedge clk );
			bus_cs		= 1'b0;
			bus_valid	= 1'b0;
			@( posedge clk );
		end
	endtask

	task bus_read;
		begin
			@( negedge clk );
			bus_cs		= 1'b1;
			bus_address	= 1'b0;
			bus_write	= 1'b0;
			bus_valid	= 1'b1;
			@( posedge clk );
			assert( bus_ready );
			@( negedge clk );
			bus_cs		= 1'b0;
			bus_valid	= 1'b0;
			@( posedge clk );
		end
	endtask

	task opll_write(
		input	[7:0]	address,
		input	[7:0]	data
	);
		begin
			bus_write_data( 1'b0, address );
			bus_write_data( 1'b1, data );
		end
	endtask

	task sample_output;
		begin
			repeat( 20000 ) @( posedge clk );
			max_l = 0;
			max_r = 0;
			repeat( 100000 ) begin
				@( posedge clk );
				sample_l = $signed( sound_l_out );
				sample_r = $signed( sound_r_out );
				if( sample_l < 0 ) sample_l = -sample_l;
				if( sample_r < 0 ) sample_r = -sample_r;
				if( sample_l > max_l ) max_l = sample_l;
				if( sample_r > max_r ) max_r = sample_r;
			end
		end
	endtask

	task measure_output;
		input [7:0] pan;
		integer pan_channel;
		begin
			for( pan_channel = 0; pan_channel < 9; pan_channel = pan_channel + 1 ) begin
				opll_write( 8'h50 + pan_channel, pan );
			end
			sample_output();
			$display( "OPLL PAN %0d max: L=%0d R=%0d", pan, max_l, max_r );
		end
	endtask

	initial begin
		clk			= 1'b0;
		reset_n		= 1'b0;
		enable_count	= 4'd0;
		enable_run		= 1'b0;
		bus_cs		= 1'b0;
		bus_address	= 1'b0;
		bus_write	= 1'b0;
		bus_valid	= 1'b0;
		bus_wdata	= 8'd0;
		max_l		= 0;
		max_r		= 0;

		repeat( 20 ) @( posedge clk );
		reset_n = 1'b1;
		enable_run = 1'b1;
		repeat( 100 ) @( posedge clk );

		bus_read();
		opll_write( 8'h30, 8'h10 );
		opll_write( 8'h10, 8'h80 );
		opll_write( 8'h20, 8'h15 );

		sample_output();
		$display( "OPLL default PAN max: L=%0d R=%0d", max_l, max_r );
		assert( max_l > 0 );
		assert( max_r > 0 );
		assert( max_l == max_r );

		measure_output( 8'd128 );
		assert( max_l > 0 );
		assert( max_r > 0 );
		assert( max_l == max_r );

		measure_output( 8'd1 );
		assert( max_l > 0 );
		assert( max_r == 0 );

		measure_output( 8'd255 );
		assert( max_l == 0 );
		assert( max_r > 0 );

		for( channel = 0; channel < 9; channel = channel + 1 ) begin
			opll_write( 8'h50 + channel, 8'd1 );
		end
		opll_write( 8'h50, 8'd255 );
		repeat( 20000 ) @( posedge clk );
		max_l = 0;
		max_r = 0;
		repeat( 100000 ) begin
			@( posedge clk );
			sample_l = $signed( sound_l_out );
			sample_r = $signed( sound_r_out );
			if( sample_l < 0 ) sample_l = -sample_l;
			if( sample_r < 0 ) sample_r = -sample_r;
			if( sample_l > max_l ) max_l = sample_l;
			if( sample_r > max_r ) max_r = sample_r;
		end
		$display( "OPLL channel 1 right PAN max: L=%0d R=%0d", max_l, max_r );
		assert( max_r > max_l );
		$finish;
	end
endmodule
