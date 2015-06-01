use FindBin;
use lib "$FindBin::Bin/extlib/lib/perl5";
use Mojolicious::Lite;
use Carp 'croak';
use Crypt::RC4;
use Encode 'encode';
use File::Path 'mkpath';
use MIME::Lite;
use Mojo::ByteStream;
use Mojo::Util 'xml_escape';

# コンフィグの読み込み
my $my_config_file = app->home->rel_file('aska.my.conf');

if (-f $my_config_file) {
  plugin 'Config', file => $my_config_file;
}
else {
  plugin 'Config';
}

# データファイルがなければ作成
my $data_file = app->home->rel_file('data/data.txt');
unless (-f $data_file) {
  unless(open my $fh, '>', $data_file) {
    my $error = "Can't open $data_file: $!";
    app->log->error($error);
    croak($error);
  }
}
app->config->{logfile} = $data_file;

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
      require $self->app->home->rel_file('lib/captsec.pl');
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

# ヘルパー定義

my @names = qw(no date name email sub comment url host pwd time );
# データ行を解析して、Perlのデータにする
app->helper('aska.parse_data_line' => sub {
  my ($self, $line) = @_;
  
  my $row = {};
  my @values = split(/<>/, $line);
  
  # 各値をエスケープの復元処理
  for (my $i = 0; $i < @names; $i++) {
    my $name = $names[$i];
    $row->{$name} = $self->aska->decode_data($values[$i]);
  }
  
  return $row;
});

# データ用のエスケープ処理
app->helper('aska.encode_data' => sub {
  my ($self, $data) = @_;
  
  # エスケープ処理
  $data =~ s/&/&amp;/g;
  $data =~ s/</&lt;/g;
  $data =~ s/>/&gt;/g;
  $data =~ s/"/&quot;/g;
  $data =~ s/'/&#39;/g;
  $data =~ s|\r\n|<br />|g;
  $data =~ s|[\r\n]|<br />|g;
  
  return $data;
});

# データ用のエスケープ復元処理
app->helper('aska.decode_data' => sub {
  my ($self, $data) = @_;
  
  return unless defined $data;
  
  # エスケープ復元処理
  $data =~ s/&lt;/</g;
  $data =~ s/&gt;/>/g;
  $data =~ s/&quot;/"/g;
  $data =~ s/&amp;/&/g;
  $data =~ s/&#39;/'/g;
  $data =~ s|<br />|\n|g;
  
  return $data;
});

# 保存データ行の作成
app->helper('aska.create_data_line' => sub {
  my ($self, $in) = @_;
  
  $in->{sub} =~ s/\x0D\x0A|\x0D|\x0A//g if defined $in->{sub};
  $in->{name} =~ s/\x0D\x0A|\x0D|\x0A//g if defined $in->{name};
  $in->{pwd}  =~ s/\x0D\x0A|\x0D|\x0A//g if defined $in->{pwd};
  $in->{captcha} =~ s/\x0D\x0A|\x0D|\x0A//g if defined $in->{captcha};
  $in->{comment} =~ s/(\x0D\x0A|\x0D|\x0A)+$//g if defined $in->{comment};
  
  # エスケープして行のデータを作成
  my $entry = {};
  for my $name (@names) {
    if (defined $in->{$name}) {
      $entry->{$name} = $self->aska->encode_data($in->{$name});
    }
    else {
      $entry->{$name} = '';
    }
  }

  # 行の作成
  my $line = join(
    '<>',
    (
      $entry->{no},
      $entry->{date},
      $entry->{name},
      $entry->{email},
      $entry->{sub},
      $entry->{comment},
      $entry->{url},
      $entry->{host},
      $entry->{pwd},
      $entry->{time}
    )
  );
  $line .= '<>';
  
  return $line;
});

# コメント解析
app->helper('aska.parse_comment' => sub {
  my ($self, $comment) = @_;
  
  # コンフィグ
  my $config = $self->app->config;
  
  # XMLエスケープ
  my $edit_comment = xml_escape($comment);

  # オートリンク
  my $autolink = $config->{autolink};
  if ($autolink) {
    $edit_comment =~ s/(s?https?:\/\/([\w\-.!~*'();\/?:\@=+\$,%#]|&amp;)+)/<a href="$1" target="_blank">$1<\/a>/g;
  }
  
  # 引用に色をつける
  my $ref_col = $config->{ref_col};
  if ($ref_col) {
    $edit_comment =~ s/^(&gt;.+)$/<span style="color:$ref_col">$1<\/span>/mg;
  }

  # 改行を<br />に変換
  $edit_comment =~ s#\x0D\x0A|\x0D|\x0A#<br />#g;
  
  # 自動HTMLエスケープしないようにバイトストリームオブジェクトに変換
  my $edit_comment_b = Mojo::ByteStream->new($edit_comment);
  
  return $edit_comment_b;
});

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
  my $addr = $self->tx->remote_address;
  my $host;
  if ($config->{gethostbyaddr}) {
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

  $host ||= $addr;
  return ($host, $addr);
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
  require $self->app->home->rel_file('lib/pngren.pl');

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
  my $data_file = $config->{logfile};
  open(my $in_fh, $data_file) or croak("open error: $data_file");
  while (my $line = <$in_fh>) {
    $line = Encode::decode('UTF-8', $line);
    my ($no, $date, $nam, $eml, $sub, $comment, $url, $hos, $pw, $tim)
      = split(/<>/, $line);
    
    my $flg;
    foreach my $wd (@wd) {
      $wd = quotemeta $wd;
      print $wd;
      if ("$nam $eml $sub $comment $url" =~ /$wd/i) {
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

  my ($self, $in, $date, $host) = @_;

  # 件名をMIMEエンコード
  my $msub = "BBS : $in->{sub}";

  # コメント内の改行復元
  my $comment = $in->{comment};
  $comment =~ s/<br>/\n/g;
  $comment =~ s/&lt;/>/g;
  $comment =~ s/&gt;/</g;
  $comment =~ s/&quot;/"/g;
  $comment =~ s/&amp;/&/g;
  $comment =~ s/&#39;/'/g;

  # メール本文を定義
  my $mbody = <<EOM;
掲示板に投稿がありました。

投稿日：$date
ホスト：$host

件名  ：$in->{sub}
お名前：$in->{name}
E-mail：$in->{email}
URL   ：$in->{url}

$comment
EOM

  # メールアドレスがない場合は管理者メールに置き換え
  my $config = $self->app->config;
  $in->{email} ||= $config->{mailto};

  # メール送信
  my $ml = MIME::Lite->new(
    From => $in->{email},
    To => $config->{mailto},
    Subject => encode('MIME-Header-ISO_2022_JP', $msub),
    Type => 'text/plain; charset="ISO-2022-JP"',
    Encoding => '7bit',
    Data => encode('ISO-2022-JP', $mbody)
  );
  $ml->send();
});

app->start;
