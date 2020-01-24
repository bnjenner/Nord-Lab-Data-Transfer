############## DATA TRANSFER SCRIPTS ##############

The following scripts are implementations of 
the Rclone data transfer protocol that accomplish
a specific set of tasks defined by the needs of 
the Nord Lab at UC Davis and their system 
infrastructure. Please familarize yourself with the 
following programs as well as the functionality
of Rclone before using these scripts. 

For questions of comments, PLEASE contact
Bradley Jenner at <bnjenner@ucdavis.edu>

################### General Notice ################

Clone this repository to your computer and add it 
to your path in .bash_profile

    git clone https://github.com/bnjenner/Nord_Lab_Data_Transfer.git
    export PATH=$PATH:path/to/this/repository


#################### clone.sh  ####################

usage:
    
   clone.sh [-h] [-s source] [-s destination] [-e email]

description:
    
   file copy protocol (rclone) with completion and error update emails.

arguments:
    
    -h help		prints help documentation
    
    -s source		source location for files to copy
    
    -d drive		copy location from source
    
    -r remote		copy location from drive (optional second transfer)
    
    -e email		email address to send completion or error emails
    
    -k key          key file specifying email and password ("email:password")     
    
    -x external         external drive for storing and splitting large files temporarily
    
    -l log              directory for log files
    
    -v verbose          save intermediate log files for debugging

#################### unchunk.sh  ####################

usage:

   unchunk.sh [-h] [-d directory] 

description:

   concatenate files previously split by clone.sh   

arguments:

    -h help     prints help documentation
    
    -d directory        split directory to reassemble


#################### cluster_sync.sh  ####################

usage:

   cluster_sync.sh [-h] [-s source] [-d destination]

description:

   Implementation of clone.sh that copies contents of subdirectories into corresponding, pre-existing directories.  

arguments:

    -h help     prints help documentation
    
    -s source       source location for files to copy
    
    -d drive        copy location for source
    
    -e email        email address to send completion or error message
    
    -x external         external drive for storing and splitting large files temporarily
    
    -l log              directory for log files 



