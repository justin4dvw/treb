#! /usr/bin/env RScript

library(mongolite)
mongodb_connection <- function(db, coll){
  my_collection = mongo(collection = coll, db = db) # create connection, database and collection
  return(my_collection)
}

mongodb_import_initdb <- function(db, coll){
  ## import from a backup via json
  library(jsonlite)
  
  buckets <- mongodb_connection('foundation4D', 'buckets') 
  buckets$import(file("json_files/buckets.json"))
  
  regexPatterns <- mongodb_connection('Misc_keywords4D', 'regexPatterns') 
  regexPatterns$import(file("json_files/regexPatterns.json"))
}