include { CallPeaks } from '../../../modules/local/macs3/callpeak'
include { ConsensusPeaks } from '../../../modules/local/bedtools/consensus'
include { FeatureCounts } from '../../../modules/local/featurecounts'

def organismKey(organism) {
    organism.toLowerCase().replaceAll(/\s+/, '_')
}

workflow Peaks {
    take:
    bam         // tuple(sample_id, study_name, bam, bai)
    sample_info // tuple(sample_id, organism, single_end)
    references  // tuple(organism, reference, gtf) - one row per unique organism

    main:
    bam_info = bam
        .join(sample_info, by: 0)
        .map { sample_id, study_name, bam_file, _bai, organism, single_end ->
            tuple(sample_id, study_name, bam_file, organismKey(organism), single_end)
        }

    CallPeaks(bam_info.map { sample_id, study_name, bam_file, organism, single_end ->
        if (!params.macs_gsize[organism]) {
            error "No MACS3 genome size in params.macs_gsize for organism ${organism}"
        }
        tuple(sample_id, study_name, bam_file, params.macs_gsize[organism], single_end)
    })

    // one organism and one layout per study - same assumption as FeatureCounts in the RNA-seq pipeline
    gtf_keyed = references.map { organism, _reference, gtf -> tuple(organismKey(organism), gtf) }
    study_info = bam_info
        .map { _sample_id, study_name, _bam, organism, single_end -> tuple(organism, study_name, single_end) }
        .unique()
        .combine(gtf_keyed, by: 0)
        .map { _organism, study_name, single_end, gtf -> tuple(study_name, single_end, gtf) }

    consensus_input = CallPeaks.out.peaks
        .map { _sample_id, study_name, peaks -> tuple(study_name, peaks) }
        .groupTuple(by: 0)
        .join(study_info.map { study_name, _single_end, gtf -> tuple(study_name, gtf) }, by: 0)

    ConsensusPeaks(consensus_input)

    counts_input = bam_info
        .map { _sample_id, study_name, bam_file, _organism, _single_end -> tuple(study_name, bam_file) }
        .groupTuple(by: 0)
        .join(ConsensusPeaks.out.saf, by: 0)
        .join(study_info.map { study_name, single_end, _gtf -> tuple(study_name, single_end) }, by: 0)

    FeatureCounts(counts_input)

    emit:
    peaks = CallPeaks.out.peaks
    consensus = ConsensusPeaks.out.annotated
    counts = FeatureCounts.out.counts
}
