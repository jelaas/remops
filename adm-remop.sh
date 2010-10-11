#!/bin/bash
#
# File: adm-remop.sh
# Implements:
#
# Copyright: Jens Låås UU, 2010
# Copyright license: According to GPL, see file COPYING in this directory.
#

# adm-remop newkey <role>
# adm-remop req <role>
# adm-remop bless <user> <role>
# adm-remop init

REMOPDIR=REMOPDIR
REMOPUSER=REMOPUSER

if [ "$1" = init ]; then
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

if [ "$1" = newkey ]; then
    RUSER="$USER"
    if [ "$2" = "-u" ]; then
	RUSER="$3"
	shift 2
    fi
    ROLE="$2"
    if [ -z "$ROLE" ]; then
	echo "Need ROLE as argument"
	exit 2
    fi
    
    if [ -f "$HOME/.remop/keys/$RUSER/$ROLE/key" ]; then
	echo "Key $HOME/.remop/keys/$RUSER/$ROLE/key already exists!"
	exit 1
    fi

    mkdir -p $HOME/.remop/keys/$RUSER/$ROLE
    (umask 0077;ssh-keygen -b 2048 -t rsa -f $HOME/.remop/keys/$RUSER/$ROLE/key)
    chmod 0444 $HOME/.remop/keys/$RUSER/$ROLE/key.pub
    echo "Created key for user $RUSER with role $ROLE"
    exit 0
fi

if [ "$1" = req ]; then
    RUSER="$USER"
    if [ "$2" = "-u" ]; then
	RUSER="$3"
	shift 2
    fi
    ROLE="$2"
    KEY="$3"
    if [ -z "$KEY" ]; then
	KEY="$HOME/.remop/keys/$RUSER/$ROLE/key.pub"
	if [ ! -f "$KEY" ]; then
	    echo "You need to create a suitable key for $ROLE first."
	    echo " $ adm-remop newkey $ROLE"
	    echo "($KEY does not exist)."
	    exit 1
	fi
    fi
    if [ ! -f "$KEY" ]; then
	echo "You need need a suitable key for $ROLE."
	echo "($KEY does not exist)."
	exit 1
    fi
    
    RND="$(head -c 32 /dev/urandom | md5sum |cut -d ' ' -f 1)"

    cp -p $KEY $REMOPDIR/req/req.$RUSER.$ROLE.pub.$RND || exit 1
    logger -i -p syslog.info "$RUSER:req:$ROLE:$KEY:"
    exit 0
fi

if [ "$1" = reqlist ]; then
    for f in $REMOPDIR/req/req.*; do
	RUSER="$(echo $f|cut -d . -f 2)"
	ROLE="$(echo $f|cut -d . -f 3)"
	echo "$RUSER($(stat -c %U $f)) $ROLE $(stat -c %y $f)"
    done
    exit 0
fi

if [ "$1" = list ]; then
    for d in $REMOPDIR/keys/*; do
	echo "User $(basename $d):"
	for f in $d/*; do
	    echo " $(basename $f)"
	done
    done
    exit 0
fi

if [ "$1" = reject ]; then
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

if [ "$1" = bless ]; then
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

if [ "$1" = curse ]; then
    if [ "$USER" != "$REMOPUSER" ]; then
	echo "You are not the administrative remop user '$REMOPUSER'"
	exit 1
    fi

    RUSER="$2"
    ROLE="$3"
    F=/tmp/keylst.$$

    rm -f $REMOPDIR/keys/$RUSER/$ROLE/key.pub $REMOPDIR/keys/$RUSER/$ROLE/key.pub.sig
    
    grep -v "^$RUSER:$ROLE:" $REMOPDIR/keylist > $F
    cp $F $REMOPDIR/keylist
    openssl dgst -sha512 -sign $REMOPDIR/etc/key.pem -out $REMOPDIR/keylist.sig $REMOPDIR/keylist

    rm -f $F
    logger -i -p syslog.info "$USER:curse:$RUSER:$ROLE:"
    exit 0
fi

cat <<EOF
User:
=====
adm-remop newkey [-u <user>] <role>
 Create a new RSA ssh key pair for <role>. Key store in current working dir.

adm-remop req [-u <user>] <role> [keyfile]
 Create a request for authorization.

Administrator:
==============
adm-remop bless <user> <role>
 Accept an authorization request.

adm-remop curse <user> <role>
 Remove authorization for role from user.

adm-remop init
 Initialize repository and create the repository RSA key pair.

adm-remop reqlist
 List pending request.

adm-remop reject <user> <role>
 Reject authorization request.

adm-remop list
 List all existing authorizations.

EOF

