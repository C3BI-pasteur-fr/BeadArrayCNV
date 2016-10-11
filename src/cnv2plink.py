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
import sys
import argparse


def cnvs_extract(fididd, cnvfh, fhout, prog_type):
    if prog_type == 'p':
        return extract_penncnv(fididd, cnvfh, fhout)
    else:
        return extract_quanticnv(fididd, cnvfh, fhout)


def extract_fid(fiidfh):
    line = fiidfh.readline()
    f = line.split()
    if f[0].lower() != 'fid':
        print >>sys.stderr, 'Pedigree file not well form: header must have a first column with FID title'
        sys.exit(1)
    if f[1].lower() != 'iid':
        print >>sys.stderr, 'Pedigree file not well form: header must have a second column with IID title'
        sys.exit(1)
    fididd = {}
    line = fiidfh.readline()
    while line:
        fd = line.split()
        if fd:
            fid = fd[0]
            iid = fd[1]
            fididd[iid] = fid
        line = fiidfh.readline()
    return fididd


def first(field):
    fd = field.split(':')
    fdpos = fd[1].split('-')
    return fd[0][3:], fdpos[0], fdpos[1]


def fourth(field):
    return field.split(',')[1].split('=')[1]


def extract_penncnv(fididd, cnvfh, fhout):
    line = cnvfh.readline()
    while line:
        fi = {}
        fd = line.split()
        fi['IID'] = os.path.basename(fd[4]).split('.')[-1]  # futur plus de .
        print fi['IID']
        try:
            fi['FID'] = fididd[fi['IID']]
        except:
            print >>sys.stderr, "Warning: no Family ID for %s" % fi['IID']
            fi['FID'] = '--'
        fi['CHR'] = first(fd[0])[0]
        fi['BP1'] = first(fd[0])[1]
        fi['BP2'] = first(fd[0])[2]
        fi['TYPE'] = fd[3].split(',')[1].split('=')[1]  # cn
        fi['SCORE'] = fd[7].split('=')[1]
        fi['SITES'] = fd[1].split('=')[1]
        print >>fhout, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % (fi['FID'], fi['IID'], fi['CHR'], fi['BP1'],
                                                           fi['BP2'], fi['TYPE'], fi['SCORE'],
                                                           fi['SITES'])
        line = cnvfh.readline()


def extract_quanticnv(fididd, cnvfh, fhout):
    cnvfh.readline()
    line = cnvfh.readline()
    while line:
        fi = {}
        fld = line.split()
        fi['IID'] = fld[0].split('.')[-1]  # futur plus de
        try:
            fi['FID'] = fididd[fi['IID']]
        except:
            print >>sys.stderr, "Warning: no Family ID for %s" % fi['IID']
            fi['FID'] = '--'
        fi['CHR'] = fld[1]
        fi['BP1'] = fld[2]
        fi['BP2'] = fld[3]
        fi['TYPE'] = fld[8]  # cn
        fi['SCORE'] = fld[9]
        fi['SITES'] = fld[7]
        print >>fhout, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % (fi['FID'], fi['IID'], fi['CHR'], fi['BP1'],
                                                           fi['BP2'], fi['TYPE'], fi['SCORE'],
                                                           fi['SITES'])
        line = cnvfh.readline()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='cnv2plink',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description="Reformat CNV file into plink format")

    parser.add_argument('-f', '--fiidfile', metavar='file',
                        dest='fiidfh',
                        type=argparse.FileType('r'),
                        help="Pedigree file with Family ID (FID) and Individual ID (IID) at first and second columns. ",
                        required=True)

    parser.add_argument('-i', '--cnvfile', metavar='file',
                        dest='cnvfile',
                        type=argparse.FileType('r'),
                        help="CNV file. ",
                        required=True)

    parser.add_argument("-t", "--type",
                        action='store',
                        dest='type_analyse',
                        choices=['p', 'q'],
                        required=True,
                        help="CNV result obtain from PennCNV (-t p) or QuantiSNP (-t q) programs")

    parser.add_argument("-o", "--outdir",
                        action='store',
                        dest='outdir',
                        default='PLINK', 
                        help="Write Plink file(s) into the specified path")

    args = parser.parse_args()

    #try:
    #    cnv_fh = open(args.cnvfile)
    #except IOError, err:
    #    print >>sys.stderr, err
    #    exit(1)

    fididd = extract_fid(args.fiidfh)
    filename = os.path.basename(args.cnvfile.name)
    fhout = open("%s/%s.plk" % (args.outdir, filename), 'w')
    cnvs_extract(fididd, args.cnvfile, fhout, args.type_analyse)
