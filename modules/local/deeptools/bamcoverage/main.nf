process BamCoverage {
    tag "Writing bigWig for ${sample_id}"
    publishDir { "${params.bigwig_dir}/${study_name}" }, mode: 'copy'

    container "quay.io/biocontainers/deeptools:3.5.6--pyhdfd78af_0"

    input:
    tuple val(sample_id), val(study_name), path(bam), path(bai), val(single_end)

    output:
    tuple val(sample_id), val(study_name), path("${sample_id}.bw")

    script:
    def extend_args = single_end ? '' : '--extendReads'
    """
    bamCoverage \\
        -b ${bam} \\
        -o ${sample_id}.bw \\
        -p ${task.cpus} \\
        --binSize 10 \\
        --normalizeUsing CPM \\
        ${extend_args}
    """
}
