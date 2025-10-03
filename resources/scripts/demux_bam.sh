#!/bin/bash
#SBATCH --time=1:30:00
#SBATCH --job-name=demux_culi
#SBATCH --error=/work/richlab/aliciarich/read_processing/logs/demux_culi_%A_%a.err
#SBATCH --output=/work/richlab/aliciarich/read_processing/logs/demux_culi_%A_%a.out
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --constraint='gpu_v100|gpu_t4'
#SBATCH --partition=gpu,guest_gpu
#SBATCH --gres=gpu:1
#SBATCH --mem=32GB
#SBATCH --array=1-19


module load apptainer


TRIMMED_FASTQ="$WORK/projects/read_processing/datasets/culi/raw"
mkdir -p "$TRIMMED_FASTQ"

reads="/work/richlab/aliciarich/read_processing/reads/loris"
tables="/work/richlab/aliciarich/read_processing/samples/loris"

demux_summaries="${tables}/dorado_summaries/demuxed_fastq"
basecalled="${reads}/basecalled"
samp_sheet="${tables}/sample_sheets/hdz${SLURM_ARRAY_TASK_ID}_sample_sheet.csv"

samples="${reads}/demuxed/samples_fastq"

demuxed="${samples}/hdz${SLURM_ARRAY_TASK_ID}"
trimmed="${reads}/trimmed/samples_bam/hdz${SLURM_ARRAY_TASK_ID}"

mkdir -p $demux_summaries $samples $demuxed $trimmed

cd "/work/richlab/aliciarich/read_processing/containers"

apptainer exec \
  --bind "${basecalled}:/data/basecalled" \
  --bind "${demuxed}:/data/demuxed" \
  --bind "${samp_sheet}:/data/samplesheet.csv:ro" \
  "dorado.sif" \
    dorado demux \
      "/data/basecalled/hdz${SLURM_ARRAY_TASK_ID}.bam" \
      --output-dir "/data/demuxed" \
      --sample-sheet "/data/samplesheet.csv" \
      --kit-name 'SQK-16S114-24' \
      --emit-summary

find $demuxed -type f -name "*.txt" | while read txt; do           
    mv -vf "$txt" "${demux_summaries}/hdz${SLURM_ARRAY_TASK_ID}_barcoding_summary.txt"   
done

find "$demuxed" -type f -name "*.bam" | while read -r bam; do
  base_name=$(basename "$bam" .bam)
  sampleID="${base_name#*_}"
  out_bam="${trimmed}/${sampleID}.bam"
  echo "Trimming $bam -> $out_bam"
  
  apptainer exec \
    --bind "$(dirname "$bam")":"$(dirname "$bam")" \
    --bind "$(dirname "$out_bam")":"$(dirname "$out_bam")" \
    "dorado.sif" \
      dorado trim \
        --sequencing-kit "SQK-16S114-24" \
        "$bam" > "$out_bam"
done
