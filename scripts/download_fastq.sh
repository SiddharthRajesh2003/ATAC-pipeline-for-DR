#!/bin/bash

#SBATCH -J Fastq_Download_atac
#SBATCH -p public
#SBATCH -o slurm_logs/download_%j.txt
#SBATCH -e slurm_logs/download_%j.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=srajes23@asu.edu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --qos=public
#SBATCH --time=48:00:00
#SBATCH --mem=50GB
#SBATCH -A grp_srangas1

# usage, from atac_pipeline/: sbatch scripts/download_fastq.sh <name in runs/runs_<name>.txt>

set -euo pipefail

base=/scratch/srajes23/atac_pipeline
perm=/data/srangas1/ATAC-pipeline-for-DR
sra_sif=$perm/containers/sra-tools_latest.sif
config=$perm/ncbi_config
sra=$base/sra_data
study=$1
fastq=$base/fastq/$study
mapfile -t runs < "runs/runs_$study.txt"

mkdir -p "$config" "$sra" "$fastq" "$base/tmp"

module load apptainer

APPT="apptainer exec --bind /scratch/srajes23:/scratch/srajes23 --home $config:/home/srajes23"

for acc in "${runs[@]}"; do
    # Yuan is too large to redo after a walltime kill: resubmitting skips finished runs
    [ -f "$fastq/$acc.done" ] && continue
    rm -f "$sra/$acc/$acc.sra.lock"
    $APPT "$sra_sif" prefetch "$acc" -O "$sra" --max-size u
    # --include-technical: the 10x barcode read is stored as technical and is dropped without it
    $APPT "$sra_sif" fasterq-dump "$sra/$acc/$acc.sra" -O "$fastq" -t "$base/tmp" -e 8 --split-files --include-technical --force
    pigz -f -p 8 "$fastq/$acc"_*.fastq
    touch "$fastq/$acc.done"
    rm -rf "${sra:?}/$acc"
done
