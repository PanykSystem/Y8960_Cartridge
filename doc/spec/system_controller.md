# System Controller の仕様
	起動時に、ConfogROM の 7E0000h-7FFFFFh の 128KB を、SerialSRAM の 00000h- にコピーする。
	その間、他のモジュールは停止、/WAIT=L を出して MSX本体も止める。

	I/O の 40h-4Fh に接続されている。
	40h に 128=80h を書き込んだ場合に有効化される。有効化されるまでは、40-4Fh へのリードアクセスに
	対して、応答を返さない。

	|I/Oアドレス|意味|
	|---|---|
	|40h|イネーブラ|
	|41h|デバイスセレクト|
	|42h|ファンクションセレクト|
	|43h-4Fh|ファンクションによって意味が変化する|

	有効化されると、40h のリードは 80h の反転である 7Fh を返す。
	MSX上で動作するプログラムは、7Fh が読めたことで System Controller の存在を認識する。

	System Controller が有効な状態で、41h に書き込む値はデバイスセレクトである。
	41h へ書き込む値(ID)は、下記の意味を持つ。

	|41h へ書き込む値(ID)|意味|
	|---|---|
	|00h|N/A|
	|01h|V9968 Cartridge|
	|02h|Y8960 Cartridge|
	|03h|FPGA MSXtR CPU Board|
	|04h|FPGA MSXtR VDP Board|
	|05h|FPGA MSXtR SND Board|
	|06h-FEh|Reserved|
	|FFh|N/A|

	該当するデバイスは、System Controller が有効な時に 41h に自身の ID が書き込まれると、
	41h リードでその ID の全ビット反転を返すようになる。
	自身の ID ではない場合は、リードに応答を返さない。
	（別のデバイスが応答するので、バス競合を避けるため）

	このプロジェクトは、Y8960 Cartridge なので、02h だけをサポートしている。

# Y8960 System Controller ファンクション

	|42h へ書き込む値(ID)|意味|
	|---|---|
	|00h|N/A|
	|01h|Config ROM Reader/Writer|
	|02h-FFh|N/A|

	System Controller が有効で、かつ 41h に 02h が書き込まれている状態では、
	I/O 42h に 01h が書き込まれた後に、I/O 42h を読み出すと FEh が返る。
	I/O 42h に 01h 以外が書き込まれた後に、I/O 42h を読み出すと、FFh が返る。
	System Controller が無効または、
	System Controller が有効で 41h に 02h以外が書き込まれている状態では、
	I/O 42h の読み出しには応答しない。

# Config ROM Reader/Writer
	I/Oアドレス 43h-4Fh は下記のように変化する。

	|I/Oアドレス|意味|
	|---|---|
	|43h|Address最下位8bit|
	|44h|Address中位8bit|
	|45h|Address最上位8bit|
	|46h|コマンド|
	|47h|データ|
	|48h-4Fh|Reserved|

	Reserved への読み書きは応答しない。
	コマンドは下記のものがある。

	|コマンド|意味|
	|---|---|
	|00h|読み出し|
	|01h|書き込み|
	|02h|セクター消去|
	|03h|チップ消去|
	|04h|ステータス読み出し|
	|05h-FFh|Reserved|

	読み出し(00h)/ステータス読み出し(04h) の結果は、コマンド完了後に 47h から読み出せる。
	ステータス読み出しでは、ConfigROM のステータスレジスタ1 が読み出され、bit0 が BUSY である。
	書き込み(01h)/セクター消去(02h)/チップ消去(03h) はコマンドを発行するのみであり、
	完了は MSX 側からステータス読み出しを繰り返し、BUSY=0 になったことで確認する。
	セクター消去は 64KB 単位 (アドレス下位 16bit は無視) である。
	46h の読み出しは FFh を返す。Reserved のコマンドは無視される。
	コマンド実行中 (数μs) は、System Controller への I/O アクセスは受け付けられない (WAIT は出ない)。
	46h にコマンドを書いた後は、40h が 7Fh を返すまでリードを繰り返してから次のアクセスを行うこと。
