#! /bin/sh
#$ -S /bin/sh

########################################################################################
#                                                                                      #
#   Author: Maufrais Corinne,                                                          #
#   Organization: Center of Informatics for Biology,                                   #
#                 Institut Pasteur, Paris.                                             #  
#   Distributed under GPLv3 Clause. Please refer to the COPYING document.              #
#                                                                                      #
########################################################################################

umask 002
module purge
module load Python/2.7.8

#################################################################################
# Help displaying                                                               #
#################################################################################


if [ "$1" = "-h" ] 
then
	echo "" ;
	echo "USAGE:";
	echo "quantisnpfilter [options] -d indir";
	echo "";
	echo "quantisnpfilter filter quantiSNP output files and dispatch them in subdirectory  (LOH, CNV, QC)";
	echo "";
	echo "Options:";
	echo "-h,         Show this help message and exit";
	echo "";
	echo "-i file     File containing the list of sample's name";
	echo "-d dir      Path where located quantiSNP output files (Default: QuantiSNP_Result)";
	echo "-x dir      LOH output path (Default: QuantiSNP_Result/LOH)"
	echo "-y dir      CNV output path (Default: QuantiSNP_Result/CNV)"
	echo "-z dir      QC output path (Default: QuantiSNP_Result/QC)"
	echo "-t str      Analyse type. (Default a)";
	echo "              a: cnv, loh and qc files";
	echo "              c: cnv files only";
	echo "              l: loh files only";
	echo "              q: quality file only";
	echo "-p int      no. probes (Default 4)";
	echo "-l int      Bp length (Default 1000)";
	echo "-m int      Max log  (Default 15)";
	echo "-b float    Std deviation BAF (Default 0.13)";
	echo "-r float    Std deviation LRR (Default 0.27)";
fi


#################################################################################
# Default options
#################################################################################

QUANTIDIR='QuantiSNP_Result'
ANALYSE_TYPE='a'
PROBE=4
LENGHT=1000
MAX_LOG=15
STD_BAF=0.13
STD_LRR=0.27
SIF_LIST=''
LOHDIR=${QUANTIDIR}/LOH
CNVDIR=${QUANTIDIR}/CNV
QCDIR=${QUANTIDIR}/QC
# SRC=/pasteur/projets/specific/PFGE_activites/CIB/distrib/
SRC=''

while getopts "i:d:t:p:l:m:b:r:x:y:z:a:" opt; do
	case $opt in
		i)
		SIF_LIST="$OPTARG"
		;;
		d)
		QUANTIDIR="$OPTARG"
		;;
		t)
		ANALYSE_TYPE="$OPTARG"
		;;
		p)
		PROBE="$OPTARG"
		if [ ${PROBE} -le 0 ]; then echo "The no. probe must be positive (option -p)" ;  exit 1;  fi
		;;
		l)
		LENGTH="$OPTARG"
		if [ ${LENGTH} -le 0 ]; then echo "The length must be positive (option -l)" ;  exit 1;  fi
		;;
		m)
		MAX_LOG="$OPTARG"
		if [ ${MAX_LOG} -le 0 ]; then echo "The Max log must be positive (option -m)" ;  exit 1;  fi
		;;
		b)
		STD_BAF=$OPTARG
	# if [ ${STD_BAF} -le 0.0 ]; then echo "The std BAF must be positive (option -b)" ;  exit 1;  fi
		;;
		r)
		STD_LRR=$OPTARG
	 # if [ ${STD_LRR} -le 0.0 ]; then echo "The str LRR must be positive (option -r)" ;  exit 1;  fi
		;;
		x)
		LOHDIR="$OPTARG"
		;;
		y)
		CNVDIR="$OPTARG"
		;;
		z)
		QCDIR="$OPTARG"
		;;
                a)
                SRC="$OPTARG"
       echo ${SRC}
                ;;
  esac
done		

if [ ${SGE_TASK_ID} ]
then
  SIF=$(cat ${SIF_LIST} | head -n ${SGE_TASK_ID} | tail -n 1)
else
  SIF=$(cat ${SIF_LIST} | head -n ${SLURM_ARRAY_TASK_ID} | tail -n 1)
fi
SIF_NAME=$(basename ${SIF})
mkdir -p ${LOHDIR}
mkdir -p ${CNVDIR}
mkdir -p ${QCDIR}

echo "quantisnpfilter.py -t ${ANALYSE_TYPE} -p ${PROBE} -l ${LENGTH} -m ${MAX_LOG} -b ${STD_BAF} -r ${STD_LRR} -d ${QUANTIDIR} -x ${LOHDIR} -y ${CNVDIR} -z ${QCDIR} ${SIF_NAME}"

${SRC}/quantisnpfilter.py -t ${ANALYSE_TYPE} -p ${PROBE} -l ${LENGTH} -m ${MAX_LOG} -b ${STD_BAF} -r ${STD_LRR} -d ${QUANTIDIR} -x ${LOHDIR} -y ${CNVDIR} -z ${QCDIR} ${SIF_NAME}









