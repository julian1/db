
set -x


# select pg_size_pretty(pg_database_size('ads'));

# dbprod is 9.1.9, postgis 2.0

function recreate_roles()
{
	local HOST=$1
	#local FILE=$( tempfile)

	local FILE="~/imos/cache/$HOST-roles" 

	if [ ! -f "$FILE" ]; then
		echo '*** downloading roles***' 
		# dump just the schema with data 
		/usr/bin/pg_dump --host "$HOST"  --port 5432 --username "jfca" --no-password -Fc -n "$SCHEMA"  --file "$FILE"  "$DB"  || exit
		ls -lh "$FILE"
	else
		echo '*** using cached version of roles ***' 
	fi

	# dump all the user accounts
	pg_dumpall --host dbprod.emii.org.au --port 5432 --username "jfca" --no-password   --roles-only -f "$FILE" 

	# restore accounts on local machine
	psql -h localhost -d postgres -U postgres -f "$FILE"
}

function create_user()
{
	local USER="$1" 
	local PASS="$2" 

	#psql -U postgres -c "(SELECT * FROM pg_catalog.pg_user WHERE usename = '$USER');" #LOGIN PASSWORD 'my_password';"
	#exit
	#psql -U postgres -c "begin IF NOT EXISTS ( SELECT * FROM pg_catalog.pg_user WHERE  usename = '$USER') THEN CREATE ROLE $USER; END IF; end" #LOGIN PASSWORD 'my_password';"

	# drop and recreate ... problematic for dependencies.
	psql -U postgres -c "DROP ROLE IF EXISTS $USER;"
	psql -U postgres -c "create user $USER;" 
	psql -U postgres -c "alter user $USER with password '$PASS';" 
}

function create_db () 
{ 
	local DB=$1
	local OWNER=$2 

	# drop and recreate on local machine 
	psql -U postgres -c "drop database if exists $DB;" || exit
	#dropdb -U postgres "$DB"  || exit

	# when restoring the existing schema will restore the postgis stuff 
	createdb -U postgres -O $OWNER "$DB" || exit

	# leads to view creation problem if not used
	psql -U postgres -d "$DB" -c 'CREATE EXTENSION "uuid-ossp";' 
}

function add_postgis_support()
{
	# useful to be able to do this separately from creating db and templates, in order to test dependencies
	# when testing
	local DB=$1

	createlang -U postgres plpgsql "$DB" > /dev/null

	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/postgis.sql > /dev/null
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/spatial_ref_sys.sql > /dev/null
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/postgis_comments.sql > /dev/null

	# with raster support:
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/rtpostgis.sql > /dev/null
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/raster_comments.sql > /dev/null

	# with topology support:
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/topology.sql > /dev/null
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/topology_comments.sql > /dev/null

	# Import legacy support 
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/legacy.sql > /dev/null
}


function recreate_db_schema () 
{ 
	# note that if it's a partial dump (eg schema) then we need to install postgis first
	# which goes in the public schema. 

	# dump and restore schema and objects - eg. including liquibase db changelog
	local HOST=$1
	local DB=$2
	local SCHEMA=$3
	local FILE="~/imos/cache/$HOST-$DB-$SCHEMA.backup" 

	if [ ! -f "$FILE" ]; then
		echo '*** downloading schema ***' 
		# dump just the schema with data 
		/usr/bin/pg_dump --host "$HOST"  --port 5432 --username "jfca" --no-password -Fc -n "$SCHEMA"  --file "$FILE"  "$DB"  || exit
		ls -lh "$FILE"
	else
		echo '*** using cached version of schema ***' 
	fi

	# maybe remove old existing schema 
	psql -U postgres -d "$DB" -c "drop schema if exists $SCHEMA cascade;"

	# restore on local db
	pg_restore -U postgres  -d "$DB" "$FILE" || exit
}

function create_db_schema () 
{ 
	# create a simple in the db 
	local DB=$1
	local OWNER=$2
	local SCHEMA=$3
	
	psql -U postgres -d "$DB" -c "drop schema if exists $SCHEMA cascade;"
	psql -U postgres -d "$DB" -c "create schema $SCHEMA;" 
	psql -U postgres -d "$DB" -c "ALTER SCHEMA $SCHEMA OWNER TO $OWNER;" 
}


function add_grant_for_geometry()
{
	local DB=$1
	local USER=$2
	
	psql -U postgres -d "$DB" -c "grant all on geometry_columns to $USER;"
	psql -U postgres -d "$DB" -c "grant all on spatial_ref_sys to $USER;"
}



	#create_db 'maplayers' 'gisadmin'
	#exit

# only do this once
#recreate_roles  'dbprod.emii.org.au' 

# create the databases
# only do this once 
if false; then
	create_db 'harvest'   'gisadmin'
	add_postgis_support 'harvest'    # tested to be required for argo

	create_db 'maplayers' 'gisadmin'
	add_postgis_support 'maplayers'

	create_db 'report_db'  'gisadmin'
	add_postgis_support 'report_db'   # tested to be required for argo

	create_db 'data_warehouse'  'gisadmin'
