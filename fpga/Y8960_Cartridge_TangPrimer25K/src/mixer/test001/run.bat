@echo off
if exist work (
	rmdir /S /Q work
)
vlib work
vlog ..\mixier.v
if errorlevel 1 exit /b 1
vlog -sv tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -do run.do tb
move /Y transcript log.txt
