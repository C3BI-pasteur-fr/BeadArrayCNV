#! /bin/sh
#$ -S /bin/sh
#$ -V
#$ -cwd

########################################################################################
#                                                                                      #
#   Author: Maufrais Corinne,                                                          #
#   Organization: Center of Informatics for Biology,                                   #
#                 Institut Pasteur, Paris.                                             #
#   Distributed under GPLv3 Clause. Please refer to the COPYING document.              #
#                                                                                      #
########################################################################################

source /etc/profile.d/pasteur_modules.sh

umask 002 
module purge
module load penncnv
module load Python/2.7.8

CONFIG_FILE=$1
if [ ${CONFIG_FILE} ] 
then
   source ./${CONFIG_FILE}
fi

mkdir slurm_logs

# Split Illumina Report file into individual SIFs
if [ ${DO_SPLITTER} = True ]
	then
	rm -rf ${SIFS_LIST}
	mkdir -p ${SPLITTER_DIR}
        if [ ${SPLITTER_START} ]
             then
                 START="-s ${SPLITTER_START}"
             else
		START=""
        fi
        if [ ${SPLITTER_STOP} ]
             then 
                 STOP="-l ${SPLITTER_STOP}"
             else
		 STOP=""        
        fi
	echo "srun  -J splitter ${QUEUE} ${SRC}/sifsplitter.py -c -r ${SPLITTER_SEP} -p ${SPLITTER_DIR} -a ${SIFS_LIST} -i ${ILLUMINA_REPORT_FILE} ${START} ${STOP}"
	srun -J splitter ${QUEUE} ${SRC}/sifsplitter.py -c -r ${SPLITTER_SEP} -p ${SPLITTER_DIR} -a ${SIFS_LIST} -i ${ILLUMINA_REPORT_FILE} -s ${SPLITTER_START} -l ${SPLITTER_STOP} || exit 1
fi
## Number of task
TASK_ID=`wc -l ${SIFS_LIST}| awk '{print $1}'`

## Creation of the *.pfb file with Illumina specific data:
if [ ${DO_PFB} = True ]
	then
		echo "srun -J compile_pfb ${QUEUE} compile_pfb.pl `more ${SIFS_LIST}` -output ${PFB_FILE}"
		srun -J compile_pfb ${QUEUE} compile_pfb.pl `more ${SIFS_LIST}` -output ${PFB_FILE} || exit 1
fi

## Creation of the gcmodel file with Illumina specific data 
if [ ${DO_GC} = True ]
	then
		echo "srun -J cal_gc_snp ${QUEUE} cal_gc_snp.pl -v ${GC5_BASE_SORT} ${PFB_FILE} -out ${GCMODEL_FILE}"
		srun -J cal_gc_snp ${QUEUE} cal_gc_snp.pl -v ${GC5_BASE_SORT} ${PFB_FILE} -out ${GCMODEL_FILE} || exit 1 
fi

