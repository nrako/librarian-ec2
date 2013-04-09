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
      vagrant > /dev/null && \
      cd -"

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
LOCAL_COOKBOOKS=$2/cookbooks-src

EC2_SSH_PRIVATE_KEY=$3

#make sure this matches the CHEF_FILE_CACHE_PATH in `bootstrap.sh`
CHEF_FILE_CACHE_PATH=/tmp/cheftime

#Upload Chefile and dna.json to directory (need to use sudo to copy over to $CHEF_FILE_CACHE_PATH and run chef)
echo "Uploading Cheffile and dna.json"
scp -q -i $EC2_SSH_PRIVATE_KEY -r -P $PORT \
  $CHEFFILE \
  $DNA \
  $USERNAME@$IP:.

if [ -d $LOCAL_COOKBOOKS ]; then
  echo "Uploading $LOCAL_COOKBOOKS"
  scp -i $EC2_SSH_PRIVATE_KEY -r -P $PORT \
    $LOCAL_COOKBOOKS \
    $USERNAME@$IP:.
fi

#check to see if the bootstrap script has completed running
echo "Check requirements chef-solo and librarian-chef"
MAX_TESTS=10
SLEEP_BETWEEN_TESTS=30

OVER=0
TESTS=0
while [ $OVER != 1 ] && [ $TESTS -lt $MAX_TESTS ]; do
  echo "Testing for installation of chef-solo"
  (ssh -q -t -p "$PORT" -o "StrictHostKeyChecking no" \
    -i $EC2_SSH_PRIVATE_KEY \
    $USERNAME@$IP \
    "which chef-solo > /dev/null")
  if [ "$?" -ne "0" ] ; then
    TESTS=$(echo $TESTS+1 | bc)
    sleep $SLEEP_BETWEEN_TESTS
  else
    OVER=1
  fi
done
if [ $TESTS = $MAX_TESTS ]; then
    echo "${INSTANCE} never got chef-solo installed" 1>&2
    exit 1
fi
echo "$INSTANCE has chef-solo installed"

OVER=0
TESTS=0
while [ $OVER != 1 ] && [ $TESTS -lt $MAX_TESTS ]; do
  echo "Testing for installation of librarian-chef"
  (ssh -q -t -p "$PORT" -o "StrictHostKeyChecking no" \
    -i $EC2_SSH_PRIVATE_KEY \
    $USERNAME@$IP \
    "which librarian-chef > /dev/null")
  if [ "$?" -ne "0" ] ; then
    TESTS=$(echo $TESTS+1 | bc)
    sleep $SLEEP_BETWEEN_TESTS
  else
    OVER=1
  fi
done
if [ $TESTS = $MAX_TESTS ]; then
    echo "${INSTANCE} never got librarian-chef installed" 1>&2
    exit 1
fi
echo "$INSTANCE has librarian-chef installed"

#Okay, run it.
echo "Run librarian-chef and chef-solo, this can take a while"

if [ -d $LOCAL_COOKBOOKS ]; then
  eval "ssh -q -t -p \"$PORT\" -l \"$USERNAME\" -i \"$EC2_SSH_PRIVATE_KEY\" $USERNAME@$IP \"sudo -i sh -c 'cd $CHEF_FILE_CACHE_PATH && \
  cp -r /home/$USERNAME/cookbooks-src .'\""
fi

eval "ssh -q -t -p \"$PORT\" -l \"$USERNAME\" -i \"$EC2_SSH_PRIVATE_KEY\" $USERNAME@$IP \"sudo -i sh -c 'cd $CHEF_FILE_CACHE_PATH && \
mkdir -p /root/.ssh && \
mv /home/ubuntu/.ssh/id_rsa /root/.ssh/id_rsa && \
chmod 600 /root/.ssh/id_rsa && \
chown root:root /root/.ssh/id_rsa && \
cp -r /home/$USERNAME/Cheffile . && \
cp -r /home/$USERNAME/dna.json . && \
librarian-chef install && \
chef-solo -c $CHEF_FILE_CACHE_PATH/solo.rb -j dna.json'\""

echo "Done!"

exit