#!/usr/bin/env bash

# GLOBAL VARIABLES

DOWNLOAD_PATH="/tmp/downloads"

# MAIN PROVISION TASK
do_provision()
{
	sudo mkdir -p ${DOWNLOAD_PATH}

	sudo apt-get install -y zip wget re2c curl libcurl3 openssl dirmngr libgearman-dev
	sudo apt-get install -y autoconf g++ make libssl-dev libcurl4-openssl-dev pkg-config libsasl2-dev libpcre3-dev

	install_php_and_composer
	install_git
	install_nodejs
	install_nginx
	install_phpmyadmin
	set_crontab
	set_hosts
	set_bash

	sudo usermod -a -G www-data vagrant

	sudo apt-get remove -y --purge apache2
	sudo apt-get autoremove -y

	sudo rm -Rf ${DOWNLOAD_PATH}
}

# PHP & COMPOSER
install_php_and_composer()
{
	sudo apt-get install -y php7.0 php7.0-cli php7.0-common php7.0-curl php7.0-dev php7.0-gd php7.0-intl php7.0-json php7.0-mbstring php7.0-mcrypt php7.0-mysql php7.0-xml php7.0-zip php7.0-imap
	sudo apt-get install -y php7.0-redis php7.0-imagick php7.0-fpm

	sudo sed -i "s/^;cgi\.fix_pathinfo.*/cgi\.fix_pathinfo = 0/g" /etc/php/7.0/fpm/php.ini
	sudo sed -i "s/^post_max_size.*/post_max_size = 20M/g" /etc/php/7.0/fpm/php.ini
	sudo sed -i "s/^upload_max_filesize.*/upload_max_filesize = 20M/g" /etc/php/7.0/fpm/php.ini

	sudo sed -i "s/^;listen\.backlog.*/listen\.backlog = -1/g" /etc/php/7.0/fpm/pool.d/www.conf
	sudo sed -i "s/^pm\.max_children.*/pm\.max_children = 10/g" /etc/php/7.0/fpm/pool.d/www.conf
	sudo sed -i "s/^pm\.start_servers.*/pm\.start_servers = 4/g" /etc/php/7.0/fpm/pool.d/www.conf
	sudo sed -i "s/^pm\.min_spare_servers.*/pm\.min_spare_servers = 2/g" /etc/php/7.0/fpm/pool.d/www.conf
	sudo sed -i "s/^pm\.max_spare_servers.*/pm\.max_spare_servers = 6/g" /etc/php/7.0/fpm/pool.d/www.conf
	sudo sed -i "s/^;pm\.max_requests.*/pm\.max_requests = 1000/g" /etc/php/7.0/fpm/pool.d/www.conf
	sudo sed -i "s/^;slowlog.*/slowlog = \/var\/log\/php7\.0-fpm-\$pool\.log\.slow/g" /etc/php/7.0/fpm/pool.d/www.conf
	sudo sed -i "s/^;request_slowlog_timeout.*/request_slowlog_timeout = 5s/g" /etc/php/7.0/fpm/pool.d/www.conf
	sudo sed -i "s/^;catch_workers_output.*/catch_workers_output = yes/g" /etc/php/7.0/fpm/pool.d/www.conf

	sudo sed -i "s/^;emergency_restart_threshold.*/emergency_restart_threshold = 10/g" /etc/php/7.0/fpm/php-fpm.conf
	sudo sed -i "s/^;emergency_restart_interval.*/emergency_restart_interval = 1m/g" /etc/php/7.0/fpm/php-fpm.conf
	sudo sed -i "s/^;process_control_timeout.*/process_control_timeout = 10s/g" /etc/php/7.0/fpm/php-fpm.conf

	cd ${DOWNLOAD_PATH}

	sudo wget https://github.com/wcgallego/pecl-gearman/archive/master.zip
	unzip master.zip 
	cd pecl-gearman-master/
	sudo phpize
	./configure
	sudo make
	sudo make install
	echo "extension=gearman.so" | sudo tee /etc/php/7.0/mods-available/gearman.ini
	sudo phpenmod -v 7.0 -s ALL gearman

	sudo pecl install mongodb
	echo "extension=mongodb.so" | sudo tee /etc/php/7.0/mods-available/mongodb.ini
	sudo phpenmod -v 7.0 -s ALL mongodb

	sudo service php7.0-fpm restart

	cd ${DOWNLOAD_PATH}
	curl -s https://getcomposer.org/installer | php
	sudo mv composer.phar /usr/local/bin/composer
}

