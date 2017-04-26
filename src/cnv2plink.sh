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


if [ "$1" = "-h" ] 
then
	echo "" ;
	echo "USAGE:";
	echo "cnv2plink [options] -d outdir -i list -r indir -f file";
	echo "";
	echo "cnv2plink Reformat CNV file into plink format";
	echo "";
	echo "-i file     File containing the list of sample's name";
	echo "-o dir      Path where PLINK output files will be stored (Default: PLINK)";
	echo "";
	echo "-d dir      Input path for CNV files (Default: PennCNV_RESULTS for penncnv program\
                      or QuantiSNP_Result/CNV for quantisnp program";
	echo "-t str      CNV type: p or q";
	echo "............CNV files from PennCNV (-t p) or QuantiSNP (-t q) programs";
	echo "-f file     Pedigree file with Family ID (FID) and Individual ID (IID) at first and second columns";
	echo "";
	echo "";
fi
SIF_LIST=''
PLINK_DIR=PLINK
CNV_DIR=''
CNV_TYPE=''
IND_DIR=''
SRC=''
while getopts "i:o:d:t:f:a:" opt; do
	case $opt in
		i)
		SIF_LIST="$OPTARG"
		;;
		o)
		PLINK_DIR="$OPTARG"
		;;
		d)
		IND_DIR="$OPTARG"
		;;
		t)
		CNV_TYPE="$OPTARG"
if [ ${CNV_TYPE} != "p" ] && [ ${CNV_TYPE} != "q" ]; then echo "CNV type must be: p or q (option -t)"; exit; fi;
		;;
		f)
		PEDIGREE="$OPTARG" 
		;;
                a)
                SRC="$OPTARG"

  esac
done		


mkdir -p ${PLINK_DIR}
if [ ${SGE_TASK_ID} ]
then
  SIF=$(cat ${SIF_LIST} | head -n ${SGE_TASK_ID} | tail -n 1)
else
  SIF=$(cat ${SIF_LIST} | head -n ${SLURM_ARRAY_TASK_ID} | tail -n 1)
fi

SIF_NAME=$(basename ${SIF})

if [ ${CNV_TYPE} = "p" ]
    then
    	if [ "${IND_DIR}" = "" ]; then IND_DIR='PennCNV_RESULTS'; fi
		CNV="${IND_DIR}/${SIF_NAME}_rawcnv"
    else
    	if [ "${IND_DIR}" = "" ]; then IND_DIR='QuantiSNP_Result/CNV';fi
		CNV="${IND_DIR}/${SIF_NAME}.cnv"
fi

echo "cnv2plink -i ${CNV} -t ${CNV_TYPE} -f ${PEDIGREE} -o ${PLINK_DIR}"
python ${SRC}/cnv2plink.py -i ${CNV} -t ${CNV_TYPE} -f ${PEDIGREE} -o ${PLINK_DIR} || exit 1


