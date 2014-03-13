#!/bin/bash

poll_intervall=30

while [ true ]
  do
    error=0
    for pid in $(pgrep ntlm_auth)
    do ps -o s h $pid|grep Z #</dev/null
      if [ $? -eq 0 ]
        then
          state="Alarm"
          logger -i "ntlm_auth ($pid) dead"
          (( error++ ))
        else
          state="ok"
      fi
      date=$(date +"%F %T")
      echo "$date: $pid $state"
    done
    if [ $error -ne 0 ]
      then
        logger -i "restarting apache2..."
        service apache2 restart &> /dev/null
        if [ $? -ne 0 ]
          then
            logger -i "Failed to restart apache2"
        fi
    fi
    sleep $poll_intervall
  done
