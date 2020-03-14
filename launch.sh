#!/bin/sh

QDROUTERD_HOME=/qpid-dispatch
CONFIG_FILE=/tmp/qdrouterd.conf

echo "${QDROUTERD_CONF}" | awk '{gsub(/\\n/,"\n")}1' >> $CONFIG_FILE

echo "--------------------------------------------------------------"
cat $CONFIG_FILE
echo "--------------------------------------------------------------"

exec qdrouterd -c $CONFIG_FILE