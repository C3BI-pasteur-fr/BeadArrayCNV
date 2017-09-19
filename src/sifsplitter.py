#!/usr/bin/env python

########################################################################################
#                                                                                      #
#   Author: Maufrais Corinne,                                                          #
#   Organization: Center of Informatics for Biology,                                   #
#                 Institut Pasteur, Paris.                                             #  
#   Distributed under GPLv3 Clause. Please refer to the COPYING document.              #
#                                                                                      #
########################################################################################

# version 2: 01/2015: new Illumina Final Report format

import os
import sys
import argparse


def parse_header(infh):
    """
    Parse the header of the Illumina Final report.
    Determine the number of sample in the analyse.

    WARNING: This function must be modified if the Final report of Illumina header
    changed from the version: Janauary 2015
    """
    line = infh.readline()
    n_samples = 0
    while '[Data]' not in line:
        if 'Num Samples' in line:
            n_samples = int(line.split('Num Samples')[1])
        line = infh.readline()
    return n_samples


# ["SNP Name", "Sample ID", "Chr", "Position", "Log R Ratio", "B Allele Freq"]
def parse_field(infh, separator, field_name=[]):
    """
    determine the position, in the Illumina Final report, of each interesting field needed for
    the creation of the SIF file(s).
    Field's name must be in the field_name list
    """
    line = infh.readline()
    fld = line.strip().split(separator)
    column_id = {}
    for fn in field_name:
        try:
            column_id[fn] = fld.index(fn)
        except:
            column_id[fn] = -1
    return column_id


def write_sif_line(outfh, line, col_id, clean):
    """
    write one line in SIF file
    WARNING: function must be modified, if:
        - the SIF format has changed (version Janauary 2015)
        - the Final report of Illumina header line has changed (version Janauary 2015)
    """
    fld = line.split()
    if clean:
        try:
            lrr = float(fld[col_id["Log R Ratio"]])
        except:
            lrr = 0
        try:
            baf = float(fld[col_id["B Allele Freq"]])
        except:
            baf = 0
        print >>outfh, "%s\t%s\t%s\t%s\t%s" % (fld[col_id["SNP Name"]], fld[col_id["Chr"]],
                                               fld[col_id["Position"]], lrr, baf)
    else:
        print >>outfh, "%s\t%s\t%s\t%s\t%s" % (fld[col_id["SNP Name"]], fld[col_id["Chr"]],
                                               fld[col_id["Position"]], fld[col_id["Log R Ratio"]],
                                               fld[col_id["B Allele Freq"]])


def write_sif_header(outfh, sample_name):
    """
    write one line in SIF file
    WARNING: function must be modified, if the SIF format has changed from the version: Janauary 2015
    """
    print >>outfh, "%s\t%s\t%s\t%s\t%s" % ("Name", "Chr", "Position", sample_name + ".Log R Ratio",
                                           sample_name + ".B Allele Freq")


def final_report_pass(infh, first_sample):
    """
    Move to the Nieme sample
    """
    sample_name_ref = ''
    cnt = 0
    pos = infh.tell()
    line = infh.readline()
    while line:
        sample_name = line.split()[col_id["Sample ID"]]
        if not sample_name == sample_name_ref:
            sample_name_ref = sample_name
            cnt += 1
            if cnt >= first_sample:
                infh.seek(pos)
                return
        pos = infh.tell()
        line = infh.readline()


