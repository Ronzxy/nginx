#!/bin/bash
#
# 作者：Skygangsta<skygangsta@hotmail.com>
#
# Nginx 编译脚本，支持 Debian/Redhat 系 Linux 系统

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

WORK_HOME=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
BUILD_PATH=/usr
NGINX_VERSION=`grep "#define NGINX_VERSION" ${WORK_HOME}/src/core/nginx.h | awk -F ' ' '{print $3}' | awk -F '"' '{print $2}'`
NGINX_VERSION_MINOR=`printf $NGINX_VERSION | awk -F '.' '{print $2}'`
NGX_CONF_DIR=${WORK_HOME}/dist/nginx/conf
# 探测cpu核心数
if [ -f /proc/cpuinfo ]; then
    j="-j$(grep 'model name' /proc/cpuinfo | wc -l || 1)"
fi

check_build_tools() {
    # 安装编译工具
    if [ -f "/etc/debian_version" ]; then
        dpkg -V gcc g++ make patch cgdb || \
            apt update && \
            apt install -y gcc g++ make patch cgdb
    fi

    if [ -f "/etc/redhat-release" ]; then
        yum install -y gcc g++ make patch cgdb
    fi
}

check_install_deps() {
    # 安装依赖
    if [ -f "/etc/debian_version" ]; then
        dpkg -V libpcre3-dev zlib1g-dev libssl-dev libjemalloc-dev locales ||  
            apt update && \
            apt install -y libpcre3-dev zlib1g-dev libssl-dev libjemalloc-dev locales
    fi

    if [ -f "/etc/redhat-release" ]; then
        yum install -y libpcre3-devel zlib1g-devel libssl-devel libjemalloc-devel locales
    fi
}

configure() {
    if [ -f "${WORK_HOME}/Makefile" ]; then
        clean
    fi

    check_build_tools
    check_install_deps

    cd ${WORK_HOME} && ./configure --prefix=$BUILD_PATH \
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
    --user=nobody --group=nogroup \
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

    cp ${WORK_HOME}/debug.* ${WORK_HOME}/src/core

    sed -i "s/^CFLAGS.*$/& -finstrument-functions/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1
    sed -i "s/^CORE_DEPS.*$/&\n\tsrc\/core\/debug.h \\\/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1
    sed -i "s/^HTTP_DEPS.*$/&\n\tsrc\/core\/debug.h \\\/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1
    sed -i "s/^objs\/nginx:.*$/&\n\tobjs\/src\/core\/debug.o \\\/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1
    sed -i "s/^\t\$(LINK).*$/&\n\tobjs\/src\/core\/debug.o \\\/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1

    # 编译 debug.c
    sed -i "s/^objs\/src\/core\/nginx.o:.*$/objs\/src\/core\/debug.o: \$\(CORE_DEPS\) \\\\\n&/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1
    sed -i "s/^objs\/src\/core\/nginx.o:.*$/\tsrc\/core\/debug.c\\n&/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1
    sed -i "s/^objs\/src\/core\/nginx.o:.*$/\t\$\(CC\) -c \$\(CFLAGS\) \$\(CORE_INCS\) \\\\\n&/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1
    sed -i "s/^objs\/src\/core\/nginx.o:.*$/\t\t-o objs\/src\/core\/debug.o \\\\\n&/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1
    sed -i "s/^objs\/src\/core\/nginx.o:.*$/\t\tsrc\/core\/debug.c\\n\\n\\n&/g" ${WORK_HOME}/objs/Makefile > /dev/null 2>&1

    # 引用 debug.h 头文件
    grep "^[#]include <debug.h>$" ${WORK_HOME}/src/core/ngx_core.h > /dev/null 2>&1 || \
        sed -i "s/^[#]include <ngx_errno.h>$/#include <debug.h>\\n&/g" ${WORK_HOME}/src/core/ngx_core.h

    # 加入 DEBUG_MAIN 宏
    grep "^#define DEBUG_MAIN 1$" ${WORK_HOME}/src/core/nginx.c > /dev/null 2>&1 || \
        sed -i "s/^[#]include <ngx_config.h>$/#define DEBUG_MAIN 1\\n\\n\\n&/g" ${WORK_HOME}/src/core/nginx.c

    # main 函数加入 enable_debug()
    grep "enable_debug()" ${WORK_HOME}/src/core/nginx.c > /dev/null 2>&1 || \
        sed -i "/main(int argc, char \*const \*argv)/{n;s/{/&\\n    \/\/ Don't delete if you no longer use it please comment it\\n    enable_debug();\\n/g}" ${WORK_HOME}/src/core/nginx.c


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
    
    cp ${WORK_HOME}/debug.* ${WORK_HOME}/src/core

    make $j
}

