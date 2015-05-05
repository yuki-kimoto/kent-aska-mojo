#!/usr/local/bin/perl
;#--------------------------------------------------------------------
;#
;#      SI-PNG連結スクリプト Ver 1.1(2001/2/2)
;#      (c) 2000, 2001 桜月
;#
;#      金銭の授受を伴わぬ改造・再配布なら
;#      自由に行っていただいてかまいません。
;#
;#      最新版の入手先ならびにSI-PNGについてはこちら。
;#      http://www.aurora.dti.ne.jp/~zom/Counter/index.html
;#
;#--------------------------------------------------------------------
;#
;# □画像連結関数・その書式
;#
;#      &pngren::PngRen($sipng, *narabi [, *trns [, *plte [, 0 or 1]]]);
;#      ([]内は省略可)
;#
;#       $sipng     SI-PNGファイルの指定。
;#       *narabi    数字の並びを格納した配列の参照。
;#
;#          以下は省略可能です。
;#
;#       *trns      透過処理を施す場合、"$trns{パレット番号} = 透明度"
;#                  という連想配列の参照を渡す。
;#       *plte      パレットの色を変更する場合、"$plte{パレット番号} = 色"
;#                  という連想配列の参照を渡す。
;#       0 or 1     数字を横につなぐなら0(もしくは省略)、縦につなぐなら1。
;#
;#--------------------------------------------------------------------
;#
;# (1) 基本的な使い方
;#
;#      require 'pngren.pl';
;#      $sipng  = './italic.png';               # SI-PNGファイルの指定。
;#      @narabi = (1, 2, 3, 4);                 # 数字の並び順を指定。
;#      &pngren::PngRen($sipng, *narabi);       # 数字の連結表示。
;#
;#
;# この例を実行すると、[1234]と表示される。
;#
;#--------------------------------------------------------------------
;#
;# (2) 任意のパレットの色を透過させたい場合の例
;#
;#      require 'pngren.pl';
;#      $sipng   = './gothic.png';
;#      @narabi  = (0, 0, 2);   # ここまでは通常の例と同じ。
;#      %trns    = ();
;#      $trns{0} = 0;           # 0番パレットの透明度を0(完全な透過)に設定。
;#      $trns{3} = 63;          # 3番パレットの透明度を63(75%の透過)に設定。
;#      &pngren::PngRen($sipng, *narabi, *trns);
;#
;#
;# この例を実行すると、0番パレットの色は完全な透過に、3番パレットの色は
;# 透明度63(75%の透過)に処理された上で、[002]と表示される。
;# なお元となるSI-PNGに透過情報が含まれていてもここでの指定の方が
;# 優先される(つまり上書きされる)。
;#
;# パレット番号の範囲は0-255。透明度の範囲も0(完全な透過)-255(透過なし)。
;#
;#--------------------------------------------------------------------
;#
;# (3) 任意のパレットの色を変更したい場合の例
;#
;#      require 'pngren.pl';
;#      $sipng   = './celtic.png';
;#      @narabi  = (3, 4);      # ここまでは通常の例と同じ。
;#      %plte    = ();
;#      $plte{0} = 'ffff00';    # 0番パレットの色を'ffff00'にする。
;#                              # 色は'RRGGBB'形式で指定(htmlと同じ)。
;#      &pngren::PngRen($sipng, *narabi, undef, *plte);
;#                                       ^^^^^
;#                  注・(2)の透過指定を使わぬ場合、ここは"undef"としておく。
;#
;#
;# この例を実行すると、0番パレットの色が強制的に黄色に変更された上で
;# [34]と表示される。
;#
;# パレット番号の範囲は0-255。値(色)の範囲は'000000'-'ffffff'.
;#
;#--------------------------------------------------------------------
;#
;# (4) 数字を縦につなぎたい場合の例
;#
;#      &pngren::PngRen($sipng, *narabi, undef, undef, 1);
;#                                       ^^^^^  ^^^^^
;#  注・(2)の透過指定や(3)の色変更を使わぬ場合、ここは"undef"としておく。
;#
;#--------------------------------------------------------------------
;#
;# (5) 戻り値
;#
;# &pngren::PngRen()関数の戻り値は以下の通りです。
;#
;#      0   正常に終了。
;#      1   エラー・指定されたSI-PNGはない。
;#      3   エラー・指定されたファイルはSI-PNGではない。
;#      4   エラー・指定されたSI-PNGはローマ数字版用のもの。
;#      5   エラー・画像が大きすぎる(幅x高さが16384を越えた)。
;#
;#
;# なおこのスクリプトには拙作の「PNGカウンタ」と同じエラー表示
;# ルーチンが含まれています。これを利用するには、上記の「戻り値」を
;# そのまま"&pngren::Error()"関数に引数として渡せばOKです。
;#
;# Ver1.0には、エラーが発生した時でもPNGのヘッダだけ出力されてしまう
;# というバグがありました。詳しくは末尾の更新履歴をご覧ください。
;#
;#--------------------------------------------------------------------
;#
;# □その他の情報
;#
;# SI-PNGは仕様上最大16個まで画像を内包できます。
;# 従って以下のようなSI-PNGも存在しえます。
;#
;#   [0123456789祝]
;#
;# これは9の右側に「祝」という画像が織り込まれている例ですが、
;# この「祝」の画像を取り出すにはどうすればよいか、以下その方法に
;# ついて解説いたします。
;#
;#
;# (1) 11番目以降の画像の取り出し方
;#
;# 先ほど例としてあげたSI-PNGを素に「祝5000」という画像を
;# 合成・連結するには以下のようにスクリプトを書きます。
;#
;#      @narabi = (10, 5, 0, 0, 0);             # 数字の並び順を指定。
;#      &pngren::PngRen($sipng, *narabi);       #「祝5000」が表示される。
;#
;# これを見てお気づきかもしれませんが、実は「@narabi配列」の各値は
;# 数字そのものを表しているのではなく、「左から何番目の画像か」を
;# 表しているのです。従いまして、
;#
;# ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐
;# │０│１│２│３│４│５│６│７│８│９│AM│PM│：│
;# └─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘
;#    0   1   2   3   4   5   6   7   8   9  10  11  12
;#   番  番  番  番  番  番  番  番  番  番  番  番  番
;#   目  目  目  目  目  目  目  目  目  目  目  目  目
;#
;# このような並びのSI-PNGを使って、[PM2:55]と表示するには、
;#
;#      $sipng  = 'watch.png";                 # SI-PNG名。
;#      @narabi = (11, 2, 12, 5, 5);           # 数字の並び順を指定。
;#      &pngren::PngRen($sipng, *narabi);      #「PM2:55」が表示される。
;#
;# とすればよいわけです。
;#
;#
;# 参考・内包されている画像の数を調べる関数
;#
;#      &pngren::Oshiete($sipng);
;#
;#      戻り値がそのまま内包されている画像の数を表す。
;#      指定されたファイルがなかったり、あってもそれがSI-PNGでは
;#      なければ0を返す。
;#
;#--------------------------------------------------------------------


