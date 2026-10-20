process Bowtie2Align {
    tag "Aligning reads for ${sample_id} of study ${study_name}"
    publishDir { "${params.align_logs_dir}/${study_name}" }, mode: 'copy', pattern: '*_bowtie2.log'

    container "quay.io/biocontainers/bowtie2:2.5.4--he96a11b_7"

    input:
    tuple val(sample_id), val(study_name), val(single_end), path(reads), val(organism), path(index)

    output:
    tuple val(sample_id), val(study_name), path("${sample_id}.sam"), path("${sample_id}_bowtie2.log")

    script:
    def reads_args = single_end ? "-U ${reads[0]}" : "-1 ${reads[0]} -2 ${reads[1]}"
    // -X 2000: keep nucleosome-spanning fragments, not just the ~500 bp default
    """
    bowtie2 \\
        -p ${task.cpus} \\
        --very-sensitive \\
        -X 2000 \\
        -x ${index}/${organism} \\
        ${reads_args} \\
        -S ${sample_id}.sam \\
        2> ${sample_id}_bowtie2.log
    """
}
