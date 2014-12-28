
# Use change_schema_permissions.sql instead of this


## WE should use the pure sql and dynamic sql rather than heavy shell stuff

## This is more complicated than it needs to be becauset htere is no 'grant all on' that works for 
## all tables in older versions of postgres like dbdev.


#HOST=dbprod.emii.org.au
HOST=db.emii.org.au
USER=jfca
DB=maplayers
ROLE=gisadmin


## grants on tables
psql -h $HOST -U $USER -d $DB -c "select table_schema, table_name  from information_schema.tables where table_catalog='$DB' and table_schema != 'information_schema' order by table_schema,table_type" | grep -v 'table_schema' | grep -v '\-\-\-\-' |  grep -v 'rows)' | grep -v "^$" | sed 's/ *| */./' | while read table; do 
	echo $table; 
	# READ 
	# psql -h $HOST -U $USER -d $DB -c "grant select on table $table to $ROLE;"
	# all (includes write)
	# WRITE
	psql -h $HOST -U $USER -d $DB -c "grant all on table $table to $ROLE;"
	# REVOKE
	#psql -h $HOST -U $USER -d $DB -c "revoke all on table $table from $ROLE;"
done

echo 

## grants on sequences
psql -h $HOST -U $USER -d $DB -c "select sequence_schema,sequence_name from information_schema.sequences order by sequence_schema" | grep -v 'sequence_schema' | grep -v '\-\-\-\-' |  grep -v 'rows)' | grep -v "^$" | sed 's/ *| */./' | while read sequence; do 
	echo $sequence 
	# GRANT
	# psql -h $HOST -U $USER -d $DB -c "grant select on sequence $sequence to $ROLE;"
	# WRITE
	psql -h $HOST -U $USER -d $DB -c "grant all on sequence $sequence to $ROLE;"
	# REVOKE
	# psql -h $HOST -U $USER -d $DB -c "revoke all on sequence $sequence from $ROLE;"
done

