#!/bin/bash
#SBATCH --job-name=stage_bams
#SBATCH --time=00:20:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --partition=batch,guest
#SBATCH --output=/work/richlab/aliciarich/read_processing/logs/stage_bams_%j.out
#SBATCH --error=/work/richlab/aliciarich/read_processing/logs/stage_bams_%j.err

set -euo pipefail

DEMUX_ROOT="/work/richlab/aliciarich/read_processing/reads/loris/demuxed/samples_bam"
KEYFILE="/work/richlab/aliciarich/read_processing/samples/loris/inventories/sample_subject.tsv"
DEST_ROOT="/work/richlab/aliciarich/read_processing/datasets"

# load key → map sampleID → subject
declare -A SUBJECT
while IFS=$'\t' read -r sid subj; do
  [[ "$sid" == "sampleID" ]] && continue
  [[ -z "${sid:-}" || -z "${subj:-}" ]] && continue
  SUBJECT["$sid"]="$subj"
done < "$KEYFILE"

mkdir -p "$DEST_ROOT/culi/bam_raw" "$DEST_ROOT/warb/bam_raw" "$DEST_ROOT/unkn/bam_raw"

shopt -s nullglob
n=0; n_unk=0
# Recurse and handle spaces safely
find "$DEMUX_ROOT" -type f -name "*.bam" -print0 | while IFS= read -r -d '' bam; do
  bname=$(basename "$bam")                         # keep Dorado’s long prefix
  # pull sampleID as the token starting with 'HDZ-'
  sample=$(echo "$bname" | grep -o -m1 'HDZ-[A-Za-z0-9-]\+')
  # skip obvious controls
  if [[ "$bname" == *_NTC* || "$bname" == *_unclassified* ]]; then
    echo "skip control: $bname"
    continue
  fi
  subj="${SUBJECT[$sample]:-}"
  short="unkn"
  if [[ -n "$subj" ]]; then
    short=$(echo "$subj" | tr '[:upper:]' '[:lower:]' | cut -c1-4) # culi|warb
  else
    ((n_unk++))
  fi
  dest="$DEST_ROOT/$short/bam_raw/$bname"
  # create/update symlink (no data copy)
  ln -sf "$bam" "$dest"
  ((n++))
done

echo "Linked $n BAMs into $DEST_ROOT/{culi,warb,unkn}/bam_raw (unknowns: $n_unk)"