package pngren;

# チャンク出力ルーチン。
sub ChunkDasu(){
	print pack('N', length($chunkdata) - 4).$chunkdata;
	my($crc) = 0xffffffff;
	foreach(unpack('C*', $chunkdata)){
		$crc = $crc_table[($crc ^ $_) & 0xff] ^ ($crc >> 8);
	}
	print pack('N', ~$crc);
	undef($chunkdata);
}


# CRC用初期設定。
sub CrcTable(){
	@crc_table = ();
	for(0 .. 255){
		$crc = $_;
		for(0 .. 7){
			if($crc & 1){ $crc = 0xedb88320 ^ ($crc >> 1); }
			else{ $crc = $crc >> 1; }
		}
		$crc_table[$_] = $crc;
	}
}


# 情報。
sub Oshiete(){

	local($filemei) = @_;
	my($ngsa);

	unless(open(IN, $filemei)){
		return 0;
	}
	binmode(IN);
	seek(IN, 0x21,  0);
	read(IN, $ngsa, 4);
	close(IN);
	return (unpack('N', $ngsa) - 20) >> 2;
}


# メイン。
sub PngRen(){

	local($filemei, *suuji, *trns, *plte, $muki) = @_;

	# PNG読みとり。
	$filemei = $filemei || './pngcntr.png';
	if(!open(IN, $filemei)){ return 1; }
	binmode(IN);
	seek(IN, 0, 0);
	read(IN, $png, -s $filemei);
	close(IN);
	
	if(substr($png, 0, 0x10) ne "\x89PNG\x0d\x0a\x1a\x0a\0\0\0\x0dIHDR"){
		return 3;
	}
	if(substr($png, 0x18, 5) ne "\x08\x03\0\0\0"){ return 3; }
	if(substr($png, 0x25, 3) ne 'pgC'){ return 3; }
	if(substr($png, 0x28, 1) ne 'I'){ return 4; }
	$pgchdr = 0x29;
	
	# 連結。
	unless(@suuji){ $suuji[0] = 0; }
	$kosuu   = (unpack('N', substr($png, 0x21, 4)) - 20) >> 2;
	$pnghaba =  unpack('N', substr($png, 0x10, 4)) + 1;
	$pgcichi =  unpack('V', substr($png, $pgchdr + 16, 4));
	$x_kei   = $y_kei = 0;
	if($muki == 1){ *ren = *TateRen; }
	else{           *ren = *YokoRen; }
	
	if(&ren){ return 5; }
	# ここまで。
	
	# ここから後は、Error()に処理を渡してはならん。
	
	binmode(STDOUT);
	$| = 1;
	
	&CrcTable();
	
	# PNGヘッダ出力。
	print "Content-type: image/png\n\n";
	print "\x89PNG\x0d\x0a\x1a\x0a";
	
	# IHDR.
	$chunkdata = 'IHDR'.pack('N2', $x_kei, $y_kei)."\x08\x03\0\0\0";
	&ChunkDasu();
	
	# PLTE.
	($pltehjmr, $pltengsa, $trnshjmr, $trnsngsa)
		= unpack('V4', substr($png, $pgchdr, 16));
	if(%plte){ &PlteShori(); }
	else{
		print substr($png, $pltehjmr - 8, $pltengsa + 12);
		$pltengsa /= 3;
	}
	
	# tRNS.
	if(%trns){ &TrnsShori(); }
	elsif($trnsngsa){
		print substr($png, $trnshjmr - 8, $trnsngsa + 12);
	}
	
	# IDAT.
	# 無圧縮zlib化。
	$s1 = 1;	$s2 = 0;
	foreach(unpack('C*', $ashk_src)){
		$s1 += $_;
		if($s1 > 65520){$s1 -= 65521; }
		$s2 += $s1;
		if($s2 > 65520){$s2 -= 65521; }
	}
	
	$len=pack('v', length($ashk_src));
	$chunkdata = "IDATx\x01\x01".$len.~$len.$ashk_src.pack('n2', $s2, $s1);
	&ChunkDasu();
	
	# IEND.
	print "\0\0\0\0IEND\xaeB`\x82";
	# ここまで。
	
	return 0;
}


