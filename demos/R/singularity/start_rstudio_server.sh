#!/bin/bash

# Demo: Start a Singularity container for R Studio Server
# Last modified on 2024-08-22 by Brian High <high@uw.edu>
# See: https://rocker-project.org/use/singularity.html
# And: https://davetang.org/muse/2024/02/09/running-rstudio-server-with-singularity/
# Created on 2021-04-06 by John Yocum <jtyocum@uw.edu>

# Usage example:
# salloc   # To get on a compute node
# bash /projects/demo/singularity/bin/start_rstudio_server.sh rstudio_4.4.sif

RS_CONTAINER_NAME=${1}
RS_CONTAINER_BASE=/projects/demo/singularity/sif/rstudio_server
RS_CONTAINER_IMAGE=${RS_CONTAINER_BASE}/${RS_CONTAINER_NAME}

# Get container sif file (if missing)
#mkdir -p $RS_CONTAINER_BASE
#cd $RS_CONTAINER_BASE || exit 1
#[ -r $RS_CONTAINER_IMAGE ] || singularity pull docker://rocker/rstudio:4.4

if [ "$#" -ne 1 ]; then
    echo "Usage: $(basename ${0}) IMAGE"
    echo "Available images:"
    ls ${RS_CONTAINER_BASE}
    exit 1
fi

if [ ! -f ${RS_CONTAINER_IMAGE} ]; then
    echo "Error: R Studio container image not found"
    exit 1
fi

# Create session specific temporary directories
TMPDIR=/projects/demo/$USER/tmp
mkdir -p $TMPDIR
cd $TMPDIR || exit 1

# Add some system packages to the container
#sudo singularity build --sandbox container ${RS_CONTAINER_IMAGE}
#sudo singularity exec --writable container \ 
#  bash -c 'apt-get update && apt-get install -y imagemagick libcurl4-openssl-dev libmagick++-dev librsvg2-dev'
#sudo singularity build ${RS_CONTAINER_IMAGE} container/ && sudo rm -rf container

# Singularity setup
mkdir -p run var-lib-rstudio-server
printf 'provider=sqlite\ndirectory=/var/lib/rstudio-server\n' > database.conf

# Generate random password
RS_CONTAINER_PASSWD=$(openssl rand -base64 12)
echo "PASSWORD=${RS_CONTAINER_PASSWD}" > ${TMPDIR}/rs.passwd

# Pick random port number
while :
do
    RAND_PORT=$(shuf -i 50000-60000 -n 1)
    if netstat -l -t -n | grep -q -v ${RAND_PORT}; then
        break
    fi
done

# Print instructions for connecting
INSTRUCTIONS="
The following SSH commands should be run from your computer. If you are using PuTTY, you will need to adapt the settings.

    ssh -p 22 -L ${RAND_PORT}:${HOSTNAME}:${RAND_PORT} ${USER}@login.hpc.sph.washington.edu

Once the SSH tunnel is setup, use a browser to visit http://localhost:${RAND_PORT}/, and login with ${USER} / ${RS_CONTAINER_PASSWD}
"
printf "${INSTRUCTIONS}"

# Start server
PASSWORD=${RS_CONTAINER_PASSWD} singularity exec --bind run:/run,var-lib-rstudio-server:/var/lib/rstudio-server,database.conf:/etc/rstudio/database.conf ${RS_CONTAINER_IMAGE} /usr/lib/rstudio-server/bin/rserver --auth-none=0 --auth-pam-helper-path=pam-helper --server-user=$(whoami) --www-port=${RAND_PORT}

