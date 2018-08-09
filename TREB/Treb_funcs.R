
# func for capturing TREB data from page 7 to 24 and 3,4
TREB_month_parse <- function(month, year){
  # path of the TREB data files: path <- 'C:/Users/Cristina/Cristina4dvw/production_code/TREB/TREB_data/'
  # month: list of two digits for month or months: month <- c('01', '02', '03', '04', '05','06', '07', '08', '09', '10','11', '12')
  # year: last two digits of year: year <- 15
  wd <- getwd() 
  print(wd)
  # check existing files
  if(!dir.exists(paste0(wd,"/TREB_data/"))){
    dir.create("TREB_data", showWarnings = TRUE, recursive = FALSE, mode = "0777")
  } 
  path <- paste0(wd,"/TREB_data/")
  library('tabulizer')
  treb_url <- "http://www.trebhome.com/market_news/market_watch"
  treb_year <- paste0('20',year)
  
  # run the loop over months after changing year above
  final_treb_months = data.frame()
  for(m in 1:length(month)){ 
    file.name <- paste0('mw', year, month[m])
    treb_filename = file = paste0(path, file.name, '.pdf')
    treb_file <- paste(treb_url, treb_year, paste0(file.name,'.pdf'), sep = '/')
    
    # check that file exists if not downloaded it
    filedownloaded = FALSE
    if(!file.exists(treb_filename)){
      res <- tryCatch(curl::curl_fetch_disk(treb_file, treb_filename),  error = function(e) e)
      if(res$status_code==404){
        # file downloaded
        print(paste("Attempting to capture current month TREB data. File not found: ",paste0("20",year), "-", month[m], sep=" "))
        unlink(treb_filename)
        next
      }
      if(res$status_code==200){
        filedownloaded = TRUE
      }
    } else filedownloaded = TRUE
    
    # process file
    if(filedownloaded){
      print(paste("File found and downloaded:",paste0("20",year), "-", month[m], "@", Sys.time(), sep=" "))
      path.file <-  paste0(path, 'tmp/')
      if(!dir.exists(path.file)){
        dir.create(path.file, showWarnings = TRUE, recursive = FALSE, mode = "0777")
      } 
      ## tabulizer Split PDF into separate pages
      split_pdf(treb_filename, outdir = path.file)
      
      # counters for looping the data over, months and different pages in file
      pageInfo <- seq(7,24)
      propType <- c('Detached', 'Detached','Semi_detached', 'Semi_detached','Condo_town','Condo_town', 'Condo','Condo', 'Link', 'Link',
                    'Row_attached_town', 'Row_attached_town','Coop_apt','Coop_apt', 'Detached_condo', 'Detached_condo','Coowner_apt','Coowner_apt')
      
      #%%%%%%%%%%%%%% stage 1 -  for capturing data from page 7 to 24
      # header of final file to hold all the records
      total1 <- data.frame(type = as.character(), region = as.character(), subRegion = as.character(), numberOfSales = as.character(),
                           salesAmount = as.character(), avgPrice = as.character(), medianPrice = as.character(), newListings = as.character(), 
                           activeListings = as.character(), avgSPLP = as.character(), avgDOM = as.character(), reportDate = as.character(), stringsAsFactors = F)
      
      # process each relevant page
      i = 1
      while(i <= length(pageInfo)){
        print(paste0("...Processing TREB report year: ","20", year, "-", month[m], " page: ",pageInfo[i]))
        final <- total1[0,]
        final[1:65,] <- NA
        final$reportDate <- paste(paste0('20', year), month[m],'01', sep = "/")
        final$type <- propType[i]
        if(pageInfo[i] < 10) ind.file <- paste0(path.file, file.name, '0', pageInfo[i], '.pdf') 
        else ind.file <- paste0(path.file, file.name, pageInfo[i], '.pdf')
        
        print(ind.file)
        tmp.table <- extract_tables(ind.file, method = 'matrix')
        for(j in 1:length(tmp.table)){
          if(nrow(tmp.table[[j]])>1) tmp.table <- as.data.frame(tmp.table[[j]], stringsAsFactors = F)
        }
        # correct some inconsistencies in table after 2015/07
        if(!"Essa" %in% tmp.table[39:42,]$V1){
          # try options
          if(any(tmp.table$V1=="EGswsiallimbury")){
            tmp.table$V1[tmp.table$V1=="EGswsiallimbury"] <- "Essa"
          }
          if(any(tmp.table$V1=="GEswsiallimbury")){
            tmp.table$V1[tmp.table$V1=="GEswsiallimbury"] <- "Essa"
          }
        }
        if(!"Bradford West Gwillimbury" %in% tmp.table[39:42,]$V1){
          tmp.table$V1[tmp.table$V1=="Bradford West"] <- "Bradford West Gwillimbury"
        }
        print(tmp.table[39:42,])
        
        # remove empty columns if any
        non_na_cols <- c(1:ncol(tmp.table))[c(unname(sapply(tmp.table[5,], function(x) x!="")))]
        tmp.table <- tmp.table[,c(non_na_cols)]
        
        for(j in 1:nrow(tmp.table)){
          if(grepl(pattern = "Burlington", tmp.table[j,1]) & !grepl(pattern = "\rBurlington", tmp.table[j,1])) break
        }
        
        final$region[1:4] <- 'Halton'
        final[1:4, 3:11] <- tmp.table[j:c(j+3), 1:9]
        final$region[5:7] <- 'Peel'
        final[5:7, 3:11] <- tmp.table[c(j+5):c(j+7), 1:9]
        ## detect if summary of city of Toronto present
        if(grepl(pattern = "TURN PAGE", tmp.table[c(j+9),1])){
          final$region[8:16] <- 'York'
          final[8:16, 3:11] <- tmp.table[c(j+13):c(j+21), 1:9]
          final$region[17:24] <- 'Durham'
          final[17:24, 3:11] <- tmp.table[c(j+23):c(j+30), 1:9]
          final$region[25] <- 'Dufferin'
          final[25, 3:11] <- tmp.table[c(j+32), 1:9]
          final$region[26:30] <- 'Simcoe'
          final[26:30, 3:11] <- tmp.table[c(j+34):c(j+38), 1:9]
          lrow <- 31
        }
        if(grepl(pattern = "Toronto", tmp.table[c(j+9),1])){
          # account for differences
          final[66:68,] <- NA
          final$reportDate <- paste(paste0('20', year), month[m],'01', sep = "/")
          final$type <- propType[i]
          final$region[8:10] <- 'Toronto'
          final[8:10, 3:11] <- tmp.table[c(j+9):c(j+11), 1:9]
          final$region[11:19] <- 'York'
          final[11:19, 3:11] <- tmp.table[c(j+13):c(j+21), 1:9]
          final$region[20:27] <- 'Durham'
          final[20:27, 3:11] <- tmp.table[c(j+23):c(j+30), 1:9]
          final$region[28] <- 'Dufferin'
          final[28, 3:11] <- tmp.table[c(j+32), 1:9]
          final$region[29:33] <- 'Simcoe'
          final[29:33, 3:11] <- tmp.table[c(j+34):c(j+38), 1:9]
          lrow <- 34
        }
        
        # processing next page
        print(paste0("...Processing TREB report year: ","20", year, "-", month[m], " page: ",pageInfo[i+1]))
        if(pageInfo[i+1] < 10) ind.file1 <- paste0(path.file, file.name, '0', pageInfo[i+1], '.pdf') 
        else  ind.file1 <- paste0(path.file, file.name, pageInfo[i+1], '.pdf')
        
        print(ind.file1)
        tmp.table1 <- extract_tables(ind.file1, method = 'matrix')
        for(j in 1:length(tmp.table1)){
          if(nrow(tmp.table1[[j]])>1) tmp.table1 <- data.frame(tmp.table1[[j]], stringsAsFactors = F)
        }
        # remove empty columns if any
        non_na_cols <- c(1:ncol(tmp.table1))[c(unname(sapply(tmp.table1[5,], function(x) x!="")))]
        tmp.table1 <- tmp.table1[,c(non_na_cols)]
        
        for(j in 1:nrow(tmp.table1)){
          if(grepl(pattern = "Toronto West", tmp.table1[j,1])) break
        }
        
        final$region[lrow:c(lrow+9)] <- 'Toronto West'
        final[lrow:c(lrow+9), 3:11] <- tmp.table1[c(j+1):c(j+10), 1:9]
        final$region[c(lrow+10):c(lrow+23)] <- 'Toronto Central'
        final[c(lrow+10):c(lrow+23), 3:11] <- tmp.table1[c(j+12):c(j+25), 1:9]
        final$region[c(lrow+24):c(lrow+34)] <- 'Toronto East'
        final[c(lrow+24):c(lrow+34), 3:11] <- tmp.table1[c(j+27):c(j+37), 1:9]
        
        total1 <- rbind.data.frame(total1, final)
        rm(final, tmp.table, tmp.table1, ind.file, ind.file1)
        i = i+2
      }
      
      # standardizing fields - removing currency symbol, comma etc.
      for(i in 1:nrow(total1)){
        total1[i,] <-  sapply(total1[i,], function(x) gsub('[-,\\$%]', '',x))
        total1[i,] <- sapply(total1[i,], function(x) gsub('[[:space:]]', '',x))
      }
      
      # converting data types to numeric
      total1$numberOfSales <- as.numeric(total1$numberOfSales)
      total1$salesAmount <- as.double(total1$salesAmount)
      total1$avgPrice <- as.numeric(total1$avgPrice)
      total1$medianPrice <- as.numeric(total1$medianPrice)
      total1$newListings <- as.numeric(total1$newListings)
      total1$activeListings <- as.numeric(total1$activeListings)
      total1$avgSPLP <- as.numeric(total1$avgSPLP)
      total1$avgDOM <- as.numeric(total1$avgDOM)
      total1$reportDate <- as.POSIXct(strptime(total1$reportDate, format = '%Y/%m/%d'))
      
      ############# stage 2 -  for capturing data from page 3 & 4
      all_type <- data.frame(type = as.character(), region = as.character(), subRegion = as.character(), numberOfSales = as.character(),
                             salesAmount = as.character(), avgPrice = as.character(), medianPrice = as.character(), newListings = as.character(), 
                             snlr = as.character(), activeListings = as.character(), mosInv = as.character(), avgSPLP = as.character(),
                             avgDOM = as.character(), reportDate = as.character(), stringsAsFactors = F)
      
      # fill in some columns and prep-data
      tmp.all <- all_type[0,]
      tmp.all[1:65,] <- NA
      tmp.all$reportDate <- paste(paste0('20', year), month[m],'01', sep = "/")
      tmp.all$type <- 'All'
      
      # extract table from page 3
      print(paste0("...Processing TREB report year: ","20", year, "-", month[m], " page: 03"))
      tmp.file <- paste0(path.file, file.name, '03','.pdf')
      tmp.table <- extract_tables(tmp.file, method = 'matrix')
      for(j in 1:length(tmp.table)){
        if(nrow(tmp.table[[j]])>5) tmp.table <- data.frame(tmp.table[[j]], stringsAsFactors = F)
      }
      
      # remove empty columns if any
      non_na_cols <- c(1:ncol(tmp.table))[c(unname(sapply(tmp.table[5,], function(x) x!="")))]
      tmp.table <- tmp.table[,c(non_na_cols)]
      
      # correct some inconsistencies in table after 2015/07
      if(!"Essa" %in% tmp.table[39:42,]$X1){
        tmp.table$X1[tmp.table$X1=="Bradford West"] <- "Bradford West Gwillimbury"
        # try options
        if(any(tmp.table$X1=="EGswsiallimbury")){
          tmp.table$X1[tmp.table$X1=="EGswsiallimbury"] <- "Essa"
        }
        if(any(tmp.table$X1=="GEswsiallimbury")){
          tmp.table$X1[tmp.table$X1=="GEswsiallimbury"] <- "Essa"
        }
      }
      if(!"Bradford West Gwillimbury" %in% tmp.table[39:42,]$X1){
        tmp.table$X1[tmp.table$X1=="Bradford West"] <- "Bradford West Gwillimbury"
      }
      print(tmp.table[39:42,])
      
      for(j in 1:nrow(tmp.table)){
        if(grepl(pattern = "Burlington", tmp.table[j,1]) & !grepl(pattern = "\rBurlington", tmp.table[j,1])) break
      }
      
      tmp.all$region[1:4] <- 'Halton'
      tmp.all[1:4, 3:13] <- tmp.table[j:c(j+3), 1:11]
      tmp.all$region[5:7] <- 'Peel'
      tmp.all[5:7, 3:13] <- tmp.table[c(j+5):c(j+7), 1:11]
      ## detect if summary of city of Toronto present
      if(grepl(pattern = "TURN PAGE", tmp.table[c(j+9),1])){
        tmp.all$region[8:16] <- 'York'
        tmp.all[8:16, 3:13] <- tmp.table[c(j+12):c(j+20), 1:11]
        tmp.all$region[17:24] <- 'Durham'
        tmp.all[17:24, 3:13] <- tmp.table[c(j+22):c(j+29), 1:11]
        tmp.all$region[25] <- 'Dufferin'
        tmp.all[25, 3:13] <- tmp.table[c(j+31), 1:11]
        tmp.all$region[26:30] <- 'Simcoe'
        tmp.all[26:30, 3:13] <- tmp.table[c(j+33):c(j+37), 1:11]
        lrow <- 31
      }
      if(grepl(pattern = "Toronto", tmp.table[c(j+9),1])){
        # account for differences
        tmp.all[66:68,] <- NA
        tmp.all$reportDate <- paste(paste0('20', year), month[m],'01', sep = "/")
        tmp.all$type <- 'All'
        tmp.all$region[8:10] <- 'Toronto'
        tmp.all[8:10, 3:13] <- tmp.table[c(j+9):c(j+11), 1:11]
        tmp.all$region[11:19] <- 'York'
        tmp.all[11:19, 3:13] <- tmp.table[c(j+13):c(j+21), 1:11]
        tmp.all$region[20:27] <- 'Durham'
        tmp.all[20:27, 3:13] <- tmp.table[c(j+23):c(j+30), 1:11]
        tmp.all$region[28] <- 'Dufferin'
        tmp.all[28, 3:13] <- tmp.table[c(j+32), 1:11]
        tmp.all$region[29:33] <- 'Simcoe'
        tmp.all[29:33, 3:13] <- tmp.table[c(j+34):c(j+38), 1:11]
        lrow <- 34
      }
      
      
      # extract table from page 4
      print(paste0("...Processing TREB report year: ","20", year, "-", month[m], " page: 04"))
      tmp.file1 <- paste0(path.file, file.name, '04','.pdf')
      tmp.table1 <- extract_tables(tmp.file1, method = 'matrix')
      for(j in 1:length(tmp.table1)){
        if(nrow(tmp.table1[[j]])>5) tmp.table1 <- data.frame(tmp.table1[[j]], stringsAsFactors = F)
      }
      
      # remove empty columns if any
      non_na_cols <- c(1:ncol(tmp.table1))[c(unname(sapply(tmp.table1[5,], function(x) x!="")))]
      tmp.table1 <- tmp.table1[,c(non_na_cols)]
      
      for(j in 1:nrow(tmp.table1)){
        if(grepl(pattern = "Toronto West", tmp.table1[j,1])) break
      }
      
      tmp.all$region[lrow:c(lrow+9)] <- 'Toronto West'
      tmp.all[lrow:c(lrow+9), 3:13] <- tmp.table1[c(j+1):c(j+10), 1:11]
      tmp.all$region[c(lrow+10):c(lrow+23)] <- 'Toronto Central'
      tmp.all[c(lrow+10):c(lrow+23), 3:13] <- tmp.table1[c(j+12):c(j+25), 1:11]
      tmp.all$region[c(lrow+24):c(lrow+34)] <- 'Toronto East'
      tmp.all[c(lrow+24):c(lrow+34), 3:13] <- tmp.table1[c(j+27):c(j+37), 1:11]
      all_type <- rbind.data.frame(all_type, tmp.all)
      rm(tmp.all, tmp.table, tmp.table1, tmp.file, tmp.file1)
      
      # standardizing fields - removing currency symbol, comma etc.
      for(i in 1:nrow(all_type)){
        all_type[i,] <- sapply(all_type[i,], function(x) gsub('[-,\\$%]', '',x))
        all_type[i,] <- sapply(all_type[i,], function(x) gsub('[[:space:]]', '',x))
      }
      
      # converting data types to numeric
      all_type$numberOfSales <- as.numeric(all_type$numberOfSales)
      all_type$salesAmount <- as.double(all_type$salesAmount)
      all_type$avgPrice <- as.numeric(all_type$avgPrice)
      all_type$medianPrice <- as.numeric(all_type$medianPrice)
      all_type$newListings <- as.numeric(all_type$newListings)
      all_type$snlr <- as.numeric(all_type$snlr)
      all_type$activeListings <- as.numeric(all_type$activeListings)
      all_type$mosInv <- as.numeric(all_type$mosInv)
      all_type$avgSPLP <- as.numeric(all_type$avgSPLP)
      all_type$avgDOM <- as.numeric(all_type$avgDOM)
      all_type$reportDate <- as.POSIXct(strptime(all_type$reportDate, format = '%Y/%m/%d'))
      
      #combining stage 1 & stage 2 data
      ## adding two more columns in stage 1 data -  snlr and mosInv
      total2 <- data.frame(type = total1$type, region = total1$region, subRegion = total1$subRegion, numberOfSales = total1$numberOfSales,
                           salesAmount = total1$salesAmount, avgPrice = total1$avgPrice, medianPrice = total1$medianPrice, newListings = total1$newListings,
                           snlr = as.numeric(NA), activeListings = total1$activeListings, mosInv = as.numeric(NA), avgSPLP = total1$avgSPLP,
                           avgDOM = total1$avgDOM, reportDate = total1$reportDate)
      final_treb <- rbind.data.frame(all_type, total2)
      # append 
      final_treb_months <- rbind.data.frame(final_treb_months, final_treb)
      unlink(paste0(path.file,'*'))
    }
  }
  return(final_treb_months)
}

