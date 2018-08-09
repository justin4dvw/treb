from util import *
import sys, os
paths=[
os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), 'util')
]
for each in paths:
    sys.path.append(each)
from get_report import *
from load_links import *
import logging

logging.basicConfig(format='%(asctime)s %(message)s')


keys={}

today = get_current_date()

keys['base_url'] = read_namespace_link('treb', filename='../../config/links.yaml')
keys['year'] = today.year
keys['ym'] = get_year_month(today.year, today.month)

download_url=generate_url(keys)

download_report(download_url,
                saved_file_name='treb_{year}_{month}.pdf'.format(year=today.year, month=today.month)
                )
