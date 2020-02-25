#!/bin/bash

###############################################################
#### Usage Message

usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-s source] [-d destination]

description:
    rclone file copy protocol with completion and error update emails.

arguments:
    -h help   prints help documentation
    -s source   source location for files to copy
    -d destination    copy location for source files
    -f final    copy location from destination. Optional second transfer
    -e email    email address to send completion email.
    -k key    key file specifying email and password ("email:password")
    -x external         external drive for storing and splitting large intermediate files temporarily
    -l log              directory for log files
    -v verbose          save intermediate log files for debugging

For questions of comments, contact Bradley Jenner at <bnjenner@ucdavis.edu>
EOF
)

###############################################################
#### Exit and Error and Debug Messages

# traps error messages, last executed commands, and the line of the error
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command failed on line ${LINENO}."' ERR


###############################################################
#### Argument Parser

while getopts ':hs:d:f:e:k:x:l:vi:' option; do
  case $option in
    h) echo "$usage"
       exit
       ;;
    s) SOURCE_DIR=${OPTARG}
       ;;
    d) DEST_DIR=${OPTARG}
       ;;
    f) FINAL_DIR=${OPTARG-NA}
       ;;
    e) EMAIL=${OPTARG}
       ;;
    k) KEY=${OPTARG}
       ;;
    x) EXTERNAL=${OPTARG%/}
       ;;
    l) LOG_DIR=${OPTARG%/}
       ;;
    v) VERBOSE=VERBOSE
       ;;
    i) ID=${OPTARG}
       ;;
  esac
done
shift $((OPTIND - 1))

echo "############ CLONE.SH ############"

###############################################################
#### Functions

## clone_and_check() : main transfer and check protocol.
clone_and_check() {

  # clone_and_check() operates in two parts-- cloning and checking. It's not brain surgery.

  echo "###### Iniating Transfer: ${5} ######"
  rclone copy $1 $2 --verbose --include-from=$3 \
    --tpslimit=3 --transfers=3 --checkers=3 --buffer-size=48M \
    --retries-sleep=10s --retries=5 --ignore-size \
    --log-file=${LOG_DIR}/log_${ID}_${4}_transfer.out.txt


  echo "###### Checking Transfer: ${5} ######"
  rclone check $1 $2 --verbose --files-from=$3 --one-way \
    --tpslimit=3 --transfers=3 --checkers=3 --buffer-size=48M \
    --retries-sleep=10s --retries=5 --ignore-size \
    --log-file=${LOG_DIR}/log_${ID}_${4}_check.out.txt

}

## chunk_and_clone() : checks error messages for files that failed due to size. Splits these files into chunks for separate uploads
chunk_and_clone () {

  # chunk_and_clone() operates by parsing the log files output by clone and check. It then looks to see if any of the files
  # are over an internally specified file size limit (this limit is determined by the server or storage device), and then breaks
  # that file into separate chunks into a specified split directory and transfered then.

  transfer_errors=`awk 'BEGIN { FS = ": " } /ERROR/ {print $2}' ${1} | grep -v "Attempt .* failed with .* errors and" | sort -u` # extracts transfer errors 


  # exits if no errors, no need to waste time 
  if [ -z $transfer_errors ]
  then
    return 0
  fi


  size_limit=15000000000 # cut off file size (usually remote specific) 15000000000
  size_chunks=$(( ${size_limit} / 2)) # chunk sizes for transfer

  external_split_dir=${EXTERNAL}/clone_split_directory # directory to store chunked files for transfer
  location_dir=${2%/} # location of input (source)
  destination_dir=$3 # location for output (destination)
  index="${4}_chunk" # index prefix


  # makes external split drive if necessary
  [[ -d ${external_split_dir} ]] || mkdir ${external_split_dir}


  for file in ${transfer_errors[@]}
  do

    # checks file sizes of each file in error messages
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

      # lists all files in split dir for transfer
      ls ${external_split_dir}/${chunky_file}_split/ > ${LOG_DIR}/temp_chunky_files_${ID}.txt

      # calls clone and check for transfer
      clone_and_check ${external_split_dir}/${chunky_file}_split/ \
                      ${destination_dir%/}/${chunky_file}_split/ \
                      ${LOG_DIR}/temp_chunky_files_${ID}.txt \
                      ${index}_split


      # checks to see if any errors occured in transfer, if not the original logfiles are corrected and the output stats are 
      # placed into the original logfile. Finally, the temporary split dir is deleted.
      chunk_check=`grep -e '0 differences found' ${LOG_DIR}/log_${ID}_${index}_split_check.out.txt`

      if [[ $chunk_check != "" ]]
      then

        sed -i '' "/${file}/d" ${LOG_DIR}/log_${ID}_${i}_transfer.out.txt
        sed -i '' "/${file}/d" ${1}
        sed -i '' "/${file}/d" $CHECK
        cat ${LOG_DIR}/temp_chunky_files_${ID}.txt >> $CHECK

        rm -rf ${external_split_dir}/

      fi

    fi

  done

}

