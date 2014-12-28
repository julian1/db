
set -x

function log_message()
{
    local MSG=$1
    echo "$(date '+%F %T'): $MSG" 
}

HOST='localhost'
PORT=15432
USER='postgres'
DIR=20131011



DBS='AODNMEST aatams3 aodaac-prod aodn_maplayers auvusers ftp_user_registration inventory maplayers portal_preview portal_preview_backup postgres publications report_db test userdata userdataaodn waodn waodn_portal wms_scanner wms_scanner_public'

#DBS='auvusers'
# pg_restore  -U postgres -d harvest        -n anmn_realtime $SRC/harvest.dump


# restore databases 
for DB in $DBS; do

    FILE="$DIR/$DB.dump" 
    log_message "restore $DB from $FILE" 


	# it's better to do the creation manually, to avoid generation from templates etc. 

	psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres  -c 'drop database if exists "'$DB'";' || exit
	psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres  -c 'create database "'$DB'";' || exit

	pg_restore   -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" "$FILE"
done


