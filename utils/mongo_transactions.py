from pymongo import MongoClient
import sys
import urllib
sys.path.append('../treb_py')

from load_links import load_credentials



def connect_to_mongo(credential_file=None):
    _c = load_credentials(credential_file)
    if credential_file:
        _c['password']=urllib.quote(_c['password'])
        _c['cred']='{username}:{password}@'.format(**_c)
    else:
        _c['cred']=''

    address='mongodb://{cred}{ServerAddress}:{port}'.format(**_c)

    client=MongoClient(address)

    return client

def is_dupe(db, collection, record):
    try:
        db[collection].find(record)[0]
        return True
    except:
        return False


def insert_record(db,collection,record):
    if isinstance(record, dict):
        if not is_dupe(db,collection,record):
            db[collection].insert_one(record)
        return True
    elif isinstance(record, list):
        records=[r for r in record if not is_dupe(db_collection,r)]
        db[collection].insert_many(records)
        return True
