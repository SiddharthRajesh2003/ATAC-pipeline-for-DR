process FastQC {
    tag "Running FastQC (${stage}) for ${sample_id}"
    publishDir { "${params.fastqc_dir}/${study_name}/${stage}" }, mode: 'copy'

    container "quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"

    input:
    tuple val(sample_id), val(study_name), path(reads)
    val(stage)

    output:
    tuple val(sample_id), val(study_name), path("*.zip"), path("*.html")

    script:
    """
    export HOME=\$PWD
    export XDG_CACHE_HOME=\$PWD/.cache
    fastqc -o . ${reads.join(' ')}
    """
}
