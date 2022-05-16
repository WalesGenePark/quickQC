#!/usr/bin/perl -w

# Original author - Peter Giles

# Update log
# Update 04Sep20 - Initial development started

no warnings 'uninitialized';

use Data::Dumper;
#use File::Find::Rule;
#use File::Path;
#use File::Path qw(make_path);
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

# find all the subdirectories of a given directory
my @subdirs = File::Find::Rule->directory()
			->in( $rundir );
@subdirs = grep { /Lane\d+$/ } @subdirs;

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Run multiQC
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

for $dir (@subdirs){
	chdir $dir;
	print "Running multiQC on ... "; print GREEN "$dir\n";
	$cmd = "multiqc -s -d -f -q .";
	if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
	else { die "System call '$cmd' failed: $!"; }
}


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Yield summary
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

for $dir (@subdirs){
	chdir $dir;
	print "Running yieldgraph report on ... "; print GREEN "$dir\n";
	$cmd = "yieldgraph";
	if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
	else { die "System call '$cmd' failed: $!"; }
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Copy data to ARCCA
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

if($rundir =~ /\/data\/QC\/quick/){
	print "Copying data to ARCCA ... ";
	print GREEN "$rundir\n";

	$todir = $rundir;
	$todir =~ s/\/data\/QC\/quick/\/wgp1\/wgp\/sequencing\/QC\/quick/;
	$cmd = "rsync -a --stats $rundir/ $todir/";
	#print MAGENTA "$cmd\n";
	#if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
	#else { die "System call '$cmd' failed: $!"; }

}


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Update index
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

$quickqcdir = "/wgp1/wgp/sequencing/QC/quick/";
chdir $quickqcdir;

print "Updating quickQC index in ... ";
print GREEN "$quickqcdir\n";

$cmd = "./createindex.pl";
if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
else { die "System call '$cmd' failed: $!"; }

