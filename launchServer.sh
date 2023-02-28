#!/bin/bash

EC2_HOSTNAME=`ec2metadata --public-hostname`
echo ${EC2_HOSTNAME}


sudo pkill ffmpeg
sudo pkill packager

sudo ./caddy reverse-proxy --from  ${EC2_HOSTNAME}:443 --to 0.0.0.0:8080 >/dev/null 2> caddy.log &
sudo python3 ./dash_server-master/dash_server.py /var/www/html/ -l INFO -4 -a 0.0.0.0 -p 8080 >/dev/null 2> dash_server.log &
