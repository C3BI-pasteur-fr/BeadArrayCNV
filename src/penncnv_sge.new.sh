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
module load penncnv/2009.08.27


#################################################################################
# Help displaying                                                               #
#################################################################################

if [ "$1" = "-h" ]
then
	echo "" ;
	echo "USAGE:";
	echo "penncnv [-h] [-n int] [-l str] [-c int] [-h HMM] [-p PFB]";
	echo "          [-g GCMODEL] [-k] [-s int] [-v] [-d RESDIR] SIFFILE";
	echo "optional arguments:";
	echo "-h,             show this help message and exit";
	echo "";
	echo "detect_cnv options:";
	echo "-n int          minimum number of SNPs within CNV (default: 3)";
	echo "-l str          minimum length of bp within CNV (default: 1k)";
 	echo "-c int          minimum confidence score of CNV (default: 15)";
	echo "-m HMM          HMM model file (default: hhall.hmm)";
	echo "-p PFB          population frequency for B allelel file (default: hhall.hg18.pfb)";
	echo "-g GCMODEL      a file containing GC model for wave adjustment (default: hhall.hg18.gcmodel)";
	echo "";
	echo "kcolumn options:";
	echo "  -k            Perform column extraction on input file (default: False)";
	echo "  -s int        split (default: 2)";
	echo "";
	echo "General options:";
	echo "  -o RESDIR     Output path (default: PennCNV_RESULTS)";
  exit
fi

# PennCNV options
# ## detect_cnv options
DETECT_MINSNP=3
DETECT_MINLENGTH='1k'
DETECT_MINCONF=15

DETECT_GCMODEL=''
DETECT_PFB=''
DETECT_HMM=''

# ## kcolumn options
KCOLUMN="false"
KC_SPLIT=2
# ## general_options
DETECT_CNV_DIR='PennCNV_RESULTS'
mkdir -p ${DETECT_CNV_DIR}

while getopts ":n:l:c:m:p:g:s:o:k" opt; do
	echo $opt $OPTIND $OPTARG
	case $opt in
		
		n)
		DETECT_MINSNP="$OPTARG"
		if [ $DETECT_MINSNP -le 0 ]; then echo "   the minimum number of SNPs must be positive (option -n)" ; exit ; fi
		;;
		l)
		DETECT_MINLENGTH="$OPTARG"
		;;
		c)
		DETECT_MINCONF="$OPTARG"
		if [ $DETECT_MINCONF -le 0 ]; then echo "   minimum confidence score must be positive (option -c)" ; exit ; fi
		;;
		m)
		DETECT_HMM="$OPTARG"
		;;
		p)
		DETECT_PFB="$OPTARG"
		;;
		g)
		DETECT_GCMODEL="$OPTARG"
		;;
		k)
		KCOLUMN='true'
		;;
		s)
		KC_SPLIT="$OPTARG"
		if [ $KC_SPLIT -le 0 ]; then echo "   the ksplit number must be positive (option -s)" ; exit ; fi
		;;
		o)
		DETECT_CNV_DIR="$OPTARG"
		;;
  esac
done		

shift $((OPTIND -1))
SIF=$(cat $1 | head -n ${SGE_TASK_ID} | tail -n 1)
SIF_NAME=$(basename ${SIF}) 


if [ "${KCOLUMN}" = 'true' ]
   then
     echo "kcolumn.pl ${SIF} split ${17} -heading 3 --name_by_header -tab --out ${SIF}"
     kcolumn.pl ${SIF} split ${KC_SPLIT} -heading 3 --name_by_header -tab --out ${SIF}
     echo "detect_cnv.pl --test --hmm ${DETECT_HMM} --pfb ${DETECT_PFB} --gcmodel ${DETECT_GCMODEL} --minsnp ${DETECT_MINSNP} --confidence --minlength ${DETECT_MINLENGTH} --minconf ${DETECT_MINCONF} --out ${DETECT_CNV_DIR}/${SIF_NAME}_rawcnv ${SIF}.*"
	 detect_cnv.pl --test --hmm ${DETECT_HMM} --pfb ${DETECT_PFB} --gcmodel ${DETECT_GCMODEL} --minsnp ${DETECT_MINSNP} --confidence --minlength ${DETECT_MINLENGTH} --minconf ${DETECT_MINCONF} --out ${DETECT_CNV_DIR}/${SIF_NAME}_rawcnv ${SIF}.*
   else
     echo "detect_cnv.pl --test --hmm ${DETECT_HMM} --pfb ${DETECT_PFB} --gcmodel ${DETECT_GCMODEL} --minsnp ${DETECT_MINSNP} --confidence --minlength ${DETECT_MINLENGTH} --minconf ${12} --out ${DETECT_CNV_DIR}/${SIF_NAME}_rawcnv ${SIF}"
    detect_cnv.pl --test --hmm ${DETECT_HMM} --pfb ${DETECT_PFB} --gcmodel ${DETECT_GCMODEL} --minsnp ${DETECT_MINSNP} --confidence --minlength ${DETECT_MINLENGTH} --minconf ${DETECT_MINCONF} --out ${DETECT_CNV_DIR}/${SIF_NAME}_rawcnv ${SIF}
fi

echo "visualize_cnv.pl --format bed --out ${DETECT_CNV_DIR}/${SIF_NAME}_bedcnv ${DETECT_CNV_DIR}/${SIF_NAME}_rawcnv"
visualize_cnv.pl --format bed --out ${DETECT_CNV_DIR}/${SIF_NAME}_bedcnv ${DETECT_CNV_DIR}/${SIF_NAME}_rawcnv

echo "detect_cnv.pl --summary --pfb ${DETECT_PFB} --out ${DETECT_CNV_DIR}/${SIF_NAME}_summary ${SIF}"
detect_cnv.pl --summary --pfb ${DETECT_PFB}  --out ${DETECT_CNV_DIR}/${SIF_NAME}_summary ${SIF}
