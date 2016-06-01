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


OPENVPN="/usr/local/sbin/openvpn"

if [ ! -x $OPENVPN ]
then
	echo "No openvpn binary available"
fi

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


AUTHFILE=`mktemp`

security find-generic-password -s "Tunnelblick-Auth-${CONFIG}" -g -w -a username >> $AUTHFILE || fail "Failed to find username from keychain"
security find-generic-password -s "Tunnelblick-Auth-${CONFIG}" -g -w -a password >> $AUTHFILE || fail "Failed to find password from keychain"

cd "$CONFIG_DIR"

echo "Sudo password"
sudo ${OPENVPN} --config "${CONFIG_FILE}" --writepid "$PIDFILE" --auth-user-pass "$AUTHFILE" --script-security 2 &

sleep 7
rm $AUTHFILE

wait
