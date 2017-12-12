# Centreon Docker images

This is a "work in progress" project. It’s not usuable so far.

Despite having "alpine" in its name, this project makes only a little use of Alpine Linux. I gave up with the idea of building the Centreon stack under this distribution, only the MariaDB database image is made from the Alpine official image.

I’m currently trying to build the last Centreon source code using the CentOS 7 image.

## A bit of history

On [Docker Hub](https://hub.docker.com/search/?isAutomated=0&isOfficial=0&page=1&pullCount=0&q=centreon&starCount=0), the most starred and pulled image has been made by one of the Centreon author, Julien Mathis, but it hasn’t been updated for three years and is for a standalone setup of Centreon.

There seems to be some [interesting resources](https://github.com/jpdurot/docker-centreon) on Docker Hub but I’m trying to do it myself, rather than testing those.

One of the goals of this work is to learn Docker, and getting a better knowledge of Centreon’s internal, plus, I won’t bet the images available will work out-of-the-box nor will be easily adaptable for our current setup.

## What is done so far

Not much.

### Database image

It’s based on Alpine and it’s not as complete as the Debian based official MariaDB docker image. To run Centreon you may (and probably should) use the official image for your backend.

MariaDB is installed from the packages available in Alpine 3.6.

### Central image

Running Centreon with separated PHP and Web servers, seems a bit out of hand, at least for me. To simplify the problem I will try to have one container with all the necessary things. This image will, at first, be a Centreon poller too.

In the first place, I stick to Apache for the web server. Nginx may be another good choice to consider. I find it quite simpler to configure and operate, but being unaware of how Centreon is dependent of Apache I stay with the latter. 

Centreon, in contrast, is being built from source. I’m using the [sources available on GitHub](https://github.com/centreon/centreon), the branch of every component may be chosen using build arguments.

I’m aware of the availability of Centreon packaged in RPM. While this is (very) easy to deploy a standalone, and quite outdated, Centreon solution, it’s not well suited to deploy a multi-host supervision. Beside, being able to follow the developpement of the product and mastering its deployement (what is made possible installing from the source), seems to be a useful advantage to make things done.

The builds are made on the container itself (ie: there is no separate builder). I should probably change that in the futur but it’s not a priority for me (except if someone convince me of the contrary).

#### [Centreon CLib](https://github.com/centreon/centreon-clib)

This is the base part of Centreon. No particular problem to build it. On CentOS as on Alpine.

#### [Centreon Broker](https://github.com/centreon/centreon-broker)

Build on Alpine (so using Musl as standard library) with many warnings. OK on CentOS with the GNU libc (and definitively faster).

#### [Centreon Engine](https://github.com/centreon/centreon-engine)

The monitoring engine is independent (ie: may be used without Centreon). This is the only part needed (in addition of the plugins themselves) on pollers.

Using Alpine I discovered many compatibility problems in the source code. I tried to fix some, then I gave up. OK on CentOS.

#### [Centreon Connectors](https://github.com/centreon/centreon-connectors)

##### Centreon Connector Perl

Persistent Perl interpreter that executes Perl plugins very fast.

##### Centreon Connector SSH

Maintain SSH connexions opened to reduce overhead of plugin execution over SSH

#### Nagios plugins

Legacy monitoring plugins are currently installed from the package available in the system.

#### [Centreon](https://github.com/centreon/centreon)

Most of the application is written in PHP. As a downside for integration, it depends on PHP < 5.5 (NB: strictly inferior)

CentOS 7 is nice for this. We don’t have to install PHP from source as the distribution proposes PHP 5.4

#### Centreon files and directories 

All binaries related to Centreon are in /centreon (it’s used as installation prefix for all builds)

 - /centreon
 
As it’s used for installation, it also contains the default configurations, but we will never use those files.

Configuration, logs and variable data (metrics, status) are stored in the system default directories:

 - /var/lib/centreon-broker
 - /var/lib/centreon-engine
 - /var/lib/centreon
 - /var/log/centreon-engine
 - /var/log/centreon-broker
 - /var/log/centreon
 - /etc/centreon
 - /etc/centreon-engine
 - /etc/centreon-broker

## If this POC is successful 

What’s next…

### Downtimes

A container for our downtime manager.

### Inventory

A container for our inventory synchronization tool.

### Supervision Request

A container for our supervision requests tool.

### Centreon installation

Master all the Centreon toolchain, middleware + applications, from PHP to Centreon, by following the different upstreams and installing from source.

 - PHP
 - MariaDB
 - RRDTool
 - …
 - Nagios plugins
 - …