# GIT
install_git()
{
	sudo apt-get -y install git
}

# NODE
install_nodejs()
{
	curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -

	sudo apt-get -y install nodejs build-essential

	sudo npm install -g less
}

# NGINX
install_nginx()
{
	sudo apt-get remove -y --purge apache2

	sudo apt-get install -y nginx

	sudo mkdir -p /etc/nginx/ssl
	sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 1024

	sudo openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=ES/ST=Castellon/L=Castellon/O=EventsCase/CN=${EVENTSCASE_DOMAIN}" -keyout /etc/nginx/ssl/eventscase.key  -out /etc/nginx/ssl/eventscase.crt

	sudo cp ${PROVISION_PATH}/000-eventscase.conf /etc/nginx/sites-available/000-eventscase.conf
	sudo ln -s /etc/nginx/sites-available/000-eventscase.conf /etc/nginx/sites-enabled/000-eventscase.conf

	sudo rm /etc/nginx/sites-enabled/default

	ESCAPED_PROJECT_PATH=$(echo ${PROJECT_PATH} | sed "s/\//\\\\\//g")
	sudo sed -i "s/\/media\/websites\/\$host/${ESCAPED_PROJECT_PATH}/g" /etc/nginx/sites-available/000-eventscase.conf

	sudo sed -i "s/^fastcgi_param  SERVER_NAME.*/fastcgi_param  SERVER_NAME \$host;/g" /etc/nginx/fastcgi.conf

	sudo cp ${PROVISION_PATH}/nginx.conf /etc/nginx/nginx.conf

	sudo service nginx restart
}

# PHPMYADMIN
install_phpmyadmin()
{
	cd ${DOWNLOAD_PATH}

	sudo apt-get install -y debconf-utils

	echo "phpmyadmin phpmyadmin/internal/skip-preseed boolean true" | sudo debconf-set-selections
	echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
	echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | sudo debconf-set-selections

	sudo apt-get -y install phpmyadmin

	sudo apt-get -y remove --purge mariadb-*

	sudo sed -i "s/\$dbuser=.*/\$dbuser='${DB_USER}';/g" /etc/phpmyadmin/config-db.php
	sudo sed -i "s/\$dbpass=.*/\$dbpass='${DB_PASS}';/g" /etc/phpmyadmin/config-db.php
	sudo sed -i "s/\$dbserver=.*/\$dbserver='${GEARMAN_IP}';/g" /etc/phpmyadmin/config-db.php
}

# CRONTAB
set_crontab()
{
	CRONTAB=$(cat <<EOF
# m h  dom mon dow   command
* * * * *   php ${PROJECT_PATH}/vendor/bin/crunz schedule:run
EOF
)

	echo "${CRONTAB}" | sudo tee -a /var/spool/cron/crontabs/${SSH_USER}
}

# HOSTS
set_hosts()
{
	echo "127.0.0.1	localhost ${EVENTSCASE_DOMAIN} ${EVENTSCASE_HOST}" | sudo tee /etc/hosts
	echo "${GEARMAN_IP}	${GEARMAN_HOST}" | sudo tee -a /etc/hosts
}

# BASH
set_bash()
{
	GITCWD=$(cat <<EOF
parse_git_branch() {
	git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\u@\h: \[\033[33m\]\$PWD\[\033[32m\]\$(parse_git_branch)\[\033[00m\]$ '
EOF
)

	echo "alias ll=\"ls -halF\" " | sudo tee -a /home/vagrant/.bashrc
	echo "cd ${PROJECT_PATH}" | sudo tee -a /home/vagrant/.bashrc
	echo "${GITCWD}" | sudo tee -a /home/vagrant/.bashrc

	echo "alias ll=\"ls -halF\" " | sudo tee -a /root/.bashrc
	echo "cd ${PROJECT_PATH}" | sudo tee -a /root/.bashrc
	echo "${GITCWD}" | sudo tee -a /root/.bashrc
	sudo sed -i "s/\[00m[\]\][$]/\[00m\\\]#/g" /root/.bashrc

	if [ ${SSH_USER} = "root" ]
	then
		echo "sudo -i" | sudo tee -a /home/vagrant/.bashrc
	fi
}


##########################
##########################
########## MAIN ##########
##########################
##########################

do_provision
