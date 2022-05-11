## Overview

Scripts to perform FastQC analysis and count the reads in fastq files

	
## quickQC

This script acts as a launcher, creating and submitting slurms scripts for the fastq files detected in the input directory.


Example:
```
DIR=/data09/incoming/220406_M03762_0171_000000000-DFVKK/Data/Intensities/BaseCalls

quickQC -i $DIR
```


## Run scripts (runFastQC.sh and runFQcount.sh)

These files act as the link between the illuminaQC script and the containers with the analysis tools.

System specific changes that might be required the bind paths for singularity to be able to write to various filesystem locations.

```
singularity run --bind /data09:/data09 /data09/QC_pipelines/workflow/fastqc_v0.11.9.sif --outdir $outqcdir/$lane $fq
```




## quickQCreport

This script performs multiQC on the data from the quickQC script and generates other output reports

