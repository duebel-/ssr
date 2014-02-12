#! /bin/bash

FILTER="(&(|(telephoneNumber=*)(mobile=*))(!(company=Firmenname*))(showinaddressbook=CN=Default Global Address List,CN=All Global Address Lists,CN=Address Lists Container,CN=ExchangeOrg,CN=Microsoft Exchange,CN=Services,CN=Configuration,DC=CONTOSO,DC=COM))"

mkdir -p /opt/GS5/tmp/ldap
cd /opt/GS5/tmp/ldap
#rm gal_old.csv
mv gal_old.csv gal_old_$(/bin/date +%s).csv
touch gal.csv
mv gal.csv gal_old.csv
/usr/bin/ldapsearch -H ldap://dc1.contoso.com:3268 -b dc=contoso,dc=com -D cn=somebody,cn=users,dc=contoso,dc=com -x -wpassword -LLL "$FILTER" \
 sn givenname telephonenumber mobile company title department streetAddress postalCode l co \
 | /bin/sed -e :a -e '$!N;s/\n\ //;ta;P;D' \
 | /bin/sed -e 's/\(.*\)\:\:\ \(.*\)/echo -n \1": " ;echo \2 | \/usr\/bin\/base64 -d/e' \
 | /usr/bin/perl /opt/GS5/lib/tasks/ldif2csv.pl - \
 | /bin/sed -e 's/\;/,/g' \
 | /bin/sed -e '/\+49\ XXXX\ YYY\ 0/d' \
 | /bin/sed -e 's/\+49\ XXXX\ YYY\ //' > gal.csv

if [ $(/usr/bin/wc -l gal.csv|/usr/bin/cut -d' ' -f1) -lt 10 ]
then rm gal.csv
   mv gal_old.csv gal.csv
   exit 2
fi

/usr/bin/head -n 1 gal.csv > galminus.csv
/usr/bin/head -n 1 gal.csv > galplus.csv
/usr/bin/diff -u gal_old.csv gal.csv \
 | /bin/grep '^-"' \
 | /bin/sed -e 's/^\-//' >> galminus.csv
/usr/bin/diff -u gal_old.csv gal.csv \
 | /bin/grep '^+"' \
 | /bin/sed -e 's/^\+//' >> galplus.csv

echo "$HOME/.rvm/scripts/rvm"
source "$HOME/.rvm/scripts/rvm"
rake csvphonebook:delete[/opt/GS5/tmp/ldap/galminus.csv,"Public phone book"]
rake csvphonebook:add[/opt/GS5/tmp/ldap/galplus.csv,"Public phone book"]
