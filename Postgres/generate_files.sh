#!/bin/bash

###############################################################
## this script generates EMPTY files in the backup directory ##
## for perform rotation tests                                ##
###############################################################

if [ $# = 0 ]; then
        SCRIPTPATH=$(cd ${0%/*} && pwd -P)
        source $SCRIPTPATH/pg_backup.config
fi;

TODAY_DATE=`date +\%Y-\%m-\%d`
for ((i=$(($DAYS_OF_BACKUP+1)); i>=0;i--))
do
    ARCHIVE_DATE=$(date -I -d "$TODAY_DATE -$i days")
    echo "creating file backup_$BACKUP_DIR$ARCHIVE_DATE.tar"
    touch -d $ARCHIVE_DATE $BACKUP_DIR"backup_$ARCHIVE_DATE.tar"
done
