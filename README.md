############## DATA TRANSFER SCRIPTS ##############

The following scripts implement Rclone data 
transfer protocols in scripts that accomplish
a specific set of tasks defined by the needs of 
the Nord Lab at UC Davis and their system 
infrastructure. Please familarize yourself with the 
following programs as well as the syntax and usage 
of Rclone before using these scripts. 

For questions or comments, PLEASE contact
Bradley Jenner at <bnjenner@ucdavis.edu>

################### General Notice ################

Clone this repository to your computer and add it 
to your path in .bash_profile

    git clone https://github.com/bnjenner/Nord_Lab_Data_Transfer.git
    echo "export PATH=$PATH:path/to/this/repository" >> ~/.bash_profile
    source ~/.bash_profile


In order to use the email function in clone.sh
an encrypted file containing the senders gmail
username and password must be generated using 
the included script "crypt.sh". The process is 
very straight forward and can be accomplished 
using the following command:

    crypt.sh -e -k name_of_key_file.txt

#################### clone.sh  ####################

USAGE:
    
   clone.sh [-h] [-s source] [-s destination] [-e email]

DESCRIPTION:
    
   file copy protocol (rclone) with completion and error update emails.

ARGUMENTS:
    
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

USAGE:

   unchunk.sh [-h] [-d directory] 

DESCRIPTION:

   concatenate files previously split by clone.sh script   

ARGUMENTS:

    -h help     prints help documentation
    
    -d directory        split directory to reassemble


#################### cluster_sync.sh  ####################

USAGE:

   cluster_sync.sh [-h] [-s source] [-d destination]

DESCRIPTION:

   Implementation of clone.sh that copies contents of subdirectories into corresponding, pre-existing directories.  

ARGUMENTS:

    -h help     prints help documentation
    
    -s source       source location for files to copy
    
    -d drive        copy location for source
    
    -e email        email address to send completion or error message
    
    -x external         external drive for storing and splitting large files temporarily
    
    -l log              directory for log files 

#################### crypt.sh  ####################

USAGE:

   crypt.sh [-h] [-ed] [-k]

DESCRIPTION:

   Simple encryption and decryption script for email function in clone.sh

ARGUMENTS:

    -e encrypt    generate encrypted key

    -d decrypt    decrypt key file

    -k key        if -e, output name for encrpyted key file. If -d, key file to decrypt


###################################################
