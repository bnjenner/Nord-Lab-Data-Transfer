#!/bin/bash

###############################################################
#### Usage Message

usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-s source] [-d destination]

description:
    rclone file copy protocol with completion and error update emails.

arguments:
    -h help		prints help documentation
    -s source		source location for files to copy
    -d drive		copy location from source
    -r remote		copy location from drive (optional second transfer)
    -e email		email address to send completion or error emails
    -x external         external drive for storing and splitting large files temporarily
    -l log              directory for log files
    -v verbose          save intermediate log files for debugging

For questions of comments, contact Bradley Jenner at <bnjenner@ucdavis.edu>
EOF
)

###############################################################
#### Argument Parser

while getopts ':hs:d:r:e:x:l:v' option; do
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
    x) EXTERNAL=${OPTARG%/}
       ;;
    l) LOG_DIR=${OPTARG%/}
       ;;
    v) VERBOSE=VERBOSE
       ;;
  esac
done
shift $((OPTIND - 1))

###############################################################
#### Functions

## clone_and_check() : main transfer and check protocol.
clone_and_check() {

  rclone mkdir $2 

  echo "###### Iniating Transfer_${4} ######"
  rclone copy $1 $2 --verbose --include-from=$3 \
    --tpslimit=3 --transfers=3 --checkers=3 --buffer-size=48M \
    --retries-sleep=10s --retries=5 --ignore-size \
    --log-file=${LOG_DIR}/log_${ID}_${4}_transfer.out.txt


  echo "###### Checking Transfer_${4} ######"
  rclone check $1 $2 --files-from=$3 --one-way \
    --tpslimit=3 --transfers=3 --checkers=3 --buffer-size=48M \
    --retries-sleep=10s --retries=5 --ignore-size \
    --log-file=${LOG_DIR}/log_${ID}_${4}_check.out.txt

}

## chunk_and_clone() : checks error messages for files that failed due to size. Splits these files into chunks for separate uploads
chunk_and_clone () {

  transfer_errors=`awk 'BEGIN { FS = ": " } /ERROR/ {print $2}' ${1} | grep -v "Attempt .* failed with .* errors and" | sort -u` # extracts transfer errors 
  size_limit=15000000000 # cut off file size (usually remote specific) 15000000000
  size_chunks=$(( ${size_limit} / 2)) # chunk sizes for transfer  

  external_split_dir=${EXTERNAL}/clone_split_directory # directory to store chunked files for transfer 
  location_dir=${2%/} # location of input (source)
  destination_dir=$3 # location for output (destination)
  index="${4}_chunk" # index prefix


  [[ -d ${external_split_dir} ]] || mkdir ${external_split_dir}


  for file in ${transfer_errors[@]}
  do
 
    chunky_file_size=`rclone size ${location_dir}/${file} | cut -d " " -f5 | cut -d "(" -f2`

    if (( ${chunky_file_size} > ${size_limit} )) # this uses bytes for comparison
    then

      echo "###### ERROR: File (${file}) too large. Splitting now. ######"
      echo "###### Writing chunked file (${file}) to ${external_split_dir}/${chunky_file}_split/. This must be manually deleted. ######"
      chunky_file=${file%.*}
      
      [[ -d ${external_split_dir}/${chunky_file}_split ]] || mkdir ${external_split_dir}/${chunky_file}_split
      
      echo "${location_dir}/${file}" > ${LOG_DIR}/temp_chunky_files_${ID}.txt

      # split file into chunks of specified sizes.
      split -a 1 -b ${size_chunks}  ${location_dir}/${file}  ${external_split_dir}/${chunky_file}_split/${file}_split_

      ls ${external_split_dir}/${chunky_file}_split/ > ${LOG_DIR}/temp_chunky_files_${ID}.txt

      clone_and_check ${external_split_dir}/${chunky_file}_split/ \
                      ${destination_dir%/}/${chunky_file}_split/ \
                      ${LOG_DIR}/temp_chunky_files_${ID}.txt \
                      ${index}_split

      chunk_check=`grep -e '0 differences found' ${LOG_DIR}/log_${ID}_${index}_split_check.out.txt`

      if [[ $chunk_check != "" ]] 
      then

        sed -i '' "/${file}/d" ${LOG_DIR}/log_${ID}_${i}_transfer.out.txt
        sed -i '' "/${file}/d" ${1}
        sed -i '' "/${file}/d" $CHECK
        cat ${LOG_DIR}/temp_chunky_files_${ID}.txt >> $CHECK

      fi

    fi 

  done
  
}

