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
VERSION=VERSION

function verifykey {
    local F A B
    F="$1"
    
    # file must contain only one line
    A=$(wc -l "$F"|(read A B; echo $A))    
    [ "$A" != 1 ] && return 1
    
    # must begin with: 'ssh-dss' or 'ssh-rsa'
    read A B < $F
    [ "$A" = ssh-dss ] && return 0
    [ "$A" = ssh-rsa ] && return 0
    return 1
}

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
    logger -i -t adm-remop -p syslog.info ":A=init:U=$USER:"
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
    
    if ! verifykey "$KEY"; then
	echo "$KEY does not look lika a proper one-line public key!"
	exit 1
    fi
    
    cp -p "$KEY" $REMOPDIR/req/req.$RUSER.$ROLE.pub.$RND || exit 1
    # make sure the remop administration user can read the key
    chmod a+r $REMOPDIR/req/req.$RUSER.$ROLE.pub.$RND
    logger -i -t adm-remop -p syslog.info ":A=req:U=$RUSER:R=$ROLE:KEY=$KEY:"
    exit 0
fi

if [ "$1" = reqlist ]; then
    for f in $REMOPDIR/req/req.* EOF; do
	[ -f "$f" ] || continue
	[ "$f" = EOF ] && continue
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
	    [ -f "$f/key.pub" ] && echo " $(basename $f)"
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
    logger -i -t adm-remop -p syslog.info ":A=reject:U=$USER:SU=$RUSER:R=$ROLE:"
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
    logger -i -t adm-remop -p syslog.info ":A=bless:U=$USER:RU=$RUSER:R=$ROLE:"
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
    logger -i -t adm-remop -p syslog.info ":A=curse:U=$USER:RU=$RUSER:R=$ROLE:"
    exit 0
fi

cat <<EOF
adm-remop (newkey|req|bless|curse|init|reqlist|reject|list)
version $VERSION

User:
=====
adm-remop newkey [-u <user>] <role>
 Create a new RSA ssh key pair for <role>. Key stored in '\$HOME/.remop'.

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

