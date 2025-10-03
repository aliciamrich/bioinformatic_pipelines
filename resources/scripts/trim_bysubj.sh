#!/bin/bash
#SBATCH --job-name=trim_bysubj
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --partition=batch,guest
#SBATCH --array=1-19
#SBATCH --output=/work/richlab/aliciarich/read_processing/logs/trim_bysubj_%A_%a.out
#SBATCH --error=/work/richlab/aliciarich/read_processing/logs/trim_bysubj_%A_%a.err

set -euo pipefail

module load apptainer

# --- paths ---
CONTAINERS="$WORK/read_processing/containers"
SIF="${CONTAINERS}/dorado.sif"

DEMUX_ROOT="$WORK/read_processing/reads/loris/demuxed/samples_bam"
RUN_DIR_A="${DEMUX_ROOT}/hdz${SLURM_ARRAY_TASK_ID}"
RUN_DIR_B="${DEMUX_ROOT}/hdz$(printf '%02d' "${SLURM_ARRAY_TASK_ID}")"
RUN_DIR=""
if   [[ -d "$RUN_DIR_A" ]]; then RUN_DIR="$RUN_DIR_A"
elif [[ -d "$RUN_DIR_B" ]]; then RUN_DIR="$RUN_DIR_B"
else
  echo "ERROR: no run dir hdz${SLURM_ARRAY_TASK_ID} or hdz$(printf '%02d' ${SLURM_ARRAY_TASK_ID}) under $DEMUX_ROOT" >&2
  exit 1
fi

# TSV: columns 'sampleID' <tab> 'subject'  (e.g., culi / warb)
KEYFILE="$WORK/read_processing/samples/loris/inventories/sample_subject.tsv"
if [[ ! -s "$KEYFILE" ]]; then
  echo "ERROR: sample key not found: $KEYFILE" >&2
  exit 1
fi

ROOT_OUT="$WORK/read_processing/datasets"  # we’ll write to $ROOT_OUT/<culi|warb>/raw/

# --- load sample->subject map ---
declare -A SUBJECT
while IFS=$'\t' read -r sid subj; do
  [[ "$sid" == "sampleID" ]] && continue
  [[ -z "${sid:-}" || -z "${subj:-}" ]] && continue
  SUBJECT["$sid"]="$subj"
done < "$KEYFILE"
SIDS=("${!SUBJECT[@]}")

# --- per-run log for unmatched samples ---
LOGROOT="/work/richlab/aliciarich/read_processing/logs/trim_by_subject"
mkdir -p "$LOGROOT"
MISSLOG="${LOGROOT}/missing_key_hdz$(printf '%02d' "${SLURM_ARRAY_TASK_ID}").tsv"
: > "$MISSLOG"  # truncate

echo "Run dir: $RUN_DIR"
echo "Output root: $ROOT_OUT"
echo "Key entries loaded: ${#SIDS[@]}"

# --- process BAMs (recursive, NUL-safe) ---
shopt -s nullglob
n_in=0; n_out=0; n_skip=0; n_nomatch=0

find "$RUN_DIR" -type f -name "*.bam" -print0 | while IFS= read -r -d '' bam; do
  ((n_in++))
  bname="$(basename "$bam")"
  base="${bname%.bam}"

  # skip controls
  if [[ "$base" == *_NTC* || "$base" == *_unclassified* ]]; then
    echo "Skipping control/unclassified: $bam"
    ((n_skip++))
    continue
  fi

  # 1) Prefer explicit HDZ-... token after final underscore
  sample=""
  if [[ "$base" =~ _((HDZ-[A-Za-z0-9-]+))$ ]]; then
    sample="${BASH_REMATCH[1]}"
  else
    # 2) fallback: last underscore token
    sample="${base##*_}"
  fi

  # 3) If not in key, search for any exact sampleID occurrence
  if [[ -z "${SUBJECT[$sample]:-}" ]]; then
    found=""
    for sid in "${SIDS[@]}"; do
      # match end-of-string or underscore-bounded token
      if [[ "$base" == *"_${sid}" || "$base" == "${sid}" || "$base" == *"_${sid}_"* ]]; then
        sample="$sid"
        found="yes"
        break
      fi
    done
    if [[ -z "$found" ]]; then
      echo -e "${base}\t${sample}\tNOT_IN_KEY" >> "$MISSLOG"
      ((n_nomatch++))
      # still write to 'unkn/raw' so the file isn't lost; you can triage later
    fi
  fi

  subj="${SUBJECT[$sample]:-}"
  short="unkn"
  if [[ -n "$subj" ]]; then
    short="$(echo "$subj" | tr '[:upper:]' '[:lower:]' | cut -c1-4)"  # culi|warb
  fi

  OUT_DIR="${ROOT_OUT}/${short}/raw"
  mkdir -p "$OUT_DIR"

  # Keep Dorado's long prefix in the output filename (no header mismatches later)
  out="${OUT_DIR}/${base}.fastq"
  if [[ -s "$out" ]]; then
    echo "Exists, skipping: $out"
    continue
  fi

  echo "[${SLURM_ARRAY_TASK_ID}] ${bname} -> ${short}/raw/${base}.fastq  (sampleID='${sample}', subject='${subj:-NA}')"
  apptainer exec \
    --bind "$(dirname "$bam")":"$(dirname "$bam")" \
    --bind "$OUT_DIR":"$OUT_DIR" \
    "$SIF" \
      dorado trim --sequencing-kit "SQK-16S114-24" --emit-fastq "$bam" > "$out"

  ((n_out++))
done

echo "Task ${SLURM_ARRAY_TASK_ID} summary: inputs=$n_in, written=$n_out, skipped=$n_skip, not_in_key=$n_nomatch"
echo "Unmatched (if any): $MISSLOG"