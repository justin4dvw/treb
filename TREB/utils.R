#! /usr/bin/env RScript

# Check to see if packages are installed. Install them if they are not, then load them into the R session.
check.packages <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

check_github.packages <- function(){
  new.pkg <- "tabulizer"[!("tabulizer" %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    ghit::install_github(c("leeper/tabulizerjars", "leeper/tabulizer"), INSTALL_opts = "--no-multiarch", dependencies = c("Depends", "Imports"))
}

# html pakcages
packages<-c("ghit", "rJava","mongolite", "jsonlite","curl", "stringr","lubridate")
check.packages(packages)

# html pakcages
library('ghit')
library('rJava')
library('mongolite')
library('jsonlite')
library("curl")
library("stringr")
require("lubridate")

check_github.packages()
library("tabulizer")
