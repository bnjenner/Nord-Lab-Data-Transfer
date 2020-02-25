usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-e] [-d] [-k]

description:
    Simple encryption and decryption script for email function in clone.sh

arguments:
    -e encrypt    generate encrypted key
    -d decrypt    decrypt key file
    -k key        if -e, output name for encrpyted key file. If -d, key file to decrypt

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

while getopts ':hedk:p:' option; do
  case $option in
    h) echo "$usage"
       exit
       ;;
    e) EN=true
       ;;
    d) DE=true
       ;;
    k) KEY=${OPTARG}
       ;;
    p) PASS=${OPTARG}
  esac
done
shift $((OPTIND - 1))

###############################################################
#### Script

ID=`date +%s`

if [[ $EN == "true" ]] && [ ! -z $KEY ]
then

	echo -n Gmail Username: # email address input
	read email
	echo -n Email Password: # password input
	read -s password
	echo
  echo ${email}:${password} | openssl enc -aes-256-cbc -iter 3 -out $KEY # generates encrypted file
  echo "###### Encrypted Key File Generated ######"

elif [[ $DE == "true" ]]  && [ ! -z $KEY ]
then

  if [ -z $PASS ]
  then 

  	echo -n Password: # password for decryption key
  	read -s password
  	echo
  	gate=`openssl enc -in $KEY -d -aes-256-cbc -iter 3 -pass pass:$password` # decrypts file
  	echo $gate

  else

    gate=`openssl enc -in $KEY -d -aes-256-cbc -iter 3 -pass pass:$PASS` # decrypts file
    echo $gate

  fi

else

  echo "###### Arguments Missing ######"

fi

###############################################################
