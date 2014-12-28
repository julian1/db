set -x

# database creation/dropping has to be done in separate commands because they
# run outside a transaction 

USER=aatams_sattag_nrt
PASS=aatams_sattag_nrt
SCHEMA=aatams_sattag_nrt
DBS='harvest report_db'


# have to drop db and tables with grants before can drop user
for DB in $DBS; do
	psql -U postgres -c "drop database if exists $DB;" || exit
done

# have to create user first because we will give grants
psql -U postgres -c "
	drop role if exists aatams_sattag_nrt;
	create user $USER;
	alter user $USER with password '$PASS';
" || exit;

# postgres/postgis
for DB in $DBS; do

	psql -U postgres -c "create database $DB;" || exit

	# installs postgis into public schema 
	createlang -U postgres plpgsql "$DB" > /dev/null
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/postgis.sql > /dev/null
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/spatial_ref_sys.sql > /dev/null
	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/postgis_comments.sql > /dev/null

	psql -U postgres -d "$DB" -f /usr/share/postgresql/9.1/contrib/postgis-2.0/legacy.sql > /dev/null

	# grants on tables
	psql -U postgres -d "$DB" -c "grant all on spatial_ref_sys to $USER;"
	psql -U postgres -d "$DB" -c "grant all on geometry_columns to $USER;"
done

# create schemas
psql -U postgres -d harvest -c "create schema $SCHEMA   authorization $USER;" || exit
psql -U postgres -d report_db -c "create schema $SCHEMA authorization $USER;" || exit



