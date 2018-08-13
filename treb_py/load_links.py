import yaml

def read_namespace_link(namespace, filename='../config/links.yaml'):

    with open(filename,'r') as f:
        try:
            _content = yaml.load(f)
        except yaml.YAMLError as exc:
            print(exc)

    content=_content[namespace]
    return content

def load_credentials(filename=None):

    if not filename:
        credentials={'ServerAddress':'localhost',
                    'port':'27017'
                    }
    else:
        with open(filename, 'r') as f:
            try:
                credentials = yaml.load(f)
            except yaml.YAMLError as exc:
                print(exc)

    return credentials

def load_mapping(filename=None):

    with open(filename,'r') as f:
        try:
            _content = yaml.load(f)
        except yaml.YAMLError as exc:
            print(exc)

    return _content

def get_exclusion(config):
    _exclusion=[]
    if 'exclude' in config:
        if '-' in config['exclude']:
            _exclusion = [i for i in range(config['exclude'].split('-'))]
        elif ',' in config['exclude']:
            _exclusion = config['exclude'].split(',')
        else:
            _exclusion = config['exclude']
    exclusion=[int(i) for i in _exclusion ]
    return exclusion
