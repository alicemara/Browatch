#!/bin/bash

#cleanup .txt files used to define variables if script was interrupted before cleanup previously
rm -f eip2.txt eip.txt instanceid.txt deleteid.txt rgn.txt amiid.txt media.key keyid.txt keybase64.txt keyidbase64.txt pdns.txt pipe

# Check package manager and download awscli
# From: https://unix.stackexchange.com/a/571192

echo "Downloading/updating awscli & ffmpeg"
sleep 3

packagesNeeded=("awscli" "ffmpeg")
if [ -x "$(command -v apk)" ];       then sudo apk add --no-cache ${packagesNeeded[@]}
elif [ -x "$(command -v brew)" ];    then brew install ${packagesNeeded[@]}
elif [ -x "$(command -v apt-get)" ]; then sudo apt-get install ${packagesNeeded[@]}
elif [ -x "$(command -v dnf)" ];     then sudo dnf install ${packagesNeeded[@]}
elif [ -x "$(command -v zypper)" ];  then sudo zypper install ${packagesNeeded[@]}
elif [ -x "$(command -v yum)" ];     then sudo yum install ${packagesNeeded[@]}
else echo "FAILED TO INSTALL PACKAGE: Package manager not found. You must manually install: ${packagesNeeded[@]}">&2;
fi


# Having user add aws access keys to be able to run script
echo "You will need an access key from your AWS account to paste into the next step, as the script creates a new profile specific to browatch." 
read -r -p 'Stop and get that if you need it: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey_CLIAPI (Press any key to continue)' -n1 -s && echo ' '

sleep 2
echo "Setting up browatch profile/confirming profile settings"
aws configure --profile browatch

export AWS_PROFILE=browatch

# Capture desired region of deployment (in case user wants it to be different from profile default)
# Then change the default for the shell

# starting setting up EC2 instance
read -p $'What region would you like to deploy this in? (us-east-2, us-west-1, etc)\n' rgn
export AWS_DEFAULT_REGION="$rgn"


# Deletes any instances with browatch tag if they exist

doid=$(aws ec2 describe-instances --filters "Name=instance.group-name,Values='browatch'" --output text --query 'Reservations[*].Instances[*].InstanceId')

if [ -n "$doid" ]; then
aws ec2 terminate-instances --instance-ids $doid
echo "Waiting 30 seconds to allow any extra instances to terminate..."
sleep 30

else
echo "No previous browatch instances found to terminate."

fi



#aws ec2 describe-instances --filters "Name=instance.group-name,Values='browatch'" --output text --query 'Reservations[*].Instances[*].InstanceId' > deleteid.txt 
#doid=$(cat deleteid.txt)
#aws ec2 terminate-instances --instance-ids $doid

#echo "Waiting 30 seconds to allow any extra instances to terminate...(you may see an error if there were no instances to terminate)"

#sleep 30

echo "We will create your SSH keys now. They will be named browatch.pem. Any prior ones with the same name will be overwritten."
sleep 5

# delete old key from AWS

aws ec2 delete-key-pair --key-name browatch

# Move to key storage and remove old key from your machine 

rm -f browatch.pem

# generate new key

aws ec2 create-key-pair --key-name browatch --query 'KeyMaterial' --output text > browatch.pem

# set key permissions

chmod 400 browatch.pem

echo "SSH key created and any previous browatch keys in folder removed"

# deleting and remaking security groups

aws ec2 delete-security-group --group-name browatch

aws ec2 create-security-group --group-name browatch --description "browatch security group"

# enable ssh port and whatever other security rule we need
# 80 is needed for caddy to be able to pass cert challenges
# 443 is needed for https and recieving stream/ serving player
# We use port 8080 for the reverse proxy on the web server
aws ec2 authorize-security-group-ingress --group-name browatch --protocol tcp --port 22 --cidr "0.0.0.0/0"
aws ec2 authorize-security-group-ingress --group-name browatch --protocol tcp --port 80 --cidr "0.0.0.0/0"
aws ec2 authorize-security-group-ingress --group-name browatch --protocol tcp --port 443 --cidr "0.0.0.0/0"
aws ec2 authorize-security-group-ingress --group-name browatch --protocol tcp --port 8080 --cidr "0.0.0.0/0"

echo "Security group created and configured"

# spin up new aws instance 

# select up to date ubuntu image
aws ec2 describe-images --region $rgn --filters "Name=name,Values=ubuntu/images/hvm-ssd/*22.04-amd64-server-????????" --query "sort_by(Images, &CreationDate)[-1:].[ImageId]" --output text > amiid.txt

amiid=$(cat amiid.txt)

# start the instance
aws ec2 run-instances --region $rgn  --image-id $amiid --count 1 --instance-type t2.micro --key-name browatch --security-groups browatch --tag-specifications 'ResourceType=instance,Tags=[{Key=server,Value=browatch}]' --output text

echo "EC2 Instance created and starting"

sleep 1

echo "Giving the instance 30 seconds to get provisioned..."

sleep 30

# get the public DNS of the new EC2 instance
aws ec2 describe-instances --filters "Name=instance.group-name,Values=browatch" --query 'Reservations[].Instances[].PublicDnsName' --output text > pdns.txt
# make the publicdns a variable
pdns=$(cat pdns.txt)
sleep 2

# Pulling ssh keys to local machine, connecting to new Ec2 instance, and running the autoinstaller for the ec2 instance
echo "Moving server files to instance..."
sleep 2
scp -i ./browatch.pem buildServer.sh launchServer.sh killServer.sh ubuntu@${pdns}:/home/ubuntu
echo "SSHing into instance to set up web server"
sleep 2
ssh -t -i ./browatch.pem ubuntu@${pdns} 'sudo ./buildServer.sh && sudo ./launchServer.sh'
wait

echo "Waiting a minute to allow the web server to get a SSL certificate..."
sleep 58
echo "Does this unit have a soul?"
sleep 2

#Build local encoder then launching the stream
./buildEncoder.sh 
wait
./launchStream.sh ${pdns}
wait 

#Echos a link for you to use/share
echo "Kill the stream with killStream.sh and kill the web server by connecting to it and running killServer.sh"
echo "If you aren't going to use the instance again, I would recommend deleting it as well so you don't rack up charges"
#cleanup files used to define variables and debug
rm -f eip2.txt eip.txt instanceid.txt deleteid.txt rgn.txt amiid.txt media.key keyid.txt keybase64.txt keyidbase64.txt pdns.txt
