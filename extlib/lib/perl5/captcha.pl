package cap;
#┌─────────────────────────────
#│ 画像認証作成モジュール v3.2
#│ captcha.pl - 2012/03/13
#│ Copyright (c) KentWeb
#│ http://www.kent-web.com/
#└─────────────────────────────
# [ 使い方 ]
#
# 画像数字＆暗号文字の作成
# ( plain, crypt ) = cap::make( passphrase, length );
#
# 画像認証チェック
# result = cap::check( plain, crypt, passphrase, time, length );
# [ result ]
#    -1 : 不一致
#     0 : 時間オーバー
#     1 : 一致

# モジュール宣言
use strict;
use lib "./lib";
use Crypt::RC4;

#-----------------------------------------------------------
#  数字/暗号文字作成
#-----------------------------------------------------------
sub make {
	my ($passphrase,$caplen) = @_;

	# 任意の数字を生成
	my @num = (0 .. 9);
	my $plain;
	srand;
	foreach (1 .. $caplen) {
		$plain .= $num[int(rand(@num))];
	}

	# 時間を付加
	$plain .= time;

	# 暗号化
	my $crypt = RC4( $passphrase, $plain );
	$crypt =~ s/(.)/unpack('H2', $1)/eg;
	$crypt =~ s/\n/N/g;
	return ($plain,$crypt);
}

#-----------------------------------------------------------
#  投稿文字認証
#-----------------------------------------------------------
sub check {
	my ($input,$crypt,$passphrase,$cap_time,$caplen) = @_;

	# 投稿キーを復号
	$crypt =~ s/N/\n/g;
	$crypt =~ s/([0-9A-Fa-f]{2})/pack('H2', $1)/eg;
	my $plain = RC4( $passphrase, $crypt );

	# キーと時間に分解
	$plain =~ /^(\d{$caplen})(\d+)/;
	my $code = $1;
	my $time = $2;

	# キー一致
	if ($input eq $code) {
		# 制限時間オーバー
		if (time - $time > $cap_time * 60) {
			return 0;

		# 制限時間OK
		} else {
			return 1;
		}
	# キー不一致
	} else {
		return -1;
	}
}


1;

