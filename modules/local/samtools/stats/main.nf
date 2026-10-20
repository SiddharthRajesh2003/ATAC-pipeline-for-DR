process stats {
    tag "Running stats for ${sample_id}"
    publishDir { "${params.stats_dir}/${study_name}" }, mode: 'copy'

    container "quay.io/biocontainers/samtools:1.24--h9dcdb79_0"

    input:
    tuple val(sample_id), val(study_name), path(bam)

    output:
    tuple val(sample_id), val(study_name), path("${sample_id}_stats.txt")

    script:
    """
    samtools stats \\
        -@ ${task.cpus} \\
        ${bam} > ${sample_id}_stats.txt
    """
}
