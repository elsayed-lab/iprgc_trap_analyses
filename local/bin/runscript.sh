#!/usr/bin/bash
#set -o errexit
set -o errtrace
set -o pipefail
start=$(pwd)
source /usr/local/etc/bashrc
export VERSION=$(date +%Y%m)

function usage() {
    echo "This script by default will render every file in the list:"
    echo "${inputs}"
    echo "into the directory:"
    echo "${OUTPUT_DIR}"
    echo ""
    echo "It also understands the options: "
    echo "-i: colon-separated list of input files."
    echo "-o: Output directory to write data/outputs."
    echo "-c: Clean up the output directory."
    echo "-a: Copy the hpgltools repository to the current working directory."
    echo "-d: Dump the _entire_ data directory from the container to your working directory."
}


function cleanup() {
    echo "Cleaning the output directory to rerun."
    cd "${OUTPUT_DIR}" || exit
    rm -f ./*.finished*
}


function copy_hpgltools() {
    echo "Copying the hpgltools repository to the current working directory."
    mkdir -p hpgltools
    rsync -av /data/hpgltools/ hpgltools/
}


function dump() {
    echo "Copying the entire data tree from the container to the current working directory."
    echo "This includes all the R packages, any built genomes, all the raw data, _everything_."
    echo "You have 5 seconds to hit control-C before it starts."
    sleep 5
    rsync -av /data/ --exclude='R' --exclude='*.tar.gz' --exclude='*.tar' --exclude='*.tar.xz' --exclude='renv.lock' --exclude='renv/' --exclude='hpgltools/' --exclude='hpgldata/' .
}


function render_inputs() {
    source /usr/local/etc/bashrc
    echo "This is using versions: container: ${CONTAINER_VERSION}, bioconductor: ${BIOC_VERSION},"
    echo "hpgltools: ${HPGL_VERSION}, and script: ${VERSION}."
    echo "This script should render the Rmd files in the list:"
    echo "${inputs}."
    mkdir -p excel figures tmp cpm rpkm
    export TMPDIR="$(pwd)/tmp"
    for input in $(echo "${inputs}" | perl -pe "tr/:/ /"); do
        base=$(basename "$input" .Rmd)
        finished="${base}.finished"
        if [[ -f "${finished}" ]]; then
            echo "The file: ${finished} already exists, skipping this input."
        else
            echo "Rendering: ${input}"
            /usr/bin/time -v -o ${base}.time -a Rscript -e "hpgltools::renderme('${input}', 'html_document')" 2>"${base}.stderr" | tee -a "${base}.stdout"
            if [[ "$?" -ne 0 ]]; then
                echo "The Rscript failed."
            else
                echo "The Rscript completed."
                touch "${finished}"
            fi
        fi
    done
}


for arg in "$@"; do
    shift
    case "$arg" in
        '--input') set -- "$@" '-i' ;;
        '--clean') set -- "$@" '-c' ;;
        *) set -- "$@" "$arg" ;;
    esac
done
# Default behavior
number=0; rest=false; ws=false
# Parse short options
OPTIND=1
while getopts "abdch:i:" opt; do
    case "$opt" in
        'c') cleanup
           exit 0;;
        'h') usage
             exit 0;;
        'a') copy_hpgltools
                exit 0;;
        'd') dump
             exit 0;;
        'i') inputs=$OPTARG
             render_inputs
             exit 0;;
        *) usage
           exit 1;;
    esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

## If -i is not provided, then we are not working from within the container
## and so will not create a directory from within the /output bind mount.

export OUTPUT_DIR="$(date +%Y%m%d%H%M)_outputs"
mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}" || exit
## DEFAULT_INPUT is provided in the yml file.
inputs="${DEFAULT_INPUT}"
echo "No colon-separated input file(s) given, analyzing the archived data."
echo "About to rsync the data tree with: "
echo "  rsync -av /data/ --exclude='R' --exclude='renv/' --exclude='hpgltools/' --exclude='hpgldata/' ."
for i in $(/bin/ls /data/preprocessing/*.tar); do
rsync -av /data/ --exclude='R' --exclude='*.tar.gz' --exclude='*.tar' --exclude='*.tar.xz' --exclude='renv.lock' --exclude='renv/' --exclude='hpgltools/' --exclude='*.tar' .
    tar xaf "${i}"
done
for i in $(/bin/ls /data/preprocessing/*.tar.*); do
    tar xaf "${i}"
done

echo "Just a heads up, on our (aging) lab computer with 512 Gb of RAM, this takes about a day to run."
render_inputs
cd "${start}" || exit
rm -f current_output
/usr/bin/ln -s "${OUTPUT_DIR}" current_output
minutes=$(( ${SECONDS} / 60 ))
echo "This set of analyses completed in ${minutes} minutes."
