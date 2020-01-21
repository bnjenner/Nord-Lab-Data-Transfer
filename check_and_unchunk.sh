#!/bin/bash


dest_var=$1

dest_list=`rclone ls --exclude=logfolder/ --exclude=lost+found/ $dest_var | \
           awk '{$1=""; print $0}' | grep split_`

temp_list=()

for file in ${dest_list[@]}
do
	temp_list+=( `echo $file |  rev | cut -d '/' -f 2- | rev` ) 
done

split_dir_list=`echo ${temp_list[@]} | tr " " "\n" | sort -n | uniq | tr "\n" " "`


for dir in ${split_dir_list[@]}
do
	if [[ $dir = *_split ]] 
	then
		unchunk.sh -d ${dest_var%/}/${dir}
	fi
done