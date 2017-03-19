#!/bin/bash

echo please enter your domain name
read domain_name

# install docker-compose
sudo apt -y update
sudo apt -y upgrade

sudo apt install apt install apt-transport-https \
     ca-certificates curl software-properties-common

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt -y update

sudo apt install -y docker-ce docker-compose

sudo usermod -aG docker $USER

if ! type "letsencrypt"; then
    echo installing letsencrypt
    sudo apt install -y letsencrypt
else echo letsencrypt seems to be already installed
fi

sudo letsencrypt certonly --standalone -d $domain_name -d www.$domain_name -d kf.$domain_name -d kc.$domain_name -d en.$domain_name

git clone https://github.com/kobotoolbox/kobo-docker.git
