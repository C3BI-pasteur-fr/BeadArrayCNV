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


def _first(field):
    fd = field.split(':')
    fdpos = fd[1].split('-')
    return fd[0][3:], fdpos[0], fdpos[1]


def _fourth(field):
    return field.split(',')[1].split('=')[1]


def cnvs_extract(cnvfh, prog_type):
    if prog_type == 'p':
        return extract_penncnv(cnvfh)
    else:
        return extract_quanticnv(cnvfh)


def extract_penncnv(cnvfh):
    cnvdata = {}
    line = cnvfh.readline()
    while line:
        fd = line.split()
        chromosome, str_r, stp = _first(fd[0])
        if chromosome == 'chr23':
            chromosome = 'chrX'
        cn = fd[3].split(',')[1].split('=')[1]
        if chromosome in cnvdata:
            if cn in cnvdata[chromosome]:
                cnvdata[chromosome][cn].append((int(str_r), int(stp)))
            else:
                cnvdata[chromosome][cn] = [(int(str_r), int(stp))]
        else:
            cnvdata[chromosome] = {cn: [(int(str_r), int(stp))]}
        line = cnvfh.readline()
    return cnvdata


def extract_quanticnv(cnvfh):
    cnvdata = {}
    cnvfh.readline()
    line = cnvfh.readline()
    while line:
        fld = line.split()
        chromosome = fld[1]
        if chromosome == '23':
            chromosome = 'X'
        str_r = fld[2]
        stp = fld[3]
        cn = fld[8]
        if chromosome in cnvdata:
            if cn in cnvdata[chromosome]:
                cnvdata[chromosome][cn].append((int(str_r), int(stp)))
            else:
                cnvdata[chromosome][cn] = [(int(str_r), int(stp))]
        else:
            cnvdata[chromosome] = {cn: [(int(str_r), int(stp))]}
        line = cnvfh.readline()
    return cnvdata


def extract_copy_number(cnvdata, chromosome, pos):
    for cn, lst_pos in cnvdata[chromosome].items():
        for cpl in lst_pos:
            if pos >= cpl[0] and pos <= cpl[1]:
                return cn
    return 2


def extract_copy_number_all(cnvdata, pos):
    for chromosome in cnvdata.keys():
        for cn, lst in cnvdata[chromosome].items():
            for cpl in lst:
                if pos >= cpl[0] and pos <= cpl[1]:
                    return chromosome, cn
    return '', ''


def reformat_header(line, tab):
    fld = line.split('\t')
    sampleID = fld[3].split('.')[0]

    return '%s%s%s%s%s%s%s%s%s%s%s.CNV Value' % (fld[0], tab, fld[1], tab,
                                                 fld[2], tab, fld[4], tab,
                                                 fld[3], tab, sampleID)


def extract_sif(infh, cnvdata):
    line = infh.readline()
    data = {}
    while line:
        fld = line.strip().split()
        if fld[1] == '23':
            chromosome = 'X'
        elif fld[1] == 'chr23':
            chromosome = 'chrX'
        else:
            chromosome = fld[1]
        pos = int(fld[2])
        try:
            cn = extract_copy_number(cnvdata, chromosome, pos)
        except:
            cn = 2
        name = fld[0]
        allele = fld[4]
        log = fld[3]
        try:
            ch = int(chromosome)
        except:
            ch = chromosome
        if ch in data:
            if pos in data[ch]:  # A mon avis ne dois pas apparaitre .... errorFile
                data[ch][pos].append((name, allele, log, cn))
            else:
                data[ch][pos] = [(name, allele, log, cn)]
        else:
            data[ch] = {pos: [(name, allele, log, cn)]}
        line = infh.readline()
    return data


def write_snippeep(outfh, sifdata, header, tab, errorfh, sif_name):
    print >>outfh, header
    chromosomes = sifdata.keys()
    chromosomes.sort()
    error = False
    for chromosome in chromosomes:
        pos_l = sifdata[chromosome].keys()
        pos_l.sort()
        for pos in pos_l:
            for name, allele, log, cn in sifdata[chromosome][pos]:
                print >>outfh, '%s%s%s%s%s%s%s%s%s%s%s' % (name, tab, chromosome, tab, pos, tab, allele, tab, log, tab, cn)
            if len(sifdata[chromosome][pos]) > 1:
                if not error:
                    print >>errorfh, '%s\t%s\t%s\t%s' % ('Sample', 'Chr', 'Pos', 'SNP Nane')
                    error = True
                for name, allele, log, cn in sifdata[chromosome][pos]:
                    print >>errorfh, "%s\t%s\t%s\t%s" % (sif_name, chromosome, pos, name)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='sif4snippeep',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="sif4snippeep use CNV result file of PennCNV or QuantiSNP program to \
    reformat PennCNV Signal Intensity File in Snippeep Signal Intensity File format")

    general_options = parser.add_argument_group(title="Options", description=None)
    general_options.add_argument('-i', '--cnv', metavar='file',
                                 dest='cnvfile',
                                 type=str,
                                 help="CNV result file")
    general_options.add_argument('-s', '--sif', metavar='file',
                                 dest='siffh',
                                 type=file,
                                 help="Signal Intensity File",
                                 required=True)
    general_options.add_argument("-t", "--type",
                                 action='store',
                                 dest='type_analyse',
                                 choices=['p', 'q'],
                                 required=True,
                                 help="CNV result obtain from PennCNV (-t p) or QuantiSNP (-t q) programs")
    general_options.add_argument("-c", "--csv_format",
                                 dest='csv_format',
                                 action='store_true',
                                 default=False,
                                 help="Output in CSV format. (Default: tab delimited format)")
    general_options.add_argument("-o", "--out",
                                 action='store',
                                 dest='outfh',
                                 type=argparse.FileType('w'),
                                 required=True,
                                 help='Output file')
    args = parser.parse_args()

    errorfh = None

    tab = '\t'
    if args.csv_format:
        tab = ','
    try:
        cnv_fh = open(args.cnvfile)
    except IOError, err:
        print >>sys.stderr, err
        exit(1)
    cnvdata = cnvs_extract(cnv_fh, args.type_analyse)

    line = args.siffh.readline()
    header = reformat_header(line[:-1], tab)

    sifdata = extract_sif(args.siffh, cnvdata)
    errorfh = open('snippeepError.txt', 'a')
    print os.path.getsize('snippeepError.txt')
    write_snippeep(args.outfh, sifdata, header, tab, errorfh, os.path.basename(args.siffh.name))
    errorfh.close()
