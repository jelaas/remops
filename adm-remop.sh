#!/bin/bash
#
# File: adm-remop.sh
# Implements:
#
# Copyright: Jens Låås UU, 2010
# Copyright license: According to GPL, see file COPYING in this directory.
#

# adm-remop newkey <role>
# adm-remop req <role> <keyfile>
# adm-remop bless <user> <role>
# adm-remop init

REMOPDIR=REMOPDIR
REMOPUSER=REMOPUSER

if [ "$1" == init ]; then
    [ "$USER" = "$REMOPUSER" ] || (echo "You are not the administrative remop user '$REMOPUSER'";exit 1)
    if ! mkdir -p $REMOPDIR/etc $REMOPDIR/keys $REMOPDIR/req; then
	echo "Cannot create $REMOPDIR/etc $REMOPDIR/keys $REMOPDIR/req"
	exit 1
    fi

    [ -f $REMOPDIR/etc/key.pem ] || (umask 0077; openssl genrsa -out $REMOPDIR/etc/key.pem 4096)
    chmod 0400 $REMOPDIR/etc/key.pem
    openssl rsa -in $REMOPDIR/etc/key.pem -pubout -out $REMOPDIR/etc/pubkey.pem
    logger -i -p syslog.info "$USER:init:"
    exit 0
fi

if [ "$1" == newkey ]; then
    ROLE="$2"
    [ "$ROLE" ] || (echo "Need ROLE as argument"; exit 2)
    (umask 0077;ssh-keygen -b 2048 -t rsa -f rsa_$ROLE)
    echo "Created key rsa_$ROLE"
    exit 0
fi

if [ "$1" == req ]; then
    ROLE="$2"
    KEY="$3"
    [ -f "$KEY" ] || exit 1
    [ -f "$KEY.pub" ] || exit 1
    
    mkdir -p $REMOPDIR/req/$USER/$ROLE || exit 1
    cp -p $KEY $REMOPDIR/req/$USER/$ROLE/key || exit 1
    chmod 0400 $REMOPDIR/req/$USER/$ROLE/key || exit 1
    cp -p $KEY.pub $REMOPDIR/req/$USER/$ROLE/key.pub || exit 1
    logger -i -p syslog.info "$USER:req:$ROLE:$KEY:"
    exit 0
fi

if [ "$1" == bless ]; then
    [ "$USER" = "$REMOPUSER" ] || (echo "You are not the administrative remop user '$REMOPUSER'";exit 1)
    [ -f $REMOPDIR/etc/key.pem ] || exit 2
    RUSER="$2"
    ROLE="$3"
    [ -f $REMOPDIR/req/$RUSER/$ROLE/key ] || exit 1
    [ -f $REMOPDIR/req/$RUSER/$ROLE/key.pub ] || exit 1
    mkdir -p $REMOPDIR/keys/$RUSER/$ROLE
    cp $REMOPDIR/req/$RUSER/$ROLE/key $REMOPDIR/req/$RUSER/$ROLE/key.pub $REMOPDIR/keys/$RUSER/$ROLE
    openssl dgst -sha512 -sign $REMOPDIR/etc/key.pem -out $REMOPDIR/keys/$RUSER/$ROLE/key.sig $REMOPDIR/keys/$RUSER/$ROLE/key
    openssl dgst -sha512 -sign $REMOPDIR/etc/key.pem -out $REMOPDIR/keys/$RUSER/$ROLE/key.pub.sig $REMOPDIR/keys/$RUSER/$ROLE/key.pub
    echo "$RUSER:$ROLE:" >> $REMOPDIR/keylist
    openssl dgst -sha512 -sign $REMOPDIR/etc/key.pem -out $REMOPDIR/keylist.sig $REMOPDIR/keylist
    logger -i -p syslog.info "$USER:bless:$RUSER:$ROLE:"
    exit 0
fi

cat <<EOF
User:
=====
adm-remop newkey <role>
 Create a new RSA ssh key pair for <role>. Key store in current working dir.

adm-remop req <role> <keyfile>
 Create a request for authorization.

Administrator:
==============
adm-remop bless <user> <role>
 Accept an authorization request.

adm-remop init
 Initialize repository and create the repository RSA key pair.

EOF