## check_and_unchunk () : identifies files previously split by clone.sh and merges them
 check_and_unchunk () {

  dest_var=$1

  # checks to see if there are any split files in destination directory, if not, function exits
  if [ -z "$(rclone ls --exclude=logfolder/ --exclude=lost+found/ $dest_var | grep split_)" ]
  then

    return 0

  fi

  # extracts split directories from destination.
  dest_list=`rclone ls --exclude=logfolder/ --exclude=lost+found/ $dest_var | \
             awk '{$1=""; print $0}' | grep split_`


  # the following code is just a lot of manual parsing so the files can actually be 
  # read and used by rclone. It's ugly... I know.
  temp_list=()

  for file in ${dest_list[@]}
  do

    temp_list+=( `echo $file |  rev | cut -d '/' -f 2- | rev` )

  done


  split_dir_list=`echo ${temp_list[@]} | tr " " "\n" | sort -n | uniq | tr "\n" " "`


  # here is where the program actually iterates over the directories and calls the unchunk script.
  for dir in ${split_dir_list[@]}
  do

    if [[ $dir = *_split ]]
    then

      echo "###### Split File ( ${dest_var%/}/${dir} ) Identified. Merging now. ######"
      unchunk.sh -d ${dest_var%/}/${dir}

      echo "###### Merge Complete. ######"

    fi
  done

}

## mail( ) : parses log and output files to construct email file. Sends email to specified address
send_mail () {

  echo "###### Sending Email Update: Transfer ${4} ######"

  transfer_stats=$(cat "${1}") # extracts last instance of speed and transfer updates

  if test -z $(grep 'NOTICE\|ERROR' $2)
  then

  err_messages='None'

  else

    err_messages=$(grep 'NOTICE\|ERROR' $2) # extracts all error and notice messages

  fi

  if test -z $(awk 'BEGIN { FS = ": " } /ERROR/ {print $2}' ${3})
  then

        fail_files='None'

  else

  fail_files=$(awk 'BEGIN { FS = ": " } /ERROR/ {print $2}' ${3}) # extracts file names from error messages for failed transfers

  fi

  transfer_path=$4 # indicates transfer path
  output_name=$5


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

  key=`echo $SUPER_SECRET_VAR`
  sender=`echo $key | cut -d ':' -f 1` 

  curl --url 'smtp://smtp.gmail.com:587' --ssl-reqd \
  --mail-from $sender --mail-rcpt $EMAIL \
  --upload-file ${LOG_DIR}/${output_name} --user $key

}