# tRNS処理。
sub TrnsShori(){

	my($trns) = "\xff" x 256;
	my($palban, $atai);

	if($trnsngsa){
		substr($trns, 0, $trnsngsa) = substr($png, $trnshjmr, $trnsngsa);
	}
	while(($palban, $atai) = each(%trns)){
		substr($trns, $palban & 255, 1) = pack('C', $atai & 255);
	}
	$trnsngsa = 256;
	while($trnsngsa--){
		if(substr($trns, $trnsngsa, 1) ne "\xff"){
			last;
		}
	}
	$trnsngsa++;
	if($trnsngsa){
		if($trnsngsa > $pltengsa){
			$trnsngsa = $pltengsa;
		}
		$chunkdata = 'tRNS'.substr($trns, 0, $trnsngsa);
		&ChunkDasu();
	}
}


# PLTE処理。
sub PlteShori(){

	my($plte) = substr($png, $pltehjmr, $pltengsa);
	my($palban, $atai);

	$pltengsa /= 3;
	while(($palban, $atai) = each(%plte)){
		$palban &= 255;
		if($palban < $pltengsa){
			$atai = hex($atai);
			$rgb  = pack('n', ($atai >> 8) & 0xffff);
			$rgb .= pack('C', $atai & 0xff);
			substr($plte, $palban * 3, 3) = $rgb;
		}
	}
	$chunkdata = 'PLTE'.$plte;
	&ChunkDasu();
}


