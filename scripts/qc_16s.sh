#!/bin/bash
#SBATCH --job-name=qc_16s
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --partition=batch,guest
#SBATCH --output=/work/richlab/aliciarich/pipeline_16s/logs/qc_16s_%j.out
#SBATCH --error=/work/richlab/aliciarich/pipeline_16s/logs/qc_16s_%j.err

set -euo pipefail
module load apptainer
module load anaconda

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate $NRDSTOR/snakemake

# --- repo root (code) ---
cd /work/richlab/aliciarich/pipeline_16s
export PROJ_ROOT=$PWD

# --- use a tiny subset dir so the test is fast ---
# If you already have a “subset” folder with a few FASTQs, point to it here:
READS_SUBSET="/work/richlab/aliciarich/datasets/16s/culi/raw_subset"

echo "Checking subset FASTQs in: $READS_SUBSET"
ls -l "$READS_SUBSET" | head || true
echo "Count:"
find "$READS_SUBSET" -maxdepth 1 -type f -name "*.fastq" | wc -l

# --- DRY-RUN first (prints the two rules and commands) ---
snakemake -n -p \
  --profile workflow/profiles/hcc \
  --config dataset=culi reads_in="$READS_SUBSET" \
  --until nanoplot_qc

# --- REAL RUN of just fastcat -> nanoplot ---
snakemake -p \
  --profile workflow/profiles/hcc \
  --config dataset=culi reads_in="$READS_SUBSET" \
  --until nanoplot_qc \
  --rerun-incomplete --keep-going --jobs 50
  
conda deactivate