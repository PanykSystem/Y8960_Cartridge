if exist work rmdir /S /Q work
vlib work
vlog ..\..\pan\pan_lut.v
vlog ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_eg.v
vlog ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_lfo.v
vlog ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_op.v
vlog ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_pg.v
vlog ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_primitives.v
vlog ..\..\ikaopll\src\IKAOPLL_modules\IKAOPLL_timinggen.v
vlog ..\IKAOPLL_modules\IKAOPLL_dac.v
vlog ..\IKAOPLL_reg.v
vlog ..\IKAOPLL.v
vlog ..\opll.v
vlog tb.sv
vsim -c -t 1ps -do run.do tb
move transcript log.txt
