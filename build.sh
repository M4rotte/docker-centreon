#!/usr/bin/env bash

# Build images for Centreon servers.

# Arguments are prepended to the `docker-compose build` command argument array
# (before the service name)
#
# Possible values are:
#    --force-rm              Always remove intermediate containers.
#    --no-cache              Do not use cache when building the image.
#    --pull                  Always attempt to pull a newer version of the image.
#    --build-arg key=val     Set build-time variables for one service.

## NB: docker-compose service name must be the same as image’s repository
## for the flatten() function to work.
## image: `<user>/<repository>:<tag>` → service: `<repository>`
USER_ID="oxyure"
SERVICES="php-5.4.40 nginx-1.12.2 mariadb-10.1.26"


function prune_docker {
    echo -e "\n  ### Do some cleaning…\n"
    docker container prune --force
    docker image prune --force 
}

function flatten {
    ## Create a flattened version of image tagged "flat"
    ## ARG1: repository (must match service name)
    ## ARG2: entrypoint, default to ["/bin/sh"]
    if [ -z "$2" ]; then entrypoint='["/bin/sh"]'; else entrypoint="$2"; fi
    echo -e "\n  ### Flattening $USER_ID/$1:latest − Entrypoint: ${entrypoint}\n"
    RANDNAME="$(echo $RANDOM |md5sum |cut -d' ' -f1)"
    docker run -d --name "$RANDNAME" "$USER_ID/$1:latest"
    docker stop "$RANDNAME"
    docker export -o "/tmp/$RANDNAME.tar" "$RANDNAME"
    docker import \
       --change 'WORKDIR /' \
       --change 'USER root' \
       --change 'ENTRYPOINT '"${entrypoint}" \
       --message "/tmp/$RANDNAME.tar" \
       "/tmp/$RANDNAME.tar" "$USER_ID/$1:flat"
    rm "/tmp/$RANDNAME.tar"
    docker rm "$RANDNAME"
}

for service in ${SERVICES}; do

    echo -e "\n  ### Building image \"${service}\"\n"
    echo -e " \$ docker-compose build $@ ${service}\n"
    docker-compose build $@ ${service}

done

flatten php-5.4.40      '["/sbin/tini","/entrypoint"]'
flatten nginx-1.12.2    '["/sbin/tini","/entrypoint"]'
flatten mariadb-10.1.26 '["/sbin/tini","/entrypoint"]'

echo -e "\n  ### All builds finished\n"

#~ prune_docker

docker image ls

exit 0
