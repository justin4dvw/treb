import sys, os, platform
# as it is not packaged, we will have to append paths mamnually
parent_dir=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
paths=[
    parent_dir + '/utils',
    parent_dir + '/treb_py',
]

for each in paths:
    sys.path.append(each)

from mongo_transactions import *
from extract_report import PDFParser
from get_report import *
import datetime
import logging
from load_links import *


#initate logging config
today=datetime.date.today()
logging.basicConfig(format='%(asctime)s %(message)s',
                    filename="treb_report_log_{date}.txt".format(date=today.strftime('%Y-%m-%d')),
                    level=logging.INFO)

## initiate client with Property4D db
logging.info("Connecting to mongodb")
client=connect_to_mongo()
db=client['Property4D']
logging.info("connected to Property4D")



logging.info("Obtaining report parsing ranges for each dataset")
collections=read_namespace_link('collections', filename=parent_dir+ '/config/treb_report_page_info.yaml')
rpts={}
rpt_dates=[]

for collection in collections:
    if not collections[collection]['nested']:
        date_col=collections[collection]['date_col']
        try:
            last_report_date=db[collection].find().sort([(date_col,-1)]).limit(1)[0][date_col].date()
        except:
            logging.info("Could not locate record, starting from 2015")
            last_report_date=datetime.date(2015,1,1)

    rpts[collection]=find_report_range(today, last_report_date)

    rpt_dates=rpt_dates+rpts[collection]

deduped_rpt_dt=list(set(rpt_dates))
keys={}
keys['base_url'] = read_namespace_link('treb', filename=parent_dir+ '/config/links.yaml')


##download reports
files={}
for rpt_dt in deduped_rpt_dt:

    keys['year'] = rpt_dt.year
    keys['ym'] = get_year_month(rpt_dt.year, rpt_dt.month)
    download_url=generate_url(keys)
    #stupid windows filesystem...

    filename='{loc}/treb_{year}_{month}.pdf'.format(loc=parent_dir+'/treb_py/data',year=rpt_dt.year, month=rpt_dt.month)
    logging.info("Downloading report for {rpt_dt} as {filename}".format(rpt_dt=rpt_dt.strftime('%Y-%m-%d'), filename=filename))

    download_report(download_url,
                    saved_file_name=filename
                    )
    logging.info("Finished downloading report")
    files[rpt_dt]=filename

# check eligibility in insert records
for _coll in rpts:
    if
