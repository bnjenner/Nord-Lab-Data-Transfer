#!/bin/bash

TODAY=$(date '+%Y%m%d%H%M')
LOGFILE="../ncftp_log/log.${TODAY}.txt"


touch $LOGFILE

for DRIVE in "$@"
do
        cd "/media/rinaldo/${DRIVE}"
        MYFILES=`ls -I logfolder -I lost+found` 
        ncftpput -R -z -v -S .tmp -d $LOGFILE -f /home/rinaldo/Desktop/login.txt /NORDLAB_ARCHIVE $MYFILES
done

