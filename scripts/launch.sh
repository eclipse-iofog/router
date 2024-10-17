#!/bin/sh

QDROUTERD_HOME=/home/skrouterd
CONFIG_FILE=/tmp/skrouterd.conf

rm -f $CONFIG_FILE
echo "${QDROUTERD_CONF}" | awk '{gsub(/\\n/,"\n")}1' >> $CONFIG_FILE

echo "--------------------------------------------------------------"
cat $CONFIG_FILE
echo "--------------------------------------------------------------"

exec skrouterd -c $CONFIG_FILE