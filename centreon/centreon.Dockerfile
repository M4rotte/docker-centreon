# Re-add proxy setting for PEAR if needed:
# pear config-set http_proxy $http_proxy

FROM centos:7
LABEL com.oxyure.vendor="United Microbiotas" \
      maintainer="stef@oxyure.com" \
      description="Centreon central server"

ARG CENTREON_CLIB_VERSION
ARG CENTREON_ENGINE_VERSION
ARG CENTREON_BROKER_VERSION
ARG CENTREON_CONNECTORS_VERSION
ARG CENTREON_CENTREON_VERSION
ARG CENTREON_TIMEZONE


## Additional repositories & packages ##
COPY files/etc/yum.repos.d /etc

## Do not use 'fastestmirror' Yum plugin
RUN echo -e "[main]\nenabled=0" > /etc/yum/pluginconf.d/fastestmirror.conf &&\
    yum -y install epel-release &&\
    yum -y update &&\
    yum -y install binutils git make cmake glibc-devel rrdtool-devel qt-devel gnutls-devel perl-ExtUtils-Embed \
                   httpd gd fontconfig-devel libjpeg-devel libpng-devel gd-devel perl-GD perl-DateTime perl-Sys-Syslog \
                   openssl-devel perl-DBD-MySQL php php-mysql php-gd php-ldap php-xml php-mbstring \
                   perl-Config-IniFiles perl-DBI perl-JSON-XS perl-DBD-MySQL perl-rrdtool perl-Crypt-DES perl-Digest-SHA1 \
                   perl-Digest-HMAC net-snmp-utils perl-Socket6 perl-IO-Socket-INET6 net-snmp net-snmp-libs php-snmp \
                   dmidecode perl-Net-SNMP net-snmp-perl fping cpp gcc gcc-c++ libstdc++ glib2-devel glibc-static \
                   php-pear nagios-plugins-all redhat-lsb-core sendmail mailx sudo perl net-snmp-perl perl-XML-LibXML \
                   perl-JSON perl-libwww-perl perl-XML-XPath perl-Net-Telnet perl-Net-DNS perl-DBI perl-DBD-MySQL perl-DBD-Pg \
                   perl-File-Find-Object perl-Pod-Parser which openssh-clients php-pear-DB php-pear-DB-DataObject \
                   qt-mysql tzdata libssh2-devel libgcrypt-devel php-intl perl-libintl

## Create directories and set permissions
RUN mkdir /centreon &&\
    adduser -d /centreon -s /bin/bash -r centreon-engine &&\
    adduser -d /centreon -s /bin/bash -r centreon-broker &&\
    adduser -d /centreon -s /bin/bash -r centreon &&\
    chown centreon:centreon /centreon &&\
    usermod -a -G centreon apache &&\
    usermod -a -G centreon centreon-engine &&\
    usermod -a -G centreon centreon-broker &&\
    mkdir /var/lib/centreon-broker && chown centreon-broker:centreon-broker /var/lib/centreon-broker &&\
    mkdir -p /var/lib/centreon-engine/rw && chown -R centreon-engine:centreon /var/lib/centreon-engine &&\
    mkdir -p /var/lib/centreon/metrics /var/lib/centreon/status && chown -R centreon:centreon /var/lib/centreon &&\
    mkdir /var/log/centreon-engine && chown centreon-engine:centreon-engine /var/log/centreon-engine &&\
    mkdir /var/log/centreon-broker && chown centreon-broker:centreon /var/log/centreon-broker && chmod g+rwx /var/log/centreon-broker &&\
    mkdir /var/log/centreon && chown centreon:centreon /var/log/centreon &&\
    mkdir /etc/centreon && chown centreon:centreon /etc/centreon &&\
    mkdir /etc/centreon-engine && chown centreon-engine:centreon /etc/centreon-engine &&\
    mkdir /etc/centreon-broker && chown centreon-broker:centreon /etc/centreon-broker &&\
    mkdir /tmp/centreon-setup && chown centreon:centreon /tmp/centreon-setup && chmod g+rwx /tmp/centreon-setup

## Build and install CLib, Broker, Engine, Connectors, Centreon, Plugins ##
WORKDIR /usr/local/src

