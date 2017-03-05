#!/bin/bash

# Setup script for a web server using nginx secured by letsencrypt ssl
# on Ubuntu 16.04-64 (in this case Digital Ocean droplet)
# Essentially automates the process shown in this tutorial:
# https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-16-04
# Assumes you already have a secured machine and user with sudo privileges
# as per https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-16-04
# Requires a bit of interaction; it is theoretically possible to automate the
# answers to the letsencrypt prompts using Expect, but a huge hassle. Better
# to stick around and answer the questions.

echo
echo Welcome to an automated web server securing process.  Please stick around!
echo You will need to answer some questions from the letsencrypt prompts.
echo This procedure is based on, and more or less automates, the tutorial here:
echo https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-16-04
echo
echo please enter your domain name
read domain_name


echo updating distro
sudo apt -y update
sudo apt -y upgrade

# Install Nginx as per https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-16-04
if ! type "nginx"; then
    echo installing nginx
    sudo apt install -y nginx
else echo Nginx seems to be already installed
fi
echo allowing nginx through the UFW firewall
sudo ufw allow 'Nginx HTTP'

# Secure Nginx for HTTPS traffic using LetsEncrypt as per https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-16-04
if ! type "letsencrypt"; then
    echo installing letsencrypt
    sudo apt install -y letsencrypt
else echo letsencrypt seems to be already installed
fi

# Add a location to the nginx config, don't do twice (if-fi) and make a backup
if [ ! -f /etc/nginx/sites-available/defaultBAK ] ; then
echo backing up /etc/nginx/sites-available/default
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/defaultBAK
echo adding location block to /etc/nginx/sites-available/default
sudo sed -i '0,/server {/s/server {/server {\n        location ~ \/.well-known {\n            allow all;\n        }/' /etc/nginx/sites-available/default
else echo there seems to already be a backup of /etc/nginx/sites-available/default, which probably means this script has already been run. Not modifying the file.
fi

echo restarting Nginx
sudo systemctl restart nginx

if [ ! -d /etc/letsencrypt/live ]; then
    echo running letsencrypt
    sudo letsencrypt certonly -a webroot --webroot-path=/var/www/html -d $domain_name -d www.$domain_name
    echo backing up letsencrypt folder
    sudo cp -r /etc/letsencrypt/live/ /etc/letsencrypt/liveBAK
else echo it looks like letsencrypt has already been run!
fi
if [ ! -f /etc/ssl/certs/dhparam.pem ]; then
    sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
fi

if [ ! -f /etc/nginx/snippets/ssl-$domain_name.conf ]; then
    echo creating snippet to configure nginx with new cert
    echo "ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem;" > sslconf
    echo "ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;" >> sslconf
    sudo mv sslconf /etc/nginx/snippets/ssl-$domain_name.conf
else echo it looks like the snippets have already been created
fi

if [ ! -f /etc/nginx/snippets/ssl-params.conf ]; then
    echo creating ssl-params.conf
    cat > ssl-params.conf <<EOF
# from https://cipherli.st/
# and https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html

ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
ssl_ecdh_curve secp384r1;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the "preload" directive if you understand the implications.
#add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;

ssl_dhparam /etc/ssl/certs/dhparam.pem;

EOF
sudo mv ssl-params.conf /etc/nginx/snippets/ssl-params.conf
else echo the ssl-params file already exists
fi

if [ ! -f /etc/nginx/sites-available/defaultBAK2 ]; then
    echo Backing up /etc/nginx/sites-available/default
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/defaultBAK2
    sudo sed -i "0,/server_name _;/s/server_name _;/server_name $domain_name www.$domain_name;\n        return 301 https:\/\/\$server_name\$request_uri;/" /etc/nginx/sites-available/default
    echo "server {" | sudo tee -a /etc/nginx/sites-available/default
    echo "    listen 443 ssl http2 default_server;" | sudo tee -a /etc/nginx/sites-available/default
    echo "    listen [::]:443 ssl http2 default_server;" | sudo tee -a /etc/nginx/sites-available/default
    echo "    include snippets/ssl-$domain_name.conf;" | sudo tee -a /etc/nginx/sites-available/default
    echo "    include snippets/ssl-params.conf;" | sudo tee -a /etc/nginx/sites-available/default 
    echo "}" | sudo tee -a /etc/nginx/sites-available/default
else echo the server name is already set 
fi

echo allowing nginx full and disallowing http
sudo ufw allow 'Nginx Full'
sudo ufw delete allow 'Nginx HTTP'

echo restarting nginx
sudo systemctl restart nginx

echo
echo ****************************************************************
echo You should probably set up a cron job to renew your certificate.
echo as described at the end of this tutorial:
echo https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-16-04
echo ****************************************************************
echo
echo To see if the installation worked, open $domain_name from a browser
echo and see if you see the nginx welcome page. The address bar should show
echo https://$domain_name
echo even if you only enter $domain_name
echo 
echo The nginx welcome page lives at /usr/share/nginx/html/index.html 
