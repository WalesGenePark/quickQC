## Overview

These are the scripts and container definition files for running run QC by mapping the fastqc files and extracting various metrics.

## QC workflow
* Run mapping QC on all fastqc files (illuminaQC.pl)
* Create run specific QC html files (QC_html_PE_illumina.pl)
* Update index for all QC runs

	
## quickQC

This script acts as a launcher, creating and submitting slurms scripts for the fastq files detected in the input directory.

The script can apply map all samples against the same reference geneome:

```
DIR=/data09/incoming/220406_M03762_0171_000000000-DFVKK/Data/Intensities/BaseCalls
OUT=/data09/QCtest
CPUTHREADS=10

illuminaQC.pl -t $CPUTHREADS -i $DIR -o $OUT -ref hg19
```



## quickQCreport

This script generates the reports

