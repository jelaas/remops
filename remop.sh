#!/bin/bash
#
# File: remop.sh
# Implements:
#
# Copyright: Jens L��s UU, 2010
# Copyright license: According to GPL, see file COPYING in this directory.
#

# remop [-l<user>|-l <user>] [<role>@]<host> <command>

REMOPDIR=REMOPDIR
KEYS=$REMOPDIR/keys

RUSER=$USER

[ "$1" = "-l" ] && RUSER="$2" && shift 2
[ "${1:0:2}" = "-l" ] && RUSER="${1:2}" && shift

HOST=${1#*@}
ROLE=public
[ "${1/%*@*/}" ] || ROLE=${1%%@*}

shift
# Command is now $@

if [ ! -d "$KEYS/$RUSER/$ROLE" ]; then
   echo "You ($RUSER) do not possess role '$ROLE'."
   exit 1
fi

logger -i -p syslog.info "$RUSER:$ROLE:$HOST:$@:"

ssh -i $KEYS/$RUSER/$ROLE/key remops@$HOST "$@"
