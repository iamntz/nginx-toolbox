#!/bin/bash

service nginx stop

rm -rf /var/www/$2

userdel $1
groupdel $1

rm /etc/nginx/sites-available/$1
rm /etc/php/7.0/fpm/pool.d/$1.conf
rm -rf /etc/letsencrypt/live/$1

read mysqlRootPassword
mysql -uroot -p${mysqlRootPassword} -e "DROP USER $1;"
mysqladmin -uroot -p${mysqlRootPassword} drop $1