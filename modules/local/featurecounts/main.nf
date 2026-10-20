process FeatureCounts {
    tag "Counting reads in consensus peaks for ${study_name}"
    publishDir { "${params.counts_dir}/${study_name}" }, mode: 'copy'

    container "quay.io/biocontainers/subread:2.1.1--h577a1d6_0"

    input:
    tuple val(study_name), path(bams), path(saf), val(single_end)

    output:
    tuple val(study_name), path("${study_name}_peak_counts.txt"), emit: counts
    path("${study_name}_peak_counts.txt.summary"), emit: summary_log

    script:
    def paired_args = single_end ? '' : '-p --countReadPairs'
    """
    featureCounts \\
        -T ${task.cpus} \\
        ${paired_args} \\
        -F SAF \\
        -a ${saf} \\
        -o ${study_name}_peak_counts.txt \\
        ${bams}
    """
}
