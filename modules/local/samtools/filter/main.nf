process FilterBam {
    tag "Filtering BAM for ${sample_id}"
    publishDir { "${params.filtered_dir}/${study_name}" }, mode: 'copy'

    container "quay.io/biocontainers/samtools:1.24--h9dcdb79_0"

    input:
    tuple val(sample_id), val(study_name), path(bam), val(single_end)

    output:
    tuple val(sample_id), val(study_name), path("${sample_id}_filtered.bam"), path("${sample_id}_filtered.bam.bai")

    script:
    // -F 1804: drop unmapped, mate-unmapped, secondary, QC-fail and duplicate reads
    // MT is the Ensembl name, chrM the UCSC one - mito reads are 20-80% of ATAC libraries
    def pair_args = single_end ? '' : '-f 2'
    """
    samtools view -h -q 30 ${pair_args} -F 1804 ${bam} \\
        | awk '\$3 != "MT" && \$3 != "chrM"' \\
        | samtools view -@ ${task.cpus} -b -o ${sample_id}_filtered.bam -

    samtools index -@ ${task.cpus} ${sample_id}_filtered.bam
    """
}