# func for capturing TREB data from page 2, by Property type sold
TREB_pricewise <- function(month, year){
  # path of the TREB data files: path <- 'C:/Users/Cristina4dvw/Data/TREB_data/'
  # month: list of two digits for month or months: month <- c('01', '02', '03', '04', '05','06', '07', '08', '09', '10','11', '12')
  # year: last two digits of year: year <- 17
  wd <- getwd() 
  print(wd)
  # check existing files
  if(!dir.exists(paste0(wd,"/TREB_data/"))){
    dir.create("TREB_data", showWarnings = TRUE, recursive = FALSE, mode = "0777")
  } 
  path <- paste0(wd,"/TREB_data/")
  library('tabulizer')
  treb_url <- "http://www.trebhome.com/market_news/market_watch"
  treb_year <- paste0('20',year)
  
  # run the loop over months after changing year above
  price_data_months = data.frame()
  for(m in 1:length(month)){ 
    file.name <- paste0('mw', year, month[m])
    treb_filename = file = paste0(path, file.name, '.pdf')
    treb_file <- paste(treb_url, treb_year, paste0(file.name,'.pdf'), sep = '/')
    
    # check that file exists if not downloaded it
    filedownloaded = FALSE
    if(!file.exists(treb_filename)){
      res <- tryCatch(curl::curl_fetch_disk(treb_file, treb_filename),  error = function(e) e)
      if(res$status_code==404){
        # file downloaded
        print(paste("Attempting to capture current month by Property type sales. File not found: ",paste0("20",year), "-", month[m], sep=" "))
        unlink(treb_filename)
        next
      }
      if(res$status_code==200){
        filedownloaded = TRUE
      }
    } else filedownloaded = TRUE
    
    # process file
    if(filedownloaded){
      print(paste("File found and downloaded:",paste0("20",year), "-", month[m], "@", Sys.time(), sep=" "))
      path.file <-  paste0(path, 'tmp/')
      if(!dir.exists(path.file)){
        dir.create(path.file, showWarnings = TRUE, recursive = FALSE, mode = "0777")
      } 
      
      propType <- c('Dummy','Detached','Semi_detached', 'Row_attached_town','Condo_town', 'Condo', 'Link',  'Coop_apt', 
                    'Detached_condo', 'Coowner_apt')
      
      price.data <- data.frame(priceRange = as.character(), numberSold = as.numeric(), reportDate = as.character(), 
                               type = as.character(), stringsAsFactors = F)
      
      tmp.table <- extract_tables(treb_filename, method = 'data.frame',pages = 2, area = list(c(50,20,250,1000)))[[1]]
      for(p in 2:length(propType)){
        tmp <- price.data[0,]
        tmp[1:15,] <- NA
        tmp$type <- propType[p]
        tmp$reportDate <- paste(paste0('20',year), month[m], '01', sep = '/')
        tmp$priceRange <- tmp.table[1:15,1]
        tmp$numberSold <- tmp.table[1:15,p]
        price.data <- rbind.data.frame(price.data, tmp)
        rm(tmp)
      }
      
      # Field data type conversion
      for(i in 1:nrow(price.data)){
        price.data$numberSold[i] <- sapply(price.data$numberSold[i], function(x) gsub('[-,\\$%]', '',x))
        price.data$numberSold[i] <- sapply(price.data$numberSold[i], function(x) gsub('[[:space:]]', '',x))
      }
      
      price.data$numberSold <- as.numeric(price.data$numberSold)
      price.data$reportDate <- as.POSIXct(strptime(price.data$reportDate, format = '%Y/%m/%d'))
      # append 
      price_data_months <- rbind.data.frame(price_data_months, price.data)
    }
  }
  
  return(price_data_months)
}

