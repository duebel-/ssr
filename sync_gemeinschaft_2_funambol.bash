#!/bin/bash

MYSQL="/usr/bin/mysql -p$(cat ~/.mysql_root_password ) gemeinschaft"
COMMAND="
-- DELETE phone_book_entries not in GS5 from fnbl
  update funambol.fnbl_pim_contact
  set status='D',last_update=unix_timestamp()*1000
  where id not in (
    select id from phone_book_entries pbe where  pbe.phone_book_id=2 or pbe.phone_book_id=3571 or pbe.phone_book_id=3500
  ) and
  status not like 'D' and
  userid like 'nkd';
-- ADD new or UPDATE changed phone_book_entries to fnbl
  create temporary table t_newids as (
    select
    distinct pbe.id id
    from phone_book_entries pbe, phone_numbers pn
    where (
      unix_timestamp(pbe.updated_at) > (
        select max(last_update)/1000 from funambol.fnbl_pim_contact where last_update % 1000 = 0 and status in ('D','U') and userid like 'gsm'
      )
      or unix_timestamp(pn.updated_at) > (
        select max(last_update)/1000 from funambol.fnbl_pim_contact where last_update % 1000 = 0 and status in ('D','U') and userid like 'gsm'
      )
    )
    and ( pbe.phone_book_id=2 or pbe.phone_book_id=3571 or pbe.phone_book_id=3500 )
    and pn.phone_numberable_type='PhoneBookEntry'
    and pn.phone_numberable_id=pbe.id
    and pn.number is not null
  );
  delete from funambol.fnbl_pim_contact_item where contact in ( select id from t_newids);
  replace into funambol.fnbl_pim_contact
    select pbe.id id,'gsm' userid,unix_timestamp()*1000 last_update,'U' status,NULL,NULL,NULL,NULL,NULL,NULL,first_name,
      NULL,last_name,pbe.value_of_to_s display_name,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
      pbe.organization,pbe.department,NULL,NULL,NULL,NULL,NULL,NULL
    from  phone_book_entries pbe where pbe.id in (
      select id from t_newids
    );
  replace into funambol.fnbl_pim_contact_item
    select pn.phone_numberable_id contact, case pn.name when 'Mobile' then 3 when 'Office' then 10 else 1 end as type,pn.number value
    from phone_numbers pn where pn.phone_numberable_type='PhoneBookEntry' and pn.phone_numberable_id in (
      select id from t_newids
    );
  drop table t_newids;
"

echo "$COMMAND" | $MYSQL
