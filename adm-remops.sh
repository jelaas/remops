#!/bin/bash
#
# File: adm-remops.sh
# Implements:
#
# Copyright: Jens Låås UU, 2010
# Copyright license: According to GPL, see file COPYING in this directory.
#

# * adm-remops add manual <user> <role> <keyfile>
#    Add a manually managed key to server. 
#
# * adm-remops add managed <user> <role>
#    Fetch and add a managed key.
#
# * adm-remops sync check
#    Display what changes a sync would perform.
#
# * adm-remops sync now
#    Sync managed keys with operations server.
#
# * adm-remops commit
#    Commit keys in local repository to Authorized_keys.
#
# * adm-remops init <url>
#

BINDIR=BINDIR

function add_manual {
    RUSER="$1"
    ROLE="$2"
    KEYFILE="$3"
    
    mkdir -p $HOME/remops/roles/$ROLE/manual_keys
    cp $KEYFILE $HOME/remops/roles/$ROLE/manual_keys/$RUSER
}

function add_managed {
    RUSER="$1"
    ROLE="$2"

    [ -f $HOME/remops/etc/ops_base_url ] || exit 1
    read BASEURL < $HOME/remops/etc/ops_base_url
    
    if [ ! -f $HOME/remops/etc/ops_public_key ]; then
	URL=$BASEURL/etc/pubkey.pem
	wget -O $HOME/remops/etc/ops_public_key $URL
    fi

    F=/tmp/key.$RUSER.$ROLE.$$

    URL=$BASEURL/keys/$RUSER/$ROLE
    wget -O $F $URL/key.pub
    wget -O $F.sig $URL/key.pub.sig
    if ! openssl dgst -sha512 -verify $HOME/remops/etc/ops_public_key -signature $F.sig $F; then
	echo "Signature check failed for $RUSER/$ROLE"
	rm -f $F $F.sig
	return 1
    fi
    mkdir -p $HOME/remops/roles/$ROLE/managed_keys
    cp $F $HOME/remops/roles/$ROLE/managed_keys/$RUSER
    rm -f $F $F.sig
}

function sync_new {
    local L U R

    while read L; do
	U=$(echo $L|cut -d : -f 1)
	R=$(echo $L|cut -d : -f 2)
	if [ ! -f $HOME/remops/roles/$R/managed_keys/$U ]; then
	    echo "N $U:$R"
	fi
    done
}

function sync_check {
    local U R D
    
    [ -f $HOME/remops/etc/ops_base_url ] || exit 1
    read BASEURL < $HOME/remops/etc/ops_base_url

    if [ ! -f $HOME/remops/etc/ops_public_key ]; then
	URL=$BASEURL/etc/pubkey.pem
	wget -O $HOME/remops/etc/ops_public_key $URL
    fi

    F=/tmp/keylist.$$

    wget -O $F $BASEURL/keylist

    # Compare locally managed keys with central keylist
    cat $F|sync_new

    for D in $HOME/remops/roles/*; do
	[ -d "$D" ] || continue
	for U in $D/managed_keys/*; do
	    [ -f "$D" ] || continue
	    if ! grep "^$(basename $U):$(basename $D):" $F; then
		echo "D $(basename $U):$(basename $D)"
	    fi
	done
    done
}

function sync_do {
    while read CMD L; do
	U=$(echo $L|cut -d : -f 1)
        R=$(echo $L|cut -d : -f 2)
	[ "$CMD" = D ] && rm -f $HOME/remops/roles/$R/managed_keys/$U
	[ "$CMD" = N ] && add_managed $U $R
    done
}

function sync_now {
    [ -f $HOME/remops/etc/ops_base_url ] || exit 1
    
    sync_check|sync_do
}

function commit {
    F=/tmp/akeys.$$
    mkdir -p $HOME/.ssh
    chmod 0700 $HOME/.ssh
    grep -sv remops $HOME/.ssh/authorized_keys > $F
    for f in $HOME/remops/roles/*/managed_keys/* $HOME/remops/roles/*/manual_keys/*; do
	[ -f "$f" ] || continue
	U="$(basename $f)"
	R="$(dirname $f)"
	R="$(dirname $R)"
	R="$(basename $R)"
	echo -n "command=\"$BINDIR/remops $U $R\",no-port-forwarding " >> $F
	cat $f >> $F
    done
    cp $F $HOME/.ssh/authorized_keys
}

[ "$1" = add -a "$2" = manual ] && shift 2 && add_manual "$@" && exit
[ "$1" = add -a "$2" = managed ] && shift 2 && add_managed "$@" && exit

[ "$1" = sync -a "$2" = check ] && shift 2 && sync_check "$@" && exit
[ "$1" = sync -a "$2" = now ] && shift 2 && sync_now "$@" && exit

[ "$1" = commit ] && commit && exit

if [ "$1" = init -a "$2" ]; then
    URL="$2/etc/pubkey.pem"
    if wget -O /dev/null $URL; then
	mkdir -p $HOME/remops/etc
	mkdir -p $HOME/remops/roles/public/cmd
	echo "$2" > $HOME/remops/etc/ops_base_url
	wget -O $HOME/remops/etc/ops_public_key $URL
    fi
    exit
fi

cat <<EOF
adm-remops add manual <user> <role> <keyfile>
   Add a manually managed key to server. 

adm-remops add managed <user> <role>
   Fetch and add a managed key.

adm-remops sync check
   Display what changes a sync would perform.

adm-remops sync now
   Sync managed keys with operations server.

adm-remops commit
   Commit keys in local repository to Authorized_keys.

adm-remops init <base_url>
   Initialize and set base URL for operations server.

EOF
