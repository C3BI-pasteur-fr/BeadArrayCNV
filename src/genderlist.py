#!/usr/bin/env python

########################################################################################
#                                                                                      #
#   Author: Maufrais Corinne,                                                          #
#   Organization: Center of Informatics for Biology,                                   #
#                 Institut Pasteur, Paris.                                             #
#   Distributed under GPLv3 Clause. Please refer to the COPYING document.              #
#                                                                                      #
########################################################################################


import os
import argparse


def extract_sample_name(infh):
    genders = {}
    line = infh.readline()
    while line:
        genders[os.path.basename(line.strip())] = {'path': line.strip(), 'gender': ''}
        line = infh.readline()
    return genders


def extract_sample_gender(fhin, genders, sample_column_nb, gender_column_nb):
    line = fhin.readline()
    while line:
        fld = line.split()
        if fld[sample_column_nb].strip() not in genders:
            # print >>sys.stderr, "WARNING: %s sample's name not in both gender file and sample's name file" % fld[sample_column_nb].strip()
            pass
        else:
            genders[fld[sample_column_nb].strip()]['gender'] = fld[gender_column_nb].strip()
        line = fhin.readline()

    for key, val in genders.items():
        if not val['gender']:
            # print >>sys.stderr, "WARNING: %s sample's name not in both gender file and sample's name file" % key
            genders.pop(key)
    return genders


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='genderlist',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="Split SIF by gender. Create symbolic links.")

    general_options = parser.add_argument_group(title="General options", description=None)
    general_options.add_argument('-j', '--infile', metavar='file',
                                 dest='gender_infh',
                                 type=argparse.FileType('r'),
                                 help="File containing gender information for each sample used in the experiment. ",
                                 required=True)
    general_options.add_argument('-i', "--sifs_list", metavar='file',
                                 dest='sifs_list_infh',
                                 type=argparse.FileType('r'),
                                 help="File containing the list of sample's name used in the experiment. ",
                                 required=True)
    general_options.add_argument("-n", "--sample_nb",
                                 dest='sample_column_nb',
                                 metavar='int', type=int,
                                 default=2,
                                 help="Column number of the sample name.")
    general_options.add_argument("-g", "--gender_col_nb",
                                 dest='gender_column_nb',
                                 metavar='int', type=int,
                                 default=4,
                                 help="Column number of the gender type.")

    args = parser.parse_args()

    genders = extract_sample_name(args.sifs_list_infh)
    genders = extract_sample_gender(args.gender_infh, genders, args.sample_column_nb-1, args.gender_column_nb-1)

    male_lst = open('%s_male' % args.sifs_list_infh.name, 'w')
    female_lst = open('%s_female' % args.sifs_list_infh.name, 'w')
    for name in genders:
        if genders[name]['gender'].lower() in ['m', '1', 'male']:
            print >>male_lst, genders[name]['path']
        elif genders[name]['gender'].lower() in ['f', '2', 'female']:
            print >>female_lst, genders[name]['path']