## PennCNV Calling
if [ ${DO_PENN} = True ]
	then
		
	mkdir -p ${PENN_DIR}
	if [ ${DO_KCOLUMN} = True ]
		then
			echo "sbatch --wait -J penncnv -o slurm_logs/penncnv-%A_%a.out -e slurm_logs/penncnv-%A_%a.err --array=1-${TASK_ID} ${QUEUE} ${SRC}/penncnv.sh -n ${DETECT_MINSNP} -l ${DETECT_MINLENGTH} -c ${DETECT_MINCONF} -m ${DETECT_HMM_FILE} -p ${PFB_FILE} -g ${GCMODEL_FILE} -o ${PENN_DIR} -k -s ${KC_SPLIT} ${SIFS_LIST}"
		sbatch --wait -J penncnv  -o slurm_logs/penncnv-%A_%a.out -e slurm_logs/penncnv-%A_%a.err --array=1-${TASK_ID} ${QUEUE} ${SRC}/penncnv.sh -n ${DETECT_MINSNP} -l ${DETECT_MINLENGTH} -c ${DETECT_MINCONF} -m ${DETECT_HMM_FILE} -p ${PFB_FILE} -g ${GCMODEL_FILE} -o ${PENN_DIR} -k -s ${KC_SPLIT} ${SIFS_LIST} ||exit 1
		else
			echo "sbatch --wait -J penncnv  -o slurm_logs/penncnv-%A_%a.out -e slurm_logs/penncnv-%A_%a.err --array=1-${TASK_ID} ${QUEUE} ${SRC}/penncnv.sh -n ${DETECT_MINSNP} -l ${DETECT_MINLENGTH} -c ${DETECT_MINCONF} -m ${DETECT_HMM_FILE} -p ${PFB_FILE} -g ${GCMODEL_FILE} -o ${PENN_DIR} ${SIFS_LIST}" 
	sbatch --wait -J penncnv  -o slurm_logs/penncnv-%A_%a.out -e slurm_logs/penncnv-%A_%a.err --array=1-${TASK_ID} ${QUEUE} ${SRC}/penncnv.sh -n ${DETECT_MINSNP} -l ${DETECT_MINLENGTH} -c ${DETECT_MINCONF} -m ${DETECT_HMM_FILE} -p ${PFB_FILE} -g ${GCMODEL_FILE} -o ${PENN_DIR} ${SIFS_LIST} || exit 1
	fi
fi

## Pre QuantiSNP Calling: Creation of sifs_list for male and female
if [ ${QUANTI_GENDER_SORTED} = True ]
	then
                echo "srun -J genderlist ${QUEUE} ${SRC}/genderlist.py -i ${SIFS_LIST} -j ${QUANTI_GENDER_FILE}"
		srun -J genderlist ${QUEUE} ${SRC}/genderlist.py -i ${SIFS_LIST} -j ${QUANTI_GENDER_FILE} || exit 1
		## Number of task
		TASK_ID_MALE=`wc -l ${SIFS_LIST_MALE}| awk '{print $1}'`
		TASK_ID_FEMALE=`wc -l ${SIFS_LIST_FEMALE}| awk '{print $1}'`
fi

## QuantiSNP Calling
if [ ${DO_QUANTI} = True ]
	then
	mkdir -p ${QUANTI_DIR}
	QUANTI_GCopt=''
	QUANTI_PLOTopt=''
	QUANTI_GENOopt=''
	QUANTI_Xopt=''
	if [ ${QUANTI_GC} = True ]; then QUANTI_GCopt=-c; fi;
	if [ ${QUANTI_PLOT} = True ]; then QUANTI_PLOTopt=-p; fi;
	if [ ${QUANTI_GENOTYPE} = True ]; then QUANTI_GENOopt=-z; fi;
	if [ ${QUANTI_DO_X_CORRECT} = True ]; then QUANTI_Xopt=-x; fi;

	if [ ${QUANTI_GENDER_SORTED} = True ]
		then
			# results path
			mkdir -p ${QUANTI_DIR_MALE}
			mkdir -p ${QUANTI_DIR_FEMALE}
			echo "sbatch  -o slurm_logs/quantisnp_male-%A_%a.out -e slurm_logs/quantisnp_male-%A_%a.err --wait -J quantisnp ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/quantisnp.sh -i ${SIFS_LIST_MALE} -d ${SPLITTER_DIR} -o ${QUANTI_DIR_MALE} -e ${QUANTI_EMITERS} -l ${QUANTI_LENGTH} -g male ${QUANTI_GCopt} ${QUANTI_PLOTopt} ${QUANTI_GENOopt} ${QUANTI_Xopt}"
sbatch -o slurm_logs/quantisnp_male-%A_%a.out -e slurm_logs/quantisnp_male-%A_%a.err -c 4 --wait -J quantisnp ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/quantisnp.sh -i ${SIFS_LIST_MALE} -d ${SPLITTER_DIR} -o ${QUANTI_DIR_MALE} -e ${QUANTI_EMITERS} -l ${QUANTI_LENGTH} -g male ${QUANTI_GCopt} ${QUANTI_PLOTopt} ${QUANTI_GENOopt} ${QUANTI_Xopt} || exit 1
			echo "sbatch -o slurm_logs/quantisnp_female-%A_%a.out -e slurm_logs/quantisnp_female-%A_%a.err --wait -J quantisnp ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/quantisnp.sh -i ${SIFS_LIST_FEMALE} -d ${SPLITTER_DIR} -o ${QUANTI_DIR_FEMALE} -e ${QUANTI_EMITERS} -l ${QUANTI_LENGTH} -g female ${QUANTI_GCopt} ${QUANTI_PLOTopt} ${QUANTI_GENOopt} ${QUANTI_Xopt}"
