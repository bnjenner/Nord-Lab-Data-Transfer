#!/bin/bash

###############################################################
#### Usage Message

usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-s source] [-s destination] [-e email]

description:
    rclone file copy protocol with completion and error update emails.

arguments:
    -h help		prints help documentation
    -s source		source location for files to copy
    -d drive		copy location from source
    -r remote		copy location from drive (optional)
    -e email		email address to send completion or error emails
    -l log              directory for log files
    -v verbose          save intermediate log files for debugging

For questions of comments, contact Bradley Jenner at <bnjenner@ucdavis.edu>
EOF
)

###############################################################
#### Argument Parser

while getopts ':hs:d:r:e:l:v' option; do
  case $option in
    h) echo "$usage"
       exit
       ;;
    s) SOURCE_DIR=${OPTARG}
       ;;
    d) DRIVE_DIR=${OPTARG}
       ;;
    r) REMOTE_DIR=${OPTARG-NA}
       ;;
    e) EMAIL=${OPTARG}
       ;;
    l) LOG_DIR=${OPTARG}
       ;;
    v) VERBOSE=VERBOSE
       ;;
  esac
done
shift $((OPTIND - 1))

###############################################################
#### Functions

## check() : checks transfered files against files in source directory to identify failed and successful transfers
check () {
  from_list=`cat $1` # files transferred from source
  failed_list=$(awk 'BEGIN { FS = ": " } /ERROR/ {print $2}' $2) # extracts file names from error messages
  check_name=$3 # indicates transfer number

  for x in ${failed_list[@]};
  do
          for y in ${from_list[@]};
          do
                  if [ "$x" == "$y" ];
                  then
                          from_list=( "${source[@]/$x/}" )
                  fi
          done
  done

  
  for z in ${from_list[@]};
  do
    echo $z >> ${LOG_DIR}/successful_transfers_${ID}_${check_name}.txt
  done

  temp=`cat ${LOG_DIR}/successful_transfers_${ID}_${check_name}.txt`
  if [[ $temp == "" ]]
  then
    echo '#' >> ${LOG_DIR}/successful_transfers_${ID}_${check_name}.txt
  fi    

  echo '#' >> ${LOG_DIR}/failed_transfers_${ID}_${check_name}.txt
  for z in ${failed_list[@]};
  do
    echo $z >> ${LOG_DIR}/failed_transfers_${ID}_${check_name}.txt
  done

}

## mail() : parses log and output files to construct email file. Sends email to specified address
send_mail () {
  transfer_stats=$(cat "${1}") # extracts last instance of speed and transfer updates
  err_messages=$(grep 'NOTICE\|ERROR' $1) # extracts all error and notice messages
  success_files=$(cat $2) # successful transfers
  fail_files=$(cat $3) # failed transfers
  transfer_path=$4 # indicates transfer path
  output_name=$5

  if [[ $fail_files  == "#" ]]
  then
          fail_files='None'
  fi


  if [[ $err_messages  == "" ]]
  then
          err_messages='None'
  fi

  formatted_message=$(cat << EOF
RCLONE UPLOAD REPORT

**********
TRANSFER:
${transfer_path}

**********
UPLOAD STATS:
${transfer_stats}

**********
SUCCESSFUL UPLOADS:
${success_files}

**********
FAILED UPLOADS:
${fail_files}

**********
ERRORS:
${err_messages}
EOF
)
  echo -e "${formatted_message}" > ${LOG_DIR}/${output_name} # creates human readable stats file 

  curl --url 'smtp://smtp.gmail.com:587' --ssl-reqd \
  --mail-from 'noreplyboxupload@gmail.com' --mail-rcpt $EMAIL \
  --upload-file ${LOG_DIR}/${output_name} --user 'noreplyboxupload@gmail.com:sokku8-keghuh-Qatcah'
}

###############################################################
#### File Transfers

ID=`date +%s`

# checks to see if -l was specified
if [ -z "$LOG_DIR" ]
then
  LOG_DIR="clone_log"
