#!/bin/bash
#SBATCH --job-name=culi_16s
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --partition=batch,guest
#SBATCH --output=/work/richlab/aliciarich/pipeline_16s/logs/culi_16s_%j.out
#SBATCH --error=/work/richlab/aliciarich/pipeline_16s/logs/culi_16s_%j.err

set -euo pipefail
module load apptainer
module load anaconda

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate $NRDSTOR/snakemake

# --- repo root (code) ---
cd /work/richlab/aliciarich/pipeline_16s
export PROJ_ROOT=$PWD

snakemake --use-conda --profile workflow/profiles/hcc --jobs 32 --printshellcmds --rerun-incomplete