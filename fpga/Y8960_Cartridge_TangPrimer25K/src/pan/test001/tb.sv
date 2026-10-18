module tb;
	reg		[7:0]	pan;
	reg				clk;
	wire	[8:0]	gain_l;
	wire	[8:0]	gain_r;
	integer			p;
	integer			power;
	integer			error_count;
	reg		[8:0]	previous_l;
	reg		[8:0]	previous_r;

	pan_lut u_pan_lut (
		.i_clk		( clk		),
		.i_pan		( pan		),
		.o_gain_l	( gain_l	),
		.o_gain_r	( gain_r	)
	);

	always #5 clk = ~clk;

	task check;
		input string name;
		input condition;
		begin
			if( !condition ) begin
				$display( "ERROR: %s", name );
				error_count = error_count + 1;
			end
		end
	endtask

	initial begin
		error_count = 0;
		clk = 1'b0;

		pan = 8'd0;
		@( posedge clk );
		#1;
		check( "PAN 0 equals left edge", gain_l == 9'd256 && gain_r == 9'd0 );

		pan = 8'd1;
		@( posedge clk );
		#1;
		check( "PAN 1 is left edge", gain_l == 9'd256 && gain_r == 9'd0 );

		pan = 8'd128;
		@( posedge clk );
		#1;
		check( "PAN 128 is equal-power center", gain_l == 9'd181 && gain_r == 9'd181 );

		pan = 8'd255;
		@( posedge clk );
		#1;
		check( "PAN 255 is right edge", gain_l == 9'd0 && gain_r == 9'd256 );

		previous_l = 9'd256;
		previous_r = 9'd0;
		for( p = 1; p <= 255; p = p + 1 ) begin
			pan = p[7:0];
			@( posedge clk );
			#1;
			check( $sformatf( "left gain is monotonic at PAN %0d", p ), gain_l <= previous_l );
			check( $sformatf( "right gain is monotonic at PAN %0d", p ), gain_r >= previous_r );
			power = gain_l * gain_l + gain_r * gain_r;
			check( $sformatf( "equal-power error is bounded at PAN %0d", p ),
				power >= 65186 && power <= 65886 );
			previous_l = gain_l;
			previous_r = gain_r;
		end

		if( error_count == 0 ) begin
			$display( "PASS: PAN lookup endpoints, monotonicity, and equal-power curve" );
		end
		else begin
			$fatal( 1, "FAIL: %0d PAN lookup errors", error_count );
		end
		$finish;
	end
endmodule
