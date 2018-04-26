# debian 8: jessie
# debian 9: stretch
FROM debian:jessie

RUN echo "deb http://mirrors.163.com/debian/ jessie main" > /etc/apt/sources.list
#RUN echo "deb-src http://mirrors.163.com/debian/ stretch main" >> /etc/apt/sources.list

# 安装依赖包
RUN apt-get update && \
    apt-get install -y libpcre3 zlib1g openssl libjemalloc1 locales && \
    apt-get upgrade -y && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# 配置系统环境
RUN export LC_ALL=zh_CN.UTF-8
RUN printf "zh_CN.UTF-8 UTF-8\\nen_US.UTF-8 UTF-8\\n" >> /etc/locale.gen && locale-gen
RUN echo "export LANG=zh_CN.UTF-8" >> /etc/profile
RUN echo "export PATH=$PGHOME/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin" >> /etc/profile
RUN echo "Asia/Shanghai" >> /etc/timezone && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 添加用户
RUN groupadd -r -g 1201 www && \
    useradd -r -u 1201 -g www www -m -d /home/www -s /sbin/nologin

WORKDIR /

# 复制数据
COPY dist/nginx /nginx
COPY startup.sh /

RUN chmod 755 /startup.sh

EXPOSE 80 443

CMD ["./startup.sh"]
