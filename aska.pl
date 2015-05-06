#!/usr/bin/env

use FindBin;
use lib "$FindBin::Bin/extlib/perl5/lib";
use Mojolicious::Lite;
use Crypt::RC4;

my $config = app->config;

get '/' => sub {
  my $self = shift;

# データ受理
my %in = parse_form();

# 処理分岐
if ($in{mode} eq 'regist') { regist(); }
if ($in{mode} eq 'dele') { dele_data(); }
if ($in{mode} eq 'find') { find_data(); }
if ($in{mode} eq 'note') { note_page(); }
bbs_list();


#  記事表示

sub bbs_list {
  # 仮
  my %in;
    
  # レス処理
  $in{res} =~ s/\D//g;
  my %res;
  if ($in{res}) {
    my $flg;
    open(IN,"$config->{logfile}") or error("open err: $config->{logfile}");
    while (<IN>) {
      my ($no,$sub,$com) = (split(/<>/))[0,4,5];
      if ($in{res} == $no) {
        $flg++;
        $res{sub} = $sub;
        $res{com} = $com;
        last;
      }
    }
    close(IN);

    if (!$flg) { error("該当記事が見つかりません"); }

    $res{sub} =~ s/^Re://g;
    $res{sub} =~ s/\[\d+\]\s?//g;
    $res{sub} = "Re:[$in{res}] $res{sub}";
    $res{com} = "&gt; $res{com}";
    $res{com} =~ s|<br( /)?>|\n&gt; |ig;
  }

  # ページ数定義
  my $pg = $in{pg} || 0;

  # データオープン
  my ($i,@log);
  open(IN,"$config->{logfile}") or error("open err: $config->{logfile}");
  while (<IN>) {
    $i++;
    next if ($i < $pg + 1);
    next if ($i > $pg + $config->{pg_max});

    push(@log,$_);
  }
  close(IN);

  # 繰越ボタン作成
  my $page_btn = make_pager($i,$pg);

  # クッキー取得
  my @cook = get_cookie();
  $cook[2] ||= 'http://';

  # テンプレート読込
  open(IN,"$config->{tmpldir}/bbs.html") or error("open err: bbs.html");
  my $tmpl = join('', <IN>);
  close(IN);

  # 文字置換
  $tmpl =~ s/!([a-z]+_cgi)!/$config->{$1}/g;
  $tmpl =~ s/!homepage!/$config->{homepage}/g;
  $tmpl =~ s/<!-- page_btn -->/$page_btn/g;
  $tmpl =~ s/!name!/$cook[0]/;
  $tmpl =~ s/!email!/$cook[1]/;
  $tmpl =~ s/!url!/$cook[2]/;
  $tmpl =~ s/!sub!/$res{sub}/;
  $tmpl =~ s/!comment!/$res{com}/;
  $tmpl =~ s/!bbs_title!/$config->{bbs_title}/g;

  # テンプレート分割
  my ($head,$loop,$foot) = $tmpl =~ /(.+)<!-- loop_begin -->(.+)<!-- loop_end -->(.+)/s
      ? ($1,$2,$3) : error("テンプレート不正");

  # 画像認証作成
  my ($str_plain,$str_crypt);
  if ($config->{use_captcha} > 0) {
    require $config->{captcha_pl};
    ($str_plain,$str_crypt) = cap::make($config->{captcha_key},$config->{cap_len});
    $head =~ s/!str_crypt!/$str_crypt/g;
  } else {
    $head =~ s/<!-- captcha_begin -->.+<!-- captcha_end -->//s;
  }

  # ヘッダ表示
  print "Content-type: text/html; charset=shift_jis\n\n";
  print $head;

  # ループ部
  foreach (@log) {
    my ($no,$date,$name,$eml,$sub,$com,$url,undef,undef,undef) = split(/<>/);
    $name = qq|<a href="mailto:$eml">$name</a>| if ($eml);
    $com = autolink($com) if ($config->{autolink});
    $com =~ s/([>]|^)(&gt;[^<]*)/$1<span style="color:$config->{ref_col}">$2<\/span>/g if ($config->{ref_col});
    $com .= qq|<p class="url"><a href="$url" target="_blank">$url</a></p>| if ($url);

    my $tmp = $loop;
    $tmp =~ s/!num!/$no/g;
    $tmp =~ s/!sub!/$sub/g;
    $tmp =~ s/!name!/$name/g;
    $tmp =~ s/!date!/$date/g;
    $tmp =~ s/!comment!/$com/g;
    $tmp =~ s/!bbs_cgi!/$config->{bbs_cgi}/g;
    print $tmp;
  }

  # フッタ
  footer($foot);
}


#  記事書込

sub regist {
  # 仮
  my %in;
  
  # 投稿チェック
  if ($config->{postonly} && $ENV{REQUEST_METHOD} ne 'POST') {
    error("不正なリクエストです");
  }

  # 不要改行カット
  $in{sub}  =~ s|<br />||g;
  $in{name} =~ s|<br />||g;
  $in{pwd}  =~ s|<br />||g;
  $in{captcha} =~ s|<br />||g;
  $in{comment} =~ s|(<br />)+$||g;

  # チェック
  if ($config->{no_wd}) { no_wd(); }
  if ($config->{jp_wd}) { jp_wd(); }
  if ($config->{urlnum} > 0) { urlnum(); }

  # 画像認証チェック
  if ($config->{use_captcha} > 0) {
    require $config->{captcha_pl};
    if ($in{captcha} !~ /^\d{$config->{cap_len}}$/) {
      error("画像認証が入力不備です。<br />投稿フォームに戻って再読込み後、再入力してください");
    }

    # 投稿キーチェック
    # -1 : キー不一致
    #  0 : 制限時間オーバー
    #  1 : キー一致
    my $chk = cap::check($in{captcha},$in{str_crypt},$config->{captcha_key},$config->{cap_time},$config->{cap_len});
    if ($chk == 0) {
      error("画像認証が制限時間を超過しました。<br />投稿フォームに戻って再読込み後指定の数字を再入力してください");
    } elsif ($chk == -1) {
      error("画像認証が不正です。<br />投稿フォームに戻って再読込み後再入力してください");
    }
  }

  # 未入力の場合
  if ($in{url} eq "http://") { $in{url} = ""; }
  $in{sub} ||= '無題';

  # フォーム内容をチェック
  my $err;
  if ($in{name} eq "") { $err .= "名前が入力されていません<br />"; }
  if ($in{comment} eq "") { $err .= "コメントが入力されていません<br />"; }
  if ($in{email} ne '' && $in{email} !~ /^[\w\.\-]+\@[\w\.\-]+\.[a-zA-Z]{2,6}$/) {
    $err .= "Ｅメールの入力内容が不正です<br />";
  }
  if ($in{url} ne '' && $in{url} !~ /^https?:\/\/[\w\-.!~*'();\/?:\@&=+\$,%#]+$/) {
    $err .= "参照先URLの入力内容が不正です<br />";
  }
  if ($err) { error($err); }

  # コード変換
  if ($config->{chg_code} == 1) {
    require Jcode;
    $in{name} = Jcode->new($in{name})->sjis;
    $in{sub}  = Jcode->new($in{sub})->sjis;
    $in{comment} = Jcode->new($in{comment})->sjis;
  }

  # ホスト取得
  my ($host,$addr) = get_host();

  # 削除キー暗号化
  my $pwd = encrypt($in{pwd}) if ($in{pwd} ne "");

  # 時間取得
  my $time = time;
  my ($min,$hour,$mday,$mon,$year,$wday) = (localtime($time))[1..6];
  my @wk = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
  my $date = sprintf("%04d/%02d/%02d(%s) %02d:%02d",
        $year+1900,$mon+1,$mday,$wk[$wday],$hour,$min);

  # 先頭記事読み取り
  open(DAT,"+< $config->{logfile}") or error("open err: $config->{logfile}");
  eval "flock(DAT, 2);";
  my $top = <DAT>;

  # 重複投稿チェック
  my ($no,$dat,$nam,$eml,$sub,$com,$url,$hos,$pw,$tim) = split(/<>/,$top);
  if ($in{name} eq $nam && $in{comment} eq $com) {
    close(DAT);
    error("二重投稿は禁止です");
  }

  # 連続投稿チェック
  my $flg;
  if ($config->{regCtl} == 1) {
    if ($host eq $hos && $time - $tim < $config->{wait}) { $flg = 1; }
  } elsif ($config->{regCtl} == 2) {
    if ($time - $tim < $config->{wait}) { $flg = 1; }
  }
  if ($flg) {
    close(DAT);
    error("現在投稿制限中です。もうしばらくたってから投稿をお願いします");
  }

  # 記事No採番
  $no++;

  # 記事数調整
  my @data = ($top);
  my $i = 0;
  while (<DAT>) {
    $i++;
    push(@data,$_);

    last if ($i >= $config->{maxlog}-1);
  }

  # 更新
  seek(DAT, 0, 0);
  print DAT "$no<>$date<>$in{name}<>$in{email}<>$in{sub}<>$in{comment}<>$in{url}<>$host<>$pwd<>$time<>\n";
  print DAT @data;
  truncate(DAT, tell(DAT));
  close(DAT);

  # クッキー格納
  set_cookie($in{name},$in{email},$in{url}) if ($in{cookie} == 1);

  # メール通知
  mail_to($date,$host) if ($config->{mailing} == 1);

  # 完了画面
  message("ありがとうございます。記事を受理しました。");
}


#  ワード検索

sub find_data {
  # 仮
  my %in;
  
  # 条件
  $in{cond} =~ s/\D//g;
  $in{word} =~ s|<br />||g;

  # 検索条件プルダウン
  my %op = (1 => 'AND', 0 => 'OR');
  my $op_cond;
  foreach (1,0) {
    if ($in{cond} eq $_) {
      $op_cond .= qq|<option value="$_" selected="selected">$op{$_}</option>\n|;
    } else {
      $op_cond .= qq|<option value="$_">$op{$_}</option>\n|;
    }
  }

  # 検索実行
  $in{word} = Jcode->new($in{word})->sjis if ($config->{chg_code} == 1);
  my @log = search($in{word},$in{cond}) if ($in{word} ne '');

  # テンプレート読み込み
  open(IN,"$config->{tmpldir}/find.html") or error("open err: find.html");
  my $tmpl = join('', <IN>);
  close(IN);

  # 文字置換
  $tmpl =~ s/!bbs_cgi!/$config->{bbs_cgi}/g;
  $tmpl =~ s/<!-- op_cond -->/$op_cond/;
  $tmpl =~ s/!word!/$in{word}/;

  # テンプレート分割
  my ($head,$loop,$foot) = $tmpl =~ /(.+)<!-- loop_begin -->(.+)<!-- loop_end -->(.+)/s
      ? ($1,$2,$3) : error("テンプレート不正");

  # ヘッダ部
  print "Content-type: text/html; charset=shift_jis\n\n";
  print $head;

  # ループ部
  foreach (@log) {
    my ($no,$date,$name,$eml,$sub,$com,$url,undef,undef,undef) = split(/<>/);
    $name = qq|<a href="mailto:$eml">$name</a>| if ($eml);
    $com  = autolink($com) if ($config->{autolink});
    $com =~ s/([>]|^)(&gt;[^<]*)/$1<span style="color:$config->{ref_col}">$2<\/span>/g if ($config->{ref_col});
    $url  = qq|<a href="$url" target="_blank">$url</a>| if ($url);

    my $tmp = $loop;
    $tmp =~ s/!sub!/$sub/g;
    $tmp =~ s/!date!/$date/g;
    $tmp =~ s/!name!/$name/g;
    $tmp =~ s/!home!/$url/g;
    $tmp =~ s/!comment!/$com/g;
    print $tmp;
  }

  # フッタ
  footer($foot);
}


#  検索実行

sub search {
  my ($word,$cond) = @_;

  # キーワードを配列化
  $word =~ s/\x81\x40/ /g;
  my @wd = split(/\s+/,$word);

  # キーワード検索準備（Shift-JIS定義）
  my $ascii = '[\x00-\x7F]';
  my $hanka = '[\xA1-\xDF]';
  my $kanji = '[\x81-\x9F\xE0-\xFC][\x40-\x7E\x80-\xFC]';

  # 検索処理
  my @log;
  open(IN,"$config->{logfile}") or error("open err: $config->{logfile}");
  while (<IN>) {
    my ($no,$date,$nam,$eml,$sub,$com,$url,$hos,$pw,$tim) = split(/<>/);

    my $flg;
    foreach my $wd (@wd) {
      if ("$nam $eml $sub $com $url" =~ /^(?:$ascii|$hanka|$kanji)*?\Q$wd\E/i) {
        $flg++;
        if ($cond == 0) { last; }
      } else {
        if ($cond == 1) { $flg = 0; last; }
      }
    }
    next if (!$flg);

    push(@log,$_);
  }
  close(IN);

  # 検索結果
  return @log;
}


#  留意事項表示

sub note_page {
  open(IN,"$config->{tmpldir}/note.html") or error("open err: note.html");
  my $tmpl = join('', <IN>);
  close(IN);

  print "Content-type: text/html; charset=shift_jis\n\n";
  print $tmpl;
  exit;
}


#  ユーザ記事削除

sub dele_data {
  # 仮
  my %in;
  
  # 入力チェック
  if ($in{num} eq '' or $in{pwd} eq '') {
    error("削除Noまたは削除キーが入力モレです");
  }

  my ($flg,$crypt,@log);
  open(DAT,"+< $config->{logfile}") or error("open err: $config->{logfile}");
  eval "flock(DAT, 2);";
  while (<DAT>) {
    my ($no,$dat,$nam,$eml,$sub,$com,$url,$hos,$pw,$tim) = split(/<>/);

    if ($in{num} == $no) {
      $flg++;
      $crypt = $pw;
      next;
    }
    push(@log,$_);
  }

  if (!$flg or !$crypt) {
    close(DAT);
    error("削除キーが設定されていないか又は記事が見当たりません");
  }

  # 削除キーを照合
  if (decrypt($in{pwd},$crypt) != 1) {
    close(DAT);
    error("認証できません");
  }

  # ログ更新
  seek(DAT, 0, 0);
  print DAT @log;
  truncate(DAT, tell(DAT));
  close(DAT);

  # 完了
  message("記事を削除しました");
}


#  エラー画面

sub error {
  my $err = shift;

  open(IN,"$config->{tmpldir}/error.html") or die;
  my $tmpl = join('', <IN>);
  close(IN);

  $tmpl =~ s/!error!/$err/g;

  print "Content-type: text/html; charset=shift_jis\n\n";
  print $tmpl;
  exit;
}


#  メール送信

sub mail_to {
  # 仮
  my %in;
  
  my ($date,$host) = @_;

  # 件名をMIMEエンコード
  if ($config->{chg_code} == 0) { require Jcode; }
  my $msub = Jcode->new("BBS : $in{sub}",'sjis')->mime_encode;

  # コメント内の改行復元
  my $com = $in{comment};
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

件名  ：$in{sub}
お名前：$in{name}
E-mail：$in{email}
URL   ：$in{url}

$com
EOM

  # JISコード変換
  $mbody = Jcode->new($mbody,'sjis')->jis;

  # メールアドレスがない場合は管理者メールに置き換え
  $in{email} ||= $config->{mailto};

  # sendmailコマンド
  my $scmd = "$config->{sendmail} -t -i";
  if ($config->{sendm_f}) {
    $scmd .= " -f $in{email}";
  }

  # 送信
  open(MAIL,"| $scmd") or error("送信失敗");
  print MAIL "To: $config->{mailto}\n";
  print MAIL "From: $in{email}\n";
  print MAIL "Subject: $msub\n";
  print MAIL "MIME-Version: 1.0\n";
  print MAIL "Content-type: text/plain; charset=ISO-2022-JP\n";
  print MAIL "Content-Transfer-Encoding: 7bit\n";
  print MAIL "X-Mailer: $config->{version}\n\n";
  print MAIL "$mbody\n";
  close(MAIL);
}


#  フッター

sub footer {
  my $foot = shift;

  # 著作権表記（削除・改変禁止）
  my $copy = <<EOM;
<p style="margin-top:2em;text-align:center;font-family:Verdana,Helvetica,Arial;font-size:10px;">
- <a href="http://www.kent-web.com/" target="_top">ASKA BBS</a> -
</p>
EOM

  if ($foot =~ /(.+)(<\/body[^>]*>.*)/si) {
    print "$1$copy$2\n";
  } else {
    print "$foot$copy\n";
    print "</body></html>\n";
  }
  exit;
}


#  自動リンク

sub autolink {
  my $text = shift;

  $text =~ s/(s?https?:\/\/([\w\-.!~*'();\/?:\@=+\$,%#]|&amp;)+)/<a href="$1" target="_blank">$1<\/a>/g;
  return $text;
}


#  禁止ワードチェック

sub no_wd {
  # 仮
  my %in;
  
  my $flg;
  foreach ( split(/,/,$config->{no_wd}) ) {
    if (index("$in{name} $in{sub} $in{comment}", $_) >= 0) {
      $flg = 1;
      last;
    }
  }
  if ($flg) { error("禁止ワードが含まれています"); }
}


#  日本語チェック

sub jp_wd {
  # 仮
  my %in;
  
  if ($in{comment} !~ /[\x81-\x9F\xE0-\xFC][\x40-\x7E\x80-\xFC]/) {
    error("メッセージに日本語が含まれていません");
  }
}


#  URL個数チェック

sub urlnum {
  # 仮
  my %in;
  
  my $com = $in{comment};
  my ($num) = ($com =~ s|(https?://)|$1|ig);
  if ($num > $config->{urlnum}) {
    error("コメント中のURLアドレスは最大$config->{urlnum}個までです");
  }
}


#  アクセス制限

sub get_host {
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
}


#  crypt暗号

sub encrypt {
  my $in = shift;

  my @wd = (0 .. 9, 'a'..'z', 'A'..'Z', '.', '/');
  srand;
  my $salt = $wd[int(rand(@wd))] . $wd[int(rand(@wd))];
  crypt($in,$salt) || crypt ($in,'$1$'.$salt);
}


#  crypt照合

sub decrypt {
  my ($in,$dec) = @_;

  my $salt = $dec =~ /^\$1\$(.*)\$/ ? $1 : substr($dec,0,2);
  if (crypt($in,$salt) eq $dec || crypt($in,'$1$'.$salt) eq $dec) {
    return 1;
  } else {
    return 0;
  }
}


#  完了メッセージ

sub message {
  my $msg = shift;

  open(IN,"$config->{tmpldir}/message.html") or error("open err: message.html");
  my $tmpl = join('', <IN>);
  close(IN);

  $tmpl =~ s/!bbs_cgi!/$config->{bbs_cgi}/g;
  $tmpl =~ s/!message!/$msg/g;

  print "Content-type: text/html; charset=shift_jis\n\n";
  print $tmpl;
  exit;
}


#  ページ送り作成

sub make_pager {
  my ($i,$pg) = @_;

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
}


#  クッキー発行

sub set_cookie {
  my @data = @_;

  # 60日間有効
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,undef,undef) = gmtime(time + 60*24*60*60);
  my @mon  = qw|Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec|;
  my @week = qw|Sun Mon Tue Wed Thu Fri Sat|;

  # 時刻フォーマット
  my $gmt = sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT",
        $week[$wday],$mday,$mon[$mon],$year+1900,$hour,$min,$sec);

  # URLエンコード
  my $cook;
  foreach (@data) {
    s/(\W)/sprintf("%%%02X", unpack("C", $1))/eg;
    $cook .= "$_<>";
  }

  print "Set-Cookie: $config->{cookie_id}=$cook; expires=$gmt\n";
}


#  クッキー取得

sub get_cookie {
  # クッキー取得
  my $cook = $ENV{HTTP_COOKIE};

  # 該当IDを取り出す
  my %cook;
  foreach ( split(/;/,$cook) ) {
    my ($key,$val) = split(/=/);
    $key =~ s/\s//g;
    $cook{$key} = $val;
  }

  # URLデコード
  my @cook;
  foreach ( split(/<>/,$cook{$config->{cookie_id}}) ) {
    s/%([0-9A-Fa-f][0-9A-Fa-f])/pack("H2", $1)/eg;
    s/[&"'<>]//g;

    push(@cook,$_);
  }
  return @cook;
}


};

get '/admin' => sub {
  my $self = shift;

# データ受理
my %in = parse_form();

# 認証
check_passwd();

# 管理モード
admin_mode();


#  管理モード

sub admin_mode {
  # 仮
  my %in;
  
  # 削除処理
  if ($in{job_dele} && $in{no}) {

    # 削除情報
    my %del;
    foreach ( split(/\0/,$in{no}) ) {
      $del{$_}++;
    }

    # 削除情報をマッチング
    my @data;
    open(DAT,"+< $config->{logfile}") or error("open err: $config->{logfile}");
    eval "flock(DAT, 2);";
    while (<DAT>) {
      my ($no) = (split(/<>/))[0];

      if (!defined($del{$no})) {
        push(@data,$_);
      }
    }

    # 更新
    seek(DAT, 0, 0);
    print DAT @data;
    truncate(DAT, tell(DAT));
    close(DAT);

  # 修正画面
  } elsif ($in{job_edit} && $in{no}) {

    my $log;
    open(IN,"$config->{logfile}") or error("open err: $config->{logfile}");
    while (<IN>) {
      my ($no,$dat,$nam,$eml,$sub,$com,$url,undef,undef,undef) = split(/<>/);

      if ($in{no} == $no) {
        $log = $_;
        last;
      }
    }
    close(IN);

    # 修正フォームへ
    edit_form($log);

  # 修正実行
  } elsif ($in{job} eq "edit") {

    # 未入力の場合
    if ($in{url} eq "http://") { $in{url} = ""; }
    $in{sub} ||= "無題";

    # コード変換
    if ($config->{chg_code} == 1) {
      require Jcode;
      $in{name} = Jcode->new($in{name})->sjis;
      $in{sub}  = Jcode->new($in{sub})->sjis;
      $in{comment} = Jcode->new($in{comment})->sjis;
    }

    # 読み出し
    my @data;
    open(DAT,"+< $config->{logfile}") or error("open err: $config->{logfile}");
    eval "flock(DAT, 2);";
    while (<DAT>) {
      my ($no,$dat,$nam,$eml,$sub,$com,$url,$hos,$pwd,$tim) = split(/<>/);

      if ($in{no} == $no) {
        $_ = "$no<>$dat<>$in{name}<>$in{email}<>$in{sub}<>$in{comment}<>$in{url}<>$hos<>$pwd<>$tim<>\n";
      }
      push(@data,$_);
    }

    # 更新
    seek(DAT, 0, 0);
    print DAT @data;
    truncate(DAT, tell(DAT));
    close(DAT);

    # 完了メッセージ
    message("記事を修正しました");
  }

  # ページ数
  my $page = 0;
  foreach ( keys %in ) {
    if (/^page:(\d+)/) {
      $page = $1;
      last;
    }
  }

  # 最大表示件数
  my $logs = 30;

  # 削除画面を表示
  header("管理モード");
  print <<EOM;
<div align="right">
<form action="$config->{bbs_cgi}">
<input type="submit" value="&lt; 掲示板">
</form>
</div>
<div class="ttl">■ 管理モード</div>
<form action="$config->{admin_cgi}" method="post">
<input type="hidden" name="mode" value="admin">
<input type="hidden" name="pass" value="$in{pass}">
<div class="btn">
<input type="submit" name="job_edit" value="修正">
<input type="submit" name="job_dele" value="削除">
</div>
EOM

  # 記事を展開
  my $i = 0;
  open(IN,"$config->{logfile}") or error("open err: $config->{logfile}");
  while (<IN>) {
    $i++;
    next if ($i < $page + 1);
    last if ($i > $page + $logs);

    my ($no,$dat,$nam,$eml,$sub,$com,$url,$hos,undef,undef) = split(/<>/);
    $nam = qq|<a href="mailto:$eml">$nam</a>| if ($eml);

    print qq|<div class="art"><input type="checkbox" name="no" value="$no">\n|;
    print qq|[$no] <strong>$sub</strong> 投稿者：<b>$nam</b> 日時：$dat [ <span>$hos</span> ]</div>\n|;
    print qq|<div class="com">| . cut_str($com) . qq|</div>\n|;
  }
  close(IN);

  print "</dl>\n";

  # ページ繰越定義
  my $next = $page + $logs;
  my $back = $page - $logs;
  if ($back >= 0) {
    print qq|<input type="submit" name="page:$back" value="前ページ">\n|;
  }
  if ($next < $i) {
    print qq|<input type="submit" name="page:$next" value="次ページ">\n|;
  }

  print <<EOM;
</form>
</body>
</html>
EOM
  exit;
}


#  修正フォーム

sub edit_form {
  # 仮
  my %in;
  
  my $log = shift;
  my ($no,$dat,$nam,$eml,$sub,$com,$url,undef,undef,undef) = split(/<>/,$log);

  $com =~ s|<br( /)?>|\n|g;
  $url ||= "http://";

  header("管理モード ＞ 修正フォーム");
  print <<EOM;
<div align="right">
<form action="$config->{admin_cgi}" method="post">
<input type="hidden" name="mode" value="admin">
<input type="hidden" name="pass" value="$in{pass}">
<input type="submit" value="&lt; 前画面">
</form>
</div>
<div class="ttl">■ 編集フォーム</div>
<ul>
<li>変更する部分のみ修正して送信ボタンを押してください。
</ul>
<form action="$config->{admin_cgi}" method="post">
<input type="hidden" name="mode" value="admin">
<input type="hidden" name="job" value="edit">
<input type="hidden" name="no" value="$no">
<input type="hidden" name="pass" value="$in{pass}">
<table class="form-tbl">
<tr>
  <th>おなまえ</th>
  <td><input type="text" name="name" size="28" value="$nam"></td>
</tr><tr>
  <th>Ｅメール</th>
  <td><input type="text" name="email" size="28" value="$eml"></td>
</tr><tr>
  <th>タイトル</th>
  <td><input type="text" name="sub" size="36" value="$sub"></td>
</tr><tr>
  <th>参照先</th>
  <td><input type="text" name="url" size="50" value="$url"></td>
</tr><tr>
  <th>内容</th>
  <td><textarea name="comment" cols="56" rows="7">$com</textarea></td>
</tr>
</table>
<input type="submit" value="送信する">
<input type="reset" value="リセット">
</form>
</body>
</html>
EOM
  exit;
}


#  HTMLヘッダー

sub header {
  my $ttl = shift;

  print <<EOM;
Content-type: text/html; charset=shift_jis

<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=shift_jis">
<meta http-equiv="content-style-type" content="text/css">
<style type="text/css">
<!--
body,td,th { font-size:80%; background:#f0f0f0; font-family:Verdana,"MS PGothic","Osaka",Arial,sans-serif; }
p.ttl { font-weight:bold; color:#004080; border-bottom:1px solid #004080; padding:2px; }
p.err { color:#dd0000; }
p.msg { color:#006400; }
table.form-tbl { border:1px solid #8080C0; border-collapse:collapse; margin:1em 0; }
table.form-tbl th { border:1px solid #8080C0; background:#DCDCED; padding:5px; }
table.form-tbl td { border:1px solid #8080C0; background:#fff; padding:5px; }
div.ttl { border-bottom:1px solid #004080; padding:4px; color:#004080; font-weight:bold; margin:1em 0; }
div.btn input { width:60px; }
div.art { border-top:1px dotted gray; padding:5px; margin-top:10px; }
div.art span, div.art strong { color:green; }
div.com { margin-left:2em; color:#804000; font-size:90%; }
-->
</style>
<title>$ttl</title>
</head>
<body>
EOM
}


#  パスワード認証

sub check_passwd {
  # 仮
  my %in;
  
  # パスワードが未入力の場合は入力フォーム画面
  if ($in{pass} eq "") {
    enter_form();

  # パスワード認証
  } elsif ($in{pass} ne $config->{password}) {
    error("認証できません");
  }
}


#  入室画面

sub enter_form {
  header("入室画面");
  print <<EOM;
<div align="center">
<form action="$config->{admin_cgi}" method="post">
<table width="410" style="margin-top:50px">
<tr>
  <td height="50" align="center">
    <fieldset><legend>管理パスワード入力</legend><br>
    <input type="password" name="pass" size="26">
    <input type="submit" value=" 認証 "><br><br>
    </fieldset>
  </td>
</tr>
</table>
</form>
<script language="javascript">
<!--
self.document.forms[0].pass.focus();
//-->
</script>
</div>
</body>
</html>
EOM
  exit;
}


#  エラー

sub error_ {
  my $err = shift;

  header("ERROR!");
  print <<EOM;
<div align="center">
<hr width="350">
<h3>ERROR!</h3>
<p class="err">$err</p>
<hr width="350">
<form>
<input type="button" value="前画面に戻る" onclick="history.back()">
</form>
</div>
</body>
</html>
EOM
  exit;
}


#  完了メッセージ

sub message_ {
  my $msg = shift;
  
  # 仮
  my %in;

  header("完了");
  print <<EOM;
<div align="center" style="margin-top:3em;">
<hr width="350">
<p class="msg">$msg</p>
<hr width="350">
<form action="$config->{admin_cgi}" method="post">
<input type="hidden" name="pass" value="$in{pass}">
<input type="submit" value="管理画面に戻る">
</form>
</div>
</body>
</html>
EOM
  exit;
}


#  文字数カット for Shift-JIS

sub cut_str {
  my $str = shift;
  $str =~ s|<br( /)?>||g;

  my $i = 0;
  my $ret;
  while($str =~ /([\x00-\x7F\xA1-\xDF]|[\x81-\x9F\xE0-\xFC][\x40-\x7E\x80-\xFC])/gx) {
    $i++;
    $ret .= $1;
    last if ($i >= 40);
  }
  return $ret;
}

};

get '/captcha' => sub {
  my $self = shift;

# パラメータ受け取り
my $buf = $ENV{QUERY_STRING};
$buf =~ s/[<>&"'\s]//g;
&error if (!$buf);

# 復号
my $plain = &decrypt($config->{cap_len});

# 認証画像作成
if ($config->{use_captcha} == 2) {
  require $config->{captsec_pl};
  &load_capsec($plain, "$config->{bin_dir}/$config->{font_ttl}");
} else {
  &load_pngren($plain, "$config->{bin_dir}/$config->{si_png}");
}


#  認証画像作成 [ライブラリ版]

sub load_pngren {
  my ($plain, $sipng) = @_;

  # 数字
  my @img = split(//, $plain);

  # 表示開始
  require $config->{pngren_pl};
  &pngren::PngRen($sipng, \@img);
  exit;
}


#  復号

sub decrypt_ {
  my $caplen = shift;
  
  # 仮
  my $buf;

  # 復号
  $buf =~ s/N/\n/g;
  $buf =~ s/([0-9A-Fa-f]{2})/pack('H2', $1)/eg;
  my $plain = RC4( $config->{captcha_key}, $buf );

  # 先頭の数字を抽出
  $plain =~ s/^(\d{$caplen}).*/$1/ or &err_img;
  return $plain;
}


#  エラー処理

sub err_img {
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
  exit;
}


};

get '/check' => sub {
  my $self = shift;

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
if (-f $config->{logfile}) {
  print "<li>LOGパス : OK\n";
  if (-r $config->{logfile} && -w $config->{logfile}) {
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
exit;


};

app->start;

