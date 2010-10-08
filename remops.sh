#!/bin/bash
#
# File: remops.sh
# Implements:
#
# Copyright: Jens L��s UU, 2010
# Copyright license: According to GPL, see file COPYING in this directory.
#
# remops <user> <role>
# SSH_ORIGINAL_COMMAND=<cmd> [arg]*
#
# $HOME/remops/roles/public/cmd/*|list
# $HOME/remops/roles/<role>/cmd/*

if [ -z "$HOME" ]; then
    logger -i -p syslog.info "ERR=NOHOME:$RUSER:$RROLE:$CMD:"
    exit 2 # HOME needs to be set
fi

REMOPS=$HOME/remops
if [ ! -d "$REMOPS" ]; then
    mkdir -p $REMOPS/roles/public/cmd
    mkdir -p $REMOPS/roles/public/managed_keys
    mkdir -p $REMOPS/roles/public/manual_keys
fi

if [ -z "$1" ]; then
    cat <<EOF
remops <user> <role>
ENV: SSH_ORIGINAL_COMMAND=<cmd> [arg]*

EOF
    exit 0
fi

RUSER="$1"
RROLE="$2"
CMD="${SSH_ORIGINAL_COMMAND%% *}" # first word before space

if [ "$CMD" = list ]; then
    logger -i -p syslog.info "builtin:$RUSER:$RROLE:$CMD:"
    for d in $REMOPS/roles/*; do
	echo "public:list:list all available commands:"
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

if [ ! -d "$REMOPS/roles/$RROLE" ]; then
    logger -i -p syslog.info "ERR=NOROLE:$RUSER:$RROLE:$CMD:"
fi

if [ ! -f "$REMOPS/roles/$RROLE/cmd/$CMD" ]; then
    logger -i -p syslog.info "ERR=NOCMD:$RUSER:$RROLE:$CMD:"
    exit 2
fi
CMDARG="${SSH_ORIGINAL_COMMAND#* }"
logger -i -p syslog.info "exec:$RUSER:$RROLE:$CMD:$CMDARG:"

$REMOPS/roles/$RROLE/cmd/$CMD $CMDARG
