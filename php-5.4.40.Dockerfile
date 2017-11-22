FROM alpine:3.6
LABEL com.oxyure.vendor="United Microbiotas" \
      maintainer="stef@oxyure.com" \
      description="PHP 5.4.40 (PHP-FPM)"

## Additional repositories & Common packages ##
RUN echo "@v2.6 http://dl-cdn.alpinelinux.org/alpine/v2.6/main" >> /etc/apk/repositories &&\
    apk update && apk add tini bind-tools

## PHP 5.4 (from Alpine 2.6) ## ## ## ## ##
RUN apk add php@v2.6 php-mysql@v2.6 php-fpm@v2.6

## PHP-FPM configuration
RUN mkdir /run/php-fpm /var/log/php-fpm && chown nobody:nobody /run/php-fpm /var/log/php-fpm &&\
    sed -i -e 's/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/' \
           -e 's/;pid = run\/php-fpm.pid/pid = \/run\/php-fpm\/php-fpm.pid/' \
           -e 's/error_log = \/var\/log\/php-fpm.log/error_log = \/var\/log\/php-fpm\/php-fpm.log/' \
           /etc/php/php-fpm.conf

## Clean the room ##
RUN rm -rf /var/cache/apk/* /tmp/* \
           /etc/modprobe.d /etc/modules-load.d /etc/modules \
           /etc/udhcpd.conf /etc/securetty

# Copy custom files
COPY files/* /
RUN sed -i -e "s/{build_date}/$(date)/" \
           -e "s/{build_host}/$(uname -rs)/" /etc/motd

# /entrypoint may also be a symlink…
COPY entrypoints/php.entrypoint /entrypoint

## Files & perms
RUN chmod +s /bin/busybox &&\
    chmod go-rwx /entrypoint

WORKDIR /
USER root
ENTRYPOINT ["/sbin/tini","-v","--","/entrypoint"]



