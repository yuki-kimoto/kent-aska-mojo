# ASKA BBS (Mojoliciousバージョン)

これは、使いやすい掲示板である[Kent WebのASKA BBS](http://www.kent-web.com/bbs/aska.html)を、
モダンなPerlの文法とMojoliciousを使って再実装したものです。
([サンプル](http://www.kent-web.com/bbs/aska/aska.cgi))

このプロジェクトは、
モダンなPerl記述でCGIを記述することを目標にして、
開始されました。

# 特徴

　特徴は以下のようになっています。

* WebフレームワークMojoliciousを使った掲示板の実装
* CGIと組み込みのWebサーバーで実行が可能
* cpanmが内部的には利用され、ワンコマンドで、セットアップが完了
* Perl 5.10.1以上であることだけが要件。
* さくらのレンタルサーバー・スタンダードで動かすことができます。
  (またSuExecを設定しているWebサーバーで利用が可能)

# ダウンロード(開発版)

ダウンロードします。

    curl -kL https://github.com/yuki-kimoto/kent-aska-mojo/archive/devel.tar.gz > aska-devel.tar.gz

展開します。

    tar xf aska-devel.tar.gz

名前を変更します。

    mv kent-aska-mojo-devel aska

# セットアップ

ディレクトリの中に移動します。

    cd aska

ASKA BBSを最初にセットアップします。必要なモジュールがインストールされます。

    ./setup.sh

# CGIとして実効する場合

Webブラウザから「aska.cgi」にアクセスしてください。




# ASKA BBSからの移行方法

データファイル(log/log.cgi)をコピーして、「data/data.txt」にUTF-8で保存してください。

# 設定ファイル

設定ファイルは「aska.conf」です。ハッシュのリファレンスで記述されています。

# Image::Magickがインストールされているかの確認

Image::Magickがインストールされているかどうかを確認するには、
以下のコマンドで確認できます。

    perldoc Image::Magick
