process Fastp {
    tag "Processing ${sample_id}"
    publishDir { "${params.trimmed_reads_dir}/${study_name}" }, mode: 'copy'

    container "quay.io/biocontainers/fastp:1.3.6--h43da1c4_0"

    input:
    tuple val(sample_id), val(study_name), val(single_end), path(reads)

    output:
    tuple val(sample_id), val(study_name), val(single_end), path("${sample_id}_R*.fq.gz"), emit: reads
    path("${sample_id}_fastp.json"), emit: json
    path("${sample_id}_fastp.html"), emit: html

    script:
    if (single_end)
        """
        fastp -i \\
            ${reads[0]} \\
            -o ${sample_id}_R1.fq.gz \\
            -w ${task.cpus} \\
            --trim_poly_g \\
            -q 20 \\
            -j ${sample_id}_fastp.json \\
            -h ${sample_id}_fastp.html
        """
    else
        """
        fastp -i \\
            ${reads[0]} \\
            -o ${sample_id}_R1.fq.gz \\
            -I ${reads[1]} -O ${sample_id}_R2.fq.gz \\
            --detect_adapter_for_pe \\
            -w ${task.cpus} \\
            --trim_poly_g \\
            -q 20 \\
            -j ${sample_id}_fastp.json \\
            -h ${sample_id}_fastp.html
        """
}