## cleanup( ) : Intermediate File Cleanup
cleanup () {

  if [ -z "$VERBOSE" ]
  then

    rm ${LOG_DIR}/*${ID}*_check.out.txt ${LOG_DIR}/source_files_${ID}.txt

  else

    # compiles all temp and log files into a directory marked by transfer ID

    code=$1

    [[ -d ${LOG_DIR}/log_${ID}_debug ]] || mkdir ${LOG_DIR}/log_${ID}_debug

    if [[ $code == "0" ]]
    then 

      # normal exit code protocol
      rm ${LOG_DIR}/source_files_${ID}.txt
      mv ${LOG_DIR}/*${ID}*.txt ${LOG_DIR}/log_${ID}_debug/

    elif [[ $code == "1" ]]
    then

      # alternative exit code protocol, something like a connection error triggers this
      mv ${LOG_DIR}/*${ID}*.txt ${LOG_DIR}/log_${ID}_debug/

    fi
  fi

  exit

}
###############################################################
#### File Transfer Script

# checks to see if -i was specified
if [ -z "$ID" ]
then

  ID=`date +%s`

fi

# checks to see if -l was specified
if [ -z "$LOG_DIR" ]
then

  LOG_DIR="clone_log"

fi

if [ ! -z $KEY ] && [ ! -z $EMAIL ]
then
        echo "###### Password for Encrypted Key File Required ######"
        echo -n Enter Password For Key File Decryption:
        read -s password
        echo
        SUPER_SECRET_VAR=`crypt.sh -d -k $KEY -p $password` # ;)

elif [ ! -z $$EMAIL ] && [ -z $KEY ]
then

        echo "###### Encrypted File With Email Username and Password Required ######"

fi


# checks to see if log directory exists, creates it if false.
[[ -d ${LOG_DIR} ]] || mkdir ${LOG_DIR}


TRANSFER_GATE="init" # trasnfer gatekeeper variable

#### First Transfer : $SOURCE --> $DRIVE
while [ "$TRANSFER_GATE" != "pass" ]
do

  # this initial rclone ls checks to see if the directory is reachable as well as if there are connection errors with any
  # server. Additionally, the result of this command is used to generate a list of files for rclone to include in later
  # transfers.

  rclone ls --exclude=logfolder/ --exclude=lost+found/ $SOURCE_DIR --log-file=${LOG_DIR}/connection_log_${ID}.txt | \
    awk '{$1=""; print $0}' > ${LOG_DIR}/source_files_${ID}.txt

  # checks for errors and what not in the connection log file
  connection_gate=`cat ${LOG_DIR}/connection_log_${ID}.txt`

  if [[ "$connection_gate" == *"ERROR"* ]] || [[ "$connection_gate" == *"couldn’t connect SSH"* ]]
  then

    if [[ "$connection_gate" == *"couldn’t connect SSH"* ]] # checks for connection error an waits to retry 
    then

      echo "###### SSH Connection Failed: Retrying in 30 minutes. ######"
      sleep 1800

    fi

    if [[ "$connection_gate" == *"error listing"* ]] # if listing error, program fails
    then

      echo "###### Permission Error Occured: ${5} ######"
      echo "###### Ending Transfer. ######"
      echo "Tranfser ${5} experienced errors due to connection and/or permissions restrictions." > ${LOG_DIR}/connection_error_${ID}.txt
      cleanup "1"

    fi

  else

    TRANSFER_GATE="pass"

  fi

done

# checks to see how many chained transfers are called, 2 are possible.
if [ ! -z "$FINAL_DIR" ]
then

  trans_number=3

else

  trans_number=2

fi

# loop for multiple transfers
for ((i=1; i<${trans_number}; i++))
do

  if [ ${i} == 1 ]
  then

    FROM=$SOURCE_DIR
    TO=$DEST_DIR
    CHECK=${LOG_DIR}/source_files_${ID}.txt

  else

    FROM=$DRIVE_DIR
    TO=$FINAL_DIR
    CHECK=${LOG_DIR}/source_files_${ID}.txt

  fi

  clone_and_check $FROM \
                  $TO \
                  $CHECK \
                  $i \
                  "${FROM}  ->  ${TO}" 


  # will only attempt to chunk if an external drive is supplied
  if [ ! -z "$EXTERNAL" ]
  then

    chunk_and_clone ${LOG_DIR}/log_${ID}_${i}_transfer.out.txt \
                    $FROM \
                    $TO \
                    $i

  fi

  #compile statistics for easy parsing / formatting
  grep -A 4 'ETA' ${LOG_DIR}/*${i}_transfer.out.txt | tail -5 >> ${LOG_DIR}/temp_${ID}.txt


  # checks if destination isn't a remote before attempting to unchunks
  if [[ $TO != *:* ]]
  then

    check_and_unchunk $TO

  fi

  # checks to see if a key and email were supplied before sending an email.
  if [ ! -z "$EMAIL" ] && [ ! -z "$KEY" ]
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
cleanup "0"
