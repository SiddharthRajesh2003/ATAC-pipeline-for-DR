# ATAC-seq pipeline for DR

Nextflow (DSL2) pipeline for bulk ATAC-seq, run on ASU Sol (SLURM + Apptainer). It turns FASTQs into
filtered BAMs, bigwigs, per-sample MACS3 peaks, a consensus peak set per study and a peak × sample count
matrix. It uses the same samplesheet format and reference files as the RNA-seq pipeline, so the peaks are
annotated with the same Ensembl gene IDs as the RNA counts.

**Status:** ATAC is excluded from paper 1 (PI decision, 2026-11-13) because every sample fails the FRiP
gate in `analysis/preprocess_atac.qmd`.

## Steps

| Step | Tool | Notes |
|---|---|---|
| QC (raw + trimmed) | FastQC 0.12.1 | |
| Trimming | fastp 1.3.6 | `-q 20 --trim_poly_g`; PE adapter auto-detect |
| Index | Bowtie2 2.5.4 | built once per organism, published to `${reference}/<organism>_bowtie2_index` and reused |
| Alignment | Bowtie2 | `--very-sensitive -X 2000` (keeps nucleosome-spanning fragments) |
| Sort | samtools 1.24 | adds `@RG` (Picard needs it) |
| Mark duplicates | Picard 3.4.0 | |
| Filter | samtools | MAPQ ≥ 30, `-F 1804`, proper pairs (PE), drops `MT`/`chrM` |
| Stats | samtools flagstat / stats | the `stats` insert-size histogram is the fragment-length QC |
| Coverage | deepTools 3.5.6 `bamCoverage` | 10 bp bins, CPM |
| Peaks | MACS3 3.0.4 | PE: `-f BAMPE`; SE: `--nomodel --shift -100 --extsize 200`; `-q 0.01` |
| Consensus | bedtools 2.31.1 | union merge of all samples' peaks per study, annotated with the nearest gene TSS |
| Counts | featureCounts (subread 2.1.1) | consensus peaks as SAF |
| Report | MultiQC | one report per study |

Code layout: `main.nf` → `subworkflows/local/{preprocess_fastq,alignment,process_bam,peaks}` → `modules/local/*`.

## Inputs

**Samplesheet** (`samplesheet/samplesheet.csv`), same columns as the RNA-seq pipeline:

```
sample,study,organism,platform,layout,replicate,fastq_1,fastq_2
SRR33173255,Jiang_2026,mus_musculus,ILLUMINA,paired,1,/scratch/.../SRR33173255_1.fastq.gz,/scratch/.../SRR33173255_2.fastq.gz
```

- `organism`: `mus_musculus`, `homo_sapiens` or `rattus_norvegicus`
- `layout`: `paired` or `single` (leave `fastq_2` empty for single)
- Each study must have one organism and one layout.

**References** (`params.reference`, default `/data/srangas1/ATAC-pipeline-for-DR/reference`). These are copies of the
RNA-seq pipeline's files:

```
mouse_GRCm39_ref.fa   mouse_GRCm39_annotation.gtf
human_hg38_ref.fa     human_hg38_annotation.gtf
rat_rn8_ref.fa        rat_rn8_annotation.gtf
```

Only organisms that appear in the samplesheet are indexed. MACS3 genome sizes are in `params.macs_gsize`; the rat
value is approximate.

## Running on Sol

From `atac_pipeline/`:

```bash
# 1. Download FASTQs for a study listed in runs/runs_<study>.txt (one SRR per line)
sbatch scripts/download_fastq.sh Jiang_2026

# 2. Run the pipeline (always uses -resume)
sbatch scripts/run_pipeline.sh                       # default samplesheet
sbatch scripts/run_pipeline.sh path/to/sheet.csv     # another samplesheet
```

`download_fastq.sh` can be resubmitted after a walltime kill: it skips runs that already have a `.done` marker. It
passes `--include-technical` so that the 10x barcode read is kept.

`run_pipeline.sh` runs `$perm/main.nf` with `-profile slurm`, using the work dir `/scratch/srajes23/atac_pipeline/work`.
The Nextflow timeline, report, trace and DAG are written to `results/reports/<job id>/`. To change paths, edit `base`
and `perm` in `nextflow.config` and in both scripts.

## Outputs

Everything goes to `${base}/results/` and is split by study:

| Directory | Contents |
|---|---|
| `fastqc/<study>/{raw,trimmed}` | FastQC reports |
| `trimmed_reads/<study>` | trimmed FASTQ, fastp json/html |
| `alignment/logs/<study>` | Bowtie2 logs |
| `alignment/picard/<study>` | duplication metrics |
| `alignment/filtered_bam/<study>` | filtered BAM + index |
| `flagstat/`, `samtools_stats/` | BAM QC |
| `bigwig/<study>` | CPM bigwigs |
| `peaks/<study>` | MACS3 narrowPeak / xls / summits |
| `consensus_peaks/<study>` | `<study>_consensus.saf`, `<study>_consensus_annotated.bed` (nearest TSS + distance) |
| `counts/<study>` | `<study>_peak_counts.txt` (featureCounts) |
| `multiqc/<study>` | MultiQC report |

## Downstream

`analysis/preprocess_atac.qmd` (R) reads the pipeline outputs, the GEO peak files in `atac_data/` and the run tables
in `metadata/`. It applies the QC gates (such as FRiP ≥ 0.2) and writes `results/processed/`. Studies are kept
separate, with no merging and no batch correction. To render it, run this from `atac_pipeline/`:

```bash
quarto render analysis/preprocess_atac.qmd
```

## Known limits

- The consensus is a plain union of all peaks. If that set is too noisy, require each peak to be found in at
  least 2 samples (`modules/local/bedtools/consensus`).
- MultiQC uses the `multiqc/multiqc:latest` image, which is not pinned to a version.