def sif_creation(infh, out_path, col_id, clean, array_name, first_sample, last_sample):
    """
    Split Final report of Illumina into N SIF files.
    Write sample's names in the file: list.

    N is the number of samples in the file.
    WARNING: function must be modified, if:
        - the Final report of Illumina format has changed  from the version: Janauary 2015
    """
    nb = first_sample - 1
    sample_name_ref = ''
    line = infh.readline()
    outfh = None
    outsample = open("%s" % array_name, 'a')
    while line:
        sample_name = line.split()[col_id["Sample ID"]]
        if not sample_name == sample_name_ref:
            if outfh:
                outfh.close()
                nb += 1
                if nb == last_sample:
                    sys.exit()
            sample_name_ref = sample_name
            outfh = open("%s/%s" % (out_path, sample_name), 'w')
            print >>outsample, "%s/%s" % (out_path, sample_name)
            outsample.flush()
            write_sif_header(outfh, sample_name)
            write_sif_line(outfh, line, col_id, clean)
        else:
            write_sif_line(outfh, line, col_id, clean)
        line = infh.readline()
    outsample.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='sifsplitter',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="Split input file into individual \
                                     signal intensity files, and each file contains information for one sample")

    general_options = parser.add_argument_group(title="General options", description=None)
    general_options.add_argument('-i', '--infile', metavar='file',
                                 dest='infile',
                                 type=argparse.FileType('r'),
                                 help="full Signal Intensity File (the signal intensity values for all markers in all samples in one file)",
                                 required=True)

    general_options.add_argument("-p", "--out_path",
                                 action='store',
                                 dest='out_path',
                                 metavar='str',
                                 default='SIF_FILES',
                                 help="Path for output files")

    general_options.add_argument("-r", "--separator",
                                 action='store',
                                 dest='separator',
                                 metavar='int',
                                 type=int,
                                 choices=[0, 1, 2],
                                 default=0,
                                 help="""field separator
                   0  ... tabulation
                   1  ... comma
                   2  ... space
                                 """)
    general_options.add_argument("-c", "--clean",
                                 dest='clean',
                                 action='store_true',
                                 default=False,
                                 help="clean data for each sample. Remove GType column if exist. Clean non numeric \
                   value in 'Log R Ratio' and 'B Allele Freq' columns")

    general_options.add_argument("-s", "--start_nb",
                                 dest='first_sample',
                                 metavar=int,
                                 type=int,
                                 default=1,
                                 help="First sample number. If you want to split a part of the input file. You could choose the first and the last sample number. cf -l option"
                                 )
    general_options.add_argument("-l", "--last_nb",
                                 dest='last_sample',
                                 metavar=int,
                                 type=int,
                                 help="Last sample number. If you want to split a part of the input file. You could choose the first and the last sample number. cf -s option"
                                 )
    general_options.add_argument("-a", "--array_name",
                                 dest='array_name',
                                 metavar='file',
                                 type=str,
                                 default='sifs.lst',
                                 help="Output file name. List of all individual SIF's name."
                                 )

    args = parser.parse_args()

    if args.separator == 0:
        tab = '\t'
    elif args.separator == 1:
        tab = ' '
    elif args.separator == 2:
        tab = ','

    os.umask(002)

    # Header parsing and sample number detection
    last_sample = parse_header(args.infile)
    if args.last_sample and args.last_sample < last_sample:
        last_sample = args.last_sample

    if args.first_sample > last_sample:
        print >>sys.stderr, "There is %s sample(s) in the Final Report file. The number of the first sample \
must be less than %s" % (last_sample, args.first_sample)
        sys.exit(1)

    # Field name analyse: return column number for "Name", "Chr", "Position", "Sample.Log R Ratio", "Sample.B Allele Freq"
    field_name = ["SNP Name", "Sample ID", "Chr", "Position", "Log R Ratio", "B Allele Freq"]
    col_id = parse_field(args.infile, tab, field_name)
    if 'SNP Name' not in col_id:
        print >>sys.stderr, "%s not well formed; Field header missing" % args.infile.name
        sys.exit(1)

    # divide Final report into N  sif file; one by sample with Sample ID name
    if not os.access(args.out_path, 0):
        os.mkdir(args.out_path)

    final_report_pass(args.infile, args.first_sample)
    sif_creation(args.infile, args.out_path, col_id, args.clean, args.array_name, args.first_sample, last_sample)
