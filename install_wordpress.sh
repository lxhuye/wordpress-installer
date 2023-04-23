#!/bin/bash

echo "正在更新 Ubuntu 系统..."
sudo apt-get update
sudo apt-get upgrade
echo "Ubuntu 系统更新完成。"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "请输入您的域名："
read domain_name
echo "请输入您的数据库名："
read db_name
echo "请输入您的数据库用户名："
read db_user
echo "请输入您的数据库用户密码："
read db_password

echo "开始安装必要的软件包..."
sudo apt update
sudo apt install -y nginx php-fpm php-mysql mysql-server

echo "安装和配置Nginx..."
sudo apt update
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

if ! [ -d "/etc/nginx/sites-available" ]
then 
  sudo mkdir /etc/nginx/sites-available
fi
if ! [ -d "/etc/nginx/sites-enabled" ]
then 
  sudo mkdir /etc/nginx/sites-enabled
fi

sudo bash -c "cat > /etc/nginx/sites-available/$domain_name.conf <<EOL
server {
  listen 80;
  client_max_body_size 200m;
  root /var/www/$domain_name;
  index index.php;
  server_name $domain_name;
  location / {
    try_files \$uri \$uri/ /index.php?\$args;
  }
  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_pass unix:/var/run/php/php$(php -v | grep -oP '\d+\.\d+' | head -1)-fpm.sock;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
  }
}
EOL"

sudo ln -s /etc/nginx/sites-available/$domain_name.conf /etc/nginx/sites-enabled/
sudo systemctl reload nginx

echo "下载WordPress并将其解压缩..."
cd /tmp
if [ $(df /tmp --output=avail | tail -1) -lt 1000000 ]
  then echo "Insufficient disk space in /tmp"
  exit
fi
wget https://wordpress.org/latest.tar.gz
tar -zxvf latest.tar.gz
sudo mv wordpress /var/www/$domain_name/

echo "编辑wp-config-sample.php 文件..."
if [ -f "/var/www/$domain_name/wp-config.php" ]
  then echo "File wp-config.php already exists"
  exit
fi
cd /var/www/$domain_name/
cp wp-config-sample.php wp-config.php
sudo sed -i "s/database_name_here/$db_name/g" wp-config.php
sudo sed -i "s/username_here/$db_user/g" wp-config.php
sudo sed -i "s/password_here/$db_password/g" wp-config.php
sudo sed -i "s/localhost/localhost/g" wp-config.php

echo "设置文件夹权限..."
sudo chown -R www-data:www-data /var/www/$domain_name
sudo find /var/www/$domain_name/ -type d -exec chmod 755 {} \;
sudo find /var/www/$domain_name/ -type f -exec chmod 644 {} \;

echo "修改php.ini 的上传限制..."
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 200M/" /etc/php/7.4/fpm/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 200M/" /etc/php/7.4/fpm/php.ini
sudo systemctl restart php7.4-fpm

echo "开启服务器80 

echo "开启服务器80 443 端口..."
sudo ufw enable
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo systemctl restart nginx

echo "安装完成！"
