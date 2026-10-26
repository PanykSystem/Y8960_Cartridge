if exist y8960bas.rom (
	copy /B header.bin+y8960bas.rom MSXSSE.ROM
) else (
	copy /B dummy.bin MSXSSE.ROM
)
