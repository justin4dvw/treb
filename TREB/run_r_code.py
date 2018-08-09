import os
from pymongo import MongoClient

client = MongoClient('localhost', 27017)
os.system('Rscript currdate_TREB.R')
