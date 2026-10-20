process MultiQC {
    tag "Running MultiQC for ${study_name}"
    publishDir { "${params.multiqc_dir}/${study_name}" }, mode: 'copy'

    container "multiqc/multiqc:latest"

    input:
    tuple val(study_name), path(results_dir, stageAs: "input*/*")

    output:
    path("*.html")
    path("${study_name}_multiqc_report_data"), type: 'dir'

    script:
    """
    multiqc \\
        ${results_dir} \\
        -o . \\
        -n ${study_name}_multiqc_report.html \\
        --title "ATAC-seq QC Report"\\
        --force
    """
}