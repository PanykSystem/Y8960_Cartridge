if exist work (
	rmdir /S /Q work
)
vlib work

vlog ..\IKASCC.v
vlog ..\IKASCC_player_s.v
vlog ..\..\pan\pan_lut.v
vlog ..\..\ikascc\src\IKASCC_modules\IKASCC_primitives.v
vlog ..\IKASCC_vrc_s.v
vlog ..\scc.v

vlog tb.sv
if errorlevel 1 (
	pause
	exit
)
vsim -c -t 1ps -do run.do tb
move transcript log.txt