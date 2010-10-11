#!/bin/bash
#
# File: adm-remop.sh
# Implements:
#
# Copyright: Jens L��s UU, 2010
# Copyright license: According to GPL, see file COPYING in this directory.
#

# adm-remop newkey <role>
# adm-remop req <role>
# adm-remop bless <user> <role>
# adm-remop init

REMOPDIR=REMOPDIR
REMOPUSER=REMOPUSER

if [ "$1" == init ]; then
    if [ "$USER" != "$REMOPUSER" ]; then
	echo "You are not the administrative remop user '$REMOPUSER'"
	exit 1
    fi
    if ! mkdir -p $REMOPDIR/etc $REMOPDIR/keys $REMOPDIR/req; then
	echo "Cannot create $REMOPDIR/etc $REMOPDIR/keys $REMOPDIR/req"
	exit 1
    fi
    chmod 0733 $REMOPDIR/req

    [ -f $REMOPDIR/etc/key.pem ] || (umask 0077; openssl genrsa -out $REMOPDIR/etc/key.pem 4096)
    chmod 0400 $REMOPDIR/etc/key.pem
    openssl rsa -in $REMOPDIR/etc/key.pem -pubout -out $REMOPDIR/etc/pubkey.pem
    logger -i -p syslog.info "$USER:init:"
    exit 0
fi

if [ "$1" == newkey ]; then
    ROLE="$2"
    if [ -z "$ROLE" ]; then
	echo "Need ROLE as argument"
	exit 2
    fi
    
    if [ -f "$HOME/.remop/keys/$USER/$ROLE/key" ]; then
	echo "Key $HOME/.remop/keys/$USER/$ROLE/key already exists!"
	exit 1
    fi

    mkdir -p $HOME/.remop/keys/$USER/$ROLE
    (umask 0077;ssh-keygen -b 2048 -t rsa -f $HOME/.remop/keys/$USER/$ROLE/key)
    chmod 0444 $HOME/.remop/keys/$USER/$ROLE/key.pub
    echo "Created key rsa_$ROLE"
    exit 0
fi

if [ "$1" == req ]; then
    ROLE="$2"
    KEY="$HOME/.remop/keys/$USER/$ROLE/key"
    if [ ! -f "$KEY" ]; then
	echo "You need to create a suitable key for $ROLE first."
	echo " $ adm-remop newkey $ROLE"
	echo "($KEY does not exist)."
	exit 1
    fi
    [ -f "$KEY.pub" ] || exit 1
    
    RND="$(head -c 32 /dev/urandom | md5sum |cut -d ' ' -f 1)"

    cp -p $KEY.pub $REMOPDIR/req/req.$USER.$ROLE.pub.$RND || exit 1
    logger -i -p syslog.info "$USER:req:$ROLE:$KEY:"
    exit 0
fi

if [ "$1" == reqlist ]; then
    for f in $REMOPDIR/req/req.*; do
	RUSER="$(echo $f|cut -d . -f 2)"
	ROLE="$(echo $f|cut -d . -f 3)"
	echo "$RUSER($(stat -c %U $f)) $ROLE $(stat -c %y $f)"
    done
    exit 0
fi

if [ "$1" == list ]; then
    for d in $REMOPDIR/keys/*; do
	echo "User $(basename $d):"
	for f in $d/*; do
	    echo " $(basename $f)"
	done
    done
    exit 0
fi

if [ "$1" == reject ]; then
    if [ "$USER" != "$REMOPUSER" ]; then
	echo "You are not the administrative remop user '$REMOPUSER'"
	exit 1
    fi

    RUSER="$2"
    ROLE="$3"

    for f in $REMOPDIR/req/req.$RUSER.$ROLE.pub.*; do
	if [ ! -f "$f" ]; then
	    echo "Cannot find request for $RUSER and $ROLE"
	    exit 1
	fi
    done
    PUBKEY="$REMOPDIR/req/req.$RUSER.$ROLE.pub.*"

    rm -f $PUBKEY
    logger -i -p syslog.info "$USER:reject:$RUSER:$ROLE:"
    exit 0
fi

if [ "$1" == bless ]; then
    if [ "$USER" != "$REMOPUSER" ]; then
	echo "You are not the administrative remop user '$REMOPUSER'"
	exit 1
    fi
    [ -f $REMOPDIR/etc/key.pem ] || exit 2
    RUSER="$2"
    ROLE="$3"

    for f in $REMOPDIR/req/req.$RUSER.$ROLE.pub.*; do
	if [ ! -f "$f" ]; then
	    echo "Cannot find request for $RUSER and $ROLE"
	    exit 1
	fi
    done
    PUBKEY="$REMOPDIR/req/req.$RUSER.$ROLE.pub.*"

    # FIXME: check that owner is same as $RUSER in filename

    mkdir -p $REMOPDIR/keys/$RUSER/$ROLE
    if ! cp $PUBKEY $REMOPDIR/keys/$RUSER/$ROLE/key.pub; then
	echo "Failed to copy $PUBKEY"
	exit 1
    fi
    
    openssl dgst -sha512 -sign $REMOPDIR/etc/key.pem -out $REMOPDIR/keys/$RUSER/$ROLE/key.pub.sig $REMOPDIR/keys/$RUSER/$ROLE/key.pub
    echo "$RUSER:$ROLE:" >> $REMOPDIR/keylist
    openssl dgst -sha512 -sign $REMOPDIR/etc/key.pem -out $REMOPDIR/keylist.sig $REMOPDIR/keylist

    rm -f $PUBKEY
    logger -i -p syslog.info "$USER:bless:$RUSER:$ROLE:"
    exit 0
fi

cat <<EOF
User:
=====
adm-remop newkey <role>
 Create a new RSA ssh key pair for <role>. Key store in current working dir.

adm-remop req <role>
 Create a request for authorization.

Administrator:
==============
adm-remop bless <user> <role>
 Accept an authorization request.

adm-remop init
 Initialize repository and create the repository RSA key pair.

adm-remop reqlist
 List pending request.

adm-remop reject <user> <role>
 Reject authorization request.

adm-remop list
 List all existing authorizations.

EOF

