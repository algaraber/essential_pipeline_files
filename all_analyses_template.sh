#!/bin/bash

echo "Initialising conda and activating the freyja1.4.7 analysis environment..."

source ~/miniconda3/etc/profile.d/conda.sh
conda init bash
conda activate freyja1.4.7


echo ""
echo "These are the appsession IDs of all our WelshGov runs..."
bs appsession list

RUNID=$(bs appsession list | grep YYMMDD | cut -d "|" -f 3 | sed 's/ //g')
echo ""
echo "The ID of 20YYMMDD_WG is: $RUNID"
echo "This run will be downloaded now."

bs download appsession -i $RUNID

mkdir fastq_files
mv *_L1_*/*.fastq.gz fastq_files
rm -r *_L1_*/

echo ""
echo "This is what we have downloaded:"
cd fastq_files
ls -ltha

echo ""

echo "Counting reads now..."
zgrep -c "VL00233" *_R2_001.fastq.gz >> read_count.txt

echo ""
echo "Files have these many reads in them...:"
cat read_count.txt

echo ""
echo "Now the fastqc and multiqc files will be generated."
mkdir fastqc_files
fastqc *.fastq.gz -o fastqc_files

cd ..
multiqc fastq_files/fastqc_files --interactive

echo ""
echo "Prefix will be YYMMDD_AllWales"
echo "Directory with fastq data is: $PWD/fastq_files/"


for i in $(seq 5 -1 1)
do 
	echo "Proceeding in $i seconds"
	sleep 1
done

echo ""
echo "Running artic-nf pipeline..."


mkdir $PWD/nimagen_analysis

# Nextflow pipeline:
NXF_VER=20.04.0 nextflow run connor-lab/ncov2019-artic-nf -profile singularity \
--illumina \
--prefix YYMMDD_AllWales \
--directory $PWD/fastq_files/ \
--outdir $PWD/nimagen_analysis \
--bed ${HOME}/essential_pipeline_files/nimagen_config_files_20-12-22/primer_V4.bed \
--ref ${HOME}/essential_pipeline_files/nimagen_config_files_20-12-22/MN908947.3.fasta \
--gff ${HOME}/essential_pipeline_files/nimagen_config_files_20-12-22/MN908947.3.gff \
--yaml ${HOME}/essential_pipeline_files/nimagen_config_files_20-12-22/SARS-CoV-2.types.yaml

# Running Freyja:
echo ""
echo "Running Freyja now..."

#Full location of reference genome
ref="${HOME}/essential_pipeline_files/nimagen_config_files_20-12-22/MN908947.3.fasta"

#directory containing porimer trimmed bam outputs
indir="$PWD/nimagen_analysis/ncovIllumina_sequenceAnalysis_trimPrimerSequences/"

#suffix given to primer trimmed files
SUFFIX=".mapped.primertrimmed.sorted.bam"

#creation of file list to be processed
FILES="$indir"*"$SUFFIX"

#defining dir where you want the output data to be saved
outdir="$PWD/nimagen_analysis/"

#creation of freyja folder and folder for mixtures analysis
mkdir "${outdir}/freyja"
mkdir "${outdir}/freyja/mixtures"

#update freyja database
freyja update

#create loop for files to be processed, i = full path to primer trimmed bam
for i in ${FILES}; do

#trim file name to give just unique sample code, j = sample code
j=$(echo "${i}" | sed "s|$indir||g" | sed 's/-1_seqloc_.*$//g')

#print sample code
echo ${j}

#perform freyja analysis
        freyja variants "${i}" --variants "${outdir}/freyja/${j}_var" --depths "${outdir}/freyja/${j}_depth" --ref ${ref}
        freyja demix "${outdir}/freyja/${j}_var.tsv" "${outdir}/freyja/${j}_depth" --output "${outdir}/freyja/mixtures/${j}_mix"

done

#generate aggregate freyja analysis
freyja aggregate "${outdir}/freyja/mixtures/" --output "${outdir}/YYMMDD_AllWales_freyja.tsv"


# Finally, keep a record of what has been done:

echo ""
echo "This dataset ($PWD) was analysed on:" >> record.txt
date +%Y-%m-%d >> record.txt
echo "The commands used were:" >> record.txt
cat all_analyses.sh >> record.txt

echo ""
echo "Final messages:"
echo "The multiqc_report.html is in $PWD"
echo "The QC and freyja output files are in: ${PWD}/nimagen_analysis"
echo "And the read_count.txt file is in: ${PWD}/fastq_files"
echo ""
