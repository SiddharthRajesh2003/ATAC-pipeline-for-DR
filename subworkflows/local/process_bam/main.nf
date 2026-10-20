include { MarkDuplicates } from '../../../modules/local/picard/markduplicates'
include { FilterBam } from '../../../modules/local/samtools/filter'
include { flagstat } from '../../../modules/local/samtools/flagstat'
include { stats } from '../../../modules/local/samtools/stats'
include { BamCoverage } from '../../../modules/local/deeptools/bamcoverage'

workflow Process_bam {
    take:
    bam           // tuple(sample_id, study_name, sorted_bam)
    sample_layout // tuple(sample_id, single_end)

    main:
    MarkDuplicates(bam)

    filtered = FilterBam(
        MarkDuplicates.out
            .map { sample_id, study_name, mkdp_bam, _metrics -> tuple(sample_id, study_name, mkdp_bam) }
            .join(sample_layout, by: 0)
    )
    // filtered: tuple(sample_id, study_name, bam, bai)

    filtered_bam = filtered.map { sample_id, study_name, bam_file, _bai -> tuple(sample_id, study_name, bam_file) }
    flagstat(filtered_bam)
    stats(filtered_bam) // insert-size histogram here is the ATAC fragment-length QC
    BamCoverage(filtered.join(sample_layout, by: 0))

    emit:
    bam = filtered
    flagstat = flagstat.out
    stats = stats.out
    mkdp_metrics = MarkDuplicates.out.map { sample_id, study_name, _bam, metrics -> tuple(sample_id, study_name, metrics) }
    bigwig = BamCoverage.out
}
