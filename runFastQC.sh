#!/bin/bash

#https://wotan.cardiff.ac.uk/containers/fastqc_v0.11.9.sif
#fastqc --outdir $outqcdir/$lane $fq

module load singularity

singularity run --bind /data09:/data09 /data09/QC_pipelines/workflow/fastqc_v0.11.9.sif --outdir $outqcdir/$lane $fq