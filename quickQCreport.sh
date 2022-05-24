#!/usr/bin/perl -w

# Original author - Peter Giles

# Update log
# Update 04Sep20 - Initial development started
# Transferred to Ser Cymru cluster May22

no warnings 'uninitialized';

use Data::Dumper;
use Cwd;
use List::MoreUtils qw(uniq);
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
local $Term::ANSIColor::AUTORESET = 1;
use Getopt::Long;
$|++;


sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub mildate {
	$retval = $_[0];
	@months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
	if ($retval =~ /^\d\d\d\d\d\d$/){
		$retval = substr($retval, 4,2) . @months[substr($retval, 2,2)-1] . substr($retval, 0,2);
	}
	return(ucfirst($retval));

}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Settings
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


$QUICKQCDIR = "/gluster/wgp/wgp/sequencing/QC/quick/";
$MULTIQC="module load singularity; singularity run --bind /data09:/data09 /data09/QC_pipelines/workflow/multiqc-v1.11.sif";
$YIELDGRAPH="module load singularity; singularity exec --bind /data09:/data09 --pwd WORKDIR /data09/QC_pipelines/workflow/WGPQC-v1.0.sif yieldgraph";

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Process ARGV
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

sub helpmsg {
	print "Usage: $0 -i [illuminadir] -ref [reference]\n";
	print "   -i             Input directory containing fastqc and yield files";
	print "   -debug/v		 Verbose debug output\n";
	print "   -help/h        Display help message\n";

	exit(0);
}

$DEBUG=0;

GetOptions (
	'i=s' => \$rundir,
	'v|debug' => \$verbose,
	'help|h|?' => \$help,
);

# Display help message?
if($help) {
	&helpmsg;
	exit(0);
}

# Check for ARGV input errors
$error = 0;
if($rundir eq "") {
	print RED "[ERROR] No rundir defined\n";
	$error = 1;
}
if($error == 1) { &helpmsg; }

# Verbose output?
if($verbose){
	$DEBUG=1;
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Check directory exists
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

if (! -d "$rundir") {
		print RED "[ERROR] Directory '$rundir' not found\n";
		exit(1);
}


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Find lanes
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

$cmd="find $rundir -type d | sed 's/.*\\\///' | grep Lane";
@subdirs = `$cmd`;
chomp(@subdirs);
@subdirs = sort @subdirs;


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Run multiQC
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

for $dir (@subdirs){
	chdir $dir;
	print "Running multiQC on ... "; print GREEN "$dir\n";
	$cmd = "$MULTIQC -s -d -f -q $rundir/$dir";
	#if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
	#else { die "System call '$cmd' failed: $!"; }
}


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Yield summary
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

for $dir (@subdirs){
	chdir $dir;
	print "Running yieldgraph report on ... "; print GREEN "$dir\n";
	$cmd = "$YIELDGRAPH";
	$cmd =~ s/WORKDIR/$rundir\/$dir/;
	print($cmd);
	if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
	else { die "System call '$cmd' failed: $!"; }
}


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Copy data to ARCCA
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

if($rundir =~ /\/data09\/QC\/quick/){
	print "Copying data to ARCCA ... ";
	print GREEN "$rundir\n";

	$cmd = "rsync -a --stats $rundir/ $QUICKQCDIR/";
	#print MAGENTA "$cmd\n";
	if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
	else { die "System call '$cmd' failed: $!"; }

}


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Update index
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

chdir $QUICKQCDIR;

print "Updating quickQC index in ... ";
print GREEN "$QUICKQCDIR\n";

$cmd = "./createindex.pl";
if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
else { die "System call '$cmd' failed: $!"; }

