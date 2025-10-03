#!/bin/bash
#SBATCH --job-name=trim_recurs
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --partition=batch,guest
#SBATCH --output=/work/richlab/aliciarich/read_processing/logs/trim_%j.out
#SBATCH --error=/work/richlab/aliciarich/read_processing/logs/trim_%j.err

# Avoid aborting the whole loop on one failure
set -u -o pipefail

module load apptainer

SIF="/work/richlab/aliciarich/read_processing/containers/dorado.sif"
ROOT="/work/richlab/aliciarich/read_processing/datasets"

trim_subject () {
  local subj="$1"
  local in="$ROOT/$subj/bam_raw"
  local out="$ROOT/$subj/raw"
  mkdir -p "$out"

  echo "=== Trimming subject=${subj}"
  echo "INPUT:  $in"
  echo "OUTPUT: $out"

  # Collect BAMs (follow symlinks)
  mapfile -d '' BAMS < <(find -L "$in" -type f -name "*.bam" -print0 2>/dev/null || true)
  echo "Found ${#BAMS[@]} BAMs for ${subj}"

  local wrote=0 failed=0 skipped=0
  local fail_log="$out/trim_failures.txt"
  : > "$fail_log"

  for bam in "${BAMS[@]}"; do
    local bname="$(basename "$bam")"

    # Skip typical controls
    if [[ "$bname" == *NTC* || "$bname" == *unclassified* ]]; then
      echo "skip control: $bname"; ((skipped++)); continue
    fi

    # Resolve symlink target and verify readability
    local real; real="$(readlink -f -- "$bam" || true)"
    if [[ -z "$real" || ! -r "$real" ]]; then
      echo "BROKEN or unreadable: $bam" | tee -a "$fail_log"
      ((failed++)); continue
    fi

    # Keep full dorado prefix; just change extension
    local fq="$out/${bname%.bam}.fastq"
    if [[ -s "$fq" ]]; then
      echo "exists, skip: $fq"; ((skipped++)); continue
    fi

    echo "trim -> $fq"
    if apptainer exec \
         --bind "$(dirname "$real")":"$(dirname "$real")" \
         --bind "$out":"$out" \
         "$SIF" \
         dorado trim --sequencing-kit "SQK-16S114-24" --emit-fastq "$real" > "$fq"
    then
      ((wrote++))
    else
      echo "ERROR trimming: $bam" | tee -a "$fail_log"
      [[ -s "$fq" ]] || rm -f "$fq"
      ((failed++))
    fi
  done

  echo "subject=${subj} wrote=${wrote} skipped=${skipped} failed=${failed}"
  [[ "$failed" -gt 0 ]] && echo "See failures in: $fail_log"
}

trim_subject culi
trim_subject warb
trim_subject unkn   # enable if needed
