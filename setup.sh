#!/bin/bash
#This script uploads everything required for `chef-solo` to run
set -e

if test -z "$3"
then
  echo "I need 
1) IP address of a machine to provision
2) Path to a Vagrant VM folder (a folder containing a Vagrantfile) that you want me to extract Chef recipes from
3) Path to a SSH private key for this machine"
  exit 1
fi


#Run vagrant to create dna.json
echo "Making dna.json"
eval "cd \"$2\" && \
      vagrant > /dev/null"

#Try to match and extract a port provided to the script
ADDR=$1
IP=${ADDR%:*}
PORT=${ADDR#*:}
if [ "$IP" == "$PORT" ] ; then
  
    PORT=22
fi

USERNAME=ubuntu
CHEFFILE=$2/Cheffile
DNA=$2/dna.json

EC2_SSH_PRIVATE_KEY=$3

#make sure this matches the CHEF_FILE_CACHE_PATH in `bootstrap.sh`
CHEF_FILE_CACHE_PATH=/tmp/cheftime

#Upload Chefile and dna.json to directory (need to use sudo to copy over to $CHEF_FILE_CACHE_PATH and run chef)
echo "Uploading Cheffile and dna.json"
scp -i $EC2_SSH_PRIVATE_KEY -r -P $PORT \
  $CHEFFILE \
  $DNA \
  $USERNAME@$IP:.



#check to see if the bootstrap script has completed running
echo "Check requirements chef-solo and librarian-chef"

eval "ssh -q -t -p \"$PORT\" -l \"$USERNAME\" -i \"$EC2_SSH_PRIVATE_KEY\" $USERNAME@$IP \"sudo -i which chef-solo > /dev/null \""

if [ "$?" -ne "0" ] ; then
    echo "chef-solo not found on remote machine; it is probably still bootstrapping, give it a minute."
    exit
fi

eval "ssh -q -t -p \"$PORT\" -l \"$USERNAME\" -i \"$EC2_SSH_PRIVATE_KEY\" $USERNAME@$IP \"sudo -i which librarian-chef > /dev/null \""

if [ "$?" -ne "0" ] ; then
    echo "librarian-chef not found on remote machine; it is probably still bootstrapping, give it a minute."
    exit
fi

#Okay, run it.
echo "Run librarian-chef and chef-solo, this can take a while"

eval "ssh -t -p \"$PORT\" -l \"$USERNAME\" -i \"$EC2_SSH_PRIVATE_KEY\" $USERNAME@$IP \"sudo -i sh -c 'cd $CHEF_FILE_CACHE_PATH && \
cp -r /home/$USERNAME/Cheffile . && \
cp -r /home/$USERNAME/dna.json . && \
librarian-chef install && \
chef-solo -c solo.rb -j dna.json'\""

echo "Done!"

exit