install() {
    if [ ! -x "${WORK_HOME}/objs/nginx" ]; then
        build
    fi

    mkdir -p ${WORK_HOME}/dist/nginx/sbin
    cp objs/nginx ${WORK_HOME}/dist/nginx/sbin
    cp -r conf html ${WORK_HOME}/dist/nginx

    if [ -r /.dockerenv ]; then
        make install
        cp -r ${WORK_HOME}/conf/* /etc/nginx
        cp -r ${WORK_HOME}/html   /home/www
        mkdir -p /var/cache/nginx /var/log/nginx
    fi
}

# 初始化运行环境
make_env() {
    mkdir -p ${WORK_HOME}/dist/nginx/logs ${WORK_HOME}/dist/nginx/cache
    
    if [ -r /.dockerenv ]; then
        NGX_CONF_DIR="/etc/nginx"
    fi
    # 去掉生产配置并打开调试
    sed -i -E "s/^user.*;$/# &/g" ${NGX_CONF_DIR}/nginx.conf > /dev/null 2>&1
    sed -i -E "s/^thread_pool.*;$/# &/g" ${NGX_CONF_DIR}/nginx.conf > /dev/null 2>&1
    sed -i -E "s/^\s*aio.*;$/# &/" `grep threads=default -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    
    sed -i -E "s/ reuseport//" `grep reuseport -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/^worker_processes.*3;$/# &/" `grep worker_processes -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/^# daemon            off;$/daemon            off;/" `grep daemon -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/^# master_process    off;$/master_process    off;/" `grep master_process -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/^# worker_processes  1;$/worker_processes  1;/" `grep worker_processes -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    
    sed -i -E "s/^error_log  \/var\/log\/nginx\/error_default.log warn;$/error_log  \/var\/log\/nginx\/error_default.log debug;/" `grep debug_core -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    # sed -i -E "s/^# error_log  \/var\/log\/nginx\/error_debug_core.log debug_core;$/error_log  \/var\/log\/nginx\/error_debug_core.log debug_core;/" `grep debug_core -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    # sed -i -E "s/^# error_log  \/var\/log\/nginx\/error_debug_alloc.log debug_alloc;$/error_log  \/var\/log\/nginx\/error_debug_alloc.log debug_alloc;/" `grep debug_alloc -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    # sed -i -E "s/^# error_log  \/var\/log\/nginx\/error_debug_mutex.log debug_mutex;$/error_log  \/var\/log\/nginx\/error_debug_mutex.log debug_mutex;/" `grep debug_mutex -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    # sed -i -E "s/^# error_log  \/var\/log\/nginx\/error_debug_event.log debug_event;$/error_log  \/var\/log\/nginx\/error_debug_event.log debug_event;/" `grep debug_event -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/^    # error_log  \/var\/log\/nginx\/error_debug_http.log debug_http;$/    error_log  \/var\/log\/nginx\/error_debug_http.log debug_http;/" `grep debug_http -rl ${NGX_CONF_DIR}` > /dev/null 2>&1

    if [ ! -r /.dockerenv ]; then
        make_env_dir
    fi
    
    ulimit -HSn 65535
}

make_env_dir() {
    sed -i -E "s/\/etc\/nginx\///" `grep \/etc\/nginx -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/\/var\/cache\/nginx/cache/" `grep \/var\/cache\/nginx -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/\/var\/log\/nginx/logs/" `grep \/var\/log\/nginx -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/\/var\/run\/nginx.pid/cache\/nginx.pid/" `grep \/var\/run\/nginx.pid -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/\/var\/lock\/nginx.lock/cache\/nginx.lock/" `grep \/var\/lock\/nginx.lock -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
    sed -i -E "s/\/home\/www\///" `grep \/home\/www -rl ${NGX_CONF_DIR}` > /dev/null 2>&1
}

run() {
    if [ -x "${WORK_HOME}/dist/nginx/sbin/nginx" -o -x "/usr/sbin/nginx" ]; then
        make_env

        echo "Starting debug nginx..."
        if [ ! -r /.dockerenv ]; then
            ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx
        else
            /usr/sbin/nginx
        fi
    else
        install
    fi    
}

reload() {
    if [ ! -r /.dockerenv ]; then
        ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx -s reload
    else
        /usr/sbin/nginx -s reload
    fi
}

stop() {
    if [ ! -r /.dockerenv ]; then
        ${WORK_HOME}/dist/nginx/sbin/nginx -c ${WORK_HOME}/dist/nginx/conf/nginx.conf -p ${WORK_HOME}/dist/nginx -s stop
        # 如果关闭失败，强制杀死 nginx
        if [ -f ${WORK_HOME}/dist/nginx/cache/nginx.pid ]; then
            kill `head ${WORK_HOME}/dist/nginx/cache/nginx.pid`
        fi
    else
        /usr/sbin/nginx -s stop
        # 如果关闭失败，强制杀死 nginx
        if [ -f /var/run/nginx.pid ]; then
            kill /var/run/nginx.pid
        fi
    fi
}

clean() {
    if [ -f ${WORK_HOME}/dist/nginx/cache/nginx.pid -o -f /var/run/nginx.pid ]; then
        stop
    fi    
    
    if [ -a "${WORK_HOME}/Makefile" ]; then
        make clean > /dev/null 2>&1 || rm -rf ${WORK_HOME}/objs ${WORK_HOME}/Makefile
        rm -rf ${WORK_HOME}/src/core/debug.*
    fi

    if [ -d "${WORK_HOME}/dist" ]; then
        rm -rf "${WORK_HOME}/dist"
    fi

    if [ -r /.dockerenv ]; then
        rm -rf /etc/nginx/*
        cp -r ${WORK_HOME}/conf/* /etc/nginx
    fi
}

debug() {
    if [ -f ${WORK_HOME}/dist/nginx/cache/nginx.pid -o -f /var/run/nginx.pid ]; then 
        dpkg -V cgdb || apt update && apt install -y --force-yes cgdb
        
        if [ -f /var/run/nginx.pid ]; then
            cgdb -p `head /var/run/nginx.pid`
        else
            cgdb -p `head ${WORK_HOME}/dist/nginx/cache/nginx.pid`
        fi
    else
        echo "Error: Plase run nginx first!"
        exit 1
    fi
}

# 创建/启动 docker 容器
docker_env() {
    docker ps -a | grep build_nginx_${NGINX_VERSION} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        # 容器未创建
        if [ ${NGINX_VERSION_MINOR} -gt 2 ]; then
            # 大于 1.2 使用 debian 9: stretch 镜像
            docker run --name build_nginx_${NGINX_VERSION} \
                --publish 8080:8080/tcp \
                --volume=${WORK_HOME}:/data \
                --volume=${WORK_HOME}/docker/data/www:/home/www \
                --volume=${WORK_HOME}/docker/data/conf:/etc/nginx \
                --volume=${WORK_HOME}/docker/data/logs:/var/log/nginx \
                --volume=/usr/bin/docker:/usr/bin/docker \
                --volume=/var/run/docker.sock:/var/run/docker.sock \
                --cpu-shares=1024 --memory=512m --memory-swap=-1 \
                --oom-kill-disable=true \
                --restart=always \
                -t -i -d debian:stretch bash || exit 1
        else
            # 小于 1.2 使用 debian 8: jessie 镜像
            docker run --name build_nginx_${NGINX_VERSION} \
                --publish 8080:8080/tcp \
                --volume=${WORK_HOME}:/data \
                --volume=${WORK_HOME}/docker/data/www:/home/www \
                --volume=${WORK_HOME}/docker/data/conf:/etc/nginx \
                --volume=${WORK_HOME}/docker/data/logs:/var/log/nginx \
                --volume=/usr/bin/docker:/usr/bin/docker \
                --volume=/var/run/docker.sock:/var/run/docker.sock \
                --cpu-shares=1024 --memory=512m --memory-swap=-1 \
                --oom-kill-disable=true \
                --restart=always \
                -t -i -d debian:jessie bash || exit 1
        fi
    else
        docker ps | grep build_nginx_${NGINX_VERSION} > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            docker start build_nginx_${NGINX_VERSION} || exit 1
        fi
    fi
}

# 在 docker 容器中编译
build_in_docker() {
    if [ ${NGINX_VERSION_MINOR} -gt 2 ]; then
        # 大于 1.2 使用 debian 9: stretch 镜像
        echo "deb http://mirrors.163.com/debian/ stretch main" > /etc/apt/sources.list
        sed -i "s/^FROM debian:.*$/FROM debian:stretch/g" ${WORK_HOME}/Dockerfile
    else
        echo "deb http://mirrors.163.com/debian/ jessie main" > /etc/apt/sources.list
        sed -i "s/^FROM debian:.*$/FROM debian:jessie/g" ${WORK_HOME}/Dockerfile
    fi

    if [ ! -f /.dockerinit ]; then
        export LC_ALL=zh_CN.UTF-8
        printf "zh_CN.UTF-8 UTF-8\\nen_US.UTF-8 UTF-8\\n" >> /etc/locale.gen && locale-gen
        echo "export LANG=zh_CN.UTF-8" >> /etc/profile
        echo "export PATH=$PGHOME/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin" >> /etc/profile
        echo "Asia/Shanghai" >> /etc/timezone && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

        > /.dockerinit
    fi

    # 清理之前编译的数据
    clean
    # 编译 nginx
    install
}

# 构建 docker 镜像
docker_images() {
    build_in_docker

    # 检查 docker 依赖
    dpkg -V libltdl-dev || apt update && apt install -y libltdl-dev
    # 创建 nginx 镜像
    docker build -t nginx:$NGINX_VERSION $WORK_HOME
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
    docker)
        # 创建 nginx docker 构建容器
        docker_env

        docker exec -t -i build_nginx_${NGINX_VERSION} /data/builder build_in_docker

        exit 0
    ;;
    images)
        # 创建 nginx docker 镜像
        docker_env

        docker exec -t -i build_nginx_${NGINX_VERSION} /data/builder docker_images

        exit 0
    ;;
    docker_images)
        # 在 docker 构建容器中执行，创建 docker 镜像
        docker_images       
        
        exit 0
    ;;
    build_in_docker)
        # 在 docker 构建容器中执行，初始化 docker 容器
        build_in_docker

        exit 0
    ;;
    *)
        echo $"Usage: {configure | build | install | clean}"
        exit 1
    ;;
esac
