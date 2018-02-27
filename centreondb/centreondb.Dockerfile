FROM alpine:3.6
LABEL com.oxyure.vendor="United Microbiotas" \
      maintainer="stef@oxyure.com" \
      description="MariaDB 10.1.26"

## Repositories & packages ##
RUN apk update && apk add bind-tools &&\
    apk add mariadb=10.1.26-r0 mariadb-client=10.1.26-r0 \
            nrpe nagios-plugins-load

# Set Europe/Paris for timezone.
RUN apk add --no-cache tzdata &&\
    cp /usr/share/zoneinfo/Europe/Paris /etc/localtime &&\
    echo "Europe/Paris" > /etc/timezone &&\
    apk del --purge tzdata

## Configure NRPE server
RUN sed -i -e 's/allowed_hosts=127.0.0.1/allowed_hosts=127.0.0.1,centreon/' /etc/nrpe.cfg

## Configure MariaDB
COPY files/etc/mysql/my.cnf /etc/mysql/my.cnf

## Remove some files ##
## Add some information in the MOTD file ##
COPY files/etc/motd-centreondb /etc/motd
RUN rm -rf /var/cache/apk/* /tmp/* \
           /etc/modprobe.d /etc/modules-load.d /etc/modules \
           /etc/udhcpd.conf /etc/securetty &&\
    sed -i -e "s/{build_date}/$(date)/" \
           -e "s/{build_host}/$(uname -rs)/" /etc/motd

# Entrypoint
COPY centreondb.entrypoint /entrypoint

# Files and perms
RUN chmod go-rwx /entrypoint &&\
    chmod 0755 /etc/mysql/my.cnf

WORKDIR /
USER root
ENTRYPOINT ["/entrypoint"]
