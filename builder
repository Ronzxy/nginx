#!/bin/bash
#
# 作者：Skygangsta<skygangsta@hotmail.com>
#
# Nginx 编译脚本，仅支持 Debian 系 Linux 系统

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

WORK_HOME=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
BUILD_PATH=/usr
NGINX_VERSION=`grep "#define NGINX_VERSION" src/core/nginx.h | awk -F ' ' '{print $3}' | awk -F '"' '{print $2}'`
NGINX_VERSION_MINOR=`printf $NGINX_VERSION | awk -F '.' '{print $2}'`
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
    --with-cc-opt='-O0 -g3 -m64 -mtune=generic' \
    --with-ld-opt="-ljemalloc"

    # http 2.0 模块
    # --with-http_v2_module \
    # 使用多线程 1.7.1+
    # --with-threads \
    # --with-stream \
    # --with-cc-opt='-O2 -g -m64 -mtune=generic' \
    
    # -O0：这个等级（字母“O”后面跟个零）关闭所有优化选项，也是CFLAGS或CXXFLAGS中没有设置-O等级时的默认等级。这样就不会优化代码，这通常不是我们想要的。 
    # -O1：这是最基本的优化等级。编译器会在不花费太多编译时间的同时试图生成更快更小的代码。这些优化是非常基础的，但一般这些任务肯定能顺利完成。 
    # -O2：-O1的进阶。这是推荐的优化等级，除非你有特殊的需求。-O2会比-O1启用多一些标记。设置了-O2后，编译器会试图提高代码性能而不会增大体积和大量占用的编译时间。 
    # -O3：这是最高最危险的优化等级。用这个选项会延长编译代码的时间，并且在使用gcc4.x的系统里不应全局启用。自从3.x版本以来gcc的行为已经有了极大地改变。在3.x，-O3生成的代码也只是比-O2快一点点而已，而gcc4.x中还未必更快。用-O3来编译所有的软件包将产生更大体积更耗内存的二进制文件，大大增加编译失败的机会或不可预知的程序行为（包括错误）。这样做将得不偿失，记住过犹不及。在gcc 4.x.中使用-O3是不推荐的。 
    # -Os：这个等级用来优化代码尺寸。其中启用了-O2中不会增加磁盘空间占用的代码生成选项。这对于磁盘空间极其紧张或者CPU缓存较小的机器非常有用。但也可能产生些许问题，因此软件树中的大部分ebuild都过滤掉这个等级的优化。使用-Os是不推荐的。

    # -g1）不包含局部变量和与行号有关的调试信息，只能用于回溯跟踪和堆栈转储之用。
    # -g2）包括扩展的符号表、行号、局部或外部变量。
    # -g3）包含级别2中的调试信息和源代码中定义的宏。
    # [回溯跟踪指的是监视程序在运行过程中的函数调用历史，堆栈转储则是一种以原始的十六进制格式保存程序执行环境的方法，两者都是经常用到的调试手段。]
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

# 初始化运行环境
make_env() {
    mkdir -p ${WORK_HOME}/dist/nginx/logs ${WORK_HOME}/dist/nginx/cache
    
    # 去掉生产配置并打开调试
    sed -i -E "s/^user.*;$/# &/g" ${WORK_HOME}/dist/nginx/conf/nginx.conf > /dev/null 2>&1
    sed -i -E "s/^thread_pool.*;$/# &/g" ${WORK_HOME}/dist/nginx/conf/nginx.conf > /dev/null 2>&1
    sed -i -E "s/^\s*aio.*;$/# &/" `grep threads=default -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    
    sed -i -E "s/ reuseport//" `grep reuseport -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/etc\/nginx\///" `grep \/etc\/nginx -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/var\/cache\/nginx/cache/" `grep \/var\/cache\/nginx -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/var\/log\/nginx/logs/" `grep \/var\/log\/nginx -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/var\/run\/nginx.pid/cache\/nginx.pid/" `grep \/var\/run\/nginx.pid -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/var\/lock\/nginx.lock/cache\/nginx.lock/" `grep \/var\/lock\/nginx.lock -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/\/home\/www\///" `grep \/home\/www -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    
    sed -i -E "s/^worker_processes.*3;$/# &/" `grep worker_processes -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/^# daemon            off;$/daemon            off;/" `grep daemon -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/^# master_process    off;$/master_process    off;/" `grep master_process -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/^# worker_processes  1;$/worker_processes  1;/" `grep worker_processes -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    
    sed -i -E "s/^error_log  logs\/error_default.log warn;$/error_log  logs\/error_default.log debug;/" `grep debug_core -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    # sed -i -E "s/^# error_log  logs\/error_debug_core.log debug_core;$/error_log  logs\/error_debug_core.log debug_core;/" `grep debug_core -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    # sed -i -E "s/^# error_log  logs\/error_debug_alloc.log debug_alloc;$/error_log  logs\/error_debug_alloc.log debug_alloc;/" `grep debug_alloc -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    # sed -i -E "s/^# error_log  logs\/error_debug_mutex.log debug_mutex;$/error_log  logs\/error_debug_mutex.log debug_mutex;/" `grep debug_mutex -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    # sed -i -E "s/^# error_log  logs\/error_debug_event.log debug_event;$/error_log  logs\/error_debug_event.log debug_event;/" `grep debug_event -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    sed -i -E "s/^    # error_log  logs\/error_debug_http.log debug_http;$/    error_log  logs\/error_debug_http.log debug_http;/" `grep debug_http -rl ${WORK_HOME}/dist/nginx/conf` > /dev/null 2>&1
    
    ulimit -HSn 65535
}

run() {
    if [ ! -x "${WORK_HOME}/dist/nginx/sbin/nginx" ]; then
        install
    fi
    
    make_env
    
    echo "Starting debug nginx..."
    ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx
}

reload() {
    ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx -s reload
}

stop() {
    ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx -s stop
    # 如果关闭失败，强制杀死 nginx
    if [ -f ${WORK_HOME}/dist/nginx/cache/nginx.pid ]; then
        kill `head ${WORK_HOME}/dist/nginx/cache/nginx.pid`
    fi
}

clean() {
    if [ -f ${WORK_HOME}/dist/nginx/cache/nginx.pid ]; then
        stop
    fi    
    
    if [ -a "${WORK_HOME}/Makefile" ]; then
        make clean
    fi

    if [ -a "${WORK_HOME}/dist" ]; then
        rm -rf dist
    fi
}

debug() {
    if [ ! -f ${WORK_HOME}/dist/nginx/cache/nginx.pid ]; then
        echo "Error: Plase run nginx first!"
        exit 1
    fi
    
    dpkg -V cgdb || apt update apt install -y --force-yes cgdb
    
    cgdb -p `head ${WORK_HOME}/dist/nginx/cache/nginx.pid`
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
    make)
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
    debug)
        debug
        exit 0
    ;;
    *)
        echo $"Usage: {configure | build | install | clean}"
        exit 1
    ;;
esac
