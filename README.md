# ASKA BBS (Mojoliciousバージョン)

これは、使いやすい掲示板である[Kent WebのASKA BBS](http://www.kent-web.com/bbs/aska.html)を、
モダンなPerlの文法とMojoliciousを使って再実装したものです。
([サンプル](http://www.kent-web.com/bbs/aska/aska.cgi))

このプロジェクトは、
CGIをモダンなPerlで記述で記述することを目標にして、
開始されました。

## 特徴

　特徴は以下のようになっています。

- WebフレームワークMojoliciousを使った掲示板の実装
- cpanmが内部的には利用され、ワンコマンドで、セットアップが完了
- Perl 5.10.1以上であることだけが要件。
- CGIと組み込みのWebサーバーで実行が可能
- たとえば、さくらのレンタルサーバー・スタンダードで動かすことができます。

## Perlのバージョンの確認

Perlのバージョンを確認してください。5.10.1以上であれば、利用できます。

    perl -v

## A. CGIとして利用する場合のインストール方法

CGIを設置したいディレクトリに、ダウンロードしてください。

    curl -kL https://github.com/yuki-kimoto/kent-aska-mojo/archive/latest.tar.gz > aska-latest.tar.gz

展開します。

    tar xf aska-latest.tar.gz

名前を変更します。

    mv kent-aska-mojo-latest aska

ディレクトリの中に移動します。

    cd aska

セットアップします。必要なモジュールがインストールされます。

    ./setup.sh

セットアップの確認をします。以下のコマンドを実行してください。

    perl -c aska.pl

と入力してください。「syntax OK」と表示されればセットアップが成功しています。

CGIを設置したら次のURLでアクセスすることができます。

    http://yourhost/somepath/aska/aska.cgi

上記の方法は、さくらのスタンダードで利用できることを確認済みです。

### 自分のユーザー権限で実効しない場合の追加の作業

　CGIスクリプトを、自分のユーザー権限で実効できない環境の場合は、次の追加の作業を行ってください。
たとえば、CGIスクリプトがapache権限で実行されるような場合です。

askaディレクトリの中のすべてのファイルをapacheユーザー権限に変更します。

    chown -R apache:apache aska

また、この場合は、CGIが実行できる設定になっている必要がありますので、
Apacheの設定ファイルをチェックしてください。

たとえば以下のような設定が必要です。

    <Directory /var/www/html>
        Options +ExecCGI
        AddHandler cgi-script .cgi
    </Directory>

### B. 組み込みのサーバーで実効する場合のインストール方法

任意のディレクトリに、ダウンロードしてください。

    curl -kL https://github.com/yuki-kimoto/kent-aska-mojo/archive/latest.tar.gz > aska-latest.tar.gz

展開します。

    tar xf aska-latest.tar.gz

名前を変更します。

    mv kent-aska-mojo-latest aska

ディレクトリの中に移動します。

    cd aska

セットアップします。必要なモジュールがインストールされます。

    ./setup.sh

セットアップの確認をします。以下のコマンドを実行してください。

    perl -c aska.pl

と入力してください。「syntax OK」と表示されればセットアップが成功しています。

組み込みのサーバーを起動します。

    ./aska

ポート番号が10080で起動するので、次のURLでアクセスしてください。

    http://yourhost:10080

アプリケーションを停止するには次のようにします。

    ./aska --stop

## 設定ファイル

設定ファイルは「aska.conf」です。ハッシュのリファレンスで記述されています。

## FAQ

### ASKA BBSからの内部的な改善点を教えてください。

- WebフレームワークとしてMojoliciousを利用。
  - HTTPリクエスの解析、パラーメータの受け取り、クッキーの取得処理
  - URLのルーティングの改善、テンプレートの記述を改善、ヘッダ、フッタを部品に
- グローバルなファイルハンドルは利用せずに、レキシカル変数を使用
- 必要モジュールのインストールのシステムとしてcpanmを使用
- Emailの送信にMIME::Liteを使用して簡潔にした
- ページ送りの処理にData::PageとData::Page::Navigationを利用して簡潔にした。
- 文字コードのエンコードにはEncodeモジュールを使用。JCodeの使用をなくした。
- データ保存のときのエンコード処理のロジックを共通化して改善
- CGIに加えて組み込みWebサーバーで起動ができるので、非常に高速でスケーラビリティがある。
- 開発サーバーが利用できるので、開発が非常に楽になった。

## ASKA BBSからデータを移行することはできますか

データファイル(log/log.cgi)の内容をコピーして、「data/data.txt」に貼り付けて、UTF-8で保存してください。

### CentOSでセットアップができません

CentOSでは、Perlのコアモジュールのすべてがインストールされませんので、
以下のコマンドでコアモジュールをインストールしてください。

    yum -y install perl-core

### PSGIに対応していますか

はいPSGIに対応しています。

### Perlのバージョンが5.8です

そのような場合は、perlbrewを使って、5.10.1以上のPerlをインストールすることで、
利用することが可能になります。CGIは無理ですが、組み込みのWebサーバーを使って
利用できます。

### Image::Magickがインストールされているかの確認したいです

Image::Magickがインストールされているかどうかを確認するには、
以下のコマンドで確認できます。

    perldoc Image::Magick

## 開発者向けの情報

開発を行う場合は、次のコマンドを実行すると、組み込みの開発サーバーが起動します。

    ./morbo

次のURLでアクセス可能です。

    http://yourhost:3000

「aska.my.conf」という設定ファイルを作成すると、
そちらが優先的に読み込まれるので便利です。

    cp aska.conf aska.my.conf
