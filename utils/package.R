# Check to see if packages are installed. Install them if they are not, then load them into the R session.
check.packages <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

# html pakcages
packages<-c("RCurl", "httr", "xml2", "rvest", "XML", "R.utils")
check.packages(packages)

# html pakcages
library('RCurl') # for GET & other functions
library('httr')
library('xml2')
library('rvest')
library('XML')
library('R.utils')

# string processing packages
packages<-c("tm", "stringr", "urltools", "tidyverse", "magick", "kableExtra")
check.packages(packages)

# string processing packages
library('tm') #for NLP operations
library('stringr')  
library('urltools')
library('tidyverse')
library('magick') # image processing floorplan saving
library('kableExtra')

# visualization packages
packages<-c("ggplot2", "plotly", "wordcloud", "RColorBrewer", "rJava", "RWeka")
check.packages(packages)

# visualization packages
library('ggplot2')
library('plotly') #for interactive visuaization
library('wordcloud') #for word cloud visualization
library('RColorBrewer') #for brewer pal color palette
library('RWeka') # for Ngram tokenizer

# MongnDB packages
packages<-c("mongolite", "RJSONIO", "jsonlite", "rlist", "e1071")
check.packages(packages)

# MongnDB packages
library('mongolite')
# JSON packages
library('RJSONIO')
library('jsonlite')

# list package
library('rlist') # to use kist.append function

# ML packages
library('e1071')

# MongnDB packages
packages<-c("streamR", "rtweet", "rpinterest", "Rlinkedin", "httpuv", "data.table")
check.packages(packages)

# social media API package
library('streamR')
library('rtweet')
library('rpinterest')
library('Rlinkedin')
library("httpuv")
library("data.table")

# utils and WEB APIs packages
packages<-c("rstudioapi","stringr","dismo","googleway") 
check.packages(packages)

# utils and WEB APIs packages
library('rstudioapi')
library('stringr')
library('dismo')
library('googleway')

## shiny WEB server
packages<-c("shiny","shinyBS") 
check.packages(packages)

# utils and WEB APIs packages
library('shiny')
library('shinyBS')


# installing packages
# doInstall <- TRUE
# toInstall <- c("twitteR", "dismo", "maps")
# if(doInstall){install.packages(toInstall, repos = "http://cran.us.r-project.org")}
# lapply(toInstall, library, character.only = TRUE)
