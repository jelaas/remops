#!/bin/bash
#
# File: remops.sh
# Implements:
#
# Copyright: Jens Låås UU, 2010, 2011
# Copyright license: According to GPL, see file COPYING in this directory.
#
# remops <user> <role>
# SSH_ORIGINAL_COMMAND=<cmd> [arg]*
#
# $HOME/remops/roles/public/cmd/*|list
# $HOME/remops/roles/<role>/cmd/*

VERSION=VERSION

if [ -z "$1" ]; then
    cat <<EOF
remops <user> <role>
ENV: SSH_ORIGINAL_COMMAND=<cmd> [arg]*

EOF
    exit 0
fi

RUSER="$1"
ROLES="$2"
CMD="${SSH_ORIGINAL_COMMAND%% *}" # first word before space

if [ -z "$HOME" ]; then
    logger -i -t remops -p syslog.info ":ERR=NOHOME:U=$RUSER:R=$ROLES:C=$CMD:"
    exit 2 # HOME needs to be set
fi

REMOPS=$HOME/remops
if [ ! -d "$REMOPS" ]; then
    mkdir -p $REMOPS/roles/public/cmd
    mkdir -p $REMOPS/roles/public/managed_keys
    mkdir -p $REMOPS/roles/public/manual_keys
fi

if [ "$CMD" = list ]; then
    logger -i -t remops -p syslog.info ":A=builtin:U=$RUSER:R=$ROLES:C=$CMD:"
    echo "public:list:list all available commands:"
    for d in $REMOPS/roles/*; do
	for f in $d/cmd/*; do
	    [ -x "$f" ] || continue
	    [ "$(basename $f)" = '*' ] && continue
	    [ "${f: -1}" = '~' ] && continue
	    if [ -f "$f.txt" ]; then
		echo $(basename $d):$(basename $f):$(cat "$f.txt"|tr -d '\r\n'):
	    else
		echo $(basename $d):$(basename $f)::
	    fi
	done
    done
    exit 0
fi

for RROLE in ${ROLES//,/ }; do
    if [ ! -d "$REMOPS/roles/$RROLE" ]; then
	logger -i -t remops -p syslog.info ":ERR=NOROLE:U=$RUSER:R=$RROLE:C=$CMD:"
    fi
done

FOUND=no
for RROLE in ${ROLES//,/ }; do
    [ -f "$REMOPS/roles/$RROLE/cmd/$CMD" ] && FOUND=yes && break
done

if [ "$FOUND" != yes ]; then
    if [ ! -f "$REMOPS/roles/public/cmd/$CMD" ]; then
	if [ "${CMD: -8}" != '-options' ]; then
	    logger -i -t remops -p syslog.info ":ERR=NOCMD:U=$RUSER:R=$ROLES:C=$CMD:"
	    echo "Invalid command '$CMD' for role(s) $ROLES" >&2
	fi
	exit 2
    fi
    RROLE=public
fi
CMDARG="${SSH_ORIGINAL_COMMAND:${#CMD}}"
logger -i -t remops -p syslog.info ":A=exec:U=$RUSER:R=$RROLE:C=$CMD:ARGS=$CMDARG:"
GLOBIGNORE=*
$REMOPS/roles/$RROLE/cmd/$CMD $CMDARG
