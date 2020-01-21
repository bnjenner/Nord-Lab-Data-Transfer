#!/bin/bash

SOURCE_DIR=${1%/}
DEST_DIR=${2%/}
LOG_DIR=${3%/}

ID=`date +%s`

rclone lsd --exclude=logfolder/ --exclude=lost+found/ $SOURCE_DIR | \
  awk '{print $5}' > ${LOG_DIR}/phase_2_source_files_${ID}.txt


for dest_dir in `ls $DEST_DIR`
do
	for source_dir in `cat ${LOG_DIR}/phase_2_source_files_${ID}.txt` 
	do
		if [[ $dest_dir == $source_dir ]]
		then
			clone.sh -s ${SOURCE_DIR}/$source_dir \
				 -d ${DEST_DIR}/$dest_dir \
				 -l $LOG_DIR \
				 -x ../ex_drive	\
			         -e bnjenner@ucdavis.edu 
		fi
	done
done 
