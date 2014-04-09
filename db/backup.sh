#!/bin/bash

num_pg_backups=30
backup_dir="backups"
prefix="fallingfruit"

pushd $backup_dir
for i in $(seq $num_pg_backups -1 1);do
  if [ -f $prefix.$i.sql ];then
    echo "Rolling backup $i to $(($i+1))"
    mv $prefix.$i.sql $prefix.$(($i+1)).sql
  fi
done
rm -f $prefix.$(($num_pg_backups+1)).sql
pg_dump -h localhost -U fallingfruit_user -Fc -b -v -f $prefix.1.sql fallingfruit_new_db
popd
