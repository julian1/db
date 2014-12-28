
# Usage:
# ./log_pg_xlog.sh /mnt/db/1/aatams/ >> /mnt/db/1/aatams.log   

dir="$1" #/mnt/db/1/main/
interval=60


xdir="$dir/pg_xlog/"
xfiles="$xdir/0*"

last=$(basename $( ls -t $xfiles | head -n 1 ))
# echo "last $last"
#exit
while true; do 

	now=$(date '+%F-%H-%M')

	current=$(basename $( ls -t $xfiles | head -n 1 ))
	processed=$(( 0x$current - 0x$last )) 
	last=$current

	count=$(ls $xdir | wc -l )

	main=$( du -hs $dir | sed 's/\t/ /' )
	pg_xlog=$( du -hs $xdir | sed 's/\t/ /' )

	echo "$now, processed $processed, pg_xlog files $count, $main, $pg_xlog, $current"
	
	sleep $interval
done


