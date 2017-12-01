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
    yum -y update &&\
    yum -y install binutils git make cmake glibc-devel rrdtool-devel qt-devel gnutls-devel \
                   httpd gd fontconfig-devel libjpeg-devel libpng-devel gd-devel perl-GD perl-DateTime \
                   openssl-devel perl-DBD-MySQL php php-mysql php-gd php-ldap php-xml php-mbstring \
                   perl-Config-IniFiles perl-DBI perl-DBD-MySQL perl-rrdtool perl-Crypt-DES perl-Digest-SHA1 \
                   perl-Digest-HMAC net-snmp-utils perl-Socket6 perl-IO-Socket-INET6 net-snmp net-snmp-libs php-snmp \
                   dmidecode perl-Net-SNMP net-snmp-perl fping cpp gcc gcc-c++ libstdc++ glib2-devel glibc-static \
                   php-pear nagios-plugins redhat-lsb-core sendmail mailx sudo perl net-snmp-perl perl-XML-LibXML \
                   perl-JSON perl-libwww-perl perl-XML-XPath perl-Net-Telnet perl-Net-DNS perl-DBI perl-DBD-MySQL perl-DBD-Pg \
                   perl-File-Find-Object perl-Pod-Parser which openssh-clients php-pear-DB php-pear-DB-DataObject \
                   php-pear-DB-DataObject-FormBuilder php-pear-MDB2 php-pear-Date php-pear-Auth-SASL php-pear-Validate \
                   php-pear-Log php-intl perl-Sys-Syslog qt-mysql &&\
    pear channel-update pear.php.net &&\
    pear upgrade-all &&\
    pear channel-update pear.php.net &&\
    yum clean all

## Build and install Tini ##
RUN cd /tmp &&\
    git clone https://github.com/krallin/tini.git &&\
    cd tini && cmake . && make && cp tini /sbin &&\
    cd /tmp && rm -rf tini

## Do the configuration which is usually done by the install.sh Centreon script
RUN adduser -d /var/lib/centreon-engine -s /bin/bash -r centreon-engine &&\
    adduser -d /var/spool/centreon-broker -s /bin/bash -r centreon-broker &&\
    adduser -d /var/spool/centreon -s /bin/bash -r centreon &&\
    mkdir /var/log/centreon-engine && chown centreon-engine:centreon-engine /var/log/centreon-engine &&\
    mkdir /var/log/centreon-broker && chown centreon-broker:centreon-broker /var/log/centreon-broker &&\
    mkdir /etc/centreon-engine && chown centreon-engine:centreon-engine /etc/centreon-engine &&\
    mkdir /etc/centreon-broker && chown centreon-broker:centreon-broker /etc/centreon-broker &&\
    mkdir /usr/local/centreon && chown centreon:centreon /usr/local/centreon &&\
    mkdir -p /usr/local/lib/centreon/plugins && chown centreon-engine:centreon /usr/local/lib/centreon/plugins &&\
    mkdir /var/lib/centreon-broker && chown centreon-broker:centreon-broker /var/lib/centreon-broker &&\



## Build and install Centreon ##
WORKDIR /tmp
RUN git clone https://github.com/centreon/centreon-clib.git &&\
    cd centreon-clib/build && cmake . && make -j3 && make install &&\
    cd /tmp && rm -rf centreon-clib &&\
    git clone https://github.com/centreon/centreon-broker.git &&\
    cd centreon-broker && cd build && cmake . && make -j3 && make install &&\
    cd /tmp && rm -rf centreon-broker &&\
    git clone https://github.com/centreon/centreon-engine.git &&\
    cd centreon-engine && cd build && cmake . && make -j3 && make install &&\
    cd /usr/local/src &&\
    git clone https://github.com/centreon/centreon.git &&\
    git clone https://github.com/centreon/centreon-plugins.git &&\
    cd centreon-plugins && cp -a . /usr/local/lib/centreon/plugins
    
    
######## Uninstall some packages ##
######RUN yum -y erase git make cmake gcc gcc-c++ glibc-devel rrdtool-devel qt-devel gnutls-devel \
######                 glib2-devel glibc-devel glibc-static fontconfig-devel libjpeg-devel libpng-devel gd-devel \
######                 rrdtool-devel qt-devel gnutls-devel openssl-devel &&\
######    yum -y autoremove

## Clean the room ##
## Add some information in the MOTD file ##
COPY files/etc/motd-centreon /etc/motd
RUN rm -rf /var/cache/yum/* /tmp/* \
           /etc/modprobe.d /etc/modules-load.d /etc/modules \
           /etc/udhcpd.conf /etc/securetty /var/www/* &&\
    sed -i -e "s/{build_date}/$(date)/" \
           -e "s/{build_host}/$(uname -rs)/" /etc/motd

# Entrypoint
COPY entrypoints/centreon.entrypoint /entrypoint

## Files & perms
RUN chmod go-rwx /entrypoint

EXPOSE 80/tcp

WORKDIR /
USER root
ENTRYPOINT ["/sbin/tini","-v","--","/entrypoint"]
