#!/bin/bash
DATSTRING=`date +%Y%m%d-%H:%M`
LOG=/var/log/incronwatch.log
NUMBER=`ps ax|grep incrond| grep -v grep |wc -l`
if [ $NUMBER -lt 1 ]
then
  echo $DATSTRING >> $LOG
  echo "Number of incrond processes is $NUMBER- starting incrond" >> $LOG
  /etc/init.d/incron start
else
  echo "Number of incrond processes is $NUMBER - doing nothing" >> /dev/null
fi
