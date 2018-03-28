#!/bin/bash
#
# 作者：Skygangsta<skygangsta@hotmail.com>
#
# Nginx 编译脚本，仅支持 Debian 系 Linux 系统

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

WORK_HOME=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
BUILD_PATH=/usr
# 探测cpu核心数
if [ -f /proc/cpuinfo ]; then
    j="-j$(grep 'model name' /proc/cpuinfo | wc -l || 1)"
fi

check_build_tools() {
    dpkg -V gcc g++ make patch || DPKG_RESULT=true

    if [ $DPKG_RESULT ]; then
        apt update

        # 安装编译工具
        apt install -y --force-yes gcc g++ make patch
    fi
}

check_install_deps() {
    dpkg -V libpcre3-dev zlib1g-dev libssl-dev libjemalloc-dev || DPKG_RESULT=true

    if [ $DPKG_RESULT ]; then
        apt update

        # 安装依赖
        apt install -y --force-yes libpcre3-dev zlib1g-dev libssl-dev libjemalloc-dev
    fi
}

configure() {
    if [ -f "${WORK_HOME}/Makefile" ]; then
        clean
    fi

    check_build_tools
    check_install_deps

    ./configure --prefix=$BUILD_PATH \
    --sbin-path=$BUILD_PATH/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/lock/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=www --group=www \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-file-aio \
    --with-cpp_test_module \
    --with-debug \
    --with-cc-opt='-O0 -g -m64 -mtune=generic' \
    --with-ld-opt="-ljemalloc"

    # http 2.0 模块
    # --with-http_v2_module \
    # 使用多线程
    # --with-threads \
    # --with-stream \
    # --with-cc-opt='-O2 -g -m64 -mtune=generic' \
}

build() {
    if [ ! -f "${WORK_HOME}/Makefile" ]; then
        configure
    fi

    make $j
}

install() {
    if [ ! -x "${WORK_HOME}/objs/nginx" ]; then
        build
    fi

    mkdir -p ${WORK_HOME}/dist/nginx/sbin
    cp objs/nginx ${WORK_HOME}/dist/nginx/sbin
    cp -r conf html ${WORK_HOME}/dist/nginx
}

run() {
    if [ ! -x "${WORK_HOME}/dist/nginx/sbin/nginx" ]; then
        install
    fi
    
    mkdir -p ${WORK_HOME}/dist/nginx/logs ${WORK_HOME}/dist/nginx/cache
    
    # 去掉生产配置并打开调试
    sed -i -E "s/^user.*;$/# user  www www;/g" ${WORK_HOME}/dist/nginx/conf/nginx.conf > /dev/null 2>&1
    sed -i -E "s/^thread_pool.*;$/# &/g" ${WORK_HOME}/dist/nginx/conf/nginx.conf > /dev/null 2>&1
    sed -i -E "s/^\s*aio.*;$/# &/" `grep threads=default -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/ reuseport//" `grep reuseport -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/etc\/nginx\///" `grep \/etc\/nginx -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/var\/cache\/nginx/cache/" `grep \/var\/cache\/nginx -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/var\/log\/nginx/logs/" `grep \/var\/log\/nginx -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/var\/run\/nginx.pid/cache\/nginx.pid/" `grep \/var\/run\/nginx.pid -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/home\/www\///" `grep \/home\/www -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    
    sed -i -E "s/^worker_processes  3;$/# worker_processes  3;/" `grep worker_processes -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/^# daemon            off;$/daemon            off;/" `grep daemon -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/^# master_process    off;$/master_process    off;/" `grep master_process -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/^# worker_processes  1;$/worker_processes  1;/" `grep worker_processes -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    
    ulimit -HSn 65535
    
    echo "Starting debug nginx..."
    ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx
}

reload() {
    ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx -s reload
}

stop() {
    ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx -s stop
}

clean() {
    if [ -a "${WORK_HOME}/Makefile" ]; then
        make clean
    fi

    if [ -a "${WORK_HOME}/dist" ]; then
        rm -rf dist
    fi
}

case "$1" in
    configure)
        configure
        exit 0
    ;;
    build)
        build
        exit 0
    ;;
    install)
        install
        exit 0
    ;;
    run)
        run
        exit 0
    ;;
    reload)
        reload
        exit 0
    ;;
    stop)
        stop
        exit 0
    ;;
    clean)
        clean
        exit 0
    ;;
    *)
        echo $"Usage: {configure | build | install | clean}"
        exit 1
    ;;
esac
