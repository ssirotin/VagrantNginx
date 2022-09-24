#! /bin/bash

set -e

export DBname="wp_mysitedb"
export DBuser="wpuser1"
export PassUser="samplepassword"
export PassRoot="12345678"
export Server_name="192.168.0.77" #ip указан для теста, в реальной среде будет доменное имя

sudo timedatectl set-timezone Europe/Moscow
sudo systemctl stop ufw
sudo systemctl disable ufw

sudo apt update && apt upgrade -y

sudo apt install --no-install-recommends -y nginx mariadb-server php php-fpm php-zip php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc 
sudo apt install -y dnsutils vim htop tree mc

sudo systemctl enable mariadb
sudo systemctl start mariadb
sudo systemctl enable nginx
sudo systemctl start nginx

cat << EOF | sudo mysql -u root -p$PassRoot
set password for 'root'@'localhost'=PASSWORD('$PassRoot');
exit
EOF

sudo systemctl restart mariadb

cat << EOF >| /etc/nginx/conf.d/website.conf
server {
    listen 80;
    listen 443;
    server_name $Server_name; #доменное имя сайта.
    set \$rootpath /var/www/ubuntu-wordpress.ru/; #указываем путь до корня сайта
    root \$rootpath; #определяем что корень сайта находится в переменной rootpath
    client_max_body_size 8M; #необходимо для установки некоторых модулей wordpress
access_log /var/log/nginx/ubuntu-wordpress.ru_access.log; #указываем пути до логов
error_log /var/log/nginx/ubuntu-wordpress.ru_error.log;
     location / {
    root \$rootpath;
    index index.html index.php index.htm;
    try_files \$uri \$uri/ @notfound;
             }

    location ~* \.(jpg|jpeg|gif|css|png|js|ico|html)$ { #настроим кеширование статических файлов для уменьшения расхода трафика и увеличения скорости работы сайта
             expires 180m;
    }

    location ~* \.php$ { #самый важный локейшн для сайта
    root \$rootpath;
    try_files \$uri = 404; #указываем что если не получилось найти файл - отдать ошибку
    fastcgi_split_path_info ^(.+\.php)(/.+)$; #необходимо для безопасности
    fastcgi_pass unix:/var/run/php74-ubuntu-wordpress.sock; #указываем путь к сокету или к порту пула php-fpm (это настроим позднее)
    fastcgi_index index.php; #несколько служебных параметров необходимых для корректной работы сайта
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
    }

    location @notfound {
    error_page 404 /4xx.html;
            return 404;
}
}
EOF

sudo mkdir -p /var/www/ubuntu-wordpress.ru/
sudo chown -R www-data:www-data /var/www/

sudo rm /etc/php/7.4/fpm/pool.d/www.conf

cat << EOF >| /etc/php/7.4/fpm/pool.d/ubuntu-wp.conf
[ubuntu-wp] ;указываем имя пула
listen = /var/run/php74-ubuntu-wordpress.sock ;указываем путь до сокета который указывали ранее

listen.allowed_clients = 127.0.0.1 ;безопасность, указываем кто может подключаться к пулу

listen.owner = www-data ;то же

listen.group = www-data ;то же

user = www-data ;от какого пользователя будет запущен пул и кто будет иметь доступ к исполнению скриптов. Следует разделять списки пользователей для разных сайтов.

group = www-data ;от какой группы пользователей будет запущен пул.

pm = dynamic ;балансирование нагрузки, режим динамический

pm.max_children = 50 ;сколько максимально воркеров может создать php-fpm

pm.start_servers = 5 ;стартовое количество воркеров

pm.min_spare_servers = 5 ; минимальное количество воркеров

pm.max_spare_servers = 35 ;

pm.status_path = /fpm-php-status ;статусная страница, нужна для мониторинга и оценки состояния, можно отключить.

php_admin_value[error_log] = /var/log/php-fpm/www-error.log ;указываем путь до логов ошибок

php_admin_flag[log_errors] = on

php_value[session.save_handler] = files ;тип файлов сессий, необходимо для их сохранения, авторизации и прочего функционала сайта

php_value[session.save_path] = /var/lib/php/session ;путь до файлов сессий
EOF

cat << EOF >| /var/www/ubuntu-wordpress.ru/index.php
<?php

phpinfo();

phpinfo(INFO_MODULES);

?>
EOF

sudo chmod +x  /var/www/ubuntu-wordpress.ru/index.php

cat << EOF | sudo mysql -u root -p$PassRoot
create database $DBname;
CREATE USER '$DBuser'@'localhost' IDENTIFIED BY '$PassUser';
GRANT ALL PRIVILEGES ON  $DBname. * TO '$DBuser'@'localhost';
FLUSH PRIVILEGES;
exit
EOF

sudo systemctl restart mariadb

cd /var/www/ubuntu-wordpress.ru/
sudo wget https://ru.wordpress.org/latest-ru_RU.tar.gz
sudo tar -xzvf latest-ru_RU.tar.gz
sudo cp -rp wordpress/* /var/www/ubuntu-wordpress.ru/
sudo chown -R www-data:www-data /var/www/ubuntu-wordpress.ru

sudo systemctl reload php7.4-fpm
sudo systemctl restart php7.4-fpm
sudo systemctl reload nginx
sudo systemctl restart nginx

exit $?