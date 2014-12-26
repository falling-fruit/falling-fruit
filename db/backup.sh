#!/bin/bash

num_backups=30
backup_dir="backups"
prefix="fallingfruit"
ymd=$(date +%Y%m%d)

pg_dump -h localhost -U ${prefix}_user -Fc -b -v -f $backup_dir/$prefix.$ymd.sql ${prefix}_new_db
pushd $backup_dir
rm $prefix.latest.sql
ln $prefix.$ymd.sql $prefix.latest.sql
n=0
for i in $(ls -1 *.sql | sort -rn);do
  n=$(($n + 1))
  if [ $n -gt $num_backups ];then
    rm $i
  fi
done
popd
