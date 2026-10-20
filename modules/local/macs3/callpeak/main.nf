process CallPeaks {
    tag "Calling peaks for ${sample_id}"
    publishDir { "${params.peaks_dir}/${study_name}" }, mode: 'copy'

    container "quay.io/biocontainers/macs3:3.0.4--py312h71493bf_0"

    input:
    tuple val(sample_id), val(study_name), path(bam), val(genome_size), val(single_end)

    output:
    tuple val(sample_id), val(study_name), path("${sample_id}_peaks.narrowPeak"), emit: peaks
    path("${sample_id}_peaks.xls"), emit: xls

    script:
    // single-end has no fragment length, so centre a 200 bp window on each Tn5 cut site
    def format_args = single_end ? '-f BAM --nomodel --shift -100 --extsize 200' : '-f BAMPE'
    """
    macs3 callpeak \\
        -t ${bam} \\
        ${format_args} \\
        -g ${genome_size} \\
        -n ${sample_id} \\
        --keep-dup all \\
        -q 0.01 \\
        --outdir .
    """
}
