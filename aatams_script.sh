set -x
#
#   491  time pg_dump -s  -h dbprod.emii.org.au -p 5433 -U jfca   aatams3  > aatams3_schema.sql
#   498  time pg_dumpall --roles-only  -h dbprod.emii.org.au -p 5433 -U jfca > aatams3_roles.sql
# 

# create the roles
# psql -f aatams3_roles.sql 

# create db
psql -d postgres -c 'drop database if exists aatams3' || exit
psql -d postgres -c 'create database aatams3'

# create aatams3 schema structure
psql -d aatams3 -f aatams3_schema.sql &> /dev/null

# import admin tools
psql -d aatams3 -f admin.sql  

# create imos extension 
# psql -d aatams3 -c "create extension imos"

psql -d aatams3 -c "select count(*) from admin.objects3 where schema = 'aatams' "

# and drop everything in aatams schema
psql -d aatams3 -c "select admin.drop_objects_in_schema('aatams')  "

# result
psql -d aatams3 -c "select count(*) from admin.objects3 where schema = 'aatams' "


