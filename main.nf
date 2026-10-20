include { Preprocess_fastq } from './subworkflows/local/preprocess_fastq'
include { Alignment } from './subworkflows/local/alignment'
include { Process_bam } from './subworkflows/local/process_bam'
include { Peaks } from './subworkflows/local/peaks'
include { MultiQC } from './modules/local/multiqc'

workflow {
    // samplesheet columns: sample, study, organism, platform, layout, replicate, fastq_1, fastq_2 (same as the RNA-seq pipeline)
    samplesheet_ch = channel
        .fromPath(params.samplesheet, checkIfExists: true)
        .splitCsv(header: true)
        .map {
            row ->
                def single_end = row.layout == 'single'
                def reads = single_end ? [file(row.fastq_1)] : [file(row.fastq_1), file(row.fastq_2)]
                tuple(row.sample, row.study, row.organism, single_end, reads)
        }

    // Side-channels used later to re-attach organism / layout after steps that drop them
    sample_organism_ch = samplesheet_ch
        .map { sample_id, _study, organism, _single_end, _reads -> tuple(sample_id, organism) }

    sample_layout_ch = samplesheet_ch
        .map { sample_id, _study, _organism, single_end, _reads -> tuple(sample_id, single_end) }

    sample_info_ch = samplesheet_ch
        .map { sample_id, _study, organism, single_end, _reads -> tuple(sample_id, organism, single_end) }

    reads_ch = samplesheet_ch
        .map { sample_id, study, _organism, single_end, reads -> tuple(sample_id, study, single_end, reads) }

    // Same files as the RNA-seq pipeline: ${params.reference} points at its reference directory
    def reference_files = [
        'mus_musculus'      : "mouse_GRCm39",
        'homo_sapiens'      : 'human_hg38',
        'rattus_norvegicus' : 'rat_rn8'
    ]

    references_ch = channel
        .fromList(
            reference_files
                .collect {
                    organism, prefix ->
                        tuple(
                            organism,
                            file("${params.reference}/${prefix}_ref.fa"),
                            file("${params.reference}/${prefix}_annotation.gtf")
                        )
                }
        )
        // only organisms in the samplesheet, so a mouse-only run doesn't build human/rat Bowtie2 indexes
        .join(sample_organism_ch.map { _sample_id, organism -> organism }.unique())

    trimmed_ch = Preprocess_fastq(reads_ch)

    // re-attach organism before alignment needs it
    reads_with_organism_ch = trimmed_ch.reads
        .join(sample_organism_ch, by: 0)
        .map {
            sample_id, study_name, single_end, reads, organism ->
                tuple(sample_id, study_name, organism, single_end, reads)
        }

    aligned_ch = Alignment(reads_with_organism_ch, references_ch)

    processed_bam_ch = Process_bam(aligned_ch.bam, sample_layout_ch)

    peaks = Peaks(processed_bam_ch.bam, sample_info_ch, references_ch)

    // barrier: don't fire MultiQC until every terminal output has been produced for every sample
    all_done = channel.empty()
        .mix(trimmed_ch.fastqc_raw)
        .mix(trimmed_ch.fastqc_trimmed)
        .mix(aligned_ch.logs)
        .mix(processed_bam_ch.flagstat)
        .mix(processed_bam_ch.stats)
        .mix(processed_bam_ch.mkdp_metrics)
        .mix(processed_bam_ch.bigwig)
        .mix(peaks.consensus)
        .mix(peaks.counts)
        .collect()
        .map { done_list -> [done_list] } // wrap so combine() treats this as one opaque value instead of spreading its elements

    study_names_ch = samplesheet_ch
        .map { _sample_id, study, _organism, _single_end, _reads -> study }
        .unique()

    multiqc_input_ch = study_names_ch
        .combine(all_done)
        .map {
            study_name, _done ->
                tuple(study_name, [
                    file("${params.fastqc_dir}/${study_name}"),
                    file("${params.trimmed_reads_dir}/${study_name}"),
                    file("${params.align_logs_dir}/${study_name}"),
                    file("${params.picard_dir}/${study_name}"),
                    file("${params.flagstat_dir}/${study_name}"),
                    file("${params.stats_dir}/${study_name}"),
                    file("${params.peaks_dir}/${study_name}"),
                    file("${params.counts_dir}/${study_name}")
                ].findAll { f -> f.exists() })
        }

    MultiQC(multiqc_input_ch)
}
