#!/bin/bash
DOMAIN=$2
USER=$1

service nginx stop
service php7.0-fpm stop

rm -rf /var/www/$DOMAIN

userdel $USER
groupdel $USER

rm /etc/php/7.0/fpm/pool.d/$USER.conf

rm /etc/nginx/sites-available/$DOMAIN
rm /etc/nginx/sites-enabled/$DOMAIN

rm -rf /etc/letsencrypt/live/$DOMAIN

read mysqlRootPassword
mysql -uroot -p${mysqlRootPassword} -e "DROP USER ${USER}@localhost;"
#mysqladmin -uroot -p${mysqlRootPassword} drop $USER

service nginx start
service php7.0-fpm start
