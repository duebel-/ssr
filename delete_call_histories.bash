#!/bin/bash

DATE=$(/bin/date -d "-3 days 00:00:00" +"%F %T")
MYSQL="/usr/bin/mysql -p$(cat ~/.mysql_root_password ) gemeinschaft"
COMMAND="DELETE FROM call_histories where created_at < '$DATE' ;"

echo "$COMMAND" | $MYSQL
