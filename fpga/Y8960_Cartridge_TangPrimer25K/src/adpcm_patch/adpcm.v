// --------------------------------------------------------------------
//	ADPCM Wrapper
// ====================================================================
//	2026/02/19 t.hara
// --------------------------------------------------------------------

module adpcm (
	input			clk,
	input			reset_n,
	input			enable,
	input			cen55,
	input			bus_cs,
	input			bus_address,
	input			bus_write,
	input			bus_valid,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	input	[7:0]	opl2_status,
	output	[15:0]	adpcm_sound_out_l,			//	signed
	output	[15:0]	adpcm_sound_out_r,			//	signed
	//	ADPCM Memory I/F
	output			adpcm_write,
	output			adpcm_valid,
	input			adpcm_ready,
	output	[23:0]	adpcm_address,
	output	[ 7:0]	adpcm_wdata,
	input	[ 7:0]	adpcm_rdata,
	input			adpcm_rdata_en
);
	reg		[7:0]	ff_reg_select;
	reg		[7:0]	ff_rdata;
	reg		[7:0]	ff_adpcm_data;
	reg		[7:0]	ff_adpcm_wdata;
	reg		[23:0]	ff_adpcm_address;
	reg				ff_bus_valid;
	reg				reg_mask_eds;				// 04h [4]
	reg				reg_mask_buffer_ready;		// 04h [3]
	reg				reg_start;					// 07h [7]
	reg				reg_record;					// 07h [6]
	reg				reg_memory_data;			// 07h [5]
	reg				reg_repeat;					// 07h [4]
	reg				reg_reset;					// 07h [0]
	reg		[12:0]	reg_start_address;			// 09h, 0Ah
	reg		[12:0]	reg_stop_address;			// 0Bh, 0Ch
	reg		[15:0]	reg_delta_n;				// 10h, 11h
	reg		[7:0]	reg_envelope_control;		// 12h
	reg		[17:0]	ff_byte_counter;
	wire			w_flag;
	reg				ff_read_state;				// 0: request state, 1: data state
	localparam		c_read_state_request = 1'b0;
	localparam		c_read_state_data = 1'b1;
	reg				ff_adpcm_access;			// ADPCM-SRAM I/F master 0: ADPCM, 1: CPU
	localparam		c_access_adpcm = 1'b0;
	localparam		c_access_cpu = 1'b1;
	reg				ff_adpcm_valid;
	reg				ff_adpcm_write;
	reg				ff_adpcm_read;
	reg				ff_core_pending;
	reg		[23:0]	ff_core_address;
	reg		[7:0]	reg_pan;					// FFh
	wire			w_adpcm_oe_n;
	wire			w_core_enable;
	wire	[23:0]	w_core_address;
	wire	[15:0]	w_pcm;
	wire	[8:0]	w_pan_gain_l;
	wire	[8:0]	w_pan_gain_r;
	wire	[8:0]	w_pan_gain;
	wire signed [25:0]	w_pan_product;
	reg				ff_pan_phase;				// 0: Lch, 1: Rch
	reg		[15:0]	ff_pan_out_l;
	reg		[15:0]	ff_pan_out_r;

	// ---------------------------------------------------------
	//	JT ADPCM (TypeB) body
	// ---------------------------------------------------------
	assign w_core_enable = enable | ~reset_n;

	jt10_adpcm_drvB u_adpcm (
		.rst_n			( reset_n							),
		.clk			( clk								),
		.cen			( w_core_enable						),
		.cen55			( cen55								),
		.acmd_on_b		( reg_start							),
		.acmd_rep_b		( reg_repeat						),
		.acmd_rst_b		( reg_reset							),
		.acmd_up_b		( reg_record						),
		.alr_b			( 2'b11								),		//	always enable
		.astart_b		( { 3'd0, reg_start_address }		),
		.aend_b			( { 3'd0, reg_stop_address }		),
		.adeltan_b		( reg_delta_n						),
		.aeg_b			( reg_envelope_control				),
		.flag			( w_flag							),
		.clr_flag		( reg_mask_eds						),
		.addr			( w_core_address						),
		.data			( ff_adpcm_data						),
		.roe_n			( w_adpcm_oe_n						),
		.pcm55_l		( w_pcm								),
		.pcm55_r		(									)
	);

	// ---------------------------------------------------------
	//	Stereo panning (register FFh)
	// ---------------------------------------------------------
	pan_lut u_pan_lut (
		.i_clk			( clk								),
		.i_pan			( reg_pan							),
		.o_gain_l		( w_pan_gain_l						),
		.o_gain_r		( w_pan_gain_r						)
	);

	//	One multiplier is shared by Lch and Rch alternately.
	assign w_pan_gain			= ff_pan_phase ? w_pan_gain_r : w_pan_gain_l;
	assign w_pan_product		= $signed( w_pcm ) * $signed( { 1'b0, w_pan_gain } );

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_pan_phase	<= 1'b0;
			ff_pan_out_l	<= 16'd0;
			ff_pan_out_r	<= 16'd0;
		end
		else begin
			ff_pan_phase	<= ~ff_pan_phase;
			if( ff_pan_phase ) begin
				ff_pan_out_r	<= w_pan_product[23:8];
			end
			else begin
				ff_pan_out_l	<= w_pan_product[23:8];
			end
		end
	end

	assign adpcm_sound_out_l	= ff_pan_out_l;
	assign adpcm_sound_out_r	= ff_pan_out_r;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_reg_select			<= 8'd0;
			reg_mask_eds			<= 1'b1;
			reg_mask_buffer_ready	<= 1'b1;
			reg_start				<= 1'b0;
			reg_record				<= 1'b0;
			reg_memory_data			<= 1'b0;
			reg_repeat				<= 1'b0;
			reg_reset				<= 1'b0;
			reg_start_address		<= 13'd0;
			reg_stop_address		<= 13'd0;
			reg_delta_n				<= 16'd0;
			reg_envelope_control	<= 8'd0;
			reg_pan					<= 8'd128;
		end
		else if( !bus_cs || !bus_valid ) begin
		end
		else if( bus_write ) begin
			if( !bus_address ) begin
				ff_reg_select	<= bus_wdata;
			end
			else begin
				case( ff_reg_select )
					8'h04: begin
						reg_mask_eds			<= bus_wdata[4];
						reg_mask_buffer_ready	<= bus_wdata[3];
					end
					8'h07: begin
						reg_start				<= bus_wdata[7];
						reg_record				<= bus_wdata[6];
						reg_memory_data			<= bus_wdata[5];
						reg_repeat				<= bus_wdata[4];
						reg_reset				<= bus_wdata[0];
					end
					8'h09: begin
						reg_start_address[7:0]	<= bus_wdata;
					end
					8'h0A: begin
						reg_start_address[12:8]	<= bus_wdata[4:0];
					end
					8'h0B: begin
						reg_stop_address[7:0]	<= bus_wdata;
					end
					8'h0C: begin
						reg_stop_address[12:8]	<= bus_wdata[4:0];
					end
					8'h10: begin
						reg_delta_n[7:0]		<= bus_wdata;
					end
					8'h11: begin
						reg_delta_n[15:8]		<= bus_wdata;
					end
					8'h12: begin
						reg_envelope_control	<= bus_wdata;
					end
					8'hFF: begin
						reg_pan					<= bus_wdata;
					end
				endcase
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_valid <= 1'b0;
		end
		else if( bus_cs ) begin
			if( !bus_address ) begin
				//	read status
				ff_bus_valid <= bus_valid;
			end
			else begin
				//	read register
				if( ff_reg_select == 8'h0F ) begin
					//	ADPCM-DATA register
					ff_bus_valid <= adpcm_rdata_en;
				end
				else begin
					//	others
					ff_bus_valid <= bus_valid;
				end
			end
		end
		else begin
			ff_bus_valid <= 1'b0;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_byte_counter <= 18'd0;
		end
		else if( ff_adpcm_valid && adpcm_ready && (ff_adpcm_access == c_access_cpu) && (ff_read_state == c_read_state_request) ) begin
			//	Upon receiving an access request, address increment
			if( ff_byte_counter == { reg_stop_address, 5'd31 } ) begin
				ff_byte_counter		<= { reg_start_address, 5'd0 };
			end
			else begin
				ff_byte_counter		<= ff_byte_counter + 18'd1;
			end
		end
		else if( !bus_cs || !bus_valid ) begin
		end
		else if( bus_write ) begin
			case( ff_reg_select )
				8'h09: begin
					//	START ADDR (L)
					ff_byte_counter		<= { reg_start_address[12:8], bus_wdata, 5'd0 };
				end
				8'h0A: begin
					//	START ADDR (H)
					ff_byte_counter		<= { bus_wdata[4:0], reg_start_address[7:0], 5'd0 };
				end
				8'h0B: begin
					//	STOP ADDR (L)
					ff_byte_counter		<= { reg_start_address, 5'd0 };
				end
				8'h0C: begin
					//	STOP ADDR (H)
					ff_byte_counter		<= { reg_start_address, 5'd0 };
				end
				default: begin
					//	hold
				end
			endcase
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_adpcm_data	<= 8'd0;
			ff_adpcm_wdata	<= 8'd0;
			ff_adpcm_address	<= 24'd0;
			ff_adpcm_access	<= c_access_adpcm;
			ff_adpcm_valid	<= 1'b0;
			ff_adpcm_write	<= 1'b0;
			ff_adpcm_read	<= 1'b0;
			ff_core_pending	<= 1'b0;
			ff_core_address	<= 24'd0;
		end
		else begin
			if( !w_adpcm_oe_n ) begin
				ff_core_pending	<= 1'b1;
				ff_core_address	<= w_core_address;
			end

			if( ff_adpcm_valid ) begin
				if( adpcm_ready ) begin
					ff_adpcm_valid <= 1'b0;
				end
			end
			else if( ff_adpcm_read ) begin
				if( adpcm_rdata_en ) begin
					ff_adpcm_read <= 1'b0;
					if( ff_adpcm_access == c_access_adpcm ) begin
						ff_adpcm_data <= adpcm_rdata;
					end
				end
			end
			else if( bus_cs && bus_valid && bus_address && (ff_reg_select == 8'h0F) &&
					(bus_write || (ff_read_state == c_read_state_request)) ) begin
				ff_adpcm_address	<= { 6'd0, ff_byte_counter };
				ff_adpcm_wdata	<= bus_wdata;
				ff_adpcm_access	<= c_access_cpu;
				ff_adpcm_valid	<= 1'b1;
				ff_adpcm_write	<= bus_write;
				ff_adpcm_read	<= ~bus_write;
			end
			else if( ff_core_pending ) begin
				ff_adpcm_address	<= ff_core_address;
				ff_adpcm_access	<= c_access_adpcm;
				ff_adpcm_valid	<= 1'b1;
				ff_adpcm_write	<= 1'b0;
				ff_adpcm_read	<= 1'b1;
				ff_core_pending	<= !w_adpcm_oe_n;
			end
		end
	end

	// Read status for distinguishing dummy reads from actual reads on ADPCM memory
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_read_state <= c_read_state_request;
			ff_rdata <= 8'hFF;
		end
		else if( (ff_read_state == c_read_state_request) && (ff_adpcm_access == c_access_cpu) && adpcm_rdata_en ) begin
			ff_read_state <= c_read_state_data;
			ff_rdata <= adpcm_rdata;
		end
		else if( !bus_cs || !bus_valid ) begin
			//	hold
		end
		else if( bus_write ) begin
			case( ff_reg_select )
				8'h09, 8'h0A, 8'h0B, 8'h0C: begin
					ff_read_state <= c_read_state_request;
					ff_rdata <= 8'hFF;
				end
				default: begin
					//	hold
				end
			endcase
		end
		else if( ff_reg_select == 8'h0F ) begin
			if( ff_read_state == c_read_state_data ) begin
				ff_read_state <= c_read_state_request;
				ff_rdata <= 8'hFF;
			end
		end
	end

	//	CPU access interface
	assign bus_rdata	= !bus_address ? { opl2_status[7:4], ff_read_state, 2'b11, w_flag }:
						  (ff_reg_select == 8'h0F) ? ff_rdata : 8'hFF;
	assign bus_rdata_en	= ~bus_write & ff_bus_valid;

	//	ADPCM RAM interface
	assign adpcm_write	= ff_adpcm_write;
	assign adpcm_valid	= ff_adpcm_valid;
	assign adpcm_address	= ff_adpcm_address;
	assign adpcm_wdata	= ff_adpcm_wdata;
endmodule
