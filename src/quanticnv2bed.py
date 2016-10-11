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
import sys

def cnv2bed(infh, outfh, bed_strand):
    cnvcolor = {'0': '128,0,0',
                '1': '255,0,0',
                '2': '0,255,0',
                '3': '0,255,0',
                '4': '0,128,0',
                '5': '0,128,0',
                '6': '0,128,0'}

    track_name = "CNVs in %s" % (infh.name)
    header = 'track name="Track: %s" description="%s" visibility=2 itemRgb="On"' % (track_name, track_name)
    print >>outfh, '%s' % (header)

    infh.readline()

    line = infh.readline()
    while line:
        flds = line.split('\t')
        if flds[1] == '23':
            chromosome = 'chrX'
        else:
            chromosome = 'chr%s' % (flds[1])
        start = int(flds[2]) - 1
        stop = flds[3]
        name = flds[0]
        nprobe = int(flds[7]) * 10
        rgb = cnvcolor[flds[8]]
        print >>outfh, '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' % (chromosome, start, stop, name, nprobe, bed_strand, '0', '0', rgb)

        line = infh.readline()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='quanticnv2bed',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="Reformat CNV files from quantiSNP program in bed format for visualization in BeadStudio software. Dispatch results in subdirectory")

    parser.add_argument(metavar='file',
                        dest='cnvfile',
                        type=str,
                        help="CNV file",
                        )

    general_options = parser.add_argument_group(title="General options", description=None)

    general_options.add_argument("-o", "--outdir",
                                 action='store',
                                 dest='outdir',
                                 default='QuantiSNP_Result/BED',
                                 help="Write bed file(s) into the specified path")

    args = parser.parse_args()

    bed_strand = '.'

    os.umask(002)
    try:
        cnv_fh = open(args.cnvfile)
    except IOError, err:
        print >>sys.stderr, err
        exit(1)
    filename = os.path.basename(args.cnvfile)
    bed_outfh = open(args.outdir + '/' + filename + 'bed', 'w')
    cnv2bed(cnv_fh, bed_outfh, bed_strand)
    bed_outfh.close()
    cnv_fh.close()
