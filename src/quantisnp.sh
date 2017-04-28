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



source /etc/profile.d/pasteur_modules.sh
module purge
module load Python/2.7.8
module load quantisnp/v2.3



umask 002

#################################################################################
# Help displaying                                                               #
#################################################################################

if [ "$1" = "-h" ]
then
	echo "" ;
	echo "USAGE:";
	echo "quantisnp_new [options] -j SIFDIR -i FILE";
        echo "quantisnp_new program can analyse one or more input SIF file(s).";
	echo "";
	echo "Options:";
	echo "-h,             show this help message and exit";
	echo "";
	echo "-d DIR              Specify the directory which contains the SIF files";
	echo "-i FILE             File containing the list of sample's name";
	echo "-o RESDIR           Output directory (Default: QuantiSNP_Result)";
	echo "";
	echo "-e INT              Iteration number used for the EM algorithm during learning. (Default: 10)";
	echo "-l INT              The characteristic length used to calculate transition probabilities. (Default: 2,000,000)";
	echo "-c                  If not specified, then local GC-based correction of the Log R ratio";
	echo "                    is not performed.";
	echo "-p                  Generates a series of plots (gzipped Postscript format) of putative copy number alterations found";
	echo "-z                  Generates a gzipped text file containing list of Generalised Genotypes";
	echo "-x                  Specifies whether to do correction of the Log R Ratio for the X chromosome";
	echo "-g {male/female}    Specifies gender of the sample. Adjusts processing for the X chromosome for males.";
	echo ".....               If not specified, then automatic gender calling is used to predict gender. (Default: Automatic)";
	echo ".....               If gender is specified, the list file of sample's name (-j option) contain only sample of the specified gender.";
	echo "";
	echo "-t FILE       Sort SIF file(s) with gender and write output file(s) into 2 specific directories";
	echo "              - gender MALE (default ResultQuantiSNP_Male) and gender FEMALE (default ResultQuantiSNP_Female).";
	echo "              FILE contains gender information for each sample (2 columns)";
	echo "              Not compatible with the -g options";
	echo "              WARNING: SIF files will be divided into SIF_MALE and SIF_FEMALE subdirectory";
  exit
fi

SIF_DIR='SIF_FILES'
SIF_LIST='sifs.lst'
RESDIR='QuantiSNP_Result'
EMITERS=10
LENGTH=2000000
GC='False'
PLOT='False'
GENOTYPE='False'
DO_X_CORRECT='False'
GENDER='Automatic' #auto detect

while getopts "i:o:d:pze:l:cxg:" opt; do
	case $opt in
		d)
		SIF_DIR="$OPTARG"
		;;
		i)
		SIF_LIST="$OPTARG"
		;;
		o)
		RESDIR="$OPTARG"
		;;
		p)
		PLOT_T='True'
		;;
		z)
		GENOTYPE='True'
		;;
		e)
		EMITERS="$OPTARG"
		if [ ${EMITERS} -le 0 ]; then echo "   Iteration number used for the EM algorithm during learning must be positive (option -e)" ;  exit 1; fi;
		;;
		l)
		LENGTH="$OPTARG"
		if [ ${LENGTH} -le 0 ]; then echo "   The characteristic length used to calculate transition probabilities must be positive (option -l)" ;  exit 1;  fi
		;;
		c)
		GC='True'
		;;
		x)
		DO_X_CORRECT='True'
		;;
		g)
		GENDER="$OPTARG"
		if [ "${GENDER}" != 'male' ] && [ "${GENDER}" != 'female' ] && [ "${GENDER}" != 'Automatic' ]; then echo " Gender must be: male or female or 'Automatic' (option -g)";  exit 1; fi
		;;
  esac
done



mkdir -p ${RESDIR}

#shift $((OPTIND-1))

if [ ${SGE_TASK_ID} ]
then
  SIF=$(cat ${SIF_LIST} | head -n ${SGE_TASK_ID} | tail -n 1)
else
  SIF=$(cat ${SIF_LIST} | head -n ${SLURM_ARRAY_TASK_ID} | tail -n 1)
fi

SIF_NAME=$(basename ${SIF}) 

SUBSAMPLELEVEL=1
CHRX=23
CHRRANGE=1:23
GDER=""
GCDIR=""
PLOT=""
GENO=""
DOX=""

if [ "${GENDER}" != "Automatic" ]; then GDER="--gender ${GENDER}" ; fi
if [ "${GC}" = "True" ]; then GCDIR="--gcdir ${QSNPGCDIR}/b36/"; fi
if [ "${PLOT_T}" = "True" ] ; then PLOT="--plot"; fi
if [ "${GENOTYPE}" = "True" ]; then GENO="--genotype"; fi
if [ "${DO_X_CORRECT}" = "True" ]; then DOX="--doXcorrect"; fi

echo "quantisnp2 ${MCRROOT} --chr ${CHRRANGE} --outdir ${RESDIR} --sampleid ${SIF_NAME} ${GDER} --emiters ${EMITERS} --lsetting ${LENGTH} ${GCDIR} ${PLOT} ${GENO} --config ${QSNPCONFIGDIR}/params.dat --levels ${QSNPCONFIGDIR}/levels.dat --input-files ${SIF} --chrX ${CHRX} ${DOX}"
quantisnp2 ${MCRROOT} --chr ${CHRRANGE} --outdir ${RESDIR} --sampleid ${SIF_NAME} ${GDER} --emiters ${EMITERS} --lsetting ${LENGTH} ${GCDIR} ${PLOT} ${GENO} --config ${QSNPCONFIGDIR}/params.dat --levels ${QSNPCONFIGDIR}/levels.dat --input-files ${SIF} --chrX ${CHRX} ${DOX}

