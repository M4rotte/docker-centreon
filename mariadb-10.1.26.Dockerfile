FROM alpine:3.6
LABEL com.oxyure.vendor="United Microbiotas" \
      maintainer="stef@oxyure.com" \
      description="MariaDB 10.1.26"

## Repositories & packages ##
RUN apk update && apk add tini bind-tools &&\
    apk add mariadb=10.1.26-r0 mariadb-client=10.1.26-r0

# Set Europe/Paris for timezone.
RUN apk add --no-cache tzdata &&\
    cp /usr/share/zoneinfo/Europe/Paris /etc/localtime &&\
    echo "Europe/Paris" > /etc/timezone &&\
    apk del --purge tzdata

## MariaDB configuration


## Clean the room ##
## Add some information in the MOTD file ##
RUN rm -rf /var/cache/apk/* /tmp/* \
           /etc/modprobe.d /etc/modules-load.d /etc/modules \
           /etc/udhcpd.conf /etc/securetty &&\
    sed -i -e "s/{build_date}/$(date)/" \
           -e "s/{build_host}/$(uname -rs)/" /etc/motd

# Entrypoint
COPY entrypoints/mariadb.entrypoint /entrypoint

# Files and perms
RUN chmod go-rwx /entrypoint

WORKDIR /
USER root
ENTRYPOINT ["/sbin/tini","-g","-v","--","/entrypoint"]
