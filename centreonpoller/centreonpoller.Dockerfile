# Re-add proxy setting for PEAR if needed:
# pear config-set http_proxy $http_proxy

FROM centos:7
LABEL com.oxyure.vendor="United Microbiotas" \
      maintainer="stef@oxyure.com" \
      description="Centreon poller server"

ARG CENTREON_CLIB_VERSION
ARG CENTREON_ENGINE_VERSION
ARG CENTREON_BROKER_VERSION
ARG CENTREON_CONNECTORS_VERSION
ARG CENTREON_TIMEZONE


## Additional repositories & packages ##
COPY files/etc/yum.repos.d /etc

## Do not use 'fastestmirror' Yum plugin
RUN echo -e "[main]\nenabled=0" > /etc/yum/pluginconf.d/fastestmirror.conf &&\
    yum -y --noplugins install epel-release &&\
    yum -y --noplugins update &&\
    yum -y --noplugins install binutils git make cmake glibc-devel rrdtool-devel qt-devel gnutls-devel perl-ExtUtils-Embed nrpe net-tools \
                       gd fontconfig-devel libjpeg-devel libpng-devel gd-devel perl-GD perl-DateTime perl-Sys-Syslog \
                       openssl-devel perl-DBD-MySQL \
                       perl-Config-IniFiles perl-DBI perl-JSON-XS perl-DBD-MySQL perl-rrdtool perl-Crypt-DES perl-Digest-SHA1 \
                       perl-Digest-HMAC net-snmp-utils perl-Socket6 perl-IO-Socket-INET6 net-snmp net-snmp-libs php-snmp \
                       dmidecode perl-Net-SNMP net-snmp-perl fping cpp gcc gcc-c++ libstdc++ glib2-devel glibc-static \
                       php-pear nagios-plugins-all nagios-plugins-nrpe redhat-lsb-core sendmail mailx sudo perl net-snmp-perl perl-XML-LibXML \
                       perl-JSON perl-libwww-perl perl-XML-XPath perl-Net-Telnet perl-Net-DNS perl-DBI perl-DBD-MySQL perl-DBD-Pg \
                       perl-File-Find-Object perl-Pod-Parser which openssh-clients \
                       qt-mysql tzdata libssh2-devel libgcrypt-devel perl-libintl

## Create directories and set permissions
RUN mkdir /centreon &&\
    mkdir /var/lib/centreon-broker &&\
    mkdir -p /var/lib/centreon-engine/rw /var/lib/centreon/metrics /var/lib/centreon/status &&\
    adduser -d /var/lib/centreon-engine -s /bin/bash -r centreon-engine &&\
    adduser -d /var/lib/centreon-broker -s /bin/bash -r centreon-broker &&\
    adduser -d /var/lib/centreon -s /bin/bash -r centreon &&\
    chown -R centreon:centreon /centreon /var/lib/centreon &&\
    usermod -a -G centreon centreon-engine &&\
    usermod -a -G centreon centreon-broker &&\
    chown centreon-broker:centreon-broker /var/lib/centreon-broker &&\
    chown -R centreon-engine:centreon /var/lib/centreon-engine &&\
    chown -R centreon:centreon /var/lib/centreon &&\
    mkdir /var/log/centreon-engine && chown centreon-engine:centreon-engine /var/log/centreon-engine &&\
    mkdir /var/log/centreon-broker && chown centreon-broker:centreon /var/log/centreon-broker && chmod g+rwx /var/log/centreon-broker &&\
    mkdir /var/log/centreon && chown centreon:centreon /var/log/centreon &&\
    mkdir /etc/centreon && chown centreon:centreon /etc/centreon &&\
    mkdir /etc/centreon-engine && chown centreon-engine:centreon /etc/centreon-engine &&\
    mkdir /etc/centreon-broker && chown centreon-broker:centreon /etc/centreon-broker


## Build and install CLib, Broker, Engine, Connectors, Plugins ##
WORKDIR /usr/local/src

