source('utils.R')
library('tabulizer')
library('mongolite')
library('jsonlite')
source('Treb_funcs.R')
source('../utils/mongoDB_connection.R') ### for local testing change to mongoDB_AWSconnection.R
require(lubridate)

################ check if already processed
outputColl <- mongodb_connection('Property4D', 'TREB_rates')
uptodate_TREB_rates <- outputColl$find()
latest_TREB <- max(as.POSIXct(uptodate_TREB_rates$data[1][[1]]$reportDate))

# check that sys.date is more than latest month saved on db
if(as.POSIXct(Sys.Date())-latest_TREB>0){
  
  # add month by month after latest
  latet_month <- as.Date(latest_TREB)
  month(latet_month) <- month(latet_month) + 1
  
  # time-frame variables, based on current date
  while(month(latet_month) <= month(Sys.Date())){
    curr_date <- unlist(str_split(latet_month, pattern = "-"))
    year<-curr_date[1]
    month<-curr_date[2]
    day<-curr_date[3]
    
    # format year
    year <- paste(unlist(str_split(year,""))[3:4], collapse = "")
    
    ################ extract TREB_data All (pages 3,4) by property type (pages 7-24)
    final_treb_months <- TREB_month_parse(month, year)
      
    #pushing treb data to MongoDB
    # create local db 
    if(nrow(final_treb_months)>0){
      outputColl <- mongodb_connection('Property4D', 'TREB_data')
      outputColl$insert(final_treb_months)
    }
    
    ############### extract TREB_pricewise, page 2 SALES BY PRICE RANGE AND HOUSE TYPE
    price_data_months <- TREB_pricewise(month, year)
    
    if(nrow(price_data_months)>0){
      all_propTypes = unique(price_data_months$type)
      
      # pushing the records into TREB_priceWiseSplit collection in MongoDB
      outputColl <- mongodb_connection('Property4D', 'TREB_priceWiseSplit')
      indb <- outputColl$find()
      
      for(p in 1:length(all_propTypes)){
        tmp1 <- price_data_months[price_data_months$type == all_propTypes[p], 1:4]
        q <- paste0('{"type":"',all_propTypes[p],'"}')
        u <- paste0('{"$push":','{"priceSplit":{ "$each":',toJSON(tmp1),'}}}')
        
        # next line is only required first time
        if(nrow(indb)<length(all_propTypes)){
          outputColl$insert(q,u)
          outputColl$update(q,u)
          indb <- outputColl$find()
        } else{
          outputColl$update(q,u)
        }  
        rm(tmp1,q,u)
      }
    }
  
    ############### extract TREB_rates, page 1 Economic Indicators
    rate_data_months <- TREB_rates(month, year)
      
    if(nrow(rate_data_months)>0){
      #pushing treb data to MongoDB
      # create local db 
      outputColl <- mongodb_connection('Property4D', 'TREB_rates')
    
      boc.rate <- rate_data_months[rate_data_months$name == 'boc overnight rate',2:4]
      q <- paste0('{"name":"BoC Overnight Rate"}')
      u <- paste0('{"$push":','{"data":{ "$each":',toJSON(boc.rate),'}}}')
      # next line is only required first time
      if(length(outputColl$find(q))==0){
        outputColl$insert(q,u)
        outputColl$update(q,u)
        indb <- outputColl$find()
      } else{
        outputColl$update(q,u)
      }  
      rm(boc.rate, q,u)
      
      prime.rate <- rate_data_months[rate_data_months$name == 'prime rate',2:4]
      q <- paste0('{"name":"Prime Rate"}')
      u <- paste0('{"$push":','{"data":{ "$each":',toJSON(prime.rate),'}}}')
      if(length(outputColl$find(q))==0){
        outputColl$insert(q,u)
        outputColl$update(q,u)
      }else{
        outputColl$update(q,u)
      }
      rm(prime.rate, q,u)
      
      mort.rate <- rate_data_months[rate_data_months$name == 'mortgage rate',2:4]
      q <- paste0('{"name":"Mortgage Rate"}')
      u <- paste0('{"$push":','{"data":{ "$each":',toJSON(mort.rate),'}}}')
      if(length(outputColl$find(q))==0){
        outputColl$insert(q,u)
        outputColl$update(q,u)
      }else{
        outputColl$update(q,u)
      }
      rm(mort.rate, q,u)
      
      # second set of rates
      gdp.rate <- rate_data_months[rate_data_months$name == 'Real GDP Growth',2:4]
      empl.rate <- rate_data_months[rate_data_months$name == 'Employment Rate Toronto',2:4]
      unempl.rate <- rate_data_months[rate_data_months$name == 'Unemployment Rate Toronto',2:4]
      infl.rate <- rate_data_months[rate_data_months$name == 'Inflation Rate',2:4]
      q <- paste0('{"name":"Real GDP Growth"}')
      u <- paste0('{"$push":','{"data":{ "$each":',toJSON(gdp.rate),'}}}')
      if(length(outputColl$find(q))==0){
        outputColl$insert(q,u)
        outputColl$update(q,u)
      }else{
        outputColl$update(q,u)
      }
      rm(gdp.rate, q,u)
      
      q <- paste0('{"name":"Employment Rate Toronto"}')
      u <- paste0('{"$push":','{"data":{ "$each":',toJSON(empl.rate),'}}}')
      if(length(outputColl$find(q))==0){
        outputColl$insert(q,u)
        outputColl$update(q,u)
      }else{
        outputColl$update(q,u)
      }
      rm(empl.rate, q,u)
      
      q <- paste0('{"name":"Unemployment Rate Toronto"}')
      u <- paste0('{"$push":','{"data":{ "$each":',toJSON(unempl.rate),'}}}')
      if(length(outputColl$find(q))==0){
        outputColl$insert(q,u)
        outputColl$update(q,u)
      }else{
        outputColl$update(q,u)
      }
      rm(unempl.rate, q,u)
      
      q <- paste0('{"name":"Inflation Rate"}')
      u <- paste0('{"$push":','{"data":{ "$each":',toJSON(infl.rate),'}}}')
      if(length(outputColl$find(q))==0){
        outputColl$insert(q,u)
        outputColl$update(q,u)
      }else{
        outputColl$update(q,u)
      }
      rm(infl.rate, q,u)
    }
    
    # increment month to continue
    month(latet_month) <- month(latet_month) + 1
  }
}

