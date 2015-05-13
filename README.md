# ASKA BBS (Mojoliciousバージョン)

これは、使いやすい掲示板である[Kent WebのASKA BBS](http://www.kent-web.com/bbs/aska.html)を、
モダンなPerlの文法とMojoliciousを使って再実装したものです。
([サンプル](http://www.kent-web.com/bbs/aska/aska.cgi))

このプロジェクトは、
CGIをモダンなPerlで記述で記述することを目標にして、
開始されました。

# 特徴

　特徴は以下のようになっています。

* WebフレームワークMojoliciousを使った掲示板の実装
* CGIと組み込みのWebサーバーで実行が可能
* cpanmが内部的には利用され、ワンコマンドで、セットアップが完了
* Perl 5.10.1以上であることだけが要件。
* さくらのレンタルサーバー・スタンダードで動かすことができます。
  (SuExecを設定している共有レンタルサーバーなら利用が可能)
  
# Perlのバージョンの確認

Perlのバージョンを確認してください。5.10.1以上であれば、利用できます。

    perl -v

# ダウンロード(開発版)

以下の利用方法で、ダウンロードするディレクトリが変わります。

## suEXEC環境を提供している共有レンタルサーバーにCGIとして設置する場合

これはさくらのレンタルサーバー・スタンダードなどが該当します。
CGIを設置するディレクトリに移動してください。この場所は、OSによって異なります。

    cd ~/www

## 自分が管理しているサーバーにCGIとして設置する場合

root権限になります。

    su -

次に、Webサーバーのドキュメントルートに移動します。この場所は、OSによって異なります。

    cd /var/www/html

この場合は、ドキュメントルートにおいてCGIが実行できる設定になっている必要がありますので、
チェックしてください。

たとえば以下の設定が必要です。

    <Directory /var/www/html>
        Options +ExecCGI
        AddHandler cgi-script .cgi
    </Directory>

## 自分が管理しているサーバーで組み込みのWebサーバーを使って起動する場合

ユーザー権限で、好きな場所にダウンロードしてください。この方法は、
管理の手間が増えますが、パフォーマンスにおいて有利です。

## ダウンロード作業

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

## 自分が管理しているサーバーにCGIとして設置する場合の追加の処理

自分が管理しているサーバーにCGIとして設置する場合は、ファイルの権限をapache
が実行に切り替えます。この値は、Apacheの設定よって異なる場合があります。

    cd /var/www/html
    chown -R apache:apache aska

# ASKA BBSへのアクセス

## suEXEC環境を提供している共有レンタルサーバーにCGIとして設置する場合

Webブラウザから「aska.cgi」にアクセスしてください。

    http://yourhost/aska/aska.cgi
    
## 自分が管理しているサーバーで組み込みのWebサーバーを使って起動する場合

Webブラウザから「aska.cgi」にアクセスしてください。

    http://yourhost/aska/aska.cgi

## 自分が管理しているサーバーで組み込みのWebサーバーを使って起動する場合

アプリケーションを開始するには次のようにします。

    ./aska

ポート番号が10080で起動するので、URLでアクセスしてください。

    http://yourhost:10080

アプリケーションを停止するには次のようにします。

    ./aska --stop

# ASKA BBSからの移行方法

データファイル(log/log.cgi)をコピーして、「data/data.txt」にUTF-8で保存してください。

# 設定ファイル

設定ファイルは「aska.conf」です。ハッシュのリファレンスで記述されています。

# FAQ

## PSGIに対応していますか

はいPSGIに対応しています。

## Perlのバージョンが5.8です

そのような場合は、perlbrewを使って、5.10.1以上のPerlをインストールすることで、
利用することが可能になります。CGIは無理ですが、組み込みのWebサーバーを使って
利用できます。

## Image::Magickがインストールされているかの確認したいです

Image::Magickがインストールされているかどうかを確認するには、
以下のコマンドで確認できます。

    perldoc Image::Magick
