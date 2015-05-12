#┌─────────────────────────────────
#│ 画像認証作成ファイル [ GD::SecurityImage + Image::Magick ]
#│ captsec.pl - 2011/07/03
#│ Copyright (c) KentWeb
#│ http://www.kent-web.com/
#└─────────────────────────────────

#-----------------------------------------------------------
#  認証画像作成 [モジュール版]
#-----------------------------------------------------------
sub load_capsec {
	my ($plain, $font) = @_;

	# 画像生成
	# [引数] スクランブルモード(0=no 1=yes) : 画像位置が散らばる機能
	#        画像横サイズ, 画像縦サイズ, 画像中を横切る線の数,
	#        フォントファイル, フォントサイズ
	use GD::SecurityImage use_magick => 1;
	my $image = GD::SecurityImage->new(
					scramble => 0,
					width    => 90,
					height   => 26,
					lines    => 8,
					font     => $font,
					ptsize   => 18,
	);
	$image->random($plain);
	$image->create("ttf", "ellipse");
	$image->particle(100); # 背景に散りばめるドット数

	# 画像出力
	my ($img_out) = $image->out(force => "png");

	# 画像表示
	print "Content-type: image/png\n\n";
	binmode(STDOUT);
	print STDOUT $img_out;
	exit;
}


1;

