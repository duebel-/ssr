#!/bin/bash
LOGGER="logger -t $0[$$] "
# $1 = folder watched
if [ ! -d "$1" ]
then
 $LOGGER "folder $1 does not exist"
 exit 15
fi
#execute Networker save command
$LOGGER "executing save command: /usr/sbin/save -q -g GROUP $1"
/usr/sbin/save -q -g GROUP $1 2>&1> /dev/null
if [ $? -eq 0 ]
then
 #delete folder
 $LOGGER "save sucess, deleting folder $1"
 rm -r "$1"/*
fi
