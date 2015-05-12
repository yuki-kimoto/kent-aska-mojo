#!/bin/sh
perl cpanm -n -l extlib Module::CoreList
perl cpanm -f -l extlib Mojolicious@6.10
perl -Iextlib/lib/perl5 cpanm -n -L extlib --installdeps .
perl cpanm -n -l extlib GD::SecurityImage@1.70
