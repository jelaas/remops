#!/bin/bash
#
# File: remop.sh
# Implements:
#
# Copyright: Jens L��s UU, 2010
# Copyright license: According to GPL, see file COPYING in this directory.
#

# remop [-l<user>|-l <user>] [<role>@]<host> <command>

REMOPDIR=$HOME/.remop
KEYS=$REMOPDIR/keys
VERSION=VERSION

RUSER=$USER

if [ -z "$1" ]; then
    cat <<EOF
remop [-l<user>|-l <user>] [<role>@]<host> <command>
version: $VERSION
EOF
    exit 0
fi

[ "$1" = "-l" ] && RUSER="$2" && shift 2
[ "${1:0:2}" = "-l" ] && RUSER="${1:2}" && shift

HOST=${1#*@}
ROLE=public
[ "${1/%*@*/}" ] || ROLE=${1%%@*}

shift
# Command is now $@

if [ "$ROLE" != public ]; then
    if [ ! -d "$KEYS/$RUSER/$ROLE" ]; then
	echo "You ($RUSER) do not possess role '$ROLE'."
	exit 1
    fi
fi


SSHOPTIONS="$(ssh -i $KEYS/$RUSER/$ROLE/key remops@$HOST "$1-options" < /dev/null)"
[ $? = 0 ] || SSHOPTIONS=""

logger -i -t remop -p syslog.info ":A=remop:U=$RUSER:R=$ROLE:H=$HOST:OPTS=$SSHOPTIONS:C=$@:"

ssh -i $KEYS/$RUSER/$ROLE/key $SSHOPTIONS remops@$HOST "$@"
