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

    def __format_table(self, table, actual_header_position=1, remove_bottom=1):
        replace_set={',':'','\$':'', '\%':''}
        table=table.replace(replace_set, regex=True)

        if remove_bottom==0:
            _tbl = pd.DataFrame(table.values[actual_header_position+1:], columns=table.values[actual_header_position])
        else:
            _tbl = pd.DataFrame(table.values[actual_header_position+1:-remove_bottom], columns=table.values[actual_header_position])
#        _tbl = _tbl.set_index(_tbl.columns[0])


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
            tbl1=self.__format_table(tbl1, actual_header_position=0, remove_bottom=3)
            tbl2=self.__format_table(tbl2, actual_header_position=0, remove_bottom=3)
        else:
            tbl1=self.__format_table(tbl1, remove_bottom=0)
            tbl2=self.__format_table(tbl2, remove_bottom=0)

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

    def load_page(self, page_number, mapping_file='../config/region_mapping.yaml', filename_pattern=r'\S+treb_(?P<year>\d+)_(?P<month>\d+).pdf'):
        # loads a page and returns a dataframe

        segment=self.__determine_segment(page_number)
        from_2015=False
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
            tables=read_pdf(self.report_name,
                                encoding='Latin',
                                multiple_tables=True,
                                guess=True,
                                pages=page_number
                                )

        if segment =='sales_by_price' and self.report_type=='treb':
            match_sets = self.__match_datasets(tables)
            for each in match_sets:

                if len(tables[each[0]]) >8:
                    segment='price_range'

                    table = self.__compare_tables(tables[each[0]], tables[each[1]], from_2015=from_2015)

            table.columns.values[0]='price_range'



        else:

            table=self.__format_table(tables[0])
            table.columns.values[0]='region'

            if from_2015:
                table=table[\
                ~(table[table.columns[0]].str.lower().str.contains('turn page')) \
                & ~(table[table.columns[0]].str.lower().str.contains('click here'))  \
                ]


        table=self.__clean_headers(table)
        table=self.__region_mapping(table, mapping_file=mapping_file)
        table['type']=segment
        file_rpt_dt = re.match(filename_pattern, self.report_name)
        _=file_rpt_dt.groupdict()
        table['reportDate']=datetime.date(int(_['year']),int(_['month']),1).strftime('%Y-%m-%d')


        self.data[page_number]={'segment':segment,
                                'data':self.__clean_headers(table)
                                }
        return table



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

        elif output_type=='json':
            return data['data'].to_json(**kwargs)

        else:
            return data['data'].to_dict(**kwargs)
