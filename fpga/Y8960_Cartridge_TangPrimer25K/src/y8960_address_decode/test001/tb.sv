// -----------------------------------------------------------------------------
//	Test of y8960_address_decode.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
//	
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------

module tb ();
	localparam		clk_base		= 1_000_000_000_000.0/28_636_360;	//	ps

	//	I/O port addresses
	localparam	[7:0]	c_ssg1_io		= 8'hA0;
	localparam	[7:0]	c_ssg2_io		= 8'hA2;
	localparam	[7:0]	c_opll_io		= 8'h7C;
	localparam	[7:0]	c_opll_old_io	= 8'h7A;	//	removed 2nd MSX-MUSIC port (must be unmapped now)
	localparam	[7:0]	c_opl2_io		= 8'hC0;
	localparam	[7:0]	c_opl2_old_io	= 8'hC2;	//	removed 2nd MSX-AUDIO port (must be unmapped now)
	localparam	[7:0]	c_timer1_io		= 8'hB0;
	localparam	[7:0]	c_timer2_io		= 8'hB2;
	localparam	[7:0]	c_sysctrl_io	= 8'h45;
	localparam	[7:0]	c_unmapped_io	= 8'h00;

	//	Memory Mapped I/O addresses (7FE0h-7FFFh window, no mirror)
	localparam	[15:0]	c_ssg_mio		= 16'h7FF0;
	localparam	[15:0]	c_ssg_mio_mirror = 16'h3FF0;	//	mirror removed -> no decode
	localparam	[15:0]	c_opl2_mio		= 16'h7FF2;
	localparam	[15:0]	c_opl2_old_mio	= 16'h7FEE;	//	removed 2nd MSX-AUDIO window (falls back to scc)
	localparam	[15:0]	c_opll_mio		= 16'h7FF4;
	localparam	[15:0]	c_io_en1_mio	= 16'h7FF6;
	localparam	[15:0]	c_io_en1_odd	= 16'h7FF7;		//	mixer volume register (handled by msx_slot) -> scc_cs here
	localparam	[15:0]	c_io_en2_mio	= 16'h7FFF;
	localparam	[15:0]	c_io_en2_even	= 16'h7FFE;		//	unassigned -> scc_cs
	localparam	[15:0]	c_normal_mem	= 16'h8000;

	//	Chip select bit order: { timer, opll, opl2, ssg, scc, sysctrl }
	localparam	[5:0]	c_cs_none		= 6'b000000;
	localparam	[5:0]	c_cs_timer		= 6'b100000;
	localparam	[5:0]	c_cs_opll		= 6'b010000;
	localparam	[5:0]	c_cs_opl2		= 6'b001000;
	localparam	[5:0]	c_cs_ssg		= 6'b000100;
	localparam	[5:0]	c_cs_scc		= 6'b000010;
	localparam	[5:0]	c_cs_sysctrl	= 6'b000001;

	reg				clk;
	reg				reset_n;
	reg		[15:0]	bus_address;
	reg				bus_io;
	reg				bus_write;
	reg				bus_valid;
	wire			bus_ready;
	reg		[7:0]	bus_wdata;
	wire			bus_timer_cs;
	wire			bus_opll_cs;
	wire			bus_opl2_cs;
	wire			bus_ssg_cs;
	wire			bus_scc_cs;
	wire			bus_sysctrl_cs;
	reg				memory_io_en;
	wire		[3:0]	led;
	integer			error_count;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	y8960_address_decode u_y8960_address_decode (
		.clk					( clk					),
		.reset_n				( reset_n				),
		.bus_address			( bus_address			),
		.bus_io					( bus_io				),
		.bus_write				( bus_write				),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_wdata				( bus_wdata				),
		.bus_timer_cs			( bus_timer_cs			),
		.bus_opll_cs			( bus_opll_cs			),
		.bus_opl2_cs			( bus_opl2_cs			),
		.bus_ssg_cs				( bus_ssg_cs			),
		.bus_scc_cs				( bus_scc_cs			),
		.bus_sysctrl_cs			( bus_sysctrl_cs		),
		.bus_timer_ready		( 1'b1					),
		.bus_opll_ready			( 1'b1					),
		.bus_opl2_ready			( 1'b1					),
		.bus_ssg_ready			( 1'b1					),
		.bus_scc_ready			( 1'b1					),
		.bus_sysctrl_ready		( 1'b1					),
		.memory_io_en			( memory_io_en			),
		.led					( led					)
	);

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	check
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
	//	Drive one Local BUS access for one clock and check the resulting
	//	chip select / bus_ready combination.
	// --------------------------------------------------------------------
	task access(
		input	[15:0]	address,
		input			io,
		input			write,
		input	[7:0]	wdata
	);
		bus_address	= address;
		bus_io		= io;
		bus_write	= write;
		bus_wdata	= wdata;
		bus_valid	= 1'b1;
		#1;
	endtask

	task idle();
		@( posedge clk );
		bus_valid	= 1'b0;
		bus_wdata	= 8'h00;
		#1;
		@( posedge clk );
	endtask

	task check_decode(
		input string	name,
		input	[15:0]	address,
		input			io,
		input			write,
		input	[5:0]	expected_cs
	);
		reg	[5:0]	actual_cs;
		access( address, io, write, 8'h00 );
		actual_cs = { bus_timer_cs, bus_opll_cs, bus_opl2_cs, bus_ssg_cs, bus_scc_cs, bus_sysctrl_cs };
		check( $sformatf( "%s (address=%04h expected_cs=%07b actual_cs=%07b)", name, address, expected_cs, actual_cs ),
			actual_cs == expected_cs );
		if( expected_cs == c_cs_none ) begin
			check( $sformatf( "%s bus_ready == 0", name ), bus_ready == 1'b0 );
		end
		else begin
			check( $sformatf( "%s bus_ready == 1", name ), bus_ready == 1'b1 );
		end
		idle();
	endtask

	//	Same as check_decode, but does not assume a relation between the
	//	expected cs vector and bus_ready (needed for the io_en1/io_en2 mio
	//	addresses, which select no module cs yet still assert bus_ready).
	task check_cs_only(
		input string	name,
		input	[15:0]	address,
		input			io,
		input			write,
		input	[5:0]	expected_cs
	);
		reg	[5:0]	actual_cs;
		access( address, io, write, 8'h00 );
		actual_cs = { bus_timer_cs, bus_opll_cs, bus_opl2_cs, bus_ssg_cs, bus_scc_cs, bus_sysctrl_cs };
		check( $sformatf( "%s (address=%04h expected_cs=%07b actual_cs=%07b)", name, address, expected_cs, actual_cs ),
			actual_cs == expected_cs );
		idle();
	endtask

	//	Write to the memory mapped I/O enabler registers (7FF6h / 7FFFh)
	task write_io_enabler(
		input	[15:0]	address,
		input	[7:0]	wdata
	);
		access( address, 1'b0, 1'b1, wdata );
		@( posedge clk );
		bus_valid	= 1'b0;
		#1;
		@( posedge clk );
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		clk				= 0;
		reset_n			= 1'b0;
		bus_address		= 16'h0000;
		bus_io			= 1'b0;
		bus_write		= 1'b0;
		bus_valid		= 1'b0;
		bus_wdata		= 8'h00;
		memory_io_en	= 1'b0;
		error_count		= 0;

		@( posedge clk );
		@( posedge clk );
		reset_n			= 1'b1;
		@( posedge clk );
		@( posedge clk );

		// --------------------------------------------------------------------
		//	Before enabling the I/O ports, every I/O access must be rejected
		//	(no module selected, bus_ready stays low).
		// --------------------------------------------------------------------
		check_decode( "ssg io (default enabled)", { 8'h00, c_ssg1_io }, 1'b1, 1'b1, c_cs_ssg );
		check_decode( "opll io (default enabled)", { 8'h00, c_opll_io }, 1'b1, 1'b1, c_cs_opll );
		check_decode( "opl2 io (disabled)",   { 8'h00, c_opl2_io }, 1'b1, 1'b1, c_cs_none );
		check_decode( "timer io (disabled)",  { 8'h00, c_timer1_io }, 1'b1, 1'b1, c_cs_none );
		//	sysctrl and undecoded I/O ports do not depend on the enabler
		check_decode( "sysctrl io",           { 8'h00, c_sysctrl_io },   1'b1, 1'b1, c_cs_sysctrl );
		check_decode( "unmapped io",          { 8'h00, c_unmapped_io },  1'b1, 1'b1, c_cs_none );

		// --------------------------------------------------------------------
		//	Enable every I/O port through the memory mapped enabler registers.
		//	This also exercises the mio address decode for c_io_en1 / c_io_en2.
		// --------------------------------------------------------------------
		memory_io_en	= 1'b1;
		write_io_enabler( c_io_en1_mio, 8'b0000_0001 );	//	opll_io_en
		write_io_enabler( c_io_en2_mio, 8'b1000_0011 );	//	opl2, ssg, timer

		// --------------------------------------------------------------------
		//	I/O port decode (now enabled)
		// --------------------------------------------------------------------
		check_decode( "ssg1 io",     { 8'h00, c_ssg1_io   }, 1'b1, 1'b1, c_cs_ssg );
		check_decode( "ssg2 io",     { 8'h00, c_ssg2_io   }, 1'b1, 1'b0, c_cs_ssg );
		check_decode( "opll io",     { 8'h00, c_opll_io   }, 1'b1, 1'b1, c_cs_opll );
		check_decode( "opll io odd", { 8'h00, c_opll_io + 8'd1 }, 1'b1, 1'b0, c_cs_opll );
		check_decode( "opll old io", { 8'h00, c_opll_old_io }, 1'b1, 1'b1, c_cs_none );
		check_decode( "opl2 io",     { 8'h00, c_opl2_io   }, 1'b1, 1'b1, c_cs_opl2 );
		check_decode( "opl2 old io", { 8'h00, c_opl2_old_io }, 1'b1, 1'b1, c_cs_none );
		check_decode( "timer1 io",   { 8'h00, c_timer1_io }, 1'b1, 1'b1, c_cs_timer );
		check_decode( "timer2 io",   { 8'h00, c_timer2_io }, 1'b1, 1'b0, c_cs_timer );
		check_decode( "sysctrl io",  { 8'h00, c_sysctrl_io },1'b1, 1'b1, c_cs_sysctrl );
		check_decode( "unmapped io", { 8'h00, c_unmapped_io},1'b1, 1'b1, c_cs_none );

		// --------------------------------------------------------------------
		//	Memory mapped I/O decode (memory_io_en=1, write only)
		// --------------------------------------------------------------------
		check_decode( "ssg mio",         c_ssg_mio,        1'b0, 1'b1, c_cs_ssg );
		check_decode( "ssg mio (mirror removed)",c_ssg_mio_mirror, 1'b0, 1'b1, c_cs_scc );
		check_decode( "opl2 mio",        c_opl2_mio,       1'b0, 1'b1, c_cs_opl2 );
		check_decode( "opl2 old mio",    c_opl2_old_mio,   1'b0, 1'b1, c_cs_scc );
		check_decode( "opll mio",        c_opll_mio,       1'b0, 1'b1, c_cs_opll );
		check_cs_only( "io_en1 mio",     c_io_en1_mio,     1'b0, 1'b1, c_cs_none );	//	io_en_cs is not exposed as a module cs
		check_decode( "7FF7h->scc",      c_io_en1_odd,     1'b0, 1'b1, c_cs_scc );
		check_decode( "7FFEh->scc",      c_io_en2_even,    1'b0, 1'b1, c_cs_scc );
		check_cs_only( "io_en2 mio",     c_io_en2_mio,     1'b0, 1'b1, c_cs_none );	//	io_en_cs is not exposed as a module cs

		//	io_en1/io_en2 exact addresses select the internal enabler (bus_ready
		//	must be asserted immediately even though no module cs is active).
		access( c_io_en1_mio, 1'b0, 1'b1, 8'h00 );
		check( "io_en1 mio bus_ready == 1", bus_ready == 1'b1 );
		idle();
		access( c_io_en2_mio, 1'b0, 1'b1, 8'h00 );
		check( "io_en2 mio bus_ready == 1", bus_ready == 1'b1 );
		idle();

		// --------------------------------------------------------------------
		//	Reads to the mio window and accesses without memory_io_en must fall
		//	back to the normal (SCC) memory access.
		// --------------------------------------------------------------------
		check_decode( "ssg mio read->scc", c_ssg_mio, 1'b0, 1'b0, c_cs_scc );

		memory_io_en	= 1'b0;
		check_decode( "ssg mio (io_en=0)->scc", c_ssg_mio, 1'b0, 1'b1, c_cs_scc );
		memory_io_en	= 1'b1;

		// --------------------------------------------------------------------
		//	Normal memory access always selects SCC
		// --------------------------------------------------------------------
		check_decode( "normal mem write->scc", c_normal_mem, 1'b0, 1'b1, c_cs_scc );
		check_decode( "normal mem read->scc",  c_normal_mem, 1'b0, 1'b0, c_cs_scc );

		// --------------------------------------------------------------------
		//	Idle bus: no chip select must ever be asserted
		// --------------------------------------------------------------------
		bus_valid	= 1'b0;
		#1;
		check( "idle bus (no cs)", { bus_timer_cs, bus_opll_cs, bus_opl2_cs, bus_ssg_cs, bus_scc_cs, bus_sysctrl_cs } == c_cs_none );
		check( "idle bus (bus_ready==0)", bus_ready == 1'b0 );

		repeat( 10 ) @( posedge clk );

		if( error_count == 0 ) begin
			$display( "OK   : all tests passed" );
		end
		else begin
			$display( "ERROR: %0d test(s) failed", error_count );
		end
		$finish;
	end
endmodule