fi

# checks to see if log directory exists, creates it if false.
[[ -d ${LOG_DIR} ]] || mkdir ${LOG_DIR}

#### First Transfer : $SOURCE --> $DRIVE

rclone lsf -q $SOURCE_DIR > ${LOG_DIR}/source_files.txt


if [ ! -z "$REMOTE_DIR" ]
then

  trans_number=3

else

  trans_number=2

fi


for ((i=1; i<${trans_number}; i++))
do
  echo "###### Iniating Transfer_${i} ######"

  if [ ${i} == 1 ]
  then 

    FROM=$SOURCE_DIR
    TO=$DRIVE_DIR
    CHECK=${LOG_DIR}/source_files.txt

  else

    FROM=$DRIVE_DIR
    TO=$REMOTE_DIR
    CHECK=${LOG_DIR}/successful_transfers_${ID}_1.txt

  fi

  file_num=`wc -l ${CHECK} | awk '{ print $1 }'`
  files_per_file=$(( (( ${file_num} / 5 )) + 4 ))

  if [ ${file_num} != 0 ]
  then

    split -a 1 -l ${files_per_file} ${CHECK} ${LOG_DIR}/split-${ID}-
    split_files=$(( `ls -dq ${LOG_DIR}/split-${ID}-* | wc -l` + 1 ))

  else

    cat ${CHECK} > ${LOG_DIR}/split-${ID}-a
    split_files=2

  fi

  for ((j=1; j<${split_files}; j++))
  do

    echo "**** Running Parallel Transfer: ${j} ****"
    k=`echo ${j} | tr '[1-5]' '[a-e]'`
    rclone copy --verbose $FROM $TO --include-from=${LOG_DIR}/split-${ID}-${k} \
    --tpslimit=1 --transfers=3 --checkers=3 --buffer-size=48M \
    --retries-sleep=3s --retries=5 --log-file=${LOG_DIR}/log_${ID}_${i}_${j}_transfer.out.txt &

  done

  wait

  rm ${LOG_DIR}/split-${ID}-?


  echo "###### Checking Transfer_${i} ######"
  rclone check $FROM $TO --files-from=${CHECK} --one-way --log-file=${LOG_DIR}/log_${ID}_${i}_check.out.txt

  check ${CHECK} \
        ${LOG_DIR}/log_${ID}_${i}_check.out.txt \
        $i

  for file in ${LOG_DIR}/log_${ID}_${i}_*_transfer.out.txt
  do 
    grep -A 4 'ETA' ${file} | tail -5 >> ${LOG_DIR}/temp_${ID}.txt
  done

  echo "###### Sending Email Update: Transfer_${i} ######"
  send_mail ${LOG_DIR}/temp_${ID}.txt \
            ${LOG_DIR}/successful_transfers_${ID}_${i}.txt \
            ${LOG_DIR}/failed_transfers_${ID}_${i}.txt \
            "${FROM}  ->  ${TO}" \
            log_${ID}_${i}_transfer_final.txt 

  rm ${LOG_DIR}/temp_${ID}*.txt 

  echo "###### Transfer_${i} Complete ######"

done

###############################################################
#### Intermediate File Cleanup
if [ -z "$VERBOSE" ]
then
  rm ${LOG_DIR}/failed_transfers_${ID}* ${LOG_DIR}/successful_transfers_${ID}* ${LOG_DIR}/*${ID}*_check.out.txt ${LOG_DIR}/*${ID}*_transfer.out.txt ${LOG_DIR}/source_files.txt
else
  [[ -d ${LOG_DIR}/log_${ID}_debug ]] || mkdir ${LOG_DIR}/log_${ID}_debug
  rm ${LOG_DIR}/source_files.txt ${LOG_DIR}/failed_transfers_${ID}* ${LOG_DIR}/successful_transfers_${ID}*
  mv ${LOG_DIR}/*${ID}*.txt ${LOG_DIR}/log_${ID}_debug/
fi

