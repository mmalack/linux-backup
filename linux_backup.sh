#!/usr/bin/env bash

# exit script if a command exits with a non-zero
set -e


########################
#  Required functions  #
########################

load_conf_file () {

    set -a
    # shellcheck disable=SC1090
    [ -f "$conf_file" ] && source "$conf_file"
    set +a
}

backup_files () {

  # create backup directory
  ssh -p"${SSH_PORT}" "${SSH_USER}"@"${SSH_HOST}" "mkdir -p ${TARGET}/${BACKUP_NAME}"

  if [ -f "$excludes_file" ]
  then
    # transfer backup file using excludes file
    tar --exclude-from="${excludes_file}" -cz "${SOURCE}" | ssh -p"${SSH_PORT}" "${SSH_USER}"@"${SSH_HOST}" "dd of=${TARGET}/${BACKUP_NAME}/${TODAY}.tar.gz bs=4M"
  else
    # transfer backup file without excludes file
    tar -cz "${SOURCE}" | ssh -p"${SSH_PORT}" "${SSH_USER}"@"${SSH_HOST}" "dd of=${TARGET}/${BACKUP_NAME}/${TODAY}.tar.gz bs=4M"
  fi
}

backup_database () {

  # transfer database file
  ${DATABASE_SOFTWARE} -p"${DATABASE_PASS}" -u "${DATABASE_USER}" -h "${DATABASE_HOST}" --port="${DATABASE_PORT}" "${DATABASE_ARGUMENTS}" "${DATABASE_NAME}" | gzip | ssh -p"${SSH_PORT}" "${SSH_USER}"@"${SSH_HOST}" "dd of=${TARGET}/${BACKUP_NAME}/${TODAY}.sql.gz bs=4M"
}

remove_old_files () {

  if [ -n "$(ssh -p"${SSH_PORT}" "${SSH_USER}"@"${SSH_HOST}" "ls -A ${TARGET}/${BACKUP_NAME}/${OLD_BACKUP}.tar.gz")" ]; then
    ssh -p"${SSH_PORT}" "${SSH_USER}"@"${SSH_HOST}" "rm ${TARGET}/${BACKUP_NAME}/${OLD_BACKUP}.tar.gz"
  fi

  if [ -n "$(ssh -p"${SSH_PORT}" "${SSH_USER}"@"${SSH_HOST}" "ls -A ${TARGET}/${BACKUP_NAME}/${OLD_BACKUP}.sql.gz")" ]; then
    ssh -p"${SSH_PORT}" "${SSH_USER}"@"${SSH_HOST}" "rm ${TARGET}/${BACKUP_NAME}/${OLD_BACKUP}.sql.gz"
  fi
}

backup_tasks () {
    backup_files
    backup_database
    remove_old_files
}

###################################
#  Initialize default parameters  #
###################################

TODAY=$(date +"%Y%m%d")
OLD_BACKUP=$(date -d "7 days ago" +"%Y%m%d")
WORKING_DIR="$(dirname "$(test -L "$0" && readlink "$0" || echo "$0")")"

# script name (does not handle symlinks)
script_name=$(basename -- "$0")
# script name without extension
script_name="${script_name%.*}"
# script name (also handles symlinks)
#script_name="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
# default .conf file (also handles symlinks)
conf_file="$WORKING_DIR/$script_name.conf"
# default .excludes file
excludes_file="$WORKING_DIR/$script_name.excludes"


##################
#  Dependencies  #
##################

# check if rsync is installed
#command -v rsync >/dev/null 2>&1 || { echo >&2 "rsync is required but not installed. Aborting..."; exit 1; }

# check if tar is installed
command -v tar >/dev/null 2>&1 || { echo >&2 "tar is required but not installed. Aborting..."; exit 1; }


##################
#  Backup tasks  #
##################

# if an individual .conf file exists, process it and ignore the directory
if [ -f "$conf_file" ]; then

  load_conf_file
  backup_tasks

  exit 1;
fi


######################################
#  Support for multiple .conf files  #
######################################

# cancel if neither directory nor .conf files exists
if [ ! -d "./${script_name}" ] || [ "$(find ./"${script_name}"/ -name "*.conf" -type f 2>/dev/null | wc -l)" -eq 0 ]; then
  echo ".conf file does not exist. Please create a file named ${conf_file} or provide at least one via directory ./${script_name}/*.conf"
  exit 1
fi

for conf_file in ./"${script_name}"/*.conf; do

  # job name
  job_name=$(basename -- "$conf_file")
  # job name without extension
  job_name="${job_name%.*}"

  load_conf_file
  excludes_file="$WORKING_DIR/$script_name/$job_name.excludes"

  backup_tasks
done