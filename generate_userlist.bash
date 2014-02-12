#! /bin/bash
FILTER="(&(sAMAccountName=*)(sn=*)(givenName=*)(mail=*))"
BASE="cn=users,dc=location1,dc=contoso,dc=com"
FIELDS="sn givenname sAMAccountName mail"

mkdir -p /opt/GS5/tmp/ldap
cd /opt/GS5/tmp/ldap
mv userlist.csv userlist$(/bin/date +%s).csv

/usr/bin/ldapsearch -H ldap://dc1.contoso.com:3268 -b $BASE -D cn=somebody,cn=users,dc=location1,dc=contoso,dc=com -x -wpassword -LLL "$FILTER" $FIELDS \
 | /bin/sed -e :a -e '$!N;s/\n\ //;ta;P;D' \
 | /bin/sed -e 's/\(.*\)\:\:\ \(.*\)/echo -n \1": " ;echo \2 | \/usr\/bin\/base64 -d/e' \
 | /usr/bin/perl /opt/GS5/lib/tasks/ldif2csv.pl - \
 | /bin/sed -e 's/\;/,/g' \
 | sed -e '1{s/sn/LastName/;s/givenname/FirstName/i;s/sAMAccountName/UserName/;s/mail/Email/}' \
 | sed -e '/UserName/s/$/,PIN/'|sed -e '/UserName/!s/$/123456/' \
 > userlist.csv

if [ $(/usr/bin/wc -l userlist.csv | /usr/bin/cut -d' ' -f1) -lt 10 ]
then exit 2
fi

source "$HOME/.rvm/scripts/rvm"
rake user_import:csv
