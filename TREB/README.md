## TREB data mining code:
- Data maining of TREB montly reports from http://www.trebhome.com/market_news/market_watch/, starting in January 01, 2015 up to current date
- Two main code processess, see each below and how to run from command line

###  init_TREB.R: Initializes from scratch TREB data collection
## TO RUN: $ RScript.exe init_TREB.R
- creates db:Property4D
- extract TREB_data from pages 3,4 (by summary) and by property type (from pages 7-24), sends formatted data to coll:TREB_data
- extracts TREB_pricewise, from page 2 SALES BY PRICE RANGE AND HOUSE TYPE, sends to coll:TREB_pricewise
- extracts TREB_rates, from page 1 Economic Indicators, sends to coll:TREB_rates


### currdate_TREB.R: Collects TREB data base on sys.date() time-stamp
## TO RUN: $ RScript.exe currdate_TREB.R
- Code base similar to init_TREB.R but this checks time_stamp of data collected since last time 
- Ensures no duplication of records in database by checking most up-to-date report on database
- This script can be scheduled to run frequently (e.g once every month on the 5th day)