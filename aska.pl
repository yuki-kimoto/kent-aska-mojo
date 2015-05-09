#!/usr/bin/env

use FindBin;
my $lib_path;
BEGIN { $lib_path = "$FindBin::Bin/extlib/lib/perl5" }
use lib $lib_path;
use Mojolicious::Lite;
use Carp 'croak';
use Crypt::RC4;
use Encode ();

# コンフィグの読み込み
plugin 'Config';

# BBS(トップページ )
any '/' => 'bbs';


# 留意事項
get '/note';

# ワード検索
get '/find';

# 管理ページ
any '/admin';

# テストページ
get '/test';

get '/captcha' => sub {
  my $self = shift;
  
  my $config = $self->app->config;

  # パラメータ受け取り
  my $buf = $self->param('crypt');
  $buf =~ s/[<>&"'\s]//g;
  
  if (!$buf) {
    $self->reply->exception('Error');
    return;
  }

  # 復号
  my $plain = $self->aska->decrypt_($config->{cap_len}, $buf);

  # 認証画像作成
  my $img_bin;
  
  # 標準出力をキャプチャ
  {
    open my $fh, '>', \$img_bin;
    local *STDOUT = $fh;
    if ($config->{use_captcha} == 2) {
      require $config->{captsec_pl};
      my $font_ttl_path = $self->app->home->rel_file("/public/images/$config->{font_ttl}");
      $self->aska->load_capsec($plain, "$font_ttl_path");
    }
    else {
      my $si_png_path = $self->app->home->rel_file("/public/images/$config->{si_png}");
      $self->aska->load_pngren($plain, "$si_png_path");
    }
  }
  
  $img_bin =~ s#Content-type: image/png\s+##;
  $self->res->headers->content_type('image/png');
  $self->render(data => $img_bin);
};

get '/check' => sub {
  my $self = shift;
  
  my $config = $self->app->config;

  print <<EOM;
Content-type: text/html; charset=shift_jis

<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=shift_jis">
<title>Check Mode</title>
</head>
<body>
<b>Check Mode: [ $config->{version} ]</b>
<ul>
EOM

  # ログファイル
  my $logfile_abs = app->home->rel_file($config->{logfile});
  if (-f $logfile_abs) {
    print "<li>LOGパス : OK\n";
    if (-r $logfile_abs && -w $logfile_abs) {
      print "<li>LOGパーミッション : OK\n";
    } else {
      print "<li>LOGパーミッション : NG\n";
    }
  } else {
    print "<li>LOGパス : NG\n";
  }

  # テンプレート
  foreach (qw(bbs find note error message)) {
    if (-f "$config->{tmpldir}/$_.html") {
      print "<li>テンプレート( $_.html ) : OK\n";
    } else {
      print "<li>テンプレート( $_.html ) : NG\n";
    }
  }

  # Image-Magick動作確認
  eval { require Image::Magick; };
  if ($@) {
    print "<li>Image-Magick動作: NG\n";
  } else {
    print "<li>Image-Magick動作: OK\n";
  }

  print <<EOM;
</ul>
</body>
</html>
EOM

};

# ヘルパー定義
# 自動リンク
app->helper('aska.autolink' => sub {
  my ($self, $text) = @_;

  $text =~ s/(s?https?:\/\/([\w\-.!~*'();\/?:\@=+\$,%#]|&amp;)+)/<a href="$1" target="_blank">$1<\/a>/g;
  return $text;
});

#  アクセス制限
app->helper('aska.get_host' => sub {
  my $self = shift;
  
  my $config = $self->app->config;
  
  # IP&ホスト取得
  my $host = $ENV{REMOTE_HOST};
  my $addr = $ENV{REMOTE_ADDR};
  if ($config->{gethostbyaddr} && ($host eq "" || $host eq $addr)) {
    $host = gethostbyaddr(pack("C4", split(/\./, $addr)), 2);
  }

  # IPチェック
  my $flg;
  foreach ( split(/\s+/,$config->{deny_addr}) ) {
    s/\./\\\./g;
    s/\*/\.\*/g;

    if ($addr =~ /^$_/i) { $flg++; last; }
  }
  if ($flg) {
    error("アクセスを許可されていません");

  # ホストチェック
  } elsif ($host) {

    foreach ( split(/\s+/,$config->{deny_host}) ) {
      s/\./\\\./g;
      s/\*/\.\*/g;

      if ($host =~ /$_$/i) { $flg++; last; }
    }
    if ($flg) {
      error("アクセスを許可されていません");
    }
  }

  if ($host eq "") { $host = $addr; }
  return ($host,$addr);
});

#  crypt暗号
app->helper('aska.encrypt' => sub {
  my ($self, $in) = @_;

  my @wd = (0 .. 9, 'a'..'z', 'A'..'Z', '.', '/');
  srand;
  my $salt = $wd[int(rand(@wd))] . $wd[int(rand(@wd))];
  crypt($in,$salt) || crypt ($in,'$1$'.$salt);
});

# crypt照合
app->helper('aska.decrypt' => sub {
  my ($self, $in, $dec) = @_;

  my $salt = $dec =~ /^\$1\$(.*)\$/ ? $1 : substr($dec,0,2);
  if (crypt($in,$salt) eq $dec || crypt($in,'$1$'.$salt) eq $dec) {
    return 1;
  } else {
    return 0;
  }
});

# ページ送り作成
app->helper('aska.make_pager' => sub {
  my ($self, $i,$pg) = @_;
  
  my $config = $self->app->config;

  # ページ繰越数定義
  $config->{pg_max} ||= 10;
  my $next = $pg + $config->{pg_max};
  my $back = $pg - $config->{pg_max};

  # ページ繰越ボタン作成
  my @pg;
  if ($back >= 0 || $next < $i) {
    my $flg;
    my ($w,$x,$y,$z) = (0,1,0,$i);
    while ($z > 0) {
      if ($pg == $y) {
        $flg++;
        push(@pg,qq!<li><span>$x</span></li>\n!);
      } else {
        push(@pg,qq!<li><a href="$config->{bbs_cgi}?pg=$y">$x</a></li>\n!);
      }
      $x++;
      $y += $config->{pg_max};
      $z -= $config->{pg_max};

      if ($flg) { $w++; }
      last if ($w >= 5 && @pg >= 10);
    }
  }
  while( @pg >= 11 ) { shift(@pg); }
  my $ret = join('', @pg);
  if ($back >= 0) {
    $ret = qq!<li><a href="$config->{bbs_cgi}?pg=$back">&laquo;</a></li>\n! . $ret;
  }
  if ($next < $i) {
    $ret .= qq!<li><a href="$config->{bbs_cgi}?pg=$next">&raquo;</a></li>\n!;
  }
  
  # 結果を返す
  return $ret ? qq|<ul class="pager">\n$ret</ul>| : '';
});

#  認証画像作成 [ライブラリ版]
app->helper('aska.load_pngren' => sub {
  my ($self, $plain, $sipng) = @_;
  
  my $config = $self->app->config;

  # 数字
  my @img = split(//, $plain);

  # 表示開始
  require $config->{pngren_pl};
  pngren::PngRen($sipng, \@img);
});

#  復号
app->helper('aska.decrypt_' => sub {
  my ($self, $caplen, $buf) = @_;
  
  my $config = $self->app->config;

  # 復号
  $buf =~ s/N/\n/g;
  $buf =~ s/([0-9A-Fa-f]{2})/pack('H2', $1)/eg;
  my $plain = Crypt::RC4::RC4( $config->{captcha_key}, $buf );

  # 先頭の数字を抽出
  $plain =~ s/^(\d{$caplen}).*/$1/ or &err_img;
  return $plain;
});

app->helper('aska.search' => sub {
  my ($self, $word, $cond) = @_;
  
  my $config = $self->app->config;

  # キーワードを配列化
  my @wd = split(/\s+/, $word);
  
  # 検索処理
  my @log;
  my $logfile_abs = app->home->rel_file($config->{logfile});
  open(my $in_fh, $logfile_abs) or croak("open error: $logfile_abs");
  while (my $line = <$in_fh>) {
    $line = Encode::decode('UTF-8', $line);
    my ($no,$date,$nam,$eml,$sub,$com,$url,$hos,$pw,$tim) = split(/<>/, $line);
    
    my $flg;
    foreach my $wd (@wd) {
      $wd = quotemeta $wd;
      print $wd;
      if ("$nam $eml $sub $com $url" =~ /$wd/i) {
        $flg++;
        if ($cond == 0) { last; }
      } else {
        if ($cond == 1) { $flg = 0; last; }
      }
    }
    next if (!$flg);

    push(@log,$line);
  }
  close($in_fh);

  # 検索結果
  return @log;
});

app->helper('aska.mail_to' => sub {

  my ($self, $in, $date,$host) = @_;
  
  my $config = $self->app->config;

  # 件名をMIMEエンコード
  if ($config->{chg_code} == 0) { require Jcode; }
  my $msub = Jcode->new("BBS : $in->{sub}",'sjis')->mime_encode;

  # コメント内の改行復元
  my $com = $in->{comment};
  $com =~ s/<br>/\n/g;
  $com =~ s/&lt;/>/g;
  $com =~ s/&gt;/</g;
  $com =~ s/&quot;/"/g;
  $com =~ s/&amp;/&/g;
  $com =~ s/&#39;/'/g;

  # メール本文を定義
  my $mbody = <<EOM;
掲示板に投稿がありました。

投稿日：$date
ホスト：$host

件名  ：$in->{sub}
お名前：$in->{name}
E-mail：$in->{email}
URL   ：$in->{url}

$com
EOM

  # JISコード変換
  $mbody = Jcode->new($mbody,'sjis')->jis;

  # メールアドレスがない場合は管理者メールに置き換え
  $in->{email} ||= $config->{mailto};

  # sendmailコマンド
  my $scmd = "$config->{sendmail} -t -i";
  if ($config->{sendm_f}) {
    $scmd .= " -f $in->{email}";
  }

  # 送信
  open(MAIL,"| $scmd") or error("送信失敗");
  print MAIL "To: $config->{mailto}\n";
  print MAIL "From: $in->{email}\n";
  print MAIL "Subject: $msub\n";
  print MAIL "MIME-Version: 1.0\n";
  print MAIL "Content-type: text/plain; charset=ISO-2022-JP\n";
  print MAIL "Content-Transfer-Encoding: 7bit\n";
  print MAIL "X-Mailer: $config->{version}\n\n";
  print MAIL "$mbody\n";
  close(MAIL);
});

#  エラー処理
app->helper('aska.err_img' => sub {
  my $self = shift;
  
  # エラー画像
  my @err = qw{
    47 49 46 38 39 61 2d 00 0f 00 80 00 00 00 00 00 ff ff ff 2c
    00 00 00 00 2d 00 0f 00 00 02 49 8c 8f a9 cb ed 0f a3 9c 34
    81 7b 03 ce 7a 23 7c 6c 00 c4 19 5c 76 8e dd ca 96 8c 9b b6
    63 89 aa ee 22 ca 3a 3d db 6a 03 f3 74 40 ac 55 ee 11 dc f9
    42 bd 22 f0 a7 34 2d 63 4e 9c 87 c7 93 fe b2 95 ae f7 0b 0e
    8b c7 de 02 00 3b
  };

  print "Content-type: image/gif\n\n";
  foreach (@err) {
    print pack('C*', hex($_));
  }
});

app->start;
