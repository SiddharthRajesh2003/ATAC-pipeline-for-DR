process sort {
    tag "Sorting BAM for ${sample_id}"

    container "quay.io/biocontainers/samtools:1.24--h9dcdb79_0"

    input:
    tuple val(sample_id), val(study_name), path(bam)

    output:
    tuple val(sample_id), val(study_name), path("${sample_id}_sorted.bam")

    script:
    """
    samtools sort \\
        -@ ${task.cpus} \\
        -o ${sample_id}_sorted.bam \\
        ${bam}
    """
}
