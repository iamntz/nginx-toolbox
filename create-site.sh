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
#
#
# sudo apt-get install sendmail imagemagick nginx php-fpm php-mysql php-dom letsencrypt composer phpunit mariadb-server-10.0 mariadb-client-core-10.0 php-curl php-gd
#
# sudo echo "AllowGroups sshusers" >> /etc/ssh/sshd_config
# sudo addgroup sshusers && adduser root sshusers
# curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

# sudo echo "cgi.fix_pathinfo=0" >> /etc/php/7.0/fpm/php.ini
# https://www.digitalocean.com/community/tutorials/how-to-install-linux-nginx-mysql-php-lemp-stack-in-ubuntu-16-04#configure-the-php-processor



show_help()
{
    echo "
Quick Usage:
    You just need to specify the user name that will run the site and
    the fully qualified domain name (i.e. without the http part; subdomains also works)

    e.g. ./create-site.sh site_user my.site.com

Advanced usage:
    -d, --domain        FQ domain
    -u, --user          site_user
    --wp_password       wordpress-password
    --wp_mail           wordpress-admin-mail
    --wp_admin          wordpress-admin-user

-h, --help              Print this help"
    exit 1
}


for i in "$@"
do
case $i in
    -h | --help )
    show_help
    exit 1
    ;;
    -d=*|--domain=*)
    DOMAIN="${i#*=}"
    shift
    ;;
    -u=*|--user=*)
    USER="${i#*=}"
    shift
    ;;
    --wp_password=*)
    WP_PASSWORD="${i#*=}"
    shift
    ;;
    --wp_mail=*)
    WP_MAIL="${i#*=}"
    shift
    ;;
    --wp_admin=*)
    WP_ADMIN="${i#*=}"
    shift
    ;;
    *)
        DOMAIN=$2
        USER=$1
    ;;
esac
done

service nginx stop

# creating default folder structure
mkdir -p /var/www/${DOMAIN}/htdocs
mkdir -p /var/www/${DOMAIN}/logs
touch /var/www/${DOMAIN}/logs/access.log
touch /var/www/${DOMAIN}/logs/error.log
touch /var/www/${DOMAIN}/htdocs/index.php

# adding group for new site
groupadd $USER
# adding user for the new site
useradd -g $USER $USER -d /var/www/$DOMAIN -G sshusers
# maybe add to www-data as well?
#useradd -g $USER $USER -d /var/www/$DOMAIN -G www-data

# changing permissions for the new site
chown -R $USER:$USER /var/www/$DOMAIN

# copying  nginx config
cp templates/nginx.conf /etc/nginx/sites-available/$DOMAIN

#copying pool config to limit access to an user
cp templates/pool.conf /etc/php/7.0/fpm/pool.d/$USER.conf

# replacing dummy value with the real domain name
sed -i s/__SITE_NAME__/$DOMAIN/g /etc/nginx/sites-available/$DOMAIN
sed -i s/__USER_NAME__/$USER/g /etc/nginx/sites-available/$DOMAIN
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN


# replacing dummy value with real user name
sed -i s/__SITE_NAME__/$USER/g /etc/php/7.0/fpm/pool.d/$USER.conf

# generating let's encrypt certificate
letsencrypt certonly --standalone -d $DOMAIN

# restarting PHP & nginx
service php7.0-fpm restart
service nginx start

# create random password
PASSWDDB="$(openssl rand -base64 12)"

# replace "-" with "_" for database username
MAINDB=${USER_NAME//[^a-zA-Z0-9]/_}

# If /root/.my.cnf exists then it won't ask for root password
if [ -f /root/.my.cnf ]; then
    mysql -e "CREATE DATABASE ${USER} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -e "CREATE USER ${USER}@localhost IDENTIFIED BY '${PASSWDDB}';"
    mysql -e "GRANT ALL PRIVILEGES ON ${USER}.* TO '${USER}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
# If /root/.my.cnf doesn't exist then it'll ask for root password
else
    echo "Please enter root user MySQL password!"
    read rootpasswd
    mysql -uroot -p${rootpasswd} -e "CREATE DATABASE ${USER} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -uroot -p${rootpasswd} -e "CREATE USER ${USER}@localhost IDENTIFIED BY '${PASSWDDB}';"
    mysql -uroot -p${rootpasswd} -e "GRANT ALL PRIVILEGES ON ${USER}.* TO '${USER}'@'localhost';"
    mysql -uroot -p${rootpasswd} -e "FLUSH PRIVILEGES;"
fi

read -p "Install WP (Y/n)? " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo -u $USER -i -- wp core download --path=htdocs
    sudo -u $USER -i -- wp core config --path=htdocs --dbname=$USER --dbuser=$USER --dbpass=${PASSWDDB}

    if [[ -z $WP_PASSWORD ]]; then
        WP_PASSWORD="$(openssl rand -base64 6)"
    fi

    if [[ -z $WP_MAIL ]]; then
        WP_MAIL=admin@$DOMAIN
    fi

    if [[ -z $WP_ADMIN ]]; then
        WP_ADMIN=admin
    fi

    echo "Installing WordPress. This may take a while."
    sudo -u $USER -i -- wp core install --path=htdocs --url=https://$DOMAIN --title="${DOMAIN}" --admin_user=${WP_ADMIN} --admin_password=${WP_PASSWORD} --admin_email=${WP_MAIL}
    sudo -H -u $USER bash -c 'mkdir ~/.ssh && ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -q -N "" -C "dev@dev" && cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys'
fi

echo "Domain: ${DOMAIN}"
echo "Mysql user: ${USER}"
echo "Mysql Password: ${PASSWDDB}"

echo "wp-admin user: ${WP_ADMIN}"
echo "wp-admin password: ${WP_PASSWORD}"
