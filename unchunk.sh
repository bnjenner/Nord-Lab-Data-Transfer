#!/bin/bash

###############################################################
#### Usage 

usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-d directory] 

description:
    concatenate split files 

arguments:
    -h help		prints help documentation
    -d directory        split directory to reassemble

For questions of comments, contact Bradley Jenner at <bnjenner@ucdavis.edu>
EOF
)

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
out_file=${files[0]%_split*}
out_path=`echo ${SPLIT_DIR} | rev | cut -d "/" -f2- | rev` 

touch ${out_path}/${out_file}

for file in ${files[@]}
do
    cat ${SPLIT_DIR}/${file} >> ${out_path}/${out_file}
done


rm -rf ${SPLIT_DIR}

