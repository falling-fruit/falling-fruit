#!/bin/bash
sqlfile=$1
cp $sqlfile /tmp/
sudo chown postgres /tmp/$sqlfile
sudo su postgres -c "dropdb fallingfruit_new_db"
sudo su postgres -c "pg_restore -v -C -d postgres /tmp/$sqlfile"
sudo su postgres -c "dropdb fallingfruit_test_db"
sudo su postgres -c "createdb -O fallingfruit_user -T fallingfruit_new_db fallingfruit_test_db"
