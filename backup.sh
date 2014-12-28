
### Should be run as screen and as postgres

function log_message()
{
    local MSG=$1
    echo "$(date '+%F %T'): $MSG" 
}

# HOST='localhost'
# USER='postgres'
DIR="./$(date +%Y%m%d)" 

# DBS='postgres public test data_warehouse aodn_portal wms_scanner meteo harvest report_db maplayers'
# DBS='data_warehouse maplayers harvest report_db'

#DBS='AODNMEST aatams3 aodaac-prod aodn_maplayers auvusers data_warehouse ftp_user_registration harvest inventory maplayers portal_preview portal_preview_backup postgres publications report_db test userdata userdataaodn waodn waodn_portal wms_scanner wms_scanner_public'

# DBS='aatams3 harvest data_warehouse'

# DBS='harvest legacy aatams3 acoustic_data_viewer data_warehouse'

DBS='data_warehouse'

if [ -d "$DIR" ]; then
    echo "dir already exists!!" 
    exit
else
    mkdir "$DIR"
fi


# backup roles
ROLES_FILE="$DIR/roles.dump" 
log_message "backing up roles to $ROLES_FILE" 
# rm "$ROLES_FILE" 2> /dev/null  
pg_dumpall --roles-only -f "$ROLES_FILE" || exit

# backup databases 
for DB in $DBS; do
    FILE="$DIR/$DB.dump" 
    log_message "back up $DB to $FILE" 
    # rm "$FILE" 2> /dev/null 

    /usr/bin/pg_dump -Fc --file "$FILE" "$DB"  || exit

    md5sum "$FILE" >> "$DIR/md5sum.txt" || exit
done

log_message "finished" 

# pushd $DIR
# md5sum * > md5sum.txt
# popd

