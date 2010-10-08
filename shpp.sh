#!/bin/bash
#
# File: shpp.sh
# Implements:
#
# Copyright: Jens L��s, SLU 2007
# Copyright license: According to GPL, see file COPYING in this directory.
#

while [ "$1" ]; do
    src="$1"
    dst=${src/%.sh/}
    echo "$src > $dst"
    cat $src > $dst
    sed -i "s,LIBEXECDIR=LIBEXECDIR,LIBEXECDIR=$LIBEXECDIR," $dst
    sed -i "s,BINDIR=BINDIR,BINDIR=$BINDIR," $dst
    sed -i "s,VERSION=VERSION,VERSION=$VERSION," $dst
    sed -i "s,REMOPDIR=REMOPDIR,REMOPDIR=$REMOPDIR," $dst
    sed -i "s,REMOPUSER=REMOPUSER,REMOPUSER=$REMOPUSER," $dst
    sed -i "s,SYSCONFDIR=SYSCONFDIR,SYSCONFDIR=$SYSCONFDIR," $dst
    sed -i "s,LOCALSTATEDIR=LOCALSTATEDIR,LOCALSTATEDIR=$LOCALSTATEDIR," $dst
    chmod a+x $dst
    shift
done

