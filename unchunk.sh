#!/bin/bash

###############################################################
#### Usage 

usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-d directory] 

description:
    concatenate files previously split  by clone.sh

arguments:
    -h help   prints help documentation
    -d directory        split directory to reassemble

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

while getopts ':hd:' option; do
  case $option in
    h) echo "$usage"
       exit
       ;;
    d) SPLIT_DIR=${OPTARG%/}
       ;;
  esac
done
shift $((OPTIND - 1))

###############################################################
#### Unchunk


files=( $(ls ${SPLIT_DIR}) )
out_file=${SPLIT_DIR%_split*}
out_path=`echo ${SPLIT_DIR} | rev | cut -d "/" -f2- | rev` 

touch ${out_file}

for file in ${files[@]}
do
    cat ${SPLIT_DIR}/${file} >> ${out_file}
done


rm -rf ${SPLIT_DIR}