sbatch -o slurm_logs/quantisnp_male-%A_%a.out -e slurm_logs/quantisnp_male-%A_%a.err -c 4 --wait -J quantisnp ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/quantisnp.sh -i ${SIFS_LIST_FEMALE} -d ${SPLITTER_DIR} -o ${QUANTI_DIR_FEMALE} -e ${QUANTI_EMITERS} -l ${QUANTI_LENGTH} -g female ${QUANTI_GCopt} ${QUANTI_PLOTopt} ${QUANTI_GENOopt} ${QUANTI_Xopt} || exit 1
		else
			echo "sbatch -o slurm_logs/quantisnp_sh-%A_%a.out -e slurm_logs/quantisnp_sh-%A_%a.err --wait -J quantisnp ${QUEUE} --array=1-${TASK_ID} ${SRC}/quantisnp.sh -i ${SIFS_LIST} -d ${SPLITTER_DIR} -o ${QUANTI_DIR} -e ${QUANTI_EMITERS} -l ${QUANTI_LENGTH} -g ${QUANTI_GENDER} ${QUANTI_GCopt} ${QUANTI_PLOTopt} ${QUANTI_GENOopt} ${QUANTI_Xopt}"
sbatch -o slurm_logs/quantisnp_sh-%A_%a.out -e slurm_logs/quantisnp_sh-%A_%a.err -c 4 --wait -J quantisnp ${QUEUE} --array=1-${TASK_ID} ${SRC}/quantisnp.sh -i ${SIFS_LIST} -d ${SPLITTER_DIR} -o ${QUANTI_DIR} -e ${QUANTI_EMITERS} -l ${QUANTI_LENGTH} -g ${QUANTI_GENDER} ${QUANTI_GCopt} ${QUANTI_PLOTopt} ${QUANTI_GENOopt} ${QUANTI_Xopt} || exit 1
	fi
fi


