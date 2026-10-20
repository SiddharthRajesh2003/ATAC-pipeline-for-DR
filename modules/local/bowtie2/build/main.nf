process Bowtie2Index {
    tag "Building Bowtie2 index for ${organism} genome"
    publishDir "${params.reference}", mode: 'copy'

    container "quay.io/biocontainers/bowtie2:2.5.4--he96a11b_7"

    input:
    tuple val(organism), path(reference)

    output:
    tuple val(organism), path("${organism}_bowtie2_index")

    script:
    """
    mkdir ${organism}_bowtie2_index
    bowtie2-build \\
        --threads ${task.cpus} \\
        ${reference} \\
        ${organism}_bowtie2_index/${organism}
    """
}
