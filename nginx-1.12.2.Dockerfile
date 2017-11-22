FROM alpine:3.6
LABEL com.oxyure.vendor="United Microbiotas" \
      maintainer="stef@oxyure.com" \
      description="Nginx 1.12.2"



## Additional repositories ##
RUN apk update && apk add tini bind-tools

## Nginx 1.12.2 ## ## ## ## ##
RUN apk add nginx=1.12.2-r0

# The alpine:3.6 image has root password disabled. We let the possibility to define one at build time.
# If the following root password build argument is empty, a (long) random string will be choosen to 
# still forbid normal users to su to root.
ARG ROOT_PASSWD=""
RUN if [ -z "${ROOT_PASSWD}" ]; then echo "root:$(echo $RANDOM |sha512sum |cut -d' ' -f1)" | chpasswd; \
        else echo "root:${ROOT_PASSWD}" | chpasswd; fi &&\
        apk update

######WORKDIR /tmp
######RUN git clone https://github.com/centreon/centreon-clib.git &&\
######    cd centreon-clib/build && cmake . && make -j3 && make install &&\
######    cd /tmp && rm -rf centreon-clib
######
######RUN git clone https://github.com/centreon/centreon-broker.git &&\
######    cd centreon-broker/build && cmake . && make -j3 && make install &&\
######    cd /tmp && rm -rf centreon-broker

## Clean the room ##
RUN rm -rf /var/cache/apk/* /tmp/* \
           /etc/modprobe.d /etc/modules-load.d /etc/modules \
           /etc/udhcpd.conf /etc/securetty /var/www/* /etc/nginx/fastcgi.conf

# Copy custom files
COPY files/* /

RUN sed -i -e "s/{build_date}/$(date)/" \
           -e "s/{build_host}/$(uname -rs)/" /etc/motd

# /entrypoint may also be a symlink…
COPY entrypoints/nginx.entrypoint /entrypoint

# Files & perms
RUN chmod +s /bin/busybox &&\
    chown root:nginx /var/log/nginx /var/www &&\
    chmod g+w /var/log/nginx /var/www &&\
    mkdir /run/nginx &&\
    chmod go-rwx /entrypoint

WORKDIR /var/www
USER root
ENTRYPOINT ["/sbin/tini","-v","--","/entrypoint"]