fi


# WORKING
# anmn realtime
#recreate_db_schema 'dbprod.emii.org.au' 'harvest' 'anmn_realtime'
#recreate_db_schema 'dbprod.emii.org.au' 'report_db' 'anmn_realtime'

# abos - NOT WORKING!
#recreate_db_schema 'dbprod.emii.org.au' 'data_warehouse' 'abos'
#recreate_db_schema 'dbprod.emii.org.au' 'harvest' 'abos'


# SRS - WORKS
if false; then

	# create the databases
	create_db 'maplayers' 'gisadmin'
	add_postgis_support 'maplayers' 

	create_db 'harvest' 'gisadmin'
	add_postgis_support 'harvest' 

	create_db 'report_db' 'gisadmin'
	add_postgis_support 'report_db' 

	# create needed schemas
	recreate_db_schema 'db.emii.org.au'  'maplayers' 'srs'
	recreate_db_schema 'dbprod.emii.org.au' 'harvest' 'srs'
	recreate_db_schema 'dbprod.emii.org.au' 'report_db' 'srs'
fi


# ARGO now runs on my machine - using report_db with that's spatially enabled 
if false ; then

	# maplayers
	recreate_db_schema 'db.emii.org.au'		'maplayers' 'argo'

	# harvest
	#recreate_db_schema 'dbprod.emii.org.au' 'harvest'	'argo_talend_new'   # too large
	create_db_schema 'harvest' 'argo_talend_new' 'argo_talend_new'  
	psql -U postgres -d harvest -c "grant all on table geometry_columns to argo_talend_new;"
	psql -U postgres -d harvest -c "grant all on spatial_ref_sys to argo_talend_new;"

	# argo
	recreate_db_schema 'dbprod.emii.org.au' 'report_db' 'argo'
fi

# CPR - starts ok, but has wfs webservice request failed
if false; then
	recreate_db_schema 'db.emii.org.au'		'maplayers' 'cpr'
	
fi

# SOOP WITH HAND ROLLED

# asf gets nulls  (because of wrong parametization setup in talend gui)
# ba runs
# co2 runs
# frrf runs 
# sst seems to run - didn't allow to complete
# tmv seems to run - didn't allow to complete 
# trv seems to run
# xbt seems to run

if false; then 

	# harvest	
	create_db 'harvest' 'gisadmin'
	add_postgis_support 'harvest'    # tested to be required for argo
	create_db_schema 'harvest' 'soop' 'soop'  
	add_grant_for_geometry 'harvest' 'soop'

	# maplayers
	create_db 'maplayers' 'gisadmin'
	add_postgis_support 'maplayers'    
	create_db_schema 'maplayers' 'aodaac' 'aodaac'  # or soop should be owner?  
	create_db_schema 'maplayers' 'soop' 'soop'  # or soop should be owner?  
	add_grant_for_geometry 'maplayers' 'soop'

	# data_warehouse
	create_db 'data_warehouse' 'gisadmin'
	add_postgis_support 'data_warehouse'    
	create_db_schema 'data_warehouse' 'soop' 'soop'  # or soop should be owner?  
fi

# USEFUL CODE
#
# changing the db
#   cd chef/data_bags/talend
#   sed -i 's/db.emii.org.au/10.0.2.2/' *
#   sed -i 's/dbprod.emii.org.au/10.0.2.2/' *
#
#   pgrep java 
#
#   cd chef/data_bags/imos_artifacts/ 
#   grep NETCDF *
#	sed -i 's/NETCDFHARVESTER/NETCDFHARVESTER_TEST/' * 
#
# for i in /var/log/talend/*/stats_file.txt; do cat $i ; echo ; done

# SOOP USING EXPORTED PRODUCTION DB
if false ; then 
	
	# create the databases
	create_db 'maplayers' 'gisadmin'
	add_postgis_support 'maplayers' 

	create_db 'harvest' 'gisadmin'
	add_postgis_support 'harvest' 

	create_db 'data_warehouse' 'gisadmin'
	add_postgis_support 'data_warehouse'

	# maplayers
	recreate_db_schema 'db.emii.org.au'		'maplayers'	     'aodaac'
	recreate_db_schema 'db.emii.org.au'		'maplayers'	     'soop'

	# harvest	
	recreate_db_schema 'dbprod.emii.org.au'		'harvest'	     'soop'

	# data_warehouse
	recreate_db_schema 'dbprod.emii.org.au' 'data_warehouse' 'soop'
fi


# AATAMS
if true; then

	USER=aatams_sattag_nrt

	# create the users
	# old/unused - create_user $USER  'y/rKQmSqKmcy5ZysFF96DC8Bm1mg9U1j'
	# talend default - create_user $USER  'aatams_sattag_nrt'
	create_user $USER 'zeserkbi923ka982ksa23ferern235n2a=='		# talend production

	# create the databases
	for DB in harvest report_db ; do
		create_db $DB 'gisadmin'
		add_postgis_support $DB
		create_db_schema $DB $USER $USER 
		add_grant_for_geometry $DB  $USER 
	done 
fi



