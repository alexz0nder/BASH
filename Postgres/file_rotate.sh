#!/bin/bash

########################################
## script for tests of deleting files ##
########################################

if [ $# = 0 ]; then
        SCRIPTPATH=$(cd ${0%/*} && pwd -P)
        source $SCRIPTPATH/pg_backup.config
fi;


cd $BACKUP_DIR
echo -e "\nCombinimg all archives into one $ARCHIVE_DATE.tar"
if [ $? -eq 0 ]; then
  echo "Archive created sucessfuly. Removing $FINAL_BACKUP_DIR directory"
else
  echo "[!!ERROR!!] Filed to make tar archive."
fi

echo "$DAYS_OF_BACKUP ? $(ls -1 | wc -l)"
if [[ $DAYS_OF_BACKUP -lt $(ls -1 | wc -l) ]]; then
  for FILE_TO_DELETE in `find . -maxdepth 1 -mtime "+$(($DAYS_OF_BACKUP-1))"`
  do
    echo $FILE_TO_DELETE
    #rm -rf $FILE_TO_DELETE
  done
fi
