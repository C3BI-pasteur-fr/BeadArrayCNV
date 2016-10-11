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
print "##  os.environ ##"
print os.environ
import sys
print '## sys.version ##'
print sys.version
import argparse


def cnv_filter(infh, outfh, probe_nb, pb_length, max_log):
    line = infh.readline()
    fld = line.strip().split('\t')
    one_hit = False
    print >>outfh, '%s' % ('\t'.join(fld[0:10]))
    line = infh.readline()
    while line:
        fld = line.strip().split('\t')
        if int(fld[7]) >= probe_nb and int(fld[6]) >= pb_length and float(fld[9]) >= max_log:
            one_hit = True
            print >>outfh, '%s' % ('\t'.join(fld[0:10]))
        line = infh.readline()
    return one_hit


def loh_filter(infh, outfh, probe_nb, pb_length, max_log):
    one_hit = cnv_filter(infh, outfh, probe_nb, pb_length, max_log)
    return one_hit


def qc_filter(infh, outfh, badout, std_baf, std_lrr):
    # error in format header. Gender on the 2nd line
    VuPop = False
    # one population by file
    one_hit = False
    line1 = infh.readline()
    line2 = infh.readline()
    fld = line2[:-1].split('\t')
    newHeader = line1[:-1] + '\t' + fld[0]
    print >>outfh, newHeader

    # Warning: The first line is not well formed: One more column
    if fld[5] not in ['male', 'female']:
        if float(fld[5]) <= std_baf and float(fld[4]) <= std_lrr:
            one_hit = True
            print >>outfh, '%s' % ('\t'.join(fld[1:]))
    else:
        if float(fld[3]) <= std_lrr and float(fld[4]) <= std_baf:
            one_hit = True
            print >>outfh, line2[:-1]

    line = infh.readline()
    while line:
        fld = line.split('\t')
        if float(fld[3]) <= std_lrr and float(fld[4]) <= std_baf:
            one_hit = True
            print >>outfh, line[:-1]
        elif not VuPop:
            # reject population is underline only once
            print >>badout, line[:-1]
            VuPop = True
        line = infh.readline()
    return one_hit


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='quantisnpdispatcher',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="Filter quantiSNP output files and dispatch them in subdirectory (LOH, CNV, QC)")

    parser.add_argument(metavar='str',
                        dest='sif_name',
                        type=str,
                        help="SIF name")

    general_options = parser.add_argument_group(title="General options", description=None)

    general_options.add_argument("-d", "--dir",
                                 action='store',
                                 dest='quanti_indir',
                                 default='QuantiSNP_Result',
                                 help="quantiSNP input files path")
    general_options.add_argument("-x",
                                 dest='lohdir',
                                 default='QuantiSNP_Result/LOH',
                                 help="Output path for LOH files")
    general_options.add_argument("-y",
                                 dest='cnvdir',
                                 default='QuantiSNP_Result/CNV',
                                 help="Output path for CNV files")
    general_options.add_argument("-z",
                                 dest='qcdir',
                                 default='QuantiSNP_Result/QC',
                                 help="Output path for QC files")
    general_options.add_argument("-t", "--type",
                                 action='store',
                                 dest='type_analyse',
                                 choices=['a', 'c', 'l', 'q'],
                                 default='a',
                                 help="""Analyze type
                 - a: cnv, loh and qc files
                 - c: cnv files only
                 - l: loh files only
                 - q: quality files only""")

    cnv_options = parser.add_argument_group(title="cnv and log options", description=None)
    cnv_options.add_argument("-p", "--probe_nb",
                             dest='probe_nb',
                             metavar='int',
                             type=int,
                             default=4,
                             help="Minimum 'number of probes' to keep position")
    cnv_options.add_argument("-l", "--pb_length",
                             dest='pb_length',
                             metavar='int',
                             type=int,
                             default=1000,
                             help="Minimum length (bp) to keep position")
    cnv_options.add_argument("-m", "--max_log",
                             dest='max_log',
                             metavar='int',
                             type=int,
                             default=15,
                             help="Minimum 'Max log' value to keep position")
    quality_options = parser.add_argument_group(title="quality options", description=None)
    quality_options.add_argument("-b", "--std_baf",
                                 dest='std_baf',
                                 metavar='float',
                                 type=float,
                                 default=0.13,
                                 help="Std deviation BAF")
    quality_options.add_argument("-r", "--std_lrr",
                                 dest='std_lrr',
                                 metavar='float',
                                 type=float,
                                 default=0.27,
                                 help="Std deviation LRR")

    args = parser.parse_args()

    if args.type_analyse in ['a', 'c']:
        cnv_infh = open("%s/%s.cnv" % (args.quanti_indir, args.sif_name))
        cnv_outfh = open("%s/%s.cnv" % (args.cnvdir, args.sif_name), 'w')
        one_hit_cnv = cnv_filter(cnv_infh, cnv_outfh, args.probe_nb, args.pb_length, args.max_log)
        cnv_outfh.close()
        cnv_infh.close()
        if one_hit_cnv:
            os.remove('%s/%s.cnv' % (args.quanti_indir, args.sif_name))
        else:
            print >>sys.stderr, '%s: All positions are below the user defined conditions. The cnv file has been removed.' % args.sif_name
            os.remove('%s/%s.cnv' % (args.cnvdir, args.sif_name))
    if args.type_analyse in ['a', 'l']:
        loh_infh = open("%s/%s.loh" % (args.quanti_indir, args.sif_name))
        loh_outfh = open("%s/%s.loh" % (args.lohdir, args.sif_name), 'w')
        one_hit_loh = loh_filter(loh_infh, loh_outfh, args.probe_nb, args.pb_length, args.max_log)
        loh_outfh.close()
        loh_infh.close()
        os.remove('%s/%s.loh' % (args.quanti_indir, args.sif_name))
        if not one_hit_loh:
            os.remove('%s/%s.loh' % (args.lohdir, args.sif_name))

    if args.type_analyse in ['a', 'q']:
        qc_infh = open("%s/%s.qc" % (args.quanti_indir, args.sif_name))
        qc_outfh = open("%s/%s.qc" % (args.qcdir, args.sif_name), 'w')
        qc_badfh = open("%s/%s" % (args.qcdir, 'qcRegected.txt'), 'a')
        one_hit_qc = qc_filter(qc_infh, qc_outfh, qc_badfh, args.std_baf, args.std_lrr)
        qc_outfh.close()
        qc_badfh.close()
        qc_infh.close()
        os.remove('%s/%s.qc' % (args.quanti_indir, args.sif_name))
        if not one_hit_qc:
            os.remove('%s/%s.qc' % (args.qcdir, args.sif_name))
