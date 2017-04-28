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


if [ "$1" = "-h" ] 
then
	echo "" ;
	echo "USAGE:";
	echo "sif4snippeep [options] -d indir -i list";
	echo "";
	echo "sif4snippeep use CNV result file of PennCNV or QuantiSNP programs to \
    reformat Signal Intensity File in Snippeep Signal Intensity File";
	echo "";
	echo "-i file     File containing the list of sample's name";
	echo "-o dir      Path where SNIPPEEP output files will be stored (Default: SNIPPEEP)";
	echo "";
	echo "-d dir      Input path for CNV files (Default: PennCNV_RESULTS for penncnv program\
                      or QuantiSNP_Result/CNV for quantisnp program";
	echo "-t str      CNV type: p or q";
	echo "............CNV files from PennCNV (-t p) or QuantiSNP (-t q) programs";
	echo "-c          Write output file in CSV tab delimited format";
	echo "";
	echo "";
fi
SIF_LIST=''
SNIPPEEP_DIR=SNIPPEEP
CNV_DIR=''
CSV=''
CNV_TYPE=''
IND_DIR=''
# SRC=/pasteur/projets/specific/PFGE_activites/CIB/distrib/
SRC='.'

while getopts "i:d:r:t:ca:o:" opt; do
	case $opt in
		i)
		SIF_LIST="$OPTARG"
		;;
		o)
		SNIPPEEP_DIR="$OPTARG"
		;;
		d)
		IND_DIR="$OPTARG"
		;;
		t)
		CNV_TYPE="$OPTARG"
if [ ${CNV_TYPE} != "p" ] && [ ${CNV_TYPE} != "q" ]; then echo "CNV type must be: p or q (option -t)"; exit; fi;
		;;
		c)
		CSV="-c"
		;;
                a)
                SRC="$OPTARG"
                ;;
  esac
done		


mkdir -p ${SNIPPEEP_DIR}
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

echo "${SRC}/sif4snippeep.py -c -i ${CNV} -s ${SIF} -t ${CNV_TYPE} ${CSV} -o ${SNIPPEEP_DIR}/${SIF_NAME}.snpp"
python ${SRC}/sif4snippeep.py -c -i ${CNV} -s ${SIF} -t ${CNV_TYPE} ${CSV} -o ${SNIPPEEP_DIR}/${SIF_NAME}.snpp || exit 1


