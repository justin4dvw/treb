import datetime
import urllib2
import requests
import logging
from dateutil.relativedelta import relativedelta

def generate_url(keys={}, str_format='{base_url}/{year}/mw{ym}.pdf'):
    try:
        _url=str_format.format(**keys)
    except:
        pass

    return _url

def get_year_month(year,month):
    yr=str(year)[2:]

    if month<10:
        mth='0'+str(month)
    else:
        mth=str(month)

    return yr + mth

def find_report_range(today,last_report_date):
    report_range_dates=[]

    while today>=last_report_date:
        if today.year>last_report_date.year or today.month>=last_report_date.month:
            report_range_dates.append(last_report_date)
            last_report_date=last_report_date + relativedelta(months=1)



    return report_range_dates


def download_report(download_url, saved_file_name=None):

    r = requests.get(download_url)

    if r.status_code==200:
        response = urllib2.urlopen(download_url)

        if not saved_file_name:
            filename = download_url[download_url.rindex('/')+1:]
        else:
            filename=saved_file_name
        with open(filename, 'wb') as f:
            f.write(response.read())
        logging.info(
        "Finished downloading the report"
        )

    else:
        logging.warning(
        "Did not download, received status code {code}".format(code=r.status_code)
        )
