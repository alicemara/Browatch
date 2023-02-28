#!/bin/bash

#22.04 has set needrestart to automaticlly be interactive, this just changes it to automatic
#If you want it to be interactive again change the line in /etc/needrestart/needrestart.conf from:
# '$nrconf{restart} = 'a'' to '#$nrconf{restart} = 'i'' 
sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install libnss3-tools

mkdir www
sudo chmod +x caddy
wget https://gitlab.com/fflabs/dash_server/-/archive/master/dash_server-master.tar.gz
tar -xf dash_server-master.tar.gz
rm dash_server-master.tar.gz

rm -r www/

sudo mkdir /var/www
sudo mkdir /var/www/html
