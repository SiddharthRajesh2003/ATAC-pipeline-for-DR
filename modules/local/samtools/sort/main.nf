process sort {
    tag "Sorting BAM for ${sample_id}"

    container "quay.io/biocontainers/samtools:1.24--h9dcdb79_0"

    input:
    tuple val(sample_id), val(study_name), path(bam)

    output:
    tuple val(sample_id), val(study_name), path("${sample_id}_sorted.bam")

    script:
    // Bowtie2 writes no @RG and Picard MarkDuplicates 3.4.0 hit an NPE on reads without one.
    // Added here, not via bowtie2 --rg-id, so -resume keeps finished alignments.
    """
    set -o pipefail
    samtools addreplacerg \\
        -r ID:${sample_id} \\
        -r SM:${sample_id} \\
        -r LB:${sample_id} \\
        -r PL:ILLUMINA \\
        -O bam \\
        ${bam} \\
        | samtools sort \\
            -@ ${task.cpus} \\
            -o ${sample_id}_sorted.bam \\
            -
    """
}
