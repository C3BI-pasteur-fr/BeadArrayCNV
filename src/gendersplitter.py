#!/usr/bin/env python

########################################################################################
#                                                                                      #
#   Author: Maufrais Corinne,                                                          #
#   Organization: Center of Informatics for Biology,                                   #
#                 Institut Pasteur, Paris.                                             #
#   Distributed under GPLv3 Clause. Please refer to the COPYING document.              #
#                                                                                      #
########################################################################################

# version 1: sample map parser and sort SIF files by gender

import os
import sys
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
            print >>sys.stderr, "WARNING: %s sample's name not in both gender file and sample's name file" % fld[sample_column_nb].strip()
        else:
            genders[fld[sample_column_nb].strip()]['gender'] = fld[gender_column_nb].strip()
        line = fhin.readline()

    for key, val in genders.items():
        if not val['gender']:
            print >>sys.stderr, "WARNING: %s sample's name not in both gender file and sample's name file" % key
            genders.pop(key)
    return genders


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='gendersplitter',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="Split SIF by gender. Create symbolic links.")

    general_options = parser.add_argument_group(title="General options", description=None)
    general_options.add_argument('-i', '--infile', metavar='file',
                                 dest='gender_infh',
                                 type=argparse.FileType('r'),
                                 help="File containing gender information for each sample used in the experiment. ",
                                 required=True)
    general_options.add_argument('-l', "--sifs_list", metavar='file',
                                 dest='sifs_list_infh',
                                 type=argparse.FileType('r'),
                                 help="File containing the list of sample's name used in the experiment. ",
                                 required=True)
    general_options.add_argument("-n", "--sample_nb",
                                 dest='sample_column_nb',
                                 metavar='int', type=int,
                                 default=2,
                                 help="Column number of the sample name.")
    general_options.add_argument("-g", "--gender_nb",
                                 dest='gender_column_nb',
                                 metavar='int', type=int,
                                 default=4,
                                 help="Column number of the gender type.")
    general_options.add_argument("-d", "--SIF_path",
                                 action='store',
                                 dest='sif_path',
                                 metavar='str',
                                 default='SIF_FILES',
                                 help="Input path where located all SIF files.")
    general_options.add_argument("-m", "--male_path",
                                 action='store',
                                 dest='male_path',
                                 metavar='str',
                                 default='SIF_FILES/MALE',
                                 help="Output path where located symbolic links of SIF file for male gender.")
    general_options.add_argument("-f", "--female_path",
                                 action='store',
                                 dest='female_path',
                                 metavar='str',
                                 default='SIF_FILES/FEMALE',
                                 help="Output path where located symbolic links of SIF file for female gender.")

    args = parser.parse_args()

    genders = extract_sample_name(args.sifs_list_infh)
    genders = extract_sample_gender(args.gender_infh, genders, args.sample_column_nb-1, args.gender_column_nb-1)
    pwd = os.getcwd()
    for name in genders:
        if genders[name]['gender'].lower() in ['m', '1', 'male']:
            dest = os.path.join(pwd, args.male_path)
        elif genders[name]['gender'].lower() in ['f', '2', 'female']:
            dest = os.path.join(pwd, args.female_path)
        print os.path.join(pwd, genders[name]['path'])
        print os.path.join(dest, name)
        os.symlink(os.path.join(pwd, genders[name]['path']), os.path.join(dest, name))
