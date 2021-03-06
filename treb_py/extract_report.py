from get_report import *
from load_links import *
import pandas as pd
import numpy as np
from tabula import read_pdf
import os
import logging
import re

class PDFParser:

    def __init__(self, report_name, config_filename='../config/treb_report_page_info.yaml',
                report_type='treb', has_multiple_tables=False,
                export_file_naming_convention='{report_name}_{segment}_{page}.csv'

                ):
        """
        Loads tables from pdf file based on borders presented

        inputs are:
        report_name: filename of the pdf file
        config_filename: specific way page should be parsed
        report_type: monthly data or others are desired

        """

        self.report_name = report_name
        self.report_type = report_type.lower()
        self.report_config = read_namespace_link(report_type.lower(), filename=config_filename)
        self.has_multiple_tables=has_multiple_tables
        self.data={}
        self.export_file_naming_convention=export_file_naming_convention

    def __format_table(self, table, actual_header_position=1, remove_bottom=1, has_header=False):
        replace_set={',':'','\$':'', '\%':''}
        table=table.replace(replace_set, regex=True)

        if remove_bottom==0:
            _tbl = pd.DataFrame(table.values[actual_header_position+1:], columns=table.values[actual_header_position])
        else:
            _tbl = pd.DataFrame(table.values[actual_header_position+1:-remove_bottom], columns=table.values[actual_header_position])

        #not null value for column detected - shift to right by 1
        
        if not isinstance(_tbl.columns[0], float) and not has_header :
            logging.info("table has non-null value for first column, shifting by one")
            _cols = list(_tbl.columns.isnull())
            _pos_shift_start = _cols.index(False)
            _pos_shift_end = _cols.index(True)

            cols=[None] + list(_tbl.columns[_pos_shift_start:_pos_shift_end]) \
                + list(_tbl.columns[_pos_shift_end+1:])

            _remainder= len(_cols) -  len(cols)
            _tbl.columns=cols

        if np.sum(_tbl[_tbl.columns[1]].isnull())==len(_tbl[_tbl.columns[1]]):
            logging.info("column following region is all empty... may have been combined")
            region_count = np.sum(_tbl[_tbl.columns[0]].str.contains('\d+', case=False, regex=True))

            if region_count>1:
                _formatted = _tbl[_tbl.columns[0]].str.extract(r'(\D+)\s+(\d+)')

                _tbl[_tbl.columns[0]] = _formatted[_formatted.columns[0]]
                _tbl[_tbl.columns[1]] = _formatted[_formatted.columns[1]]

        return _tbl

    def __match_datasets(self, tables):
        meh=[]
        match_set=[]

        i=0
        while i < len(tables):
            length=len(tables[i])
            if length in meh:
                match_set.append((meh.index(length), i))

            meh.append(length)

            i+=1
        return match_set

    def __compare_tables(self, tbl1,tbl2, column_to_compare='Total', from_2015=False):

        if from_2015:
            tbl1=self.__format_table(tbl1, actual_header_position=0, remove_bottom=3, has_header=True)
            tbl2=self.__format_table(tbl2, actual_header_position=0, remove_bottom=3, has_header=True)
        else:
            tbl1=self.__format_table(tbl1, remove_bottom=0, has_header=True)
            tbl2=self.__format_table(tbl2, remove_bottom=0, has_header=True)

        tbl1_higher_count=np.sum(tbl1[column_to_compare] > tbl2[column_to_compare])

        if tbl1_higher_count> len(tbl1)/2:

            monthly_table = tbl2

        else:

            monthly_table = tbl1

        return monthly_table


    def __create_folder_if_not_exist(self, dir):

        if not os.path.exists(dir):
            os.mkdir(dir)


    def __determine_segment(self,page_number):

        for each in self.report_config:
            _start = self.report_config[each]['page_start']
            _end = self.report_config[each]['page_end']
            if page_number >= _start and  page_number <= _end :
                return each

    def __clean_headers(self,table):
        x=re.compile('\s+|\d+|[.()/]')

        table.columns=[x.sub('',i) for i in table.columns]
        return table

    def __region_mapping(self, record, mapping_file=None):

        if isinstance(record, pd.DataFrame):
            records=record.to_dict('records')
            _rec= []
            for record in records:
                _rec.append(self.__region_mapping(record, mapping_file))


            return pd.DataFrame(_rec).dropna()

        if isinstance(record, dict):
            region_mapper=load_mapping(mapping_file)

            for each in region_mapper:
                if record['region'] in region_mapper[each]:
                    record['sub_region']=record['region']
                    record['region']=each

                    return record
            return record

    def __has_columns(self, table):
        key_words=['total','sales','volume', 'listing', 'avg']
        table_columns=[]
        for col in table.columns:
            _col=0
            for word in key_words:
                _col+=np.sum(table[col].str.contains(word, case=False))
            table_columns.append(_col)
        if sum(table_columns)>2:
            return True
        else:
            return False

    def __load_based_on_type(self, segment, page_number, from_2015):


        tables=read_pdf(self.report_name,
                            encoding='Latin',
                            multiple_tables=True,
                            guess=False,
                            pages=page_number,
                            lattice=True
                            )

        if len(tables[0].columns)<3:
            from_2015=True
            logging.info("before 2015-07, reloading data with different option")
            if segment!='sales_by_price':
                tables=read_pdf(self.report_name,
                                    encoding='Latin',
                                    multiple_tables=False,
                                    guess=True,
                                    pages=page_number
                                    )
                tables=[tables]

            else:
                # for page 2. good for all
                tables=read_pdf(self.report_name,
                                    encoding='Latin',
                                    multiple_tables=True,
                                    guess=True,
                                    pages=page_number
                                    )

        return tables, from_2015

    def load_page(self, page_number, mapping_file='../config/region_mapping.yaml', filename_pattern=r'\S+treb_(?P<year>\d+)_(?P<month>\d+).pdf'):
        # loads a page and returns a dataframe

        segment=self.__determine_segment(page_number)
        from_2015=False
        tables, from_2015 =self.__load_based_on_type(segment,page_number, from_2015)

        if segment =='sales_by_price' and self.report_type=='treb':

            match_sets = self.__match_datasets(tables)

            for each in match_sets:

                if len(tables[each[0]]) >8:
                    segment='price_range'

                    table = self.__compare_tables(tables[each[0]], tables[each[1]], from_2015=from_2015)


            table.columns.values[0]='price_range'
            # remove columns with nan so it doesnt brreak when cleaning headers
            table=table.loc[:, table.columns.notnull()]

        else:

            table_size=[]
            tables_with_col=[]
            for i in tables:
            #    if self.__has_columns(i):
            #        tables_with_col.append(i.size)

                table_size.append(i.size)

            table=tables[table_size.index(max(table_size))]

            if from_2015 and segment!='sales_by_price':
                table=self.__format_table(table, actual_header_position=0, remove_bottom=0)
            else:
                table=self.__format_table(table)

            table.columns.values[0]='region'
            table['type']=segment
            # remove columns with nan so it doesnt brreak when cleaning headers

            table=table.loc[:, table.columns.notnull()]


            table=self.__region_mapping(table, mapping_file=mapping_file)

        table=self.__clean_headers(table)


        file_rpt_dt = re.match(filename_pattern, self.report_name)
        _=file_rpt_dt.groupdict()
        table['reportDate']=datetime.date(int(_['year']),int(_['month']),1).strftime('%Y-%m-%d')

        logging.info("Found {0} records in table imported".format(len(table)))


        self.data[page_number]={'segment':segment,
                                'data':table
                                }

    def export_data(self, page_number, output_type='.csv', output_location=None, sep='|', **kwargs):
        data=self.data[page_number]

        if output_type not in ['.csv', 'json', 'dict']:
            raise Exception("Only '.csv', 'dict' or 'json' is accepted for output_format")

        elif output_type=='.csv':
            _fileformat={}
            _fileformat['report_name']=self.report_name
            _fileformat['segment']=data['segment']
            _fileformat['page']=page_number

            self.__create_folder_if_not_exist(output_location)
            filename=self.export_file_naming_convention.format(**_fileformat)
            data['data'].to_csv(filename, sep=sep)

            #remove from memory once exported
            self.data[page_number]=None
            return

        elif output_type=='json':

            #remove from memory once exported
            self.data[page_number]=None
            return data['data'].to_json(**kwargs)

        else:
            #remove from memory once exported
            self.data[page_number]=None
            return data['data'].to_dict(**kwargs)
