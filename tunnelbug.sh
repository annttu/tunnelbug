#!/bin/bash

# TunnelBug, because tunnelblick a pile of shit.

# The MIT License (MIT)
# Copyright (c) 2016 Antti Jaakkola

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

usage() {
	echo "Usage: $0 ((start|stop) configuration_name | list)"
	exit 1
}

fail() {
	echo "ERROR: $@"
	exit 1

}

OPENVPN="/opt/homebrew/sbin/openvpn"

if [ ! -x $OPENVPN ]
then
	echo "No openvpn binary available"
fi

echo -ne "\033]0;Tunnelbug\007"

ACTION="$1"
CONFIG="$2"

if [ -z "$ACTION" ]
then
	usage
fi

if [ "$ACTION" = "list" ]
then
	ls -1 "$HOME/Library/Application Support/Tunnelblick/Configurations/" |grep tblk |sed -e 's/\.tblk//'
	exit 0
fi

if [ -z "$CONFIG" ]
then
	usage
fi


CONFIG_DIR="$HOME/Library/Application Support/Tunnelblick/Configurations/${CONFIG}.tblk/Contents/Resources/"
CONFIG_FILE="$CONFIG_DIR/config.ovpn"

if [ ! -f "$CONFIG_FILE" ]
then
	fail "Configuration file $CONFIG_FILE not found"
fi

PIDFILE=/tmp/${CONFIG}.pid

if [ "$ACTION" = "stop" ]
then
	[ ! -f "$PIDFILE" ] && fail "No pid file found"
	PID=$(cat $PIDFILE)
	sudo kill $PID
	exit 0
fi

if [ "$ACTION" != "start" ]
then
	fail "Unknown action $ACTION"
fi

if [ -f $PIDFILE ]
then
	pgrep -P `cat $PIDFILE` && fail "Already running"
fi


PRIVFILE=`mktemp`.fifo

mkfifo -m 600 "$PRIVFILE"

OPTS=""

if grep auth-user-pass "$CONFIG_FILE"
then

	AUTHPASS="$(security find-generic-password -s "Tunnelblick-Auth-${CONFIG}" -g -w -a username)" ||  fail "Failed to find username from keychain"
	AUTHPASS="${AUTHPASS}\n$(security find-generic-password -s "Tunnelblick-Auth-${CONFIG}" -g -w -a password)" || fail "Failed to find password from keychain"
	PRIVPASS="$(security find-generic-password -s "Tunnelblick-Auth-${CONFIG}" -g -w -a privateKey)"

	if [ ! -z "${PRIVPASS}" ]
	then
		#OPTS='--askpass <(echo "${PRIVPASS}")'
		( while true; do echo "$PRIVPASS" > "$PRIVFILE" && sleep 1; done ) &
		OPTS='--askpass "$PRIVFILE"'
	fi
	export AUTHPASS
	export PRIVPASS
else
	export AUTHPASS=""
	export PRIVPASS=""
fi

export OPTS
export PRIVFILE
export CONFIG_FILE

cd "$CONFIG_DIR"

echo -ne "\033]0;Tunnelbug ${CONFIG}\007"

echo "Sudo password"
if [ ! -z "$AUTHPASS" ]
then
   sudo -E bash -c "exec ${OPENVPN} --auth-retry interact --verb 5 --script-security 2 --config \"\${CONFIG_FILE}\" --auth-user-pass <(echo -e \"\${AUTHPASS}\") ${OPTS}"
else
   sudo -E bash -c "exec ${OPENVPN} --auth-retry interact --verb 5 --script-security 2 --config \"\${CONFIG_FILE}\" ${OPTS}"
fi

rm $PRIVFILE

echo -e "\n\n"
