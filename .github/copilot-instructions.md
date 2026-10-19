# 基本ルール
メッセージは日本語でお願いします。

# 概要
MSXパソコン向けの音源カートリッジの FPGAデザインと、PCBデータをまとめたリポジトリです。

# 仕様
doc/spec/Y8960_Specifications.xlsx にまとめてあります。

# FPGAデザイン
SiPeed TangPrimer25K を使用しています。
fpga/Y8960_Cartridge_TangPrimer25K/Y8960_Cartridge_TangPrimer25K.gprj が GOWIN EDA の
プロジェクトファイルです。
GOWIN EDA による合成作業は、特に指示のない限りはユーザーが行います。

# FPGAデザイン上の注意点
除算演算子は使用禁止です。
乗算器も貴重なリソースであるため、時分割利用などで節約できる場合は、極力節約してください。
