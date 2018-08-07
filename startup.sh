#!/bin/bash

if [ ! -f "/usr/sbin/nginx" ]; then
    cp /nginx/sbin/nginx /usr/sbin
fi

if [ ! -f "/etc/nginx/nginx.conf" ]; then
    if [ ! -d "/etc/nginx" ]; then
        mkdir -p /etc/nginx
    else
        rm -rf /etc/nginx/*
    fi

    cp -r /nginx/conf/* /etc/nginx
fi

if [ ! -d "/usr/html" ]; then
    cp -r /nginx/html /home/www/html
fi

# 创建目录及修改权限
mkdir -p /var/cache/nginx /var/log/nginx
chown -R www:www /var/cache/nginx /var/log/nginx

/usr/sbin/nginx -g "daemon off;"
