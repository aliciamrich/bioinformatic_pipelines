#!/bin/bash
#SBATCH --job-name=culi_16s
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --partition=batch,guest
#SBATCH --output=/work/richlab/aliciarich/pipeline_16s/logs/culi_16s_%j.out
#SBATCH --error=/work/richlab/aliciarich/pipeline_16s/logs/culi_16s_%j.err

module load apptainer
cd /work/richlab/aliciarich/pipeline_16s

export PROJ_ROOT=$PWD
snakemake --profile workflow/profiles/hcc \
  --config dataset=culi reads_in=/work/richlab/aliciarich/datasets/16s/culi/raw \
  --jobs 100 --rerun-incomplete --keep-going