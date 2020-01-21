#!/bin/bash

usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-s source] [-d destination]

description:
    transfer script for phase 2 

arguments:
    -h help		prints help documentation
    -s source		source location for files to copy
    -d drive		copy location from source
    -e email		email address to send completion or error emails
    -x external         external drive for storing and splitting large files temporarily
    -l log              directory for log files

For questions of comments, contact Bradley Jenner at <bnjenner@ucdavis.edu>
EOF
)

###############################################################
#### Argument Parser

while getopts ':hs:d:e:x:l:' option; do
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
    x) EXTERNAL=${OPTARG%/}
       ;;
    l) LOG_DIR=${OPTARG%/}
       ;;
  esac
done

shift $((OPTIND - 1))

###############################################################
#### File Transfer Script

ID=`date +%s`

mkdir ${LOG_DIR}/phase_2_${ID}

rclone lsd --exclude=logfolder/ --exclude=lost+found/ $SOURCE_DIR | \
  awk '{print $5}' > ${LOG_DIR}/phase_2_${ID}/phase_2_source_dirs_${ID}.txt

rclone lsd --exclude=logfolder/ --exclude=lost+found/ $DEST_DIR | \
  awk '{print $5}' > ${LOG_DIR}/phase_2_${ID}/phase_2_dest_dirs_${ID}.txt


for dest_dir in `cat ${LOG_DIR}/phase_2_${ID}/phase_2_dest_dirs_${ID}.txt`
do
	for source_dir in `cat ${LOG_DIR}/phase_2_${ID}/phase_2_source_dirs_${ID}.txt` 
	do
		if [[ $dest_dir == $source_dir ]]
		then
			clone.sh -s ${SOURCE_DIR}/$source_dir \
				 -d ${DEST_DIR}/$dest_dir \
				 -l $LOG_DIR \
				 -x $EXTERNAL \
			     -e bnjenner@ucdavis.edu \
			     -v -i ${ID}_${dest_dir}
		fi
	done
done 

[[ -d ${LOG_DIR}/log_${ID}_debug ]] || mkdir ${LOG_DIR}/log_dir.${ID}
mv ${LOG_DIR}/*_${ID}*/ ${LOG_DIR}/log_dir.${ID}/

