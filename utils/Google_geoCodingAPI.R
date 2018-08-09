#! /usr/bin/env RScript

# To get formatted address & geocoordinates from Google Geocoding API

## UDF - URL encoding of the Google maps URL
construct.geocode.url <- function(address, return.call = "json", key='AIzaSyABJly8CGFK5xoxfD-2zdHEQa-orBUFODY', sensor = "false") {
  root <- "https://maps.google.com/maps/api/geocode/"
  u <- paste(root, 'json?' , 'key=', key, "&address=", address, "&sensor=", 'false', sep = "")
  return(URLencode(u))
}

## UDF - accessing and getting content from google maps api
### input - just adddress in character
### output - list format of the result
gGeoCode <- function(address,verbose=FALSE) {
  library(RCurl)
  if(verbose) cat(address,"\n")
  u <- construct.geocode.url(address)
  doc <- getURL(u)
  x <- jsonlite::fromJSON(doc, simplifyDataFrame = T)
  return(x)
}
