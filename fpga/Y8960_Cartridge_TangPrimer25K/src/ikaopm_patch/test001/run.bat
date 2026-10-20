@echo off
if exist work (
	rmdir /S /Q work
)
vlib work
vlog ..\..\ikaopm\src\IKAOPM.v
if errorlevel 1 exit /b 1
vlog ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_acc.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_eg.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_lfo.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_noise.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_op.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_pg.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_primitives.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_reg.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_timer.v ..\..\ikaopm\src\IKAOPM_modules\IKAOPM_timinggen.v
if errorlevel 1 exit /b 1
vlog ..\opm.v
if errorlevel 1 exit /b 1
vlog -sv tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -do run.do tb
move /Y transcript log.txt