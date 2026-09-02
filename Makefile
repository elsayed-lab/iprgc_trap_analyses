.PHONY: graph

TARGET = iprgc.sif

BIB = ${HOME}/Documents/bibtex/atb.bib

all: $(TARGET)

RMD_FILES = data/*.Rmd

SETUP_SCRIPTS = local/bin/*.sh

CONFIG_FILES = local/etc/*

DEFAULT_INPUT=preprocessing.Rmd:01_iprgc_gene_analyses.Rmd:02_iprgc_bulk_gene_analyses.Rmd:03_iprgc_transcript_analyses.Rmd:04_iprgc_bulk_transcript_analyses.Rmd:05_compare_trap_bulk.Rmd

## Note x,y is multiple binds, a:b binds host:a to container:b
SINGULARITY_BIND="/sw/local/R/renv_cache,/sw/local/spack/cache,/sw/local/apt/cache"

clean:
	sudo rm -rf *_overlay *.sif

graph:
	make -dn MAKE=: all | sed -rn "s/^(\s+)Considering target file '(.*)'\.$/\1\2/p"

%.overlay: %.yml
	mkdir -p $(basename $<)_overlay
	sudo singularity shell -B $(SINGULARITY_BIND) --overlay $(basename $@)_overlay $(basename $@).sif

%.runover: %.yml
	mkdir -p $(basename $<)_overlay
	sudo singularity run -B $(SINGULARITY_BIND) --overlay $(basename $@)_overlay $(basename $@).sif

%.shell: %.yml
	singularity shell -B $(SINGULARITY_BIND) $(basename $@).sif

%.sif: %.yml $(RMD_FILES) $(SETUP_SCRIPTS) $(CONFIG_FILES)
	cp local/etc/bashrc_template local/etc/bashrc
	echo "export DEFAULT_INPUT=$(DEFAULT_INPUT)" >> local/etc/bashrc
	test -f $(BIB) && cp $(BIB) data/atb.bib
	sudo singularity build -B $(SINGULARITY_BIND) --force $@ $<
