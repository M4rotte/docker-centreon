# Centreon Docker images

This is a "work in progress" project. The v0.8 offers a minimal working setup, with one central/poller image and one database image.

A “poller-only” image is also available.

The Centreon central image is based on the CentOS 7 official image, while the database image is based on the official Alpine 3.6 image. You can use the central image with any other MariaDB or MySQL image. Using a standard image for the database only need you to make the necessary SQL command to grant the central the right to connect to do the initial Centreon’s setup. You can find this command in the [related entrypoint Bash script](https://github.com/M4rotte/docker-centreon/blob/master/centreondb/centreondb.entrypoint). 

## A bit of history

On [Docker Hub](https://hub.docker.com/search/?isAutomated=0&isOfficial=0&page=1&pullCount=0&q=centreon&starCount=0), the most starred and pulled image has been made by one of the Centreon author, Julien Mathis, but it hasn’t been updated for three years and is for a standalone setup of Centreon.

There seems to be some [interesting](https://github.com/jpdurot/docker-centreon) [ressources](https://github.com/padelt/docker-centreon) on Docker Hub but I’m trying to do it myself, rather than testing those.

One of the goals of this work is to learn Docker, and getting a better knowledge of Centreon’s internal, plus, I won’t bet the images available would work out-of-the-box nor will be easily adaptable for our current setup.

## What is done so far

A central image with CLib, Broker, Engine, Connectors and Centreon Web. The setup (install.sh) is done during image creation but the Centreon configuration itself must be realized once the container is running. Having '/etc' being a Docker volume makes the configuration persist across container restarts.

Once the setup has took place, you must manually rename the '/centreon/www/install' directory (as '/centreon/www/install.done' for example) to prevent the installation to restart again and again. This may be a bug or a misconfiguration I made, I don’t know.

The Centreon widget “Global health” is installed.

A CLAPI export (of everything but the “TRAP” objects) exists at '/root/initial_setup.clapi' in the central’s container. It may be used to populate the database with some supervision objects. Just open a shell in the central container and issue the following command:

    # /centreon/bin/centreon -u admin -p ***** -i /root/initial_setup.clapi

(it’s important to provide an absolute path for the CLAPI input file)

### Database image

It’s based on Alpine and it’s not as complete as the Debian based official MariaDB docker image. To run Centreon you can (and probably should) use the official image as your backend.

Alpine Linux may sound as a perfect candidate for containers, because it’s tiny in RAM, but the fact it’s built on top of busybox and ulibc, instead of GNU tools and GNU libc, makes it harder to work with in a FOSS world, where the GNU libc still is the norm and so widely deployed. I encoutered problems with this database image : it was working fine on my personnal dev Docker engine setup, but it did not when I moved it on our corporate plateforme.

MariaDB is installed from the packages available in Alpine 3.6 (MariaDB version is 10.1.26). The image is named 'centreondb'.

If '/var/lib/mysql/mysql' is not a directory then MariaDB is run once to:

 1) execute its initial configuration
 2) set the root password (from an env. variable)
 3) set grants necessary for root to connect from the central with password
 
Then (or if the server was already configured) MariaDB is run to listen to requests.

#### Entrypoint

Entrypoint is a Bash script.

