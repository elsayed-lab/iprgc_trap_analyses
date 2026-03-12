#!/usr/bin/env bash
source /usr/local/etc/bashrc

## This file is intended to document my first container installation
## of every R prerequisite via renv.  Once complete I will use renv's
## snapshot function to create its json file which will then be included
## with the container recipe and invoked from within the container installation
## via renv's restore.  The starting point for this script is a reasonably minimal
## singularity instance with a blank R, build-essential, and some known prerequisites.

cd /data || exit
log=/data/setup_hpgltools.stdout
err=/data/setup_hpgltools.stderr

## The primary motivation for this document is the fact that all my containers exploded
## on 20240501.  Suddenly, none of my containers were able to successfully build because
## bioconductor changed versions of many of the prerequisites to versions which simply
## do not install.  As a result, I decided to re-evaluate how I install these prerequisites
## and remove the assumption that installing/using a specific bioconductor version would
## result in a set/usable set of packages.
##
## As a result, I decided to once again try renv.  I previously tried this for a project
## and found it a bit unsatisfactory, just because at the time I thought having extra
## copies of everything across packages too onerous.  However, if I am going to go to the
## trouble of installing a full toolchain for the container, then I will -by-definition-
## have all the packages installed in it, so that complaint is a bit stupid.

## With the above in mind, I am going to write in the following R script with each
## installation command used to get renv set up followed by whatever tasks are required
## to get me all the prerequisite packages for this container.

## If any of the resulting packages require the installation of stuff via apt/conda, then
## I will put them here, before the R script.

echo "Setting up a Debian stable instance."
echo "Dir::Cache /sw/local/apt/cache;" > /etc/apt/apt.conf.d/99-cache_dir
apt-get update
apt-get -y upgrade
for i in $(/bin/cat /usr/local/etc/deb_packages.txt); do
    { apt-get -y install $i || echo "Could not install $i."; }
done
ln -s /usr/lib/R/site-library /data/R
mkdir -p /data/renv/library/linux-debian-trixie/R-4.5
ln -s /usr/lib/R/site-library /data/renv/library/linux-debian-trixie/R-4.5/x86_64-pc-linux-gnu
## Setup renv and initialize my package versions.
## I added a little logic so that we can simply copy hpgltools/hpgldata from my working tree
## rather than go through the potentially long process of downloading them.
#if [[ -d "/data/hpgldata" ]]; then
#    echo "The hpgldata package has already been copied to /data."
#else
#    git clone https://github.com/abelew/hpgldata.git
#fi
if [[ -e "/data/hpgltools" ]]; then
    echo "The hpgltools package has already been copied to /data."
    chown -R root:root /data/hpgltools
else
    git clone https://github.com/abelew/hpgltools.git
fi

if [[ -z "${HPGLTOOLS_COMMIT}" ]]; then
    echo "HPGLTOOLS_COMMIT was empty."
    ## The %setup block of the singularity configuration includes an rsync from my $HOME
    export HPGLTOOLS_COMMIT=$(cd hpgltools && git log -1 | grep commit | awk '{print $2}')
    echo "export HPGLTOOLS_COMMIT=${HPGLTOOLS_COMMIT}" >> /usr/local/etc/bashrc
else
    echo "Using commit ID ${HPGLTOOLS_COMMIT}."
    cd hpgltools && git reset --hard ${HPGLTOOLS_COMMIT}
fi

## The bootstrap will therefore use the renv directory to install everything
## Since renv causes the container to fail, I will not _actually_ use it, but instead
## invoke activate(), snapshot(), deactivate() at the end of the process, thus
## creating the renv.lock and json files which may then be provided if one wishes
## to use this renv in other environments (but not this singularity instance,
## or it will die horribly).
echo "Running the bootstrap R installation script."
{ /usr/local/bin/bootstrap.R || echo "Failed to finish bootstrap.R"; }
echo "Using commit ID ${HPGLTOOLS_COMMIT}."
echo "The last commit included:" | tee -a ${log}
last=$(cd hpgltools && git log -1)
echo "${last}" | tee -a ${log}
{ cd /data/hpgltools && make clean && make install || echo "Failed to build hpgltools."; }
#rm -rf /data/hpgltools /data/*.tar.gz
