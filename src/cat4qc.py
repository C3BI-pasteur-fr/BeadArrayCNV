#!/usr/bin/env python


########################################################################################
#                                                                                      #
#   Author: Maufrais Corinne,                                                          #
#   Organization: Center of Informatics for Biology,                                   #
#                 Institut Pasteur, Paris.                                             #  
#   Distributed under GPLv3 Clause. Please refer to the COPYING document.              #
#                                                                                      #
########################################################################################

import argparse
import sys

def concat_penncnv_file(infh, outfh):
    # replace 23 by chrX
    line = infh.readline()
    while line:
        fld = line[:-1].split('\t')
        if fld[0].split(':')[0][3:] == '23':
            first = fld[0].replace('chr23', 'chrX')
            print >>outfh, '%s\t%s' % (first, '\t'.join(fld[1:]))
        else:
            print >>outfh, line[:-1]
        line = infh.readline()


def concat_quantisnp_file(infh, outfh, header):
    # replace 23 by chrX
    line = infh.readline()
    if not header:
        print >>outfh, line.strip()

    line = infh.readline()

    while line:
        fld = line[:-1].split('\t')
        if fld[1] == '23':
            print >>outfh, '%s\t%s\t%s' % (fld[0], 'X', '\t'.join(fld[2:]))
        else:
            print >>outfh, line[:-1]
        line = infh.readline()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='cat4qc',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="Concatenation of N QC files in one file (all.qc). QC files could\
                                     be obtained with PennCNV or QuantSNP programs")

    parser.add_argument(metavar='file',
                        dest='infiles',
                        #type=file,
                        nargs='+',
                        help="file(s)")

    parser.add_argument("-t", "--type",
                        action='store',
                        dest='type_analyse',
                        choices=['p', 'q'],
                        required=True,
                        help="QC result obtain from PennCNV (-t p) or QuantiSNP (-t q) programs")
    parser.add_argument("-o", "--outdir",
                        action='store',
                        dest='outdir',
                        default='.',
                        help="Output path (Default in place)")

    args = parser.parse_args()

    outfh = open('%s/all.qc' % args.outdir, 'w')
    header = False

    for infh_n in args.infiles:
        infh = open(infh_n)
        if args.type_analyse == 'p':
            concat_penncnv_file(infh, outfh)
        else:
            concat_quantisnp_file(infh, outfh, header)
            header = True
        infh.close()

    outfh.close()