The 'mysqld' process is killed with SIGTERM (so is gracefuly terminated [according to MariaDB documentation](https://mariadb.com/kb/en/library/shutdown/)) whatever the container receive SIGINT, SIGTERM, SIGQUIT or SIGSTOP.

'/var/lib/mysql' is, of course, a Docker volume.

### Central image

I’m aware of the availability of Centreon packaged in RPM. While this is (very) easy to deploy a standalone, and quite outdated, Centreon solution, it’s not well suited to deploy a multi-host supervision. Beside, being able to follow the developpement of the product and mastering its deployement (what is made possible installing from the source), seems to be a useful advantage to make things done.

Running Centreon with separated PHP and Web servers, seems a bit out of hand, at least for me. To simplify the problem I will try to have one container with all the necessary things. This image will, at first, be a Centreon poller too.

In the first place, I stick to Apache for the web server. Nginx may be another good choice to consider. I find it quite simpler to configure and operate, but being unaware of how Centreon is dependent of Apache I stay with the latter.

Centreon, in contrast, is being built from source. I’m using the [sources available on GitHub](https://github.com/centreon/centreon), the branch (or tag) of every component may be chosen using build arguments. The choices though dont’ seem to be enormous for a production environement… Many parts of the Centeron suite (including the core: CLib…) are in the process of being rewritten, and the new major versions of those programs aren’t finished and still not working as expected. I won’t detail the versions I used because it may not be relevant the time you’re reading this… You should probably follow the versions which are currently packaged in the CES distribution. So you know what to indicate in the build environment in case you decide to build the image. The variables are :

 - CENTREON_CLIB_VERSION
 - CENTREON_ENGINE_VERSION
 - CENTREON_BROKER_VERSION
 - CENTREON_CONNECTORS_VERSION
 - CENTREON_CENTREON_VERSION

and must contain a tag or a branch name.

The builds are made on the container itself (ie: there is no separate builder). I should probably change that in the futur but it’s not a priority for me (except if someone convince me of the contrary).

The image is named `centreon`

### [Centreon CLib](https://github.com/centreon/centreon-clib)

This is the base part of Centreon. No serious warning, not even a trivial one… should be ignored nor accepted in the building of this part… Quoting the [documentation](https://documentation.centreon.com/docs/centreon-clib/en/latest/release_notes/centreon_clib_1_0_0.html#first-release) : “_Centreon Clib is a common library for all Centreon products written in C/C++. This project provides high level implementation of many basic system mechanism. The target is to have a portable and powerful implementation._”

#### [Centreon Broker](https://github.com/centreon/centreon-broker)

It has to be installed on both the central and the poller. The broker daemon must be running on the central server.

#### [Centreon Engine](https://github.com/centreon/centreon-engine)

The monitoring engine is independent (ie: may be used without Centreon).

### [Centreon Connectors](https://github.com/centreon/centreon-connectors)

Both SSH and Perl connectors are built but some configuration remains to do. Connectors aren’t use in out current setup but are a promising functionality.

The SSH connector permits to maintain SSH connections between the poller and the supervised hosts, thus permiting to issue checks by SSH at a quite low cost. It so permits to avoid the necessity of the NRPE agent on every hosts where a SSH server is available.

The Perl connector permits to save calling the interpreter for each check. It’s another subject which also needs more studies and tests.

#### [Centreon](https://github.com/centreon/centreon)

Most of the application is written in PHP (+ some parts in Perl). As a downside for integration, it depends on PHP < 5.5 (NB: strictly inferior), thus restricting the choice of distribution. Currently (02/2018), CentOS 7 seems to be the only, still maintained, distribution offering PHP 5.4…

03/08/19 EDIT: The last Centreon Web versions, from 18.10.1, are now supporting PHP 7. I didn’t manage to test to build the image against the the very last sources though…


The initial Centreon upgrade (install/upgrade.php) which takes place the first time keeps restarting again for an unknown reason. So after it took place, you need to manually connect to the container and `mv /centreon/www/install /centreon/www/install.done`

## Docker volumes

### centreondb

#### centreondb-var-lib-mysql:/var/lib/mysql
 
This is the MariaDB $DATADIR.
 
### centreon

#### centreon-etc:/etc

The configuration of our Centreon server.

### centreon-centreon-www:/centreon/www

The Centreon Web’s document root.

### centreonpoller-etc:/etc

The configuration of our Centreon poller.

## Directories

 - /centreon
 - /var/lib/centreon
 - /var/lib/centreon-engine
 - /var/lib/centreon-broker
 - /var/log/centreon
 - /var/log/centreon-engine
 - /var/log/centreon-broker
 - /etc/centreon
 - /etc/centreon-engine
 - /etc/centreon-broker

## What’s left to do

#### Nagios plugins

Legacy monitoring plugins are currently installed from the package available in the system. It would benefit to be installed from the Github repository. Our corporate plugins should be installed the same.

#### Centreon files and directories 

The directory structures can probably be improved…

All binaries related to Centreon are mixed in /centreon (it’s used as installation prefix for **all** builds)

 - /centreon
 
As it’s used as installation prefix, it also contains the default configurations for each Centreon composants. We will never use those files, instead, configuration, logs and variable data (metrics, status) are stored in the system default directories:

 - /var/lib/centreon-broker
 - /var/lib/centreon-engine
 - /var/lib/centreon
 - /var/log/centreon-engine
 - /var/log/centreon-broker
 - /var/log/centreon
 - /etc/centreon
 - /etc/centreon-engine
 - /etc/centreon-broker

This is how I wanted it to work. I’m still not 100% sure that the files in /centreon aren’t need at all. The Centreon install process is quite complex and should be studied more deeply.

## If this POC is successful 

What’s next… Things that would need to be done if we start the projet to have Centreon managed as Docker containers.

### Downtimes

A container for our downtime manager.

### Inventory

A container for our inventory synchronization tool.

### Supervision Request

A container for our supervision requests tool.

## More things to try

### Nginx

Use Nginx in place of Apache

### Directory structures

Remove all unused filed in /centreon (upstream default configuration mostly). Just to be sure we know precisely which files are needed by the Centreon application and which files aren’t…
 
### Alpine for poller

Maybe Alpine is well fitted to act as a poller. Booting fast is more important for a poller than for a bdd or central, so it makes sense. But, this poller would may not be able to run any programme which can’t be compiled against ulibc.

### Centreon installation

Master all the Centreon toolchain, middleware + applications, from PHP to Centreon, by following the different upstreams and installing from source. Search for compile-time optimisations and intersting features we could benefit, or, features we can disable to save some ressources.

 - PHP
 - MariaDB
 - RRDTool
 - …
 - Nagios plugins
 - …

### Corporate installation

Once the current existing (or new) templating (and ACL/command/ressources), which is required for our different tools, has been precisely established. An inital CLAPI file, to be run at first central container start, to populate Centreon (central & poller) with all corporate objects have to be created.

### Logs

 - Redirect interesting logs to Logstash.