# func for capturing TREB data from page 1, industry rate
TREB_rates <- function(month, year){
  # month: list of two digits for month or months: month <- c('01', '02', '03', '04', '05','06', '07', '08', '09', '10','11', '12')
  # year: last two digits of year: year <- 17
  wd <- getwd() 
  print(wd)
  # check existing files
  if(!dir.exists(paste0(wd,"/TREB_data/"))){
    dir.create("TREB_data", showWarnings = TRUE, recursive = FALSE, mode = "0777")
  } 
  path <- paste0(wd,"/TREB_data/")
  library('tabulizer')
  treb_url <- "http://www.trebhome.com/market_news/market_watch"
  treb_year <- paste0('20',year)
  
  # run the loop over months after changing year above
  rate_data_months = data.frame()
  for(m in 1:length(month)){ 
    file.name <- paste0('mw', year, month[m])
    treb_filename = file = paste0(path, file.name, '.pdf')
    treb_file <- paste(treb_url, treb_year, paste0(file.name,'.pdf'), sep = '/')
    
    # check that file exists if not downloaded it
    filedownloaded = FALSE
    if(!file.exists(treb_filename)){
      res <- tryCatch(curl::curl_fetch_disk(treb_file, treb_filename),  error = function(e) e)
      if(res$status_code==404){
        # file downloaded
        print(paste("Attempting to capture current month industry rates. File not found: ",paste0("20",year), "-", month[m], sep=" "))
        unlink(treb_filename)
        next
      }
      if(res$status_code==200){
        filedownloaded = TRUE
      }
    } else filedownloaded = TRUE
    
    # process file
    if(filedownloaded){
      print(paste("File found and downloaded:",paste0("20",year), "-", month[m], "@", Sys.time(), sep=" "))
      path.file <-  paste0(path, 'tmp/')
      if(!dir.exists(path.file)){
        dir.create(path.file, showWarnings = TRUE, recursive = FALSE, mode = "0777")
      } 
      
      rate.data <- data.frame(name = as.character(), type = as.character(), value = as.character(), 
                              reportDate = as.character(), stringsAsFactors = F)
      # extract table
      tmp.table.rate <- extract_tables(file.name, method = 'data.frame',pages = 1, 
                                       area = list(c(80,10,420,190)), columns = list(150),
                                       guess = F)[[1]]
      print(tmp.table.rate)
      tmp.rate <- rate.data[0,]
      tmp.rate[1:9,] <- NA
      tmp.rate$reportDate <- paste(paste0('20',year), month[m], '01', sep = '/')
      tmp.rate$name[1] <- 'Real GDP Growth'
      tmp.rate$value[1] <- tmp.table.rate[2,2]
      tmp.rate$name[2] <- 'Employment Rate Toronto'
      tmp.rate$value[2] <- tmp.table.rate[5,2]
      tmp.rate$name[3] <- 'Unemployment Rate Toronto'
      tmp.rate$value[3] <- tmp.table.rate[8,2]
      tmp.rate$name[4] <- 'Inflation Rate'
      tmp.rate$value[4] <- tmp.table.rate[11,2]
      tmp.rate$name[5] <- 'boc overnight rate'
      tmp.rate$value[5] <- tmp.table.rate[14,2]
      tmp.rate$name[6] <- 'prime rate'
      tmp.rate$value[6] <- tmp.table.rate[16,2]
      tmp.rate$name[7:9] <- 'mortgage rate'
      tmp.rate$type[7:9] <- paste(c(1,3,5), 'year', sep = " ")
      tmp.rate$value[7:9] <- tmp.table.rate[18:20,2]
      
      # try another test if not detect straight
      if(!grepl(pattern = "[%]", tmp.rate$value[1])){
        tmp.table.rate <- extract_tables(file.name, method = 'data.frame',pages = 1, 
                                         area = list(c(80,10,420,190)), columns = list(125),
                                         guess = F)[[1]]
        rates <- c()
        for(k in 1:nrow(tmp.table.rate)){
          # detect all percentages in 2nd columns
          if(grepl(pattern = "[%]", tmp.table.rate[k,2])){
            #print(k)
            #print(tmp.table.rate[k,2])
            rates <- c(rates, unlist(str_extract_all(tmp.table.rate[k,2], "-?\\d+.\\d+%")))
          }
        }
        # format as df
        tmp.rate$value <- rates
      }
      
      rate.data <- rbind.data.frame(rate.data, tmp.rate)
      
      for(i in 1:nrow(rate.data)){
        rate.data$value[i] <- sapply(rate.data$value[i] , function(x) gsub('[-,\\$%]', '',x))
        rate.data$value[i]  <- sapply(rate.data$value[i] , function(x) gsub('[[:space:]]', '',x))
        rate.data$value[i]  <- sapply(rate.data$value[i] , function(x) gsub("[()]", "", x))
      }
      
      rate.data$value <- as.numeric(rate.data$value)
      rate.data$reportDate <- as.POSIXct(strptime(rate.data$reportDate, format = '%Y/%m/%d'))
      # append 
      rate_data_months <- rbind.data.frame(rate_data_months, rate.data)
    }
  }
  return(rate_data_months)
}
