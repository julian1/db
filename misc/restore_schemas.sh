
# Run with something like, 
# ./restore_schemas.sh  2>&1 | tee log.txt

# so we have to consolodate report_db into data_warehouse

set -x

date

SRC=20131010


# ls -l $SRC/harvest.dump

# 
# cd chef; grep ReportingDatabase_Database data_bags/talend/*

# aatams_sattag_nrg will be populated from new by harvester

# abos (data_warehouse)
pg_restore  -U postgres -d harvest        -n abos $SRC/harvest.dump
pg_restore  -U postgres -d data_warehouse -n abos $SRC/data_warehouse.dump

# anmn delayed (report_db)
pg_restore  -U postgres -d harvest        -n anmn $SRC/harvest.dump
pg_restore  -U postgres -d data_warehouse -n anmn $SRC/report_db.dump

# anmn_realtime (report_db)
pg_restore  -U postgres -d harvest        -n anmn_realtime $SRC/harvest.dump
pg_restore  -U postgres -d data_warehouse -n anmn_realtime $SRC/report_db.dump

# argo (report_db)
pg_restore  -U postgres -d harvest        -n argo $SRC/harvest.dump
pg_restore  -U postgres -d data_warehouse -n argo $SRC/report_db.dump

# soop (all in data_warehouse)
pg_restore  -U postgres -d harvest        -n soop $SRC/harvest.dump
pg_restore  -U postgres -d data_warehouse -n soop $SRC/data_warehouse.dump

# srs are all in data_warehouse
pg_restore  -U postgres -d harvest        -n srs $SRC/harvest.dump
pg_restore  -U postgres -d data_warehouse -n srs $SRC/report_db.dump

# adon_mest  (report_db only)
#### ran the wrong thing here...
#####pg_restore  -U postgres -d data_warehouse -n soop $SRC/report_db.dump
## this is correct
pg_restore  -U postgres -d data_warehouse -n aodn_mest $SRC/report_db.dump

# tsunami buoys harvester populates the database aodn_maplayers


date

