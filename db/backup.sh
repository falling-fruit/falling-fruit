#!/bin/bash

num_backups=14
backup_dir="backups"
prefix="fallingfruit"
ymd=$(date +%Y%m%d)

# Dump database (excluding API logs)
pg_dump --exclude-table-data api_logs* -h localhost -U ${prefix}_user -Fc -b -v -f $backup_dir/$prefix.$ymd.sql ${prefix}_new_db
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

# Dump API logs and truncate database table
# pg_dump -table api_logs -h localhost -U ${prefix}_user -Fc -b -v -f $backup_dir/$prefix.$ymd-api_logs.sql ${prefix}_new_db
# psql -c "TRUNCATE api_logs CONTINUE IDENTITY" -h localhost -U fallingfruit_user -d fallingfruit_new_db
id=(`psql -t -c "SELECT last_value FROM api_logs_id_seq;" -h localhost -U ${prefix}_user -d ${prefix}_new_db`)
path="${backup_dir}/api_logs-${ymd}-${id}.csv"
psql --no-align --field-separator ',' --pset footer -c "SELECT id, n, endpoint, request_method, REPLACE(params, E'\n', '') as params, ip_address, api_key, created_at FROM api_logs WHERE id <= ${id};" > "${path}" -h localhost -U ${prefix}_user -d ${prefix}_new_db
gzip "${path}"
if test -f "${path}.gz"; then
  psql -c "DELETE FROM api_logs WHERE id <= ${id};" -h localhost -U ${prefix}_user -d ${prefix}_new_db
  psql -c "VACUUM api_logs;" -h localhost -U ${prefix}_user -d ${prefix}_new_db
fi

# Push API logs to backup and remove
# scp "${path}.gz" <REMOTE>
# if [ $? -eq 0 ]; then
#   rm "${path}.gz"
# fi