## QuantiSNP filter: Filter quantiSNP output files and dispatch results in subdirectory (LOH, CNV, QC)"
if [ ${DO_Q_FILTER} = True ]
	then
		if [ ${QUANTI_GENDER_SORTED} = True ]
		then
			echo "sbatch -o slurm_logs/quantifilter_male-%A_%a.out -e slurm_logs/quantifilter_male-%A_%a.err --wait -J quantifilter ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/quantisnpfilter.sh -i ${SIFS_LIST_MALE} -d ${QUANTI_DIR_MALE} -t ${Q_FILTER_ANALYSE_TYPE} -p ${Q_FILTER_PROBE} -l ${Q_FILTER_LENGHT} -m ${Q_FILTER_MAX_LOG} -b ${Q_FILTER_STD_BAF} -r ${Q_FILTER_STD_LRR} -x ${QUANTI_LOH_DIR_MALE} -y ${QUANTI_CNV_DIR_MALE} -z ${QUANTI_QC_DIR_MALE} -a ${SRC}" 
		sbatch -o slurm_logs/quantifilter_male-%A_%a.out -e slurm_logs/quantifilter_male-%A_%a.err  --wait -J quantifilter ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/quantisnpfilter.sh -i ${SIFS_LIST_MALE} -d ${QUANTI_DIR_MALE} -t ${Q_FILTER_ANALYSE_TYPE} -p ${Q_FILTER_PROBE} -l ${Q_FILTER_LENGHT} -m ${Q_FILTER_MAX_LOG} -b ${Q_FILTER_STD_BAF} -r ${Q_FILTER_STD_LRR} -x ${QUANTI_LOH_DIR_MALE} -y ${QUANTI_CNV_DIR_MALE} -z ${QUANTI_QC_DIR_MALE}  -a ${SRC} || exit 1
			echo "sbatch -o slurm_logs/quantifilter_female-%A_%a.out -e slurm_logs/quantifilter_female-%A_%a.err --wait -J quantifilter ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/quantisnpfilter.sh -i ${SIFS_LIST_FEMALE} -d ${QUANTI_DIR_FEMALE} -t ${Q_FILTER_ANALYSE_TYPE} -p ${Q_FILTER_PROBE} -l ${Q_FILTER_LENGHT} -m ${Q_FILTER_MAX_LOG} -b ${Q_FILTER_STD_BAF} -r ${Q_FILTER_STD_LRR} -x ${QUANTI_LOH_DIR_FEMALE} -y ${QUANTI_CNV_DIR_FEMALE} -z ${QUANTI_QC_DIR_FEMALE}" 
			sbatch -o slurm_logs/quantifilter_female-%A_%a.out -e slurm_logs/quantifilter_female-%A_%a.err --wait -J quantifilter ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/quantisnpfilter.sh -i ${SIFS_LIST_FEMALE} -d ${QUANTI_DIR_FEMALE} -t ${Q_FILTER_ANALYSE_TYPE} -p ${Q_FILTER_PROBE} -l ${Q_FILTER_LENGHT} -m ${Q_FILTER_MAX_LOG} -b ${Q_FILTER_STD_BAF} -r ${Q_FILTER_STD_LRR} -x ${QUANTI_LOH_DIR_FEMALE} -y ${QUANTI_CNV_DIR_FEMALE} -z ${QUANTI_QC_DIR_FEMALE} -a ${SRC} || exit 1
				
		else
			echo "sbatch -o slurm_logs/quantifilter_sh-%A_%a.out -e slurm_logs/quantifilter_sh-%A_%a.err --wait -J quantifilter ${QUEUE} --array=1-${TASK_ID} ${SRC}/quantisnpfilter.sh -i ${SIFS_LIST} -d ${QUANTI_DIR} -t ${Q_FILTER_ANALYSE_TYPE} -p ${Q_FILTER_PROBE} -l ${Q_FILTER_LENGHT} -m ${Q_FILTER_MAX_LOG} -b ${Q_FILTER_STD_BAF} -r ${Q_FILTER_STD_LRR} -x ${QUANTI_LOH_DIR} -y ${QUANTI_CNV_DIR} -z ${QUANTI_QC_DIR}" 
		sbatch -o slurm_logs/quantifilter_sh-%A_%a.out -e slurm_logs/quantifilter_sh-%A_%a.err --wait -J quantifilter ${QUEUE} --array=1-${TASK_ID} ${SRC}/quantisnpfilter.sh -i ${SIFS_LIST} -d ${QUANTI_DIR} -t ${Q_FILTER_ANALYSE_TYPE} -p ${Q_FILTER_PROBE} -l ${Q_FILTER_LENGHT} -m ${Q_FILTER_MAX_LOG} -b ${Q_FILTER_STD_BAF} -r ${Q_FILTER_STD_LRR} -x ${QUANTI_LOH_DIR} -y ${QUANTI_CNV_DIR} -z ${QUANTI_QC_DIR}  -a ${SRC}|| exit 1
		fi
fi

## QuantiCNV2bed: Reformat CNV files from quantiSNP program in bed format for visualization in BeadStudio software. Dispatch results in subdirectory (BED)
if [ ${DO_Q_CNV_BED} = True ]
then
	if [ ${QUANTI_GENDER_SORTED} = True ]
		then
		echo "sbatch -o slurm_logs/quanti2bed_male-%A_%a.out -e slurm_logs/quanti2bed_male-%A_%a.err --wait -J quanti2bed ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/quanticnv2bed.sh -i ${SIFS_LIST_MALE} -d ${QUANTI_CNV_DIR_MALE} -o ${QUANTI_DIR_BED_MALE}" 
