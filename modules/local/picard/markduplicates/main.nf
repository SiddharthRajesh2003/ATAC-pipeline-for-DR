process MarkDuplicates {
    tag "Running Picard for ${sample_id} of study ${study_name}"
    publishDir { "${params.picard_dir}/${study_name}" }, mode: 'copy', pattern: '*_mkdp.txt'

    container "quay.io/biocontainers/picard:3.4.0--hdfd78af_0"

    input:
    tuple val(sample_id), val(study_name), path(bam)

    output:
    tuple val(sample_id), val(study_name), path("*_mkdp.bam"), path("*_mkdp.txt")

    script:
    def heap_gb = Math.max(1, (task.memory.toGiga() - 2).intValue())
    """
    picard -Xmx${heap_gb}g MarkDuplicates \\
        I=${bam} \\
        O=${sample_id}_mkdp.bam \\
        M=${sample_id}_mkdp.txt \\
        REMOVE_DUPLICATES=false \\
        ASSUME_SORTED=true \\
        VALIDATION_STRINGENCY=LENIENT \\
        CREATE_INDEX=true \\
        READ_NAME_REGEX=null
    """
}