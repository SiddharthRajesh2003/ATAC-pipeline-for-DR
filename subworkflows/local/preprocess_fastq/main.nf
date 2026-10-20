include { FastQC as FastqcRaw } from '../../../modules/local/fastqc'
include { FastQC as FastqcTrimmed } from '../../../modules/local/fastqc'
include { Fastp } from '../../../modules/local/fastp'

workflow Preprocess_fastq {
    take:
    reads // tuple(sample_id, study_name, single_end, [fastq_1, (fastq_2)])

    main:
    FastqcRaw(reads.map { sample_id, study_name, _single_end, fq -> tuple(sample_id, study_name, fq) }, 'raw')

    Fastp(reads)

    FastqcTrimmed(Fastp.out.reads.map { sample_id, study_name, _single_end, fq -> tuple(sample_id, study_name, fq) }, 'trimmed')

    emit:
    reads = Fastp.out.reads
    fastqc_raw = FastqcRaw.out
    fastqc_trimmed = FastqcTrimmed.out
}
