#!/bin/bash

usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-s source] [-d destination]

description:
    Implementation of clone.sh that copies contents of subdirectories into corresponding, pre-existing directories.  

arguments:
    -h help		prints help documentation
    -s source		source location for files to copy
    -d drive		location for source
    -e email		email address to send completion or error message
    -k key    key file specifying email and password ("email:password")
    -l log              directory for log files

For questions of comments, contact Bradley Jenner at <bnjenner@ucdavis.edu>
EOF
)

###############################################################
#### Exit and Error and Debug Messages

set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command failed on line ${LINENO}."' ERR

###############################################################
#### Argument Parser

while getopts ':hs:d:e:k:l:' option; do
  case $option in
    h) echo "$usage"
       exit
       ;;
    s) SOURCE_DIR=${OPTARG%/}
       ;;
    d) DEST_DIR=${OPTARG%/}
       ;;
    e) EMAIL=${OPTARG}
       ;;
    k) KEY=${OPTARG}
       ;;
    l) LOG_DIR=${OPTARG%/}
       ;;
  esac
done

shift $((OPTIND - 1))

###############################################################
#### File Transfer Script

ID=`date +%s`

echo "##### Transfer ID: ${ID} #####"

mkdir ${LOG_DIR}/phase_2_${ID}

rclone lsd --include-from=server_directories.txt $SOURCE_DIR | \
  awk '{print $5}' > ${LOG_DIR}/phase_2_${ID}/phase_2_source_dirs_${ID}.txt

rclone lsd -L --exclude=logfolder/ --exclude=box.com/ $DEST_DIR | \
  awk '{print $5}' > ${LOG_DIR}/phase_2_${ID}/phase_2_dest_dirs_${ID}.txt


for dest_dir in `cat ${LOG_DIR}/phase_2_${ID}/phase_2_dest_dirs_${ID}.txt`
do
	for dest_subdir in `ls ${DEST_DIR}/$dest_dir`
	do
		for source_dir in `cat ${LOG_DIR}/phase_2_${ID}/phase_2_source_dirs_${ID}.txt` 
		do
			if [[ $dest_subdir == $source_dir ]]
			then
				clone.sh -s ${SOURCE_DIR}/${source_dir} \
					         -d ${DEST_DIR}/${dest_dir}/${dest_subdir} \
				 	         -l $LOG_DIR \
			     	       -e $EMAIL -k $KEY \
			     	 	     -v -i ${ID}_${dest_dir}_$dest_subdir
			fi
		done
	done
done

[[ -d ${LOG_DIR}/log_${ID}_debug ]] || mkdir ${LOG_DIR}/log_dir.${ID}
mv ${LOG_DIR}/*_${ID}*/ ${LOG_DIR}/log_dir.${ID}/

