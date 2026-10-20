process flagstat {
    tag "Running flagstat for ${sample_id}"
    publishDir { "${params.flagstat_dir}/${study_name}" }, mode: 'copy'

    container "quay.io/biocontainers/samtools:1.24--h9dcdb79_0"

    input:
    tuple val(sample_id), val(study_name), path(bam)

    output:
    tuple val(sample_id), val(study_name), path("${sample_id}_flagstat.txt")

    script:
    """
    samtools flagstat \\
        -@ ${task.cpus} \\
        ${bam} > ${sample_id}_flagstat.txt
    """
}
