#!/usr/bin/env Rscript
setwd("/data")
## This script will perform the installation of the various tools I want
## into a renv tree and save the results to a renv.lock file.
## Then it will deactivate so that the actual R session will work.

## 'MHOM' is sufficiently distinct that it will get the L.panamensis MHOM/COL strain from tritrypdb.
prereq_pkgs <- c(
  "BiocManager", "devtools", "R.utils", "org.Mm.eg.db")
for (i in prereq_pkgs) {
    install.packages(i)
}
github_pkgs <- c(
  "Bioconductor/AnnotationHubData", "js229/Vennerable", "YuLab-SMU/ggtree", "davidsjoberg/ggsankey",
  "reesyxan/iDA", "dviraran/xCell")
local_pkgs <- c("hpgltools")
random_helpers <- c(
  "BSgenome", "CMplot", "devtools", "flashClust", "forestplot", "ggbio", "ggbreak",
  "glmnet", "irr", "lares", "patchwork", "pathwayPCA", "ranger", "remotes", "renv", "rpart",
  "rpart.plot", "rWikiPathways", "tidyverse", "xgboost")

start_options <- options(configure.args.preprocessCore = "--disable-threading",
                         renv.config.install.transactional = FALSE,
                         renv.config.cache.symlinks = FALSE)
source("/data/renv/activate.R")
renv_attempted <- try(renv::restore(prompt = FALSE))
if ("try-error" %in% class(renv_attempted)) {
  warning("renv failed, this will attempt to recover, but shenanigans may happen.")
}
symlinked <- R.utils::createLink(link = "/data/R", target = renv::paths$library())
for (i in random_helpers) {
  single <- paste0("bioc::", i)
  inst <- try(renv::install(single, prompt = FALSE))
}

## Hopefully at this point we have an environment which matches my workstation
## But I have found that cannot be truly guaranteed, so let us double-check
renv_installed <- as.data.frame(installed.packages())[["Package"]]

for (i in local_pkgs) {
  dep_pkgs <- remotes::dev_package_deps(i, dependencies = "Depends")[["package"]]
  missing_idx <- ! dep_pkgs %in% renv_installed
  if (sum(missing_idx) > 0) {
    missing_dep <- dep_pkgs[missing_idx]
    message("Installing still-missing Depends for ", i, ": ", toString(missing_dep))
    for (j in missing_dep) {
      single <- paste0("bioc::", j)
      installedp <- try(renv::install(single, prompt = FALSE))
    }
  } else {
    message("Yay, all entries in the Depends are installed!")
  }

  import_pkgs <- remotes::dev_package_deps(i, dependencies = "Imports")[["package"]]
  missing_idx <- ! import_pkgs %in% renv_installed
  if (sum(missing_idx) > 0) {
    missing_import <- import_pkgs[missing_idx]
    message("Installing still-missing Imports for ", i, ": ", toString(missing_import))
    for (j in missing_import) {
      single <- paste0("bioc::", j)
      installedp <- try(renv::install(single, prompt = FALSE))
    }
  } else {
    message("Yay, all the imports are installed!")
  }

  suggest_pkgs <- remotes::dev_package_deps(i, dependencies = "Suggests")[["package"]]
  missing_idx <- ! suggest_pkgs %in% renv_installed
  if (sum(missing_idx) > 0) {
    missing_suggests <- suggest_pkgs[missing_idx]
    message("Installing still-missing Suggests for ", i, ": ", toString(missing_suggests))
    for (j in missing_suggests) {
      single <- paste0("bioc::", j)
      installedp <- try(renv::install(single, prompt = FALSE))
    }
  } else {
    message("Yay, all the suggests are installed!")
  }
}

missing_helper_idx <- ! random_helpers %in% renv_installed
if (sum(missing_helper_idx) > 0) {
  missing_helpers <- random_helpers[missing_helper_idx]
  message("Install a few helper packages of interest that are not explicitly in my DESCRIPTION.")
  for (j in missing_helpers) {
    single <- paste0("bioc::", j)
    installedp <- try(renv::install(single, prompt = FALSE))
  }
}

missing_github_idx <- ! github_pkgs %in% renv_installed
missing_github <- github_pkgs[missing_github_idx]
if (sum(missing_github_idx) > 0) {
  for (pkg in missing_github) {
    github_installed <- try(renv::install(pkg, prompt = FALSE))
  }
}

message("Rebuilding preprocessCore with disable-threading just in case restore() didn't")
installedp <- try(renv::install("preprocessCore", rebuild = TRUE, prompt = FALSE))
## There is some stupidity in how the R hdf5lib package is installed
## It is not installing the private headers, which fine I guess, but that means
## the hdf5 package fails.
hdf5_stupid <- try(renv::install("Rhdf5lib", rebuild = TRUE, prompt = FALSE))
hdf5_stupid <- try(renv::install("rhdf5", rebuild = TRUE, prompt = FALSE))
renv_options <- options(start_options)
renv::snapshot()
renv::deactivate()
