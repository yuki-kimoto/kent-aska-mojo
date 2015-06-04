use FindBin;
use lib "$FindBin::Bin/extlib/lib/perl5";
use lib "$FindBin::Bin/lib";
use Mojolicious::Lite;
use Carp 'croak';
use Crypt::RC4;
use Encode 'encode';
use File::Path 'mkpath';
use MIME::Lite;
use Mojo::ByteStream;
use Mojo::Util 'xml_escape';
use Data::Page;
use Data::Page::Navigation;

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

# エントリー一覧の取得
app->helper('aska.get_entries' => sub {
  my ($self, $page) = @_;
  
  my $config = $self->app->config;

  open(my $data_fh, '<', $data_file)
    or Carp::croak("open error: $data_file");
  
  my $pg_max = $config->{pg_max};
  my $offset = ($page - 1) * $pg_max;
  
  my @lines;
  my $line_num = 0;
  while (my $line = <$data_fh>) {
    if ($line_num >= $offset && $line_num < $offset + $pg_max) {
      $line = Encode::decode('UTF-8', $line);
      push(@lines, $line);
    }
    $line_num++;
  }
  
  # ページャー
  my $pager = Data::Page->new;
  $pager->total_entries($line_num);
  $pager->entries_per_page($pg_max);
  $pager->current_page($page);
  
  # ループ部
  my $entries = [];
  for my $line (@lines) {
    my $entry = $self->aska->parse_data_line($line);
    
    push @$entries, $entry;
  }
  
  return {entries => $entries, pager => $pager};
});

my @col_names = qw(no date name email sub comment url host pwd time );
# データ行を解析して、Perlのデータにする
app->helper('aska.parse_data_line' => sub {
  my ($self, $line) = @_;
  
  my $row = {};
  my @values = split(/<>/, $line);
  
  # 各値をエスケープの復元処理
  for (my $i = 0; $i < @col_names; $i++) {
    my $name = $col_names[$i];
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
  for my $name (@col_names) {
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
  my $found;
  foreach ( split(/\s+/,$config->{deny_addr}) ) {
    s/\./\\\./g;
    s/\*/\.\*/g;

    if ($addr =~ /^$_/i) { $found++; last; }
  }
  if ($found) {
    error("アクセスを許可されていません");

  # ホストチェック
  } elsif ($host) {

    foreach ( split(/\s+/,$config->{deny_host}) ) {
      s/\./\\\./g;
      s/\*/\.\*/g;

      if ($host =~ /$_$/i) { $found++; last; }
    }
    if ($found) {
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

#  認証画像作成 [ライブラリ版]
app->helper('aska.load_pngren' => sub {
  my ($self, $plain, $sipng) = @_;
  
  # 数字
  my @img = split(//, $plain);

  # 表示開始
  require 'pngren.pl';

  pngren::PngRen($sipng, \@img);
});

#  認証画像作成 [ライブラリ版]
app->helper('aska.load_capsec' => sub {
  my ($self, $plain, $font) = @_;
  
  # 表示開始
  require 'captsec.pl';

  load_capsec($plain, $font);
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
  my ($self, $word_str, $cond) = @_;
  
  my $config = $self->app->config;

  # キーワードを配列化
  my @words = split(/\s+/, $word_str);
  
  # 検索処理
  my @lines;
  my $data_file = $config->{logfile};
  open(my $data_fh, '<', $data_file)
    or croak("open error: $data_file");
  while (my $line = <$data_fh>) {
    $line = Encode::decode('UTF-8', $line);
    my $entry = $self->aska->parse_data_line($line);

    my $text
      = "$entry->{no} $entry->{email} $entry->{sub} $entry->{comment} $entry->{url}";
    my $found;
    foreach my $word (@words) {
      $word = quotemeta $word;
      if ($text =~ /$word/i) {
        $found++;
        if ($cond == 0) { last; }
      }
      else {
        if ($cond == 1) {
          $found = 0;
          last;
        }
      }
    }
    next if (!$found);

    push(@lines, $line);
  }

  # 検索結果
  return @lines;
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
