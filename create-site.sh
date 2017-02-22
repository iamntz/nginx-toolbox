#!/bin/bash

# usage:
# ./create-site.sh user site

# to delete:
# rm -rf /var/www/site_name/
# rm /etc/nginx/sites-available/site_name
# rm /etc/php/7.0/fpm/pool.d/user.conf
# rm -rf /etc/letsencrypt/live/site_name
# userdel user
# groupdel user

service nginx stop

# creating default folder structure
mkdir -p /var/www/$2/htdocs
mkdir -p /var/www/$2/logs
touch /var/www/$2/logs/access.log
touch /var/www/$2/logs/error.log
touch /var/www/$2/htdocs/index.php

# adding group for new site
groupadd $1
# adding user for the new site
useradd -g $1 $1 -d /var/www/$2 -G sshusers
# maybe add to www-data as well?
#useradd -g $1 $1 -d /var/www/$2 -G www-data

# changing permissions for the new site
chown -R $1:$1 /var/www/$2

# copying  nginx config
cp ./templates/nginx.conf /etc/nginx/sites-available/$2

#copying pool config to limit access to an user
cp ./templates/pool.conf /etc/php/7.0/fpm/pool.d/$1.conf

# replacing dummy value with the real domain name
sed -i s/__SITE_NAME__/$2/g /etc/nginx/sites-available/$2
sed -i s/__USER_NAME__/$1/g /etc/nginx/sites-available/$2

# replacing dummy value with real user name
sed -i s/__SITE_NAME__/$1/g /etc/php/7.0/fpm/pool.d/$1.conf

# generating let's encrypt certificate
# /root/letsencrypt/certbot-auto certonly --standalone -d $2
letsencrypt certonly --standalone -d $2


# restarting PHP & nginx
service php7.0-fpm restart
service nginx start


# create random password
PASSWDDB="$(openssl rand -base64 12)"

# replace "-" with "_" for database username
MAINDB=${USER_NAME//[^a-zA-Z0-9]/_}

# If /root/.my.cnf exists then it won't ask for root password
if [ -f /root/.my.cnf ]; then
    mysql -e "CREATE DATABASE $1 /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -e "CREATE USER $1@localhost IDENTIFIED BY '${PASSWDDB}';"
    mysql -e "GRANT ALL PRIVILEGES ON $1.* TO '$1'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
# If /root/.my.cnf doesn't exist then it'll ask for root password
else
    echo "Please enter root user MySQL password!"
    read rootpasswd
    mysql -uroot -p${rootpasswd} -e "CREATE DATABASE $1 /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -uroot -p${rootpasswd} -e "CREATE USER $1@localhost IDENTIFIED BY '${PASSWDDB}';"
    mysql -uroot -p${rootpasswd} -e "GRANT ALL PRIVILEGES ON $1.* TO '$1'@'localhost';"
    mysql -uroot -p${rootpasswd} -e "FLUSH PRIVILEGES;"
fi

echo "Domain: $2"
echo "Mysql user: $1"
echo "Mysql Password: ${PASSWDDB}"

sudo -u $1 -i -- wp core download --path=htdocs
sudo -u $1 -i -- wp core config --path=htdocs --dbname=$1 --dbuser=$1 --dbpass=${PASSWDDB}
sudo -u $1 -i -- wp core install --path=htdocs --url=https://$2 --title="$2" --admin_user=admin --admin_password=123 --admin_email=admin@$2

sudo -H -u $1 bash -c 'mkdir ~/.ssh && ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -q -N "" -C "dev@dev" && cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys'