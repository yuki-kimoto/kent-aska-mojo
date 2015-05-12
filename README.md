# ASKA BBS (Mojoliciousバージョン)

これは、[Kent Web](http://www.kent-web.com/)の
[ASKA BBS](http://www.kent-web.com/bbs/aska.html)を、
モダンなPerlの文法とMojoliciousを使って再実装したものです。

モダンなPerl記述でCGIを記述することを目標にして、
このプロジェクトは開始されました。

# 特徴

　特徴は以下のようになっています。

* WebフレームワークMojoliciousを使った掲示板の実装
* CGIと組み込みのWebサーバーで実行が可能
* cpanmが内部的には利用され、ワンコマンドで、セットアップが完了
* Perl 5.10.1以上であることだけが要件です。
* さくらのレンタルサーバー・スタンダードで動かすことができます。
  (またSuExecを設定しているWebサーバーで利用が可能)


**Image::Magickがインストールされているかの確認

Image::Magickがインストールされているかどうかを確認するには、
以下のコマンドで確認できます。

    perldoc Image::Magick
