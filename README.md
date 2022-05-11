## Overview

Scripts to perform FastQC analysis and count the reads in fastq files

	
## quickQC

This script acts as a launcher, creating and submitting slurms scripts for the fastq files detected in the input directory.

The script can apply map all samples against the same reference geneome:

```
DIR=/data09/incoming/220406_M03762_0171_000000000-DFVKK/Data/Intensities/BaseCalls

quickQC -i $DIR
```



## quickQCreport

This script performs multiQC on the data from the quickQC script and generates other output reports

