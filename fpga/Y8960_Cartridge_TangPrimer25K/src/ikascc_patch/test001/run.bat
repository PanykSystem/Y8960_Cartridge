if exist work (
	rmdir /S /Q work
)
vlib work

vlog ..\..\ikascc\src\IKASCC.v
vlog ..\..\ikascc\src\IKASCC_modules\IKASCC_player_s.v
vlog ..\..\ikascc\src\IKASCC_modules\IKASCC_primitives.v
vlog ..\IKASCC_vrc_s.v
vlog ..\scc.v
vlog ..\scc_bank.v
vlog ..\..\msx_slot\msx_slot.v
vlog ..\..\y8960_address_decode\y8960_address_decode.v
vlog ..\..\ssram\ssram.v
vlog ..\..\ssram\ssram_test_model.v
vlog ..\..\ssram\sram_arbiter.v

vlog tb.sv
if errorlevel 1 (
	pause
	exit
)
vsim -c -t 1ps -do run.do tb
move transcript log.txt