sbatch -o slurm_logs/quanti2bed_male-%A_%a.out -e slurm_logs/quanti2bed_male-%A_%a.err --wait -J quanti2bed ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/quanticnv2bed.sh -i ${SIFS_LIST_MALE} -d ${QUANTI_CNV_DIR_MALE} -o ${QUANTI_DIR_BED_MALE} -a ${SRC} || exit 1
		echo "sbatch -o slurm_logs/quanti2bed_female-%A_%a.out -e slurm_logs/quanti2bed_female-%A_%a.err --wait -J quanti2bed ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/quanticnv2bed.sh -i ${SIFS_LIST_FEMALE} -d ${QUANTI_CNV_DIR_FEMALE} -o ${QUANTI_DIR_BED_FEMALE}" 
sbatch -o slurm_logs/quanti2bed_female-%A_%a.out -e slurm_logs/quanti2bed_female-%A_%a.err --wait -J quanti2bed ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/quanticnv2bed.sh -i ${SIFS_LIST_FEMALE} -d ${QUANTI_CNV_DIR_FEMALE} -o ${QUANTI_DIR_BED_FEMALE} -a ${SRC} || exit 1
		else
		echo "sbatch -o slurm_logs/quanti2bed_sh-o slurm_logs/quanti2bed_female-%A_%a.out -e slurm_logs/quanti2bed_female-%A_%a.err-%A_%a.out -e slurm_logs/quanti2bed_sh-%A_%a.err --wait -J quanti2bed ${QUEUE} --array=1-${TASK_ID} ${SRC}/quanticnv2bed.sh -i ${SIFS_LIST} -d ${QUANTI_CNV_DIR} -o ${QUANTI_DIR_BED}" 
		sbatch -o slurm_logs/quanti2bed_sh-%A_%a.out -e slurm_logs/quanti2bed_sh-%A_%a.err --wait -J quanti2bed ${QUEUE} --array=1-${TASK_ID} ${SRC}/quanticnv2bed.sh -i ${SIFS_LIST} -d ${QUANTI_CNV_DIR} -o ${QUANTI_DIR_BED} -a ${SRC} || exit 1
	fi
fi

## Concatenation: concat all individual files in a uniq file