RUN git clone https://github.com/centreon/centreon-clib.git &&\
    cd centreon-clib && git checkout $CENTREON_CLIB_VERSION && cd build &&\
    cmake -DCMAKE_INSTALL_PREFIX=/centreon -DWITH_PACKAGE_RPM=yes . &&\
    make -j3 && make install &&\
    cd /usr/local/src &&\
    git clone https://github.com/centreon/centreon-broker.git &&\
    cd centreon-broker && git checkout $CENTREON_BROKER_VERSION && cd build &&\ 
    cmake -DCMAKE_INSTALL_PREFIX=/centreon -DWITH_PACKAGE_RPM=yes . &&\
    make -j3 && make install &&\
    cd /usr/local/src &&\
    git clone https://github.com/centreon/centreon-engine.git &&\
    cd centreon-engine && git checkout $CENTREON_ENGINE_VERSION && cd build &&\
    cmake -DCMAKE_INSTALL_PREFIX=/centreon -DWITH_PACKAGE_RPM=yes . &&\
    make -j3 && make install &&\
    cd /usr/local/src &&\
    git clone https://github.com/centreon/centreon-connectors.git &&\
    cd centreon-connectors && git checkout $CENTREON_CONNECTORS_VERSION &&\
    cd ssh/build && cmake -DCMAKE_INSTALL_PREFIX=/centreon . && make -j3 && make install &&\
    cd ../../perl/build && cmake -DCMAKE_INSTALL_PREFIX=/centreon -DWITH_PACKAGE_RPM=yes . &&\
    make -j3 && make install &&\
    cd /usr/local/src &&\
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


## Configure NRPE server
RUN sed -i -e 's/allowed_hosts=127.0.0.1/allowed_hosts=127.0.0.1,centreon/' \
           -e 's/\/check_load -r -w .15,.10,.05 -c .30,.25,.20/\/check_load -r -w 1,.75,.50 -c 2,1.50,1/' /etc/nagios/nrpe.cfg 

## Do some configuration
COPY files/etc/centreon/conf.pm /etc/centreon/conf.pm
COPY files/etc/centreon-engine/* /etc/centreon-engine/
COPY files/etc/centreon-broker/* /etc/centreon-broker
COPY files/etc/init.d/centengine /etc/init.d/centengine

## More configuration ##
## Files’s owner/group are explicitly set again because the Centreon install script may have screw them…
RUN echo '/centreon/lib' >> /etc/ld.so.conf && ldconfig &&\
    usermod -a -G centreon nrpe &&\
    usermod -a -G centreon nagios &&\
    mkdir -p /var/lib/centreon/nagios-perf/ /var/cache/centreon/backup &&\
    mkdir /var/lib/centreon/.ssh && chmod 0700 /centreon/.ssh &&\
    chown -R centreon-engine:centreon /etc/centreon-engine && chmod -R g+rw /etc/centreon-engine &&\
    chown -R centreon-broker:centreon /etc/centreon-broker && chmod -R g+rw /etc/centreon-broker &&\
    chown -R centreon:centreon /etc/centreon && chmod -R g+rw /etc/centreon &&\
    chown -R centreon:centreon /centreon && chmod 0700 /centreon && chmod -R g+rwx /centreon/* &&\
    chown -R centreon:centreon /var/cache/centreon && chmod -R g+rwx /var/cache/centreon &&\
    chown -R centreon-engine:centreon /var/lib/centreon-engine && chmod -R g+rwx /var/lib/centreon-engine &&\
    chown -R centreon-broker:centreon /var/lib/centreon-broker && chmod -R g+rwx /var/lib/centreon-broker &&\
    chown -R centreon-engine:centreon /var/log/centreon-engine && chmod -R g+rwx /var/log/centreon-engine &&\
    chown -R centreon-broker:centreon /var/log/centreon-broker && chmod -R g+rwx /var/log/centreon-broker &&\
    chmod g+w /var/lib/centreon/*


# Set Europe/Paris for timezone.
RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime &&\
    echo "$CENTREON_TIMEZONE" > /etc/timezone


## Uninstall some packages ##
RUN yum -y --noplugins erase git cmake gcc gcc-c++ glibc-devel rrdtool-devel qt-devel gnutls-devel openssl-devel \
                       glib2-devel glibc-devel glibc-static fontconfig-devel libjpeg-devel libpng-devel gd-devel &&\
    yum --noplugins clean all


## Add some information in the MOTD file and remove some files ##
COPY files/etc/motd-centreonpoller /etc/motd
RUN rm -rf /var/cache/yum/* \
           /etc/modprobe.d /etc/modules-load.d /etc/modules \
           /etc/udhcpd.conf /etc/securetty /usr/local/src/* &&\
    sed -i -e "s/{build_date}/$(date)/" \
           -e "s/{build_host}/$(uname -rs)/" /etc/motd

# Entrypoint
COPY centreonpoller.entrypoint /entrypoint

## Files & perms
RUN chmod go-rwx /entrypoint

WORKDIR /
USER root
ENTRYPOINT ["/entrypoint"]