RUN git clone https://github.com/centreon/centreon-clib.git &&\
    cd centreon-clib && git checkout $CENTREON_CLIB_VERSION && cd build &&\
    cmake -DCMAKE_INSTALL_PREFIX=/centreon . && make -j3 && make install &&\
    cd /usr/local/src &&\
    git clone https://github.com/centreon/centreon-broker.git &&\
    cd centreon-broker && git checkout $CENTREON_BROKER_VERSION && cd build &&\ 
    cmake -DCMAKE_INSTALL_PREFIX=/centreon . && make -j3 && make install &&\
    cd /usr/local/src &&\
    git clone https://github.com/centreon/centreon-engine.git &&\
    cd centreon-engine && git checkout $CENTREON_ENGINE_VERSION && cd build &&\
    cmake -DCMAKE_INSTALL_PREFIX=/centreon . && make -j3 && make install &&\
    cd /usr/local/src &&\
    git clone https://github.com/centreon/centreon-connectors.git &&\
    cd centreon-connectors && git checkout $CENTREON_CONNECTORS_VERSION &&\
    cd ssh/build && cmake -DCMAKE_INSTALL_PREFIX=/centreon . && make -j3 && make install &&\
    cd ../../perl/build && cmake -DCMAKE_INSTALL_PREFIX=/centreon . && make -j3 && make install &&\
    cd /usr/local/src &&\
    git clone https://github.com/centreon/centreon.git &&\
    cd centreon && git checkout $CENTREON_CENTREON_VERSION &&\
    cd .. &&\
    git clone https://github.com/centreon/centreon-plugins.git

## Centreon : Install plugins ##
RUN cd /usr/local/src && mkdir /centreon/plugins &&\
    cp -a centreon-plugins/* /centreon/plugins &&\
    chown -R centreon-engine:centreon /centreon/plugins &&\
    chown -R centreon-engine:centreon /usr/lib64/nagios/plugins &&\
    chmod -R g+rx /centreon/plugins /usr/lib64/nagios/plugins &&\
    chown root:root /usr/lib64/nagios/plugins/check_icmp &&\
    chmod ug+s /usr/lib64/nagios/plugins/check_icmp &&\
    chmod o+rx /usr/lib64/nagios/plugins/check_icmp

## Default basic Apache configuration
RUN sed -i -e 's/#ServerName www\.example\.com:80/ServerName '"${SERVER_HOSTNAME}"':80/' /etc/httpd/conf/httpd.conf &&\
    chown -R apache:apache /var/www &&\
    chmod -R u+rwx /var/www &&\
    chmod -R o-rwx /var/www
## END Apache configuration

## Configure Centreon ##
## Most of the configuration is done by the Centreon setup script.
## We also set a working configuration for engine, broker and centcore.
## So the processes can start even if Centreon is not yet configured.
COPY files/root/centreon-template /root
RUN touch /etc/sudoers.d/centreon &&\
    cd /usr/local/src/centreon &&\
    ./install.sh -v -i -f /root/centreon-template

COPY files/etc/centreon/conf.pm /etc/centreon/conf.pm
COPY files/etc/centreon-broker /etc/centreon-broker
COPY files/etc/centreon-engine/* /etc/centreon-engine/
COPY files/etc/init.d/centengine /etc/init.d/centengine

## More configuration ##
RUN echo '/centreon/lib' >> /etc/ld.so.conf && ldconfig &&\
    cp -a /centreon/examples/centreon.sudo /etc/sudoers.d/centreon && chmod 0440 /etc/sudoers.d/centreon &&\
    chown -R centreon-engine:centreon /etc/centreon-engine && chmod -R g+rw /etc/centreon-engine &&\
    chown -R centreon-broker:centreon /etc/centreon-broker && chmod -R g+rw /etc/centreon-broker &&\
    chown -R centreon:centreon /etc/centreon && chmod -R g+rw /etc/centreon-broker &&\
    chown -R centreon:centreon /centreon && chmod -R g+rx /centreon && chmod -R g+w /centreon/www

# Set Europe/Paris for timezone.
RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime &&\
    echo "$CENTREON_TIMEZONE" > /etc/timezone

## Uninstall some packages ##
RUN yum -y erase git cmake gcc gcc-c++ glibc-devel rrdtool-devel qt-devel gnutls-devel openssl-devel \
                 glib2-devel glibc-devel glibc-static fontconfig-devel libjpeg-devel libpng-devel gd-devel &&\
    yum clean all

## Remove some files ##
## Add some information in the MOTD file ##
COPY files/etc/motd-centreon /etc/motd
RUN rm -rf /var/cache/yum/* \
           /etc/modprobe.d /etc/modules-load.d /etc/modules \
           /etc/udhcpd.conf /etc/securetty &&\
    sed -i -e "s/{build_date}/$(date)/" \
           -e "s/{build_host}/$(uname -rs)/" /etc/motd

# Entrypoint
COPY centreon.entrypoint /entrypoint

## Files & perms
RUN chmod go-rwx /entrypoint

EXPOSE 80/tcp

WORKDIR /
USER root
ENTRYPOINT ["/entrypoint"]
