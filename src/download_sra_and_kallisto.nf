#!/usr/bin/env nextflow

/* 
 * nextflow run download_sra_and_kallisto.nf -c job.config -with-report -resume
 */

Channel
    .fromPath(params.list_run_ids)
    .splitCsv(header: true, sep: "\t")
    .map{ 
        [it.Sample_ID, it.Run_ID]
    }
    .into{run_ids; run_ids_}

run_ids_.println()

process download_fastq {
    publishDir "download_fastq"

    container "yuifu/cwltool-with-bash:1.0.20180809224403"
    containerOptions = '-v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -v "$PWD":"$PWD" -w="$PWD"'

    input:
    set sample_id, run_id from run_ids

    output:
    set sample_id, file("${sample_id}.fastq.gz") into fastq_files

    script:
    """
    cwltool --debug "https://raw.githubusercontent.com/pitagora-network/pitagora-cwl/master/workflows/download-fastq/download-fastq.cwl" --run_ids ${run_id}
    mv *.fastq.gz ${sample_id}.fastq.gz
    """
}

process kallisto_se {
    publishDir "kallisto/$sample_id", mode: 'move'

    container "quay.io/biocontainers/kallisto:0.44.0--h7d86c95_2"

    input:
    set sample_id, file(fastq) from fastq_files
    path kallisto_index from params.path_kallisto_index

    output:
    file "$sample_id/*" into kallisto_results

    script:
    """
    kallisto quant -i ${kallisto_index} -o ${sample_id} --single -l 200 -s 20 $fastq
    """
}

