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
import argparse


parser = argparse.ArgumentParser(description='Process reports provided by TREB')
parser.add_argument('--start_date',   help='an integer for the accumulator')
parser.add_argument('--end_date',  help='an integer for the accumulator')
parser.add_argument('--refresh', action='store_true', help='This option will delete all records between \
                                                            the provided period and reenter all records')
parser.add_argument('--collection', help='This option will only get records for the collection provided')
parser.add_argument('--no_s3', action='store_false', help='This option will not create a copy of the records to s3')
parser.add_argument('--no_download', action='store_true', help='This option will not create a copy of the records to s3')

args=parser.parse_args()
#initate logging config
"""
p=PDFParser('treb_py/data/treb_2015_4.pdf', config_filename=parent_dir+'/config/treb_report_page_info.yaml')
for page in [2]:
    p.load_page(page, mapping_file=parent_dir+'/config/region_mapping.yaml')
sys.exit()
"""
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

    if args.start_date:
        last_report_date= datetime.datetime.strptime(args.start_date,'%Y-%m-%d').date()

    if args.end_date:
        today= datetime.datetime.strptime(args.end_date,'%Y-%m-%d').date()

    rpts[collection]=find_report_range(today, last_report_date )

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

    if not args.no_download:
        logging.info("Downloading report for {rpt_dt} as {filename}".format(rpt_dt=rpt_dt.strftime('%Y-%m-%d'), filename=filename))
        download_report(download_url,
                        saved_file_name=filename
                        )

        logging.info("Finished downloading report")
    files[rpt_dt]=filename

col={}
## parse reports and inject records
# capture total number of records
_n=0
for each in files:

    fname = files[each].replace(parent_dir+'/','')
    logging.info("processing file: {0}".format(fname))
    if os.path.isfile(fname):
        p=PDFParser(fname, config_filename=parent_dir+'/config/treb_report_page_info.yaml')
        if args.collection:

            col['collection_name']={'page_start':collections[args.collection]['page_start'],
                                    'page_end':collections[args.collection]['page_end'],
                                    'exclusion': get_exclusion(collections[args.collection])
                                    }

        else:
            for _collection in collections:
                col[_collection]={'page_start':collections[_collection]['page_start'],
                                'page_end':collections[_collection]['page_end'],
                                'exclusion': get_exclusion(collections[_collection])
                                }
        for _collection in col:
            page=col[_collection]['page_start']
            while page <= col[_collection]['page_end']:
                logging.info("Parsing page # {0}".format(page))
                if page not in col[_collection]['exclusion']:
                    p.load_page(page, mapping_file=parent_dir+'/config/region_mapping.yaml')
                    records=p.export_data(page, output_type='dict', orient='records')
                    _n += insert_record(db,'TREB_data_test',records)
                page+=1
logging.info("Finished loading; total {0} records inserted".format(_n))
