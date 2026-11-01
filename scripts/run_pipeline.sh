#!/bin/bash

#SBATCH -J DR_ATAC_Pipeline
#SBATCH -p public
#SBATCH -o slurm_logs/pipeline_%j.txt
#SBATCH -e slurm_logs/pipeline_%j.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=srajes23@asu.edu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --qos=public
#SBATCH --time=96:00:00
#SBATCH --mem=8GB
#SBATCH -A grp_srangas1

set -euo pipefail

pipeline=/data/srangas1/ATAC-pipeline-for-DR
base=/scratch/srajes23/atac_pipeline
samplesheet=${1:-samplesheet/samplesheet.csv}
reports=$base/results/reports/${SLURM_JOB_ID:-local}
workdir=$base/work

mkdir -p slurm_logs "$reports" "$workdir"

module load openjdk-17.0.3_7-gcc-12.1.0
module load nextflow-26.04.0-gcc-13.2.0
module load apptainer
module load squashfs-4.6.1-gcc-11.2.0

nextflow run "$pipeline/main.nf" \
    -profile slurm \
    -resume \
    -w "$workdir" \
    --base "$base" \
    --samplesheet "$samplesheet" \
    -with-timeline "$reports/timeline.html" \
    -with-report "$reports/report.html" \
    -with-trace "$reports/trace.txt" \
    -with-dag "$reports/dag.html"
