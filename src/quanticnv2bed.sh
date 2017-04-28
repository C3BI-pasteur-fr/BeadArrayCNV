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
source /etc/profile.d/pasteur_modules.sh
module purge
module load Python/2.7.8

#################################################################################
# Help displaying                                                               #
#################################################################################

if [ "$1" = "-h" ] 
then
	echo "" ;
	echo "USAGE:";
	echo "quanticnv2bed [options] -d indir -i list";
	echo "";
	echo "quanticnv2bed Reformat CNV files from quantiSNP program in bed format for visualization in BeadStudio software and dispatch them in subdirectory (QuantiSNP_Result/BED)";
	echo "";
	echo "Options:";
	echo "-h,         Show this help message and exit";
	echo "";
	echo "-i file     File containing the list of sample's name";
	echo "-d dir      Input path where CNV file are located (Default: QuantiSNP_Result/CNV)";
	echo "-o dir      Output path where BED files will be stored (Default: QuantiSNP_Result/BED)";
	
fi


#################################################################################
# Default options
#################################################################################

QUANTIDIR_CNV='QuantiSNP_Result/CNV'
QUANTIDIR_BED='QuantiSNP_Result/BED'
SRC='.'

while getopts "i:d:o:a:" opt; do
	case $opt in
		i)
		SIF_LIST="$OPTARG"
		;;
		d)
		QUANTIDIR_CNV="$OPTARG"
		;;
		o)
		QUANTIDIR_BED="$OPTARG"
		;;
                a)
                SRC="$OPTARG"
  esac
done		


if [ ${SGE_TASK_ID} ]
then
  SIF=$(cat ${SIF_LIST} | head -n ${SGE_TASK_ID} | tail -n 1)
else
  SIF=$(cat ${SIF_LIST} | head -n ${SLURM_ARRAY_TASK_ID} | tail -n 1)
fi

SIF_NAME=$(basename ${SIF})
mkdir -p ${QUANTIDIR_BED}

python ${SRC}/quanticnv2bed.py -o ${QUANTIDIR_BED}  ${QUANTIDIR_CNV}/${SIF_NAME}.cnv || exit 1



