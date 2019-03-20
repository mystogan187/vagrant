#!/usr/bin/env bash

# GLOBAL VARIABLES

DOWNLOAD_PATH="/tmp/downloads"

# MAIN PROVISION TASK
do_provision()
{
	sudo mkdir -p ${PROJECT_PATH}
	sudo mkdir -p ${PROJECT_PATH}/workers
	sudo mkdir -p ${PROJECT_PATH}/logs
	sudo mkdir -p ${DOWNLOAD_PATH}

	sudo apt-get install -y zip wget re2c curl libcurl3 openssl dirmngr libgearman-dev
	sudo apt-get install -y autoconf g++ make libssl-dev libcurl4-openssl-dev pkg-config libsasl2-dev libpcre3-dev

	install_php_and_composer
	install_git
	install_nodejs
	install_image_optimizers
	install_mysql
	install_mongodb
	install_gearman
	install_redis
	install_supervisor
	set_crontab
	set_hosts
	set_bash

	sudo apt-get remove -y --purge apache2
	sudo apt-get autoremove -y

	sudo rm -Rf ${DOWNLOAD_PATH}
}

# PHP & COMPOSER
install_php_and_composer()
{
	sudo apt-get install -y php7.0 php7.0-cli php7.0-common php7.0-curl php7.0-dev php7.0-gd php7.0-intl php7.0-json php7.0-mbstring php7.0-mcrypt php7.0-mysql php7.0-xml php7.0-zip php7.0-imap
	sudo apt-get install -y php7.0-redis php7.0-imagick

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

# IMAGES OPTIMIZERS
install_image_optimizers ()
{
	sudo apt-get -y install optipng
	sudo apt-get -y install jpegoptim
}

# MYSQL
install_mysql()
{
	cd ${DOWNLOAD_PATH}

	sudo apt-get install -y debconf-utils

	sudo apt-key add ${PROVISION_PATH}/mysql_pubkey.asc
	echo "deb http://repo.mysql.com/apt/debian/ stretch mysql-5.7" | sudo tee /etc/apt/sources.list.d/mysql.list

	sudo apt-get -y update

	echo "mysql-community-server mysql-community-server/root-pass password ${DB_PASS}" | sudo debconf-set-selections
	echo "mysql-community-server mysql-community-server/re-root-pass password ${DB_PASS}" | sudo debconf-set-selections

	sudo DEBIAN_FRONTEND=noninteractive apt-get -y install mysql-server

	sudo sed -i "s/^bind-address\t.*/bind-address\t= 192.168.33.66/g" /etc/mysql/mysql.conf.d/mysqld.cnf

	sudo service mysql restart

	sudo mysql -u root -p${DB_PASS} -s -e "CREATE DATABASE ${DB_NAME};"
	sudo mysql -u root -p${DB_PASS} -s -e "CREATE USER '${DB_NAME}'@'%' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_NAME}'@'%' IDENTIFIED BY '${DB_PASS}' WITH GRANT OPTION;"
	sudo mysql -u root -p${DB_PASS} -s -e "CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}' WITH GRANT OPTION;"
}

# MONGODB
install_mongodb()
{
	cd ${DOWNLOAD_PATH}

	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
	echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list

	sudo apt-get -y update

	sudo apt-get install -y mongodb-org

	sudo mkdir -p /var/log/mongodb
	sudo chown -R mongodb:mongodb /var/log/mongodb

	sudo mkdir -p /var/lib/mongodb
	sudo chown -R mongodb:mongodb /var/lib/mongodb

	sudo cp ${PROVISION_PATH}/mongod.conf /etc/mongod.conf

	sudo systemctl enable mongod

	sudo service mongod start

	sudo sleep 5s

	sudo mongo admin --eval "db.createUser({user:'${DB_USER}',pwd:'${DB_PASS}',roles:[{role:'userAdminAnyDatabase',db:'admin'},'readWriteAnyDatabase']})"
	sudo mongo ${DB_NAME} --eval "db.createUser({user:'${DB_NAME}',pwd:'${DB_PASS}',roles:[{role:'dbOwner',db:'${DB_NAME}'},{role:'dbOwner',db:'${DB_TEST}'}]})"

	sed -i "s/authorization: disabled/authorization: enabled/g"  /etc/mongod.conf

	sudo service mongod restart
}

# GEARMAN
install_gearman()
{
	sudo apt-get install -y gearman-job-server
	sudo apt-get install -y gearman-tools

	sudo sed -i "s/^PARAMS.*/PARAMS= --log-file=\/var\/log\/gearman-job-server\/gearman.log/g" /etc/default/gearman-job-server

	sudo service gearman-job-server force-reload
}

# REDIS
install_redis()
{
	sudo apt-get install -y build-essential tcl8.5

	cd ${DOWNLOAD_PATH}

	sudo wget http://download.redis.io/releases/redis-5.0.2.tar.gz
	sudo tar xzf redis-5.0.2.tar.gz
	cd redis-5.0.2
	sudo make
	sudo make install

	cd utils
	echo "" | sudo ./install_server.sh

	sudo sed -i "s/^bind .*/bind ${GEARMAN_IP}/g" /etc/redis/6379.conf

	sudo service redis_6379 reload
	sudo service redis_6379 start
	sudo service redis_6379 restart
}

# SUPERVISOR
install_supervisor()
{
	sudo apt-get install -y supervisor
	sudo apt-get install -y htop

	declare -a programs=("badges" "badges-single" "curl" "emails" "emails-single"
		"images" "pdfs" "pdfs-single" "pushmessages" "pushmessages-single")

	for (( i=0; i<${#programs[@]}; i++ ));
	do
		PROGRAM=$(cat <<EOF
[program:${programs[$i]}-program]
command=php ${PROJECT_PATH}/workers/${programs[$i]}/worker.php
autostart=true
autorestart=true
stderr_logfile=${PROJECT_PATH}/logs/${programs[$i]}-err.log
stdout_logfile=${PROJECT_PATH}/logs/${programs[$i]}-out.log
EOF
)

		echo "${PROGRAM}" | sudo tee /etc/supervisor/conf.d/${programs[$i]}-program.conf
	done

	sudo supervisorctl update
}

# CRONTAB
set_crontab()
{
	CRONTAB=$(cat <<EOF
# m h  dom mon dow   command
* * * * *   php ${PROJECT_PATH}/workers/emails/client.php >> ${PROJECT_PATH}/logs/client-emails.log
* * * * *   php ${PROJECT_PATH}/workers/pushmessages/client.php >> ${PROJECT_PATH}/logs/client-pushmessages.log
EOF
)

	echo "${CRONTAB}" | sudo tee -a /var/spool/cron/crontabs/${SSH_USER}
}

# HOSTS
set_hosts()
{
	echo "127.0.0.1	localhost ${GEARMAN_HOST}" | sudo tee /etc/hosts
	echo "${EVENTSCASE_IP}	${EVENTSCASE_DOMAIN} ${EVENTSCASE_HOST}" | sudo tee -a /etc/hosts
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
