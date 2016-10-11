#!/usr/bin/env python

########################################################################################
#                                                                                      #
#   Author: Maufrais Corinne,                                                          #
#   Organization: Center of Informatics for Biology,                                   #
#                 Institut Pasteur, Paris.                                             #  
#   Distributed under GPLv3 Clause. Please refer to the COPYING document.              #
#                                                                                      #
########################################################################################


import sys
import os
import argparse


def reformat_header(line, filename):
    fld = line.split('"')
    try:
        tracks = fld[1].split('in')[0] + 'in all.cnv'
        cnvs = fld[3].split('in')[0] + 'in all.cnv'
        fld[1] = tracks
        fld[3] = cnvs
        newheader = '"'.join(fld)
        return newheader
    except:
        print >>sys.stderr, "Not a well formated bed file: %s" % filename


def concat_bed_file(infh, outfh, header):
    if not header:
        line = infh.readline().strip()
        line = reformat_header(line, infh.name)
        if line:
            print >>outfh, line
        else:
            return False
    else:
        infh.readline()
    line = infh.readline()
    while line:
        flds = line.strip().split('\t')
        if flds[0] == 'chr23':
            print >>outfh, '%s\t%s' % ('chrX', '\t'.join(flds[1:]))
        else:
            print >>outfh, line.strip()
        line = infh.readline()
    return True

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='cat4bed',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="Concatenation of N bed files in one file (all.bed). In the header,\
                                     there is a reference to the 'all.cnv' file (concatenation of the N associated bed files)")

    parser.add_argument(metavar='file',
                        dest='infiles',
                        type=file,
                        nargs='+',
                        help="bed file(s)")
    parser.add_argument("-o", "--outdir",
                        action='store',
                        dest='outdir',
                        default='.',
                        help="Output path (Default in place)")
    args = parser.parse_args()

    os.umask(002)

    outfh = open('%s/all.cnvbed' % args.outdir, 'w')
    header = False
    for infh in args.infiles:
        header = concat_bed_file(infh, outfh, header)
        infh.close()

    outfh.close()
