#!/bin/bash

#22.04 has set needrestart to automaticlly be interactive, this just changes it to automatic
#If you want it to be interactive again change the line in /etc/needrestart/needrestart.conf from:
# '$nrconf{restart} = 'a'' to '#$nrconf{restart} = 'i'' 
sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

apt update
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt-get -y upgrade
apt-get -y install libnss3-tools caddy

mkdir www
wget https://gitlab.com/fflabs/dash_server/-/archive/master/dash_server-master.tar.gz
tar -xf dash_server-master.tar.gz
rm dash_server-master.tar.gz

rm -r www/

mkdir /var/www
mkdir /var/www/html