## mail() : parses log and output files to construct email file. Sends email to specified address
send_mail () {

  echo "###### Sending Email Update: Transfer ${4} ######"

  transfer_stats=$(cat "${1}") # extracts last instance of speed and transfer updates
  err_messages=$(grep 'NOTICE\|ERROR' $2) # extracts all error and notice messages
  fail_files=$(awk 'BEGIN { FS = ": " } /ERROR/ {print $2}' ${3}) # extracts file names from error messages # failed transfers
  transfer_path=$4 # indicates transfer path
  output_name=$5

  if [[ $fail_files  == "" ]]
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
#### File Transfer Script

ID=`date +%s`

# checks to see if -l was specified
if [ -z "$LOG_DIR" ]
then

  LOG_DIR="clone_log"

fi

# checks to see if log directory exists, creates it if false.
[[ -d ${LOG_DIR} ]] || mkdir ${LOG_DIR}


#### First Transfer : $SOURCE --> $DRIVE
rclone ls --exclude=logfolder/ --exclude=lost+found/ $SOURCE_DIR | \
  awk '{$1=""; print $0}' > ${LOG_DIR}/source_files_${ID}.txt

if [ ! -z "$REMOTE_DIR" ]
then

  trans_number=3

else

  trans_number=2

fi


for ((i=1; i<${trans_number}; i++))
do

  if [ ${i} == 1 ]
  then 

    FROM=$SOURCE_DIR
    TO=$DRIVE_DIR
    CHECK=${LOG_DIR}/source_files_${ID}.txt

  else

    FROM=$DRIVE_DIR
    TO=$REMOTE_DIR
    CHECK=${LOG_DIR}/source_files_${ID}.txt

  fi

  clone_and_check $FROM \
                  $TO \
                  $CHECK \
                  $i

  
  if [ ! -z "$EXTERNAL" ]
  then

    chunk_and_clone ${LOG_DIR}/log_${ID}_${i}_transfer.out.txt \
                    $FROM \
                    $TO \
                    $i

  fi

  #compile statistics for easy parsing / formatting
  grep -A 4 'ETA' ${LOG_DIR}/*${i}_transfer.out.txt | tail -5 >> ${LOG_DIR}/temp_${ID}.txt


  if [ ! -z "$EMAIL" ]
  then

    send_mail ${LOG_DIR}/temp_${ID}.txt \
              ${LOG_DIR}/log_${ID}_${i}_transfer.out.txt \
              ${LOG_DIR}/log_${ID}_${i}_check.out.txt \
              "${FROM}  ->  ${TO}" \
              log_${ID}_${i}_transfer_final.txt  
  fi


  echo "###### Transfer_${i} Complete ######"

  rm ${LOG_DIR}/temp_${ID}.txt

done

###############################################################
#### Intermediate File Cleanup
if [ -z "$VERBOSE" ]
then

  rm ${LOG_DIR}/*${ID}*_check.out.txt ${LOG_DIR}/source_files_${ID}.txt

else

  [[ -d ${LOG_DIR}/log_${ID}_debug ]] || mkdir ${LOG_DIR}/log_${ID}_debug
  rm ${LOG_DIR}/source_files_${ID}.txt
  mv ${LOG_DIR}/*${ID}*.txt ${LOG_DIR}/log_${ID}_debug/

fi

