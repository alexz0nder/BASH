#!/bin/bash

function load_configs () {
###########################
####### LOAD CONFIG #######
###########################

  if [ $# = 0 ]; then
          SCRIPTPATH=$(cd ${0%/*} && pwd -P)
          source $SCRIPTPATH/pg_backup.config
  fi;

  ###########################
  ### INITIALISE DEFAULTS ###
  ###########################

  if [ ! $HOSTNAME ]; then
  	HOSTNAME="localhost"
  fi;

  if [ ! $USERNAME ]; then
  	USERNAME="postgres"
  fi;

  ARCHIVE_DATE=`date +\%Y-\%m-\%d`
  FINAL_BACKUP_DIR=$BACKUP_DIR"$ARCHIVE_DATE/"
}

function perform_checks() {
###########################
#### PRE-BACKUP CHECKS ####
###########################

  # Make sure we're running as the required backup user
  if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ]; then
  	echo "This script must be run as $BACKUP_USER. Exiting." 1>&2
  	exit 1;
  fi;

  echo "Making backup directory in $FINAL_BACKUP_DIR"

  if ! mkdir -p $FINAL_BACKUP_DIR; then
  	echo "Cannot create backup directory in $FINAL_BACKUP_DIR. Go and fix it!" 1>&2
  	exit 1;
  fi;

}

function backup_globals() {
#######################
### GLOBALS BACKUPS ###
#######################

  echo -e "\n\nPerforming globals backup (roles and tablespaces)"
  echo -e "--------------------------------------------\n"

  if [ $ENABLE_GLOBALS_BACKUPS = "yes" ]
  then
          echo "Globals backup"

          if ! pg_dumpall -w -g -U "$USERNAME" --no-owner | gzip > $FINAL_BACKUP_DIR"globals".sql.gz.in_progress; then
                  echo "[!!ERROR!!] Failed to produce globals backup" 1>&2
          else
                  mv $FINAL_BACKUP_DIR"globals".sql.gz.in_progress $FINAL_BACKUP_DIR"globals".sql.gz
          fi
  else
  	echo "None"
  fi

}

function backup_schemas(){
###########################
### SCHEMA-ONLY BACKUPS ###
###########################

  if [ $SCHEMA_ONLY_LIST ]; then
     for SCHEMA_ONLY_DB in ${SCHEMA_ONLY_LIST//,/ }
     do
  	   SCHEMA_ONLY_CLAUSE="$SCHEMA_ONLY_CLAUSE or datname ~ '$SCHEMA_ONLY_DB'"
     done

     SCHEMA_ONLY_QUERY="select datname from pg_database where false $SCHEMA_ONLY_CLAUSE order by datname;"
     #SCHEMA_ONLY_QUERY="select schema_name from information_schema.schemata;"

     echo -e "\n\nPerforming schema-only backups"
     echo -e "--------------------------------------------\n"

     SCHEMA_ONLY_DB_LIST=`psql -U "$USERNAME" -At -c "$SCHEMA_ONLY_QUERY" postgres`

     echo -e "The following databases were matched for schema-only backup:\n${SCHEMA_ONLY_DB_LIST}\n"

     for DATABASE in $SCHEMA_ONLY_DB_LIST
     do
  	    echo "Schema-only backup of $DATABASE"

  	    if ! pg_dump -Fp -s -U "$USERNAME" -w "$DATABASE" --no-owner  | gzip > $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress; then
  		      echo "[!!ERROR!!] Failed to backup database schema of $DATABASE" 1>&2
  	    else
  		      mv $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz
  	    fi
     done
  else
    FULL_BACKUP_QUERY="select datname from pg_database where datname <> 'template1' and datname <> 'template0' order by datname;"

    echo -e "\n\nPerforming all databases schema only backups"
    echo -e "--------------------------------------------\n"

    for DATABASE in `psql -U "$USERNAME" -At -c "$FULL_BACKUP_QUERY" postgres`
    do
    	if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
    	then
    		echo "Backup SCHEMA of $DATABASE"

    		if ! pg_dump -Fp -s -U "$USERNAME" -w "$DATABASE" --no-owner | gzip > $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress; then
          echo "[!!ERROR!!] Failed to backup database schema of $DATABASE" 1>&2
        else
          mv $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz
        fi
      fi
    done
  fi

}

function backup_databases() {
###########################
###### FULL BACKUPS #######
###########################

  for SCHEMA_ONLY_DB in ${SCHEMA_ONLY_LIST//,/ }
  do
  	EXCLUDE_SCHEMA_ONLY_CLAUSE="$EXCLUDE_SCHEMA_ONLY_CLAUSE and datname !~ '$SCHEMA_ONLY_DB'"
  done

  FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn $EXCLUDE_SCHEMA_ONLY_CLAUSE order by datname;"

  echo -e "\n\nPerforming full backups"
  echo -e "--------------------------------------------\n"

  for DATABASE in `psql -U "$USERNAME" -At -c "$FULL_BACKUP_QUERY" postgres`
  do
  	if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
  	then
  		echo "Plain backup of $DATABASE"

  		if ! pg_dump -Fp -U "$USERNAME" -w "$DATABASE" --no-owner | gzip > $FINAL_BACKUP_DIR"$DATABASE".sql.gz.in_progress; then
  			echo "[!!ERROR!!] Failed to produce plain backup database $DATABASE" 1>&2
  		else
  			mv $FINAL_BACKUP_DIR"$DATABASE".sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE".sql.gz
  		fi
  	fi

  	if [ $ENABLE_CUSTOM_BACKUPS = "yes" ]
  	then
  		echo "Custom backup of $DATABASE"

  		if ! pg_dump -Fc -U "$USERNAME" -w "$DATABASE" -f $FINAL_BACKUP_DIR"$DATABASE".custom.in_progress; then
  			echo "[!!ERROR!!] Failed to produce custom backup database $DATABASE" 1>&2
  		else
  			mv $FINAL_BACKUP_DIR"$DATABASE".custom.in_progress $FINAL_BACKUP_DIR"$DATABASE".custom
  		fi
  	fi

  done

  echo -e "\nAll database backups complete!"
}

function make_final_archive() {
  cd $BACKUP_DIR
  echo -e "\nCombinimg all archives into one $ARCHIVE_DATE.tar"
  tar -cpf $BACKUP_DIR/"backup_$ARCHIVE_DATE".tar /$FINAL_BACKUP_DIR
  if [ $? -eq 0 ]; then
    echo "Archive created sucessfuly. Removing $FINAL_BACKUP_DIR directory"
    rm -rf /$FINAL_BACKUP_DIR
  else
    echo "[!!ERROR!!] Filed to make tar archive."
  fi

  if [[ $DAYS_OF_BACKUP -lt $(ls -1 | wc -l) ]]; then
    for FILE_TO_DELETE in `find . -maxdepth 1 -mtime "+$(($DAYS_OF_BACKUP-1))"`
    do
      rm -rf $FILE_TO_DELETE
    done
  fi
}

function help() {
  cat << EOF
  usage: $0 [options]

  -h this page
EOF
exit 0
}

function main() {
  load_configs
  perform_checks
  backup_globals
  backup_schemas
  backup_databases
  make_final_archive
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
else
  while [ $# -gt 0 ]; do
          case $1 in
                  -h)    help
                  -c)
                         if [ -r "$2" ]; then
                                  source "$2"
                                  shift 2
                         else
                                  ${ECHO} "Unreadable config file \"$2\"" 1>&2
                                  exit 1
                         fi
                         ;;
                  *)
                         ${ECHO} "Unknown Option \"$1\"" 1>&2
                         exit 2
                         ;;
          esac
  done

  main $@
fi