# 横連結。
sub YokoRen(){
	
	my($ichi, @ichi, $suuji, $nmojime);
	my(@x, @y, @line) = ((), (), ());
	
	foreach $suuji (@suuji){
		if($suuji >= $kosuu){ next; }
		
		unless($x[$suuji]){
			($x[$suuji], $y[$suuji]) =
				unpack('CC', substr($png, $pgchdr + 22 + ($suuji << 2), 2));
			$ichi[$suuji] =
				unpack('v',  substr($png, $pgchdr + 20 + ($suuji << 2), 2));
		}
		unless($y_kei){
			$y_kei = $y[$suuji];
			@line  = ("\0") x $y_kei;
		}
		$x_kei += $x[$suuji];
		if(($x_kei * $y_kei) >> 15){
			return 1;
		}
		$ichi   = $pgcichi + $ichi[$suuji];
		for(0 .. $y_kei - 1){
			$line[$_] .= substr($png, $ichi, $x[$suuji]);
			$ichi     += $pnghaba;
		}
	}
	$ashk_src = join('', @line);
	return 0;
}


# 縦連結。
sub TateRen(){
	
	my($ichi, @ichi, $suuji, $y, $nmojime);
	my(@x, @y, @line) = ((), (), ());
	
	$ashk_src = '';
	foreach $suuji (@suuji){
		if($suuji >= $kosuu){ next; }
		
		unless($x[$suuji]){
			($x[$suuji], $y[$suuji]) =
				unpack('CC', substr($png, $pgchdr + 22 + ($suuji << 2), 2));
			$ichi[$suuji] = 
				unpack('v',  substr($png, $pgchdr + 20 + ($suuji << 2), 2));
		}
		unless($x_kei){ $x_kei = $x[$suuji]; }
		
		$y_kei += $y = $y[$suuji];
		if(($x_kei * $y_kei) >> 15){
			return 1;
		}
		$ichi   = $pgcichi + $ichi[$suuji];
		while($y--){
			$ashk_src .= "\0".substr($png, $ichi, $x_kei);
			$ichi     += $pnghaba;
		}
	}
	return 0;
}


# エラー処理。
sub Error(){
	my($err) = $_[0];
	if   ($err == 0){$rgb = "\0\0\xff"; }		# 青(指定されたログがない)
	elsif($err == 1){$rgb = "\0\xff\xff"; }		# 水色(指定されたPNGがない)
	elsif($err == 2){$rgb = "\0\xff\0"; }		# 緑(PNGではない)
	elsif($err == 3){$rgb = "\xff\0\0"; }		# 赤(使えぬPNG)
	elsif($err == 4){$rgb = "\xff\0\xff"; }		# 紫(このカウンタ用ではない)
	elsif($err == 5){$rgb = "\xff\xff\0"; }		# 黄色(データ大きすぎ)
	else            {$rgb = "\xff\xff\xff"; }	# 白(未定義なエラー)
	
	binmode(STDOUT);
	$| = 1;
	
	&CrcTable();
	
	print "Content-type: image/png\n\n";
	print "\x89PNG\x0d\x0a\x1a\x0a";
	print "\0\0\0\x0dIHDR\0\0\0 \0\0\0 \x01\x03\0\0\0I\xb4\xe8\xb7";
	
	$chunkdata = "PLTE\0\0\0$rgb";
	&ChunkDasu();
	
	print "\0\0\0)IDATx\xdac\xf8\x0f\x04\x0c\x0d";
	print "\x0c\x0c\x8c\xe8D\xfb\xff\xff\x0f\xd1\x89\x06\xe6\x03\x8c\x94";
	print "\x13\xf3\xff\xff\xff\x89N`s\x01\xc8i\0\xeb[9";
	print "\xa9\xb9\xc5K\xc5\0\0\0\0IEND\xaeB`\x82";
	
	exit(-1);
}
1;

# 更新履歴
#
#       Ver 1.0(2000/11/1)
#           公開。
#
#       Ver 1.1(2001/1/28)
#           画像面積のチェックを画像連結中に行うようにした。
#           出力できる画像面積の制限を32768バイトに緩和した。
#           Ver 1.0では、
#             (1) PNGのヘッダを出力。
#             (2) エラーチェック。
#             (3) 画像出力。
#           という順で処理していたため、(2)でエラーが出るとヘッダだけ
#           出力されてしまう不具合があった。これを以下のように修正。
#             (1) エラーチェック。
#             (2) PNGのヘッダを出力。
#             (3) 画像出力。
#           つまり、エラーが発生した時は何も出力せず返ってくるようにした。
#
#       Ver 1.1(2001/2/2)
#           少し文法を修正(VerNoはそのまま)。
#
