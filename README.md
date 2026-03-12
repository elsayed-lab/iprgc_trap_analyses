<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Introduction](#introduction)
- [Cheater installation](#cheater-installation)
- [Installation](#installation)
- [Creating the container](#creating-the-container)
  - [Notes on the Makefile](#notes-on-the-makefile)
- [Generating the html/rda/excel output files](#generating-the-htmlrdaexcel-output-files)
- [Playing around inside the container](#playing-around-inside-the-container)
  - [-](#-)
- [Experimenting with renv](#experimenting-with-renv)
  - [renv setup](#renv-setup)
  - [Performed in the working tree of the container](#performed-in-the-working-tree-of-the-container)
  - [Performed in /tmp/ using the bare-bones /usr/bin/R](#performed-in-tmp-using-the-bare-bones-usrbinr)
- [Final notes](#final-notes)

<!-- markdown-toc end -->


# Introduction

Define, create, and run the analyses used in the paper:
""

This repository contains everything one should need to create a
singularity container which is able to run all of the various R
tasks performed, recreate the raw images used in the figures, create
the various intermediate rda files for sharing with others, etc.  In
addition, one may use the various singularity shell commands to enter
the container and play with the data.

# Cheater installation

Periodically I put a copy of the pre-built container here:

[https://elsayedsingularity.umiacs.io/](https://elsayedsingularity.umiacs.io/)

It probably does not have the newest changes.

# Installation

Grab a copy of the repository:

```{bash, eval=FALSE}
git pull https://github.com/elsayed-lab/iprgc_analyses.git
```

The resulting directory should contain a few subdirectories of note:

* local: Contains the configuration information and setup scripts for the
  container and software inside it.
* data: Numerically sorted R markdown files which contain all the fun
  stuff.  Look here first.
* preprocessing: Archives of the count tables produced when using cyoa
  to process the raw sequence data. Once we have accessions for SRA, I
  will finish the companion container which creates these.
* sample_sheets: A series of excel files containing the experimental
  metadata we collected over time.  In some ways, these are the most
  important pieces of this whole thing.

At the root, there should also be a yml and Makefile which contain the
definition of the container and a few shortcuts for
building/running/playing with it.

# Creating the container

With either of the following commands, singularity should read the yml
file and build a Debian stable container with a R environment suitable
for running all of the analyses in data/.

```{bash, eval=FALSE}
make
## Really, this just runs:
sudo -E singularity build tmrc3_analyses.sif tmrc3_analyses.yml
```

## Notes on the Makefile

The default Makefile target has dependencies for all of the .Rmd files
in data/; so if any of them change it should rebuild.

There are a couple options in the Makefile which may help the running
of the container in different environments:

1.  SINGULARITY_BIND: This, along with the environment variable
    'RENV_PATHS_CACHE' in local/etc/bashrc has a profound effect on
    the build time (assuming you are using renv).  It makes it
    possible to use a global renv cache directory in order to find and
    quickly install the various packages used by the container.
    If it is not set, the container will always take ~ 5 hours to
    build.  If it is set, then it takes ~ 4 minutes (assuming all the
    prerequisites are located in the cache already, YMMV).

# Generating the html/rda/excel output files

One of the neat things about singularity is the fact that one may just
'run' the container and it will execute the commands in its
'%runscript' section.  That runscript should use knitr to render a
html copy of all the data/ files and put a copy of the html outputs
along with all of the various excel/rda/image outputs into the current
working directory of the host system.

```{bash, eval=FALSE}
./iprgc.sif
```

# Playing around inside the container

If, like me, you would rather poke around in the container and watch
it run stuff, either of the following commands should get you there:

```{bash, eval=FALSE}
make iprgc.overlay
## That makefile target just runs:
mkdir -p template
sudo singularity shell --overlay iprgc_overlay iprgc.sif
```

### The container layout and organization

When the runscript is invoked, it creates a directory in $(pwd) named
YYYYMMDDHHmm_outputs/ and rsync's a copy of the working tree into it.
This working tree resides in /data/ and comprises the following:

* sample_sheets/ : xlsx files containing the metadata collected and
  used when examining the data.  It makes me more than a little sad
  that we continue to trust this most important data to excel.
* preprocessing/ : The tree created when processing the raw data
  downloaded from the various sequencers used during the
  project.  Each directory corresponds to one sample and contains all
  the logs and outputs of every program used to play with the data.
  In the context of the container this is relatively limited due to
  space constraints.
* renv/ and renv.lock : The analyses were all performed using a
  specific R and bioconductor release on my workstation which the
  container attempts to duplicate.  If one wishes to create an R
  environment on one's actual host which duplicates every version of
  every package installed, these files provide that ability.
* The various .Rmd files : These are usually numerically named
  analysis files. The 00preprocessing does not do anything, primarily
  because I do not think anyone wants a 6-10Tb container (depending on
  when/what is cleaned during processing)!  All files ending in
  _commentary are where I have been putting notes and muttering to
  myself about what is happening in the analyses.
* /usr/local/bin/* : This comprises the bootstrap scripts used to
  create the container and R environment, the runscript.sh used to run
  R/knitr on the Rmd documents, and some configuration material in
  etc/ which may be used to recapitulate this environment on a
  bare-metal host.

```{bash, eval=FALSE}
## From within the container
cd /data
## Copy out the Rmd files to a directory where you have permissions via $SINGULARITY_BIND
## otherwise you will get hit with a permissions hammer.
## Or invoke the container with an overlay.
emacs -nw 01datasets.Rmd
## Render your own copy of the data:
Rscript -e 'rmarkdown::render("01datasets.Rmd")'
## If you wish to get output files with the YYYYMM date prefix I use:
Rscript -e 'hpgltools::renderme("01datasets.Rmd")'
```

# Final notes

Once completed, there should be a file 'README.Rmd' which contains a
full accounting of the packages used with references along with an
index of the locations in the various documents where any figures are
sourced.  E.g. if (for example) Figure 4, panel D is a PCA plot; this
readme should point out exactly where that came from in the analyses
and link to the freshly generated image.  If everything is working as
intended, that freshly generated image should be identical to the
image in the paper (with the exception of any post-processing to make
them fit the page or whatever).
