#!/bin/bash

#https://wotan.cardiff.ac.uk/containers/fqcount-v1.0.sif
#fqcount $fq > $outqcdir/$lane/$name.yield

module load singularity

singularity exec --bind /data09:/data09 /data09/QC_pipelines/workflow/fqcount-v1.0.sif $fq > $outqcdir/$lane/$name.yield
    
    