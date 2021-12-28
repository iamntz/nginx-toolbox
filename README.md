# Usage

```
certbot certonly --dns-digitalocean --dns-digitalocean-credentials ~/.secrets/certbot/digitalocean.ini -d site.com -d *.site.com
./create-site.sh site_user site_url
```

# To delete a site:

```
rm -rf /var/www/site_name/
rm /etc/nginx/sites-available/site_name
rm /etc/php/7.4/fpm/pool.d/user.conf
rm -rf /etc/letsencrypt/live/site_name
userdel site_user
groupdel site_user
```

# First time Setup

### Install requirements:

```bash
add-apt-repository ppa:ondrej/php
add-apt-repository ppa:certbot/certbot
apt install sendmail imagemagick nginx composer phpunit mariadb-server redis-server
apt install php7.4-fpm php7.4-{bcmath,bz2,intl,gd,mbstring,mysql,zip,dom,curl,redis}
snap install core
snap refresh core
apt-get remove certbot
snap install --classic certbot
snap install certbot-dns-digitalocean
ln -s /snap/bin/certbot /usr/bin/certbot
```

### Make SSH allow connection from site_user

```bash
echo "AllowGroups sshusers" >> /etc/ssh/sshd_config
addgroup sshusers && adduser root sshusers
```


### Install WP-CLI

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp
```

### PHP tweaks

Set CLI php version

```
update-alternatives --set php /usr/bin/php7.4
```

Securing:
```bash
echo "cgi.fix_pathinfo=0" >> /etc/php/7.4/fpm/php.ini
```

Fix compat with large requests (e.g. ACF plugin): edit `/etc/php/7.4/fpm/php.ini` and change:
```
upload_max_filesize = 100M
post_max_size = 100M
```

https://www.digitalocean.com/community/tutorials/how-to-install-linux-nginx-mysql-php-lemp-stack-in-ubuntu-16-04#configure-the-php-processor

### Nginx tweaks

on `/etc/nginx/nginx.conf`  (http block)

```
client_max_body_size 100m;
```

### Install Redis

Change `supervised systemd` on /etc/redis/redis.conf

```
systemctl restart redis.service
```

https://www.digitalocean.com/community/tutorials/how-to-install-and-secure-redis-on-ubuntu-18-04


### Certbot setup:
Create  `~/.secrets/certbot/digitalocean.ini`

```
dns_digitalocean_token = INSERT_TOKEN_HERE
```

You find your token in DO sidebar -> API -> Personal Access Tokens

Cron job for certbot:

```
0 0 * * 1 certbot renew -q --dns-digitalocean --dns-digitalocean-credentials ~/.secrets/certbot/digitalocean.ini
```

`vim /etc/letsencrypt/renewal-hooks/deploy/01-reload-nginx` and add:

```
#! /bin/sh
set -e

/etc/init.d/nginx configtest
/etc/init.d/nginx reload
```

`chmod +x /etc/letsencrypt/renewal-hooks/deploy/01-reload-nginx`

### Logrotate:

On `/etc/logrotate.d/nginx`

```
/var/www/*/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
            run-parts /etc/logrotate.d/httpd-prerotate; \
        fi \
    endscript
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
```

