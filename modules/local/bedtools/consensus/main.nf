process ConsensusPeaks {
    tag "Building consensus peaks for ${study_name}"
    publishDir { "${params.consensus_dir}/${study_name}" }, mode: 'copy'

    container "quay.io/biocontainers/bedtools:2.31.1--h13024bc_3"

    input:
    tuple val(study_name), path(peaks), path(gtf)

    output:
    tuple val(study_name), path("${study_name}_consensus.saf"), emit: saf
    tuple val(study_name), path("${study_name}_consensus_annotated.bed"), emit: annotated

    script:
    // ponytail: union of every sample's peaks; require >= 2 samples per peak if the union is too noisy
    """
    cat ${peaks} | cut -f1-3 | sort -k1,1 -k2,2n | bedtools merge > consensus.bed

    awk 'BEGIN { OFS = "\\t"; print "GeneID", "Chr", "Start", "End", "Strand" }
        { print \$1 ":" \$2 "-" \$3, \$1, \$2 + 1, \$3, "+" }' consensus.bed > ${study_name}_consensus.saf

    # TSS of every gene in the RNA-seq GTF, so each peak carries the same Ensembl gene ID as the RNA counts
    awk -F '\\t' 'BEGIN { OFS = "\\t" } \$3 == "gene" {
        match(\$9, /gene_id "[^"]+"/); id = substr(\$9, RSTART + 9, RLENGTH - 10)
        name = id
        if (match(\$9, /gene_name "[^"]+"/)) name = substr(\$9, RSTART + 11, RLENGTH - 12)
        tss = (\$7 == "+") ? \$4 - 1 : \$5 - 1
        print \$1, tss, tss + 1, id, name, \$7
    }' ${gtf} | sort -k1,1 -k2,2n > tss.bed

    # columns: chr, start, end, tss_chr, tss_start, tss_end, gene_id, gene_name, strand, distance_to_tss
    bedtools closest -a consensus.bed -b tss.bed -d -t first > ${study_name}_consensus_annotated.bed
    """
}
