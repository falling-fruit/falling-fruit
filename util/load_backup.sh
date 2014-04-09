#!/bin/bash
sqlfile=$1
cp $sqlfile /tmp/
sudo chown postgres /tmp/$sqlfile
sudo su postgres -c "dropdb fallingfruit_db"
sudo su postgres -c "pg_restore -v -C -d postgres /tmp/$sqlfile"
