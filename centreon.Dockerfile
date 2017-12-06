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
                   php-pear nagios-plugins-all redhat-lsb-core sendmail mailx sudo perl net-snmp-perl perl-XML-LibXML \
                   perl-JSON perl-libwww-perl perl-XML-XPath perl-Net-Telnet perl-Net-DNS perl-DBI perl-DBD-MySQL perl-DBD-Pg \
                   perl-File-Find-Object perl-Pod-Parser which openssh-clients php-pear-DB php-pear-DB-DataObject \
                   php-pear-DB-DataObject-FormBuilder php-pear-MDB2 php-pear-Date php-pear-Auth-SASL php-pear-Validate \
                   php-pear-Log php-intl perl-Sys-Syslog qt-mysql &&\
    pear channel-update pear.php.net &&\
    pear upgrade-all &&\
    pear channel-update pear.php.net

## Build and install Tini ##
RUN cd /tmp &&\
    git clone https://github.com/krallin/tini.git &&\
    cd tini && cmake . && make && cp tini /sbin &&\
    cd /tmp && rm -rf tini

## Build and install CLib, Broker & Engine. Get Centreon and plugins. ##
WORKDIR /usr/local/src
RUN git clone https://github.com/centreon/centreon-clib.git &&\
    cd centreon-clib/build && cmake . && make -j3 && make install &&\
    cd /usr/local/src && rm -rf centreon-clib &&\
    git clone https://github.com/centreon/centreon-broker.git &&\
    cd centreon-broker && cd build && cmake . && make -j3 && make install &&\
    cd /usr/local/src && rm -rf centreon-broker &&\
    git clone https://github.com/centreon/centreon-engine.git &&\
    cd centreon-engine && cd build && cmake . && make -j3 && make install &&\
    cd /usr/local/src && rm -rf centreon-engine &&\
    git clone https://github.com/centreon/centreon.git &&\
    git clone https://github.com/centreon/centreon-plugins.git

## Create directories and set permissions
RUN adduser -d /var/lib/centreon-engine -s /bin/bash -r centreon-engine &&\
    adduser -d /var/spool/centreon-broker -s /bin/bash -r centreon-broker &&\
    adduser -d /var/spool/centreon -s /bin/bash -r centreon &&\
    usermod -a -G centreon apache &&\
    mkdir /var/log/centreon-engine && chown centreon-engine:centreon-engine /var/log/centreon-engine &&\
    mkdir /var/log/centreon-broker && chown centreon-broker:centreon-broker /var/log/centreon-broker &&\
    mkdir /var/log/centreon && chown centreon:centreon /var/log/centreon &&\
    mkdir /etc/centreon && chown centreon:centreon /etc/centreon &&\
    mkdir /etc/centreon-engine && chown centreon-engine:centreon /etc/centreon-engine &&\
    mkdir /etc/centreon-broker && chown centreon-broker:centreon /etc/centreon-broker &&\
    mkdir -p /usr/local/lib/centreon/plugins && chown centreon-engine:centreon /usr/local/lib/centreon/plugins &&\
    mkdir -p /usr/local/lib/nagios/plugins && chown centreon-engine:centreon /usr/local/lib/nagios/plugins &&\
    mkdir /var/lib/centreon-broker && chown centreon-broker:centreon-broker /var/lib/centreon-broker &&\
    mkdir /var/lib/centreon-engine && chown centreon-engine:centreon-engine /var/lib/centreon-engine &&\
    mkdir /var/lib/centreon && chown centreon:centreon /var/lib/centreon &&\
    mkdir /usr/share/centreon && chown centreon:centreon /usr/share/centreon &&\
    mkdir /usr/local/nagios && chown centreon-engine:centreon /usr/local/nagios &&\
    mkdir /tmp/centreon-setup

## Centreon : Install plugins ##
RUN cd /usr/local/src &&\
    cp -a centreon-plugins/* /usr/local/lib/centreon/plugins &&\
    chown -R centreon-engine:centreon /usr/local/lib/centreon/plugins /usr/local/var

## Default basic Apache configuration
RUN sed -i -e 's/#ServerName www\.example\.com:80/ServerName '"${SERVER_HOSTNAME}"':80/' /etc/httpd/conf/httpd.conf &&\
    chown -R apache:apache /var/www &&\
    chmod -R u+rwx /var/www &&\
    chmod -R o-rwx /var/www
## END Apache configuration

## Configure Centreon ##
COPY files/root/centreon-template /root
RUN touch /etc/sudoers.d/centreon
RUN cd /usr/local/src/centreon && ./install.sh -v -i -f /root/centreon-template
COPY files/etc/centreon/conf.pm /etc/centreon/conf.pm
COPY files/etc/centreon-broker /etc/centreon-broker

RUN cp -a /usr/local/etc/centengine.cfg /etc/centreon-engine &&\
    cp -a /usr/local/etc/objects/* /etc/centreon-engine


## More configuration ##
RUN echo '/usr/local/lib' >> /etc/ld.so.conf && ldconfig


## Uninstall some packages ##
RUN yum -y erase git cmake gcc gcc-c++ glibc-devel rrdtool-devel qt-devel gnutls-devel openssl-devel \
                 glib2-devel glibc-devel glibc-static fontconfig-devel libjpeg-devel libpng-devel gd-devel &&\
    yum clean all

## Clean the room ##
## Add some information in the MOTD file ##
COPY files/etc/motd-centreon /etc/motd
RUN rm -rf /var/cache/yum/* /tmp/* \
           /etc/modprobe.d /etc/modules-load.d /etc/modules \
           /etc/udhcpd.conf /etc/securetty &&\
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
