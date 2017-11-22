# Re-add proxy setting for PEAR if needed:
# pear config-set http_proxy $http_proxy


FROM centos:7
LABEL com.oxyure.vendor="United Microbiotas" \
      maintainer="stef@oxyure.com" \
      description="Centreon central server"

## Additional repositories & packages ##
COPY files/etc/yum.repos.d /etc

## Do not use 'fastestmirror' Yum plugin
RUN echo -e "[main]\nenabled=0" > /etc/yum/pluginconf.d/fastestmirror.conf &&\
    yum -y install epel-release &&\
    yum clean all &&\
    yum -y update &&\
    yum -y install binutils git make cmake glibc-devel rrdtool-devel qt-devel gnutls-devel \
                   httpd gd fontconfig-devel libjpeg-devel libpng-devel gd-devel perl-GD perl-DateTime \
                   openssl-devel perl-DBD-MySQL php php-mysql php-gd php-ldap php-xml php-mbstring \
                   perl-Config-IniFiles perl-DBI perl-DBD-MySQL perl-rrdtool perl-Crypt-DES perl-Digest-SHA1 \
                   perl-Digest-HMAC net-snmp-utils perl-Socket6 perl-IO-Socket-INET6 net-snmp net-snmp-libs php-snmp \
                   dmidecode perl-Net-SNMP net-snmp-perl fping cpp gcc gcc-c++ libstdc++ glib2-devel glibc-static \
                   php-pear nagios-plugins &&\
    pear channel-update pear.php.net &&\
    pear upgrade-all &&\
    yum clean all

## Build and install Tini
RUN cd /tmp &&\
    git clone https://github.com/krallin/tini.git &&\
    cd tini && cmake . && make && cp tini /sbin &&\
    cd /tmp && rm -rf tini

## Build and install Centreon
WORKDIR /tmp
RUN git clone https://github.com/centreon/centreon-clib.git &&\
    cd centreon-clib/build && cmake . && make -j3 && make install &&\
    cd /tmp && rm -rf centreon-clib

RUN git clone https://github.com/centreon/centreon-broker.git &&\
    cd centreon-broker && cd build && cmake . && make -j3 && make install &&\
    cd /tmp && rm -rf centreon-broker
    
RUN git clone https://github.com/centreon/centreon-engine.git &&\
    cd centreon-engine && cd build && cmake . && make -j3 && make install &&\
    cd /tmp && rm -rf centreon-engine

RUN git clone https://github.com/centreon/centreon.git &&\
    cd centreon

## Commented out until everything’s working! 
#### Uninstall some packages ##
##RUN yum -y erase git make cmake gcc gcc-c++ glibc-devel rrdtool-devel qt-devel gnutls-devel \
##                 glib2-devel glibc-devel glibc-static fontconfig-devel libjpeg-devel libpng-devel gd-devel \
##                 rrdtool-devel qt-devel gnutls-devel openssl-devel &&\
##    yum -y autoremove

#### Remove some files ##
##RUN rm -rf /var/cache/yum/* /tmp/* \
##           /etc/modprobe.d /etc/modules-load.d /etc/modules \
##           /etc/udhcpd.conf /etc/securetty /var/www/*

# Add some files
COPY files/etc/motd-centreon /etc/motd
RUN sed -i -e "s/{build_date}/$(date)/" \
           -e "s/{build_host}/$(uname -rs)/" /etc/motd

# /entrypoint may also be a symlink…
COPY entrypoints/centreon.entrypoint /entrypoint

## Files & perms
RUN chmod go-rwx /entrypoint

EXPOSE 80/tcp

WORKDIR /
USER root
ENTRYPOINT ["/sbin/tini","-v","--","/entrypoint"]
