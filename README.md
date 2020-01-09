#################### clone.sh  ####################
usage:
    clone.sh [-h] [-s source] [-s destination] [-e email]

description:
    file copy protocol (rclone and nftp) with completion and error update emails.

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


#################### unchunk.sh  ####################