if [ ${DO_CAT_QUANTI_CNV} = True ]
then
	if [ ${QUANTI_GENDER_SORTED} = True ]
		then
		echo "srun -J cat4cnv ${QUEUE} ${SRC}/cat4cnv.py -t q ${QUANTI_CNV_DIR_MALE}/*.cnv -o ${QUANTI_CNV_DIR_MALE}"
		srun -J cat4cnv ${QUEUE} ${SRC}/cat4cnv.py -t q ${QUANTI_CNV_DIR_MALE}/*.cnv -o ${QUANTI_CNV_DIR_MALE} || exit 1
		echo "srun -J cat4cnv ${QUEUE} ${SRC}/cat4cnv.py -t q ${QUANTI_CNV_DIR_FEMALE}/*.cnv -o ${QUANTI_CNV_DIR_FEMALE}"
		srun -J cat4cnv ${QUEUE} ${SRC}/cat4cnv.py -t q ${QUANTI_CNV_DIR_FEMALE}/*.cnv -o ${QUANTI_CNV_DIR_FEMALE} || exit 1
		else
		echo "srun -J cat4cnv ${QUEUE} ${SRC}/cat4cnv.py -t q ${QUANTI_CNV_DIR}/*.cnv -o ${QUANTI_CNV_DIR}"
		srun -J cat4cnv ${QUEUE} ${SRC}/cat4cnv.py -t q ${QUANTI_CNV_DIR}/*.cnv -o ${QUANTI_CNV_DIR} || exit 1
	fi
fi

if [ ${DO_CAT_PENN_CNV} = True ]
then
	echo "srun -J cat4cnv ${QUEUE}  ${SRC}/cat4cnv.py -t p ${PENN_DIR}/*_rawcnv -o ${PENN_DIR}"
	srun -J cat4cnv ${QUEUE} ${SRC}/cat4cnv.py -t p ${PENN_DIR}/*_rawcnv -o ${PENN_DIR}  || exit 1
fi

if [ ${DO_CAT_QUANTI_BED} = True ]
then
	if [ ${QUANTI_GENDER_SORTED} = True ]
		then
		echo "srun -J cat4bed ${QUEUE} ${SRC}/cat4bed.py ${QUANTI_DIR_BED_MALE}/*bed -o ${QUANTI_DIR_BED_MALE}"
		srun -J cat4bed ${QUEUE} ${SRC}/cat4bed.py ${QUANTI_DIR_BED_MALE}/*cnvbed -o ${QUANTI_DIR_BED_MALE} || exit 1
		echo "srun -J cat4bed ${QUEUE} ${SRC}/cat4bed.py ${QUANTI_DIR_BED_FEMALE}/*bed -o ${QUANTI_DIR_BED_FEMALE}"
		srun -J cat4bed ${QUEUE} ${SRC}/cat4bed.py ${QUANTI_DIR_BED_FEMALE}/*cnvbed -o ${QUANTI_DIR_BED_FEMALE} || exit 1
	else
		echo "srun -J cat4bed ${QUEUE} ${SRC}/cat4bed.py ${QUANTI_DIR_BED}/*bed -o ${QUANTI_DIR_BED}"
		srun -J cat4bed ${QUEUE} ${SRC}/cat4bed.py ${QUANTI_DIR_BED}/*cnvbed -o ${QUANTI_DIR_BED} || exit 1
	fi
fi


if [ ${DO_CAT_QUANTI_LOH} = True ]
then
        if [ ${QUANTI_GENDER_SORTED} = True ]
                then
                echo "srun -J cat4loh ${QUEUE} ${SRC}/cat4loh.py ${QUANTI_LOH_DIR_MALE}/*loh -o ${QUANTI_LOH_DIR_MALE} -t q"
                srun -J cat4loh ${QUEUE} ${SRC}/cat4loh.py ${QUANTI_LOH_DIR_MALE}/*loh -o ${QUANTI_LOH_DIR_MALE} -t q || exit 1
                echo "srun -J cat4loh ${QUEUE} ${SRC}/cat4loh.py ${QUANTI_LOH_DIR_FEMALE}/*loh -o ${QUANTI_LOH_DIR_FEMALE} -t q" 
                srun -J cat4loh ${QUEUE}  ${SRC}/cat4loh.py ${QUANTI_LOH_DIR_FEMALE}/*loh -o ${QUANTI_LOH_DIR_FEMALE} -t q || exit 1
        else
                echo "srun -J cat4cnv ${QUEUE} ${SRC}/cat4loh.py ${QUANTI_LOH_DIR}/*loh -o ${QUANTI_LOH_DIR} -t q"
                srun -J cat4cnv ${QUEUE} ${SRC}/cat4loh.py ${QUANTI_LOH_DIR}/*loh -o ${QUANTI_LOH_DIR} -t q || exit 1
        fi
fi

if [ ${DO_CAT_QUANTI_QC} = True ]
then
        if [ ${QUANTI_GENDER_SORTED} = True ]
                then
                echo "srun -J cat4qc ${QUEUE} ${SRC}/cat4qc.py ${QUANTI_QC_DIR_MALE}/*qc -o ${QUANTI_QC_DIR_MALE} -t q"
                srun -J cat4qc ${QUEUE} ${SRC}/cat4qc.py ${QUANTI_QC_DIR_MALE}/*qc -o ${QUANTI_QC_DIR_MALE} -t q || exit 1
                echo "srun -J cat4qc ${QUEUE} ${SRC}/cat4qc.py ${QUANTI_QC_DIR_FEMALE}/*qc -o ${QUANTI_QC_DIR_FEMALE} -t q" 
                srun -J cat4qc ${QUEUE}  ${SRC}/cat4qc.py ${QUANTI_QC_DIR_FEMALE}/*qc -o ${QUANTI_QC_DIR_FEMALE} -t q || exit 1
        else
                echo "srun -J cat4cnv ${QUEUE} ${SRC}/cat4qc.py ${QUANTI_QC_DIR}/*qc -o ${QUANTI_QC_DIR} -t q"
                srun -J cat4cnv ${QUEUE} ${SRC}/cat4qc.py ${QUANTI_QC_DIR}/*qc -o ${QUANTI_QC_DIR} -t q || exit 1
        fi
fi



if [ ${DO_CAT_PENN_BED} = True ]
then
	echo "srun -J cat4bed ${QUEUE} {SRC}/cat4bed.py ${PENN_DIR}/*_bedcnv -o ${PENN_DIR}"
	srun -J cat4bed ${QUEUE}  ${SRC}/cat4bed.py ${PENN_DIR}/*_bedcnv -o ${PENN_DIR} || exit 1
fi

if [ ${DO_CAT_PENN_SUMMARY} = True ] 
then
	echo "srun -J cat4summ ${QUEUE} ${SRC}/cat4summary.py -t p ${PENN_DIR}/*_summary -o ${PENN_DIR}" 
	srun -J cat4summ ${QUEUE} ${SRC}/cat4summary.py -t p ${PENN_DIR}/*_summary -o ${PENN_DIR} || exit 1
fi


## Snippeep
if [ ${DO_S_QUANTI_CNV} = True ]
then
	if [ ${QUANTI_GENDER_SORTED} = True ]
	then
		
		echo "sbatch -o slurm_logs/snippeep_male-%A_%a.out -e slurm_logs/snippeep_male-%A_%a.err --wait -J snippeep ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/sif4snippeep.sh -i ${SIFS_LIST_MALE} -o ${SNIPPEEP_QUANTI_DIR_MALE} -d ${QUANTI_CNV_DIR_MALE} -t q "
sbatch -o slurm_logs/snippeep_male-%A_%a.out -e slurm_logs/snippeep_male-%A_%a.err --wait -J snippeep ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/sif4snippeep.sh -i ${SIFS_LIST_MALE} -o ${SNIPPEEP_QUANTI_DIR_MALE} -d ${QUANTI_CNV_DIR_MALE} -t q -a ${SRC} || exit 1
		echo "sbatch -o slurm_logs/snippeep_female-%A_%a.out -e slurm_logs/snippeep_female-%A_%a.err --wait -J snippeep ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/sif4snippeep.sh -i ${SIFS_LIST_FEMALE} -o ${SNIPPEEP_QUANTI_DIR_FEMALE} -d ${QUANTI_CNV_DIR_FEMALE} -t q "
sbatch -o slurm_logs/snippeep_female-%A_%a.out -e slurm_logs/snippeep_female-%A_%a.err --wait -J snippeep ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/sif4snippeep.sh -i ${SIFS_LIST_FEMALE} -o ${SNIPPEEP_QUANTI_DIR_FEMALE} -d ${QUANTI_CNV_DIR_FEMALE} -t q -a ${SRC} || exit 1
	else
		echo "sbatch -o slurm_logs/snippeep_sh-%A_%a.out -e slurm_logs/snippeep_sh-%A_%a.err --wait -J snippeep ${QUEUE} --array=1-${TASK_ID} ${SRC}/sif4snippeep.sh -i ${SIFS_LIST} -o ${SNIPPEEP_QUANTI_DIR} -d ${QUANTI_CNV_DIR} -t q "
sbatch -o slurm_logs/snippeep_sh-%A_%a.out -e slurm_logs/snippeep_sh-%A_%a.err --wait -J snippeep ${QUEUE} --array=1-${TASK_ID} ${SRC}/sif4snippeep.sh -i ${SIFS_LIST} -o ${SNIPPEEP_QUANTI_DIR} -d ${QUANTI_CNV_DIR} -t q -a ${SRC}|| exit 1
	fi
fi

if [ ${DO_S_PENN_CNV} = True ]
then
	echo "sbatch -o slurm_logs/snippeep_sh-%A_%a.out -e slurm_logs/snippeep_sh-%A_%a.err --wait -J snippeep ${QUEUE} --array=1-${TASK_ID} ${SRC}/sif4snippeep.sh -i ${SIFS_LIST} -o ${SNIPPEEP_PENN_DIR} -d ${PENN_DIR} -t p "
sbatch -o slurm_logs/snippeep_sh-%A_%a.out -e slurm_logs/snippeep_sh-%A_%a.err --wait -J snippeep ${QUEUE} --array=1-${TASK_ID} ${SRC}/sif4snippeep.sh -i ${SIFS_LIST} -o ${SNIPPEEP_PENN_DIR} -d ${PENN_DIR} -t p  -a ${SRC}|| exit 1
fi

# plink

if [ ${DO_P_QUANTI_CNV} = True ]
then
	if [ ${QUANTI_GENDER_SORTED} = True ]
	then
		echo "sbatch  -o slurm_logs/plink_male-%A_%a.out -e slurm_logs/plink_male-%A_%a.err --wait -J plink ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/cnv2plink.sh -i ${SIFS_LIST_MALE} -o ${PLINK_QUANTI_DIR_MALE} -d ${QUANTI_CNV_DIR_MALE} -f ${PEDIGREE_FILE} -t q -a ${SRC}"
sbatch -o slurm_logs/plink_male-%A_%a.out -e slurm_logs/plink_male-%A_%a.err --wait -J plink ${QUEUE} --array=1-${TASK_ID_MALE} ${SRC}/cnv2plink.sh -i ${SIFS_LIST_MALE} -o ${PLINK_QUANTI_DIR_MALE} -d ${QUANTI_CNV_DIR_MALE} -f ${PEDIGREE_FILE} -t q -a ${SRC}|| exit 1
		echo "sbatch -o slurm_logs/plink_female-%A_%a.out -e slurm_logs/plink_female-%A_%a.err --wait -J plink ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/cnv2plink.sh -i ${SIFS_LIST_FEMALE} -o ${PLINK_QUANTI_DIR_FEMALE} -d ${QUANTI_CNV_DIR_FEMALE} -f ${PEDIGREE_FILE} -t q -a ${SRC}"
sbatch -o slurm_logs/plink_female-%A_%a.out -e slurm_logs/plink_female-%A_%a.err --wait -J plink ${QUEUE} --array=1-${TASK_ID_FEMALE} ${SRC}/cnv2plink.sh -i ${SIFS_LIST_FEMALE} -o ${PLINK_QUANTI_DIR_FEMALE} -d ${QUANTI_CNV_DIR_FEMALE} -f ${PEDIGREE_FILE} -t q -a ${SRC} || exit 1
	else
		echo "sbatch -o slurm_logs/plink_sh-%A_%a.out -e slurm_logs/plink_sh-%A_%a.err --wait -J plink ${QUEUE} --array=1-${TASK_ID} ${SRC}/cnv2plink.sh -i ${SIFS_LIST} -o ${PLINK_QUANTI_DIR} -d ${QUANTI_CNV_DIR} -f ${PEDIGREE_FILE} -t q -a ${SRC}"
sbatch -o slurm_logs/plink_sh-%A_%a.out -e slurm_logs/plink_sh-%A_%a.err --wait -J plink ${QUEUE} --array=1-${TASK_ID} ${SRC}/cnv2plink.sh -i ${SIFS_LIST} -o ${PLINK_QUANTI_DIR} -d ${QUANTI_CNV_DIR} -f ${PEDIGREE_FILE} -t q -a ${SRC}|| exit 1
	fi
fi


if [ ${DO_P_PENN_CNV} = True ]
then
	echo "sbatch -o slurm_logs/plink_sh-%A_%a.out -e slurm_logs/plink_sh-%A_%a.err --wait -J plink ${QUEUE} --array=1-${TASK_ID} ${SRC}/cnv2plink.sh -i ${SIFS_LIST} -o ${PLINK_PENN_DIR} -d ${PENN_DIR} -f ${PEDIGREE_FILE} -t p -a ${SRC} "
sbatch -o slurm_logs/plink_sh-%A_%a.out -e slurm_logs/plink_sh-%A_%a.err --wait -J plink ${QUEUE} --array=1-${TASK_ID} ${SRC}/cnv2plink.sh -i ${SIFS_LIST} -o ${PLINK_PENN_DIR} -d ${PENN_DIR} -f ${PEDIGREE_FILE} -t p -a ${SRC} || exit 1
fi


exit 0

