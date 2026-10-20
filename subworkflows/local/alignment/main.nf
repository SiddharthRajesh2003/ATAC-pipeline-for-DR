include { Bowtie2Index } from '../../../modules/local/bowtie2/build'
include { Bowtie2Align } from '../../../modules/local/bowtie2/align'
include { sort } from '../../../modules/local/samtools/sort'

def organismKey(organism) {
    organism.toLowerCase().replaceAll(/\s+/, '_')
}

def existingIndex(organism) {
    def dir = file("${params.reference}/${organism}_bowtie2_index")
    // bowtie2-build writes the .rev.* files last; publishDir copies in arbitrary order, so a half-copied index lacks them
    dir.exists() && dir.list()?.any { f -> f.contains('.rev.2.bt2') } ? dir : null
}

workflow Alignment {
    take:
    reads      // tuple(sample_id, study_name, organism, single_end, [R1, (R2)])
    references // tuple(organism, reference, gtf) - one row per unique organism

    main:
    keyed_with_existing = references.map { organism, reference, _gtf ->
        tuple(organismKey(organism), reference, existingIndex(organismKey(organism)))
    }

    already_indexed = keyed_with_existing
        .filter { _organism, _reference, idx -> idx != null }
        .map { organism, _reference, idx -> tuple(organism, idx) }

    to_index = keyed_with_existing
        .filter { _organism, _reference, idx -> idx == null }
        .map { organism, reference, _idx -> tuple(organism, reference) }

    // index: tuple(organism, index_dir)
    index = already_indexed.mix(Bowtie2Index(to_index))

    to_align = reads
        .map { sample_id, study_name, organism, single_end, fq -> tuple(organismKey(organism), sample_id, study_name, single_end, fq) }
        .combine(index, by: 0)
        .map { organism, sample_id, study_name, single_end, fq, idx -> tuple(sample_id, study_name, single_end, fq, organism, idx) }

    aligned_sam = Bowtie2Align(to_align)
    // aligned_sam: tuple(sample_id, study_name, sam, aligner_log)

    sorted = sort(aligned_sam.map { sample_id, study_name, sam, _log -> tuple(sample_id, study_name, sam) })

    emit:
    bam = sorted // tuple(sample_id, study_name, sorted_bam)
    logs = aligned_sam.map { sample_id, study_name, _sam, aligner_log -> tuple(sample_id, study_name, aligner_log) }
}
