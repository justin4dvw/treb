#! /usr/bin/env RScript
userName <- '4dvwDB2Admin'
passwd <- 'FourDVWMongoDB2017'
serverAddress <- '@ec2-35-182-45-152.ca-central-1.compute.amazonaws.com:27017/'

mongodb_connection <- function(db, coll){
  url <- paste0("mongodb://", userName, ":", passwd, serverAddress)
  connection <- mongolite::mongo(url = url, db = db, collection = coll)
  return(connection)
}

mongodb_import_initdb <- function(db, coll){
  ## import from a backup via json
  library(jsonlite)
  
  buckets <- mongodb_connection('foundation4D', 'buckets') 
  buckets$import(file("json_files/buckets.json"))
  
  regexPatterns <- mongodb_connection('Misc_keywords4D', 'regexPatterns') 
  regexPatterns$import(file("json_files/regexPatterns.json"))
}