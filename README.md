## Overview

Scripts to perform FastQC analysis and count the reads in fastq files

	
## quickQC

This script acts as a launcher, creating and submitting slurms scripts for the fastq files detected in the input directory.


Example:
```
DIR=/data09/incoming/220406_M03762_0171_000000000-DFVKK/Data/Intensities/BaseCalls

quickQC -i $DIR
```

Settings are found at the top of the file and include:

```
$SLURM_PARTITION="c_compute_cg1";
$SLURM_ACCOUNT="scwNNNN";
$SLURM_CORES=10;
$SLURM_WALLTIME="0-6:00";

$RUNFASTQC="/data09/QC_pipelines/workflow/runFastQC.sh";
$RUNFQCOUNT="/data09/QC_pipelines/workflow/runFQcount.sh";

$defaultoutputdir="/data09/QC/quick";
```


## Run scripts (runFastQC.sh and runFQcount.sh)

These files act as the link between the illuminaQC script and the containers with the analysis tools.

System specific changes that might be required the bind paths for singularity to be able to write to various filesystem locations.

```
singularity run --bind /data09:/data09 /data09/QC_pipelines/workflow/fastqc_v0.11.9.sif --outdir $outqcdir/$lane $fq
```




## quickQCreport

This script performs multiQC on the data from the quickQC script and generates other output reports

