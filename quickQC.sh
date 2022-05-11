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
# Settings
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

$SLURM_PARTITION="c_compute_cg1";
$SLURM_ACCOUNT="scw1179";
$SLURM_CORES=10;
$SLURM_WALLTIME="0-6:00";

$RUNFASTQC="/data09/QC_pipelines/workflow/runFastQC.sh";
$RUNFQCOUNT="/data09/QC_pipelines/workflow/runFQcount.sh";


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Process ARGV
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

sub helpmsg {
	print "Usage: $0 -i [illuminadir] -ref [reference]\n";
	print "   -i             Input illumina directory containing fastq files\n";
	print "   -o             Output directory [default = /data/QC/quick ] \n";
	print "   -threads/t     CPU threads for each QC run [default = $threads]\n";
	print "   -clean/c       Delete previous QC run\n";
	print "   -debug/v		 Verbose debug output\n";
	print "   -help/h        Display help message\n";

	exit(0);
}

$threads = 1;
$defaultoutputdir="/data09/QC/quick";
$outdir=$defaultoutputdir;
$DEBUG=0;

GetOptions (
	'i=s' => \$rundir,
	'o|outdir=s' => \$outdir,
	't|threads=s' => \$threads,
	'c|clean' => \$clean,
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


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Check input directory is an illumina run directory
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

print "Input directory ... "; print GREEN "$rundir\n";

if (! -d $rundir) {
	print RED "[ERROR] Input directory '$rundir' not found\n";
	exit(1);
}

if($rundir =~ /(\d\d\d\d\d\d)_(\w\d\d\d\d\d)_(\d\d\d\d)_([^_]+)/){
	$rundate = $1;
	$rundate =~ /(\d\d)(\d\d)(\d\d)/;
} else {
	print RED "[ERROR] not an Illumina run directory\n";
	exit(1);
}


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Check output directory
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Output into local directory?
if($outdir eq $defaultoutputdir){
	use Cwd;
    $basedir = $defaultoutputdir;
    # Append flowID to output directory
	if($rundir =~ /(\d\d\d\d\d\d_\w\d\d\d\d\d_\d\d\d\d_[^_\/]+)/){
	$flowID = $1;
	$outqcdir = "$basedir/$flowID";
	} else {
		print RED "[ERROR] not an Illumina run directory\n";
		exit(1);
	}

} else {
	$outqcdir = $outdir;
	$basedir = $outdir;
}





print "QC output directory ... "; print GREEN "$outqcdir\n";

# Check base directory exists
if (! -d $outdir) {
	print RED "[ERROR] Output directory '$basedir' not found\n";
	exit(1);
}

# Check for a clean run and if not stop if output directory already exists
if ($clean) {
	if (-d "$outqcdir") {
		print "Deleting existing QC output directory '$outqcdir' ... ";
		$cmd="rm -R $$outqcdir";
		if (system($cmd)){ print GREEN "DONE\n"; }
		else { print RED "ERROR\n"; exit(1); }
	}
} else {
	if (-d "$outqcdir") {
		print RED "[ERROR] Output directory '$outqcdir' already exists\n";
		print RED "        Please run again with the '--clean' flag if you want to delete the existing QC run\n";
		exit(1);
	}
}







# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Get list of fastq files
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

print "Finding fastq.gz files in run directory ... ";

# find all the subdirectories of a given directory
#my @subdirs = File::Find::Rule->directory->in( $rundir );

# find all the .fastq.gz files in @subdirs
#my @fqfiles = File::Find::Rule->file()
#          ->name( '*.fastq.gz')
#          ->in( @subdirs );
          
$cmd="find $rundir -name '*.fastq.gz'";
@fqfiles = `$cmd`;
chomp(@fqfiles);
@fqfiles = sort @fqfiles;

$numfq = @fqfiles;
if($numfq gt 0){
	print GREEN "$numfq files\n";
} else {
	print RED "... [ERROR] no fastq.gz files found\n";
}



# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Identify dates, samples, projects and lanes
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

#$DEBUG=1;

@lanes = ();
@dates = ();
@samples = ();

for $fq (@fqfiles){
	#print YELLOW "$fq\n";
	$fq =~ /\/(\d\d\d\d\d\d)_\w\d\d\d\d\d_\d\d\d\d_[^_]+.*\/([^\/]+)_\w\d+_(\w\d\d\d)_\w\d_\d\d\d.fastq.gz$/;
	push(@dates, $1);
	push(@samples, $2);
	push(@lanes, $3);
	#print "$1\t$2\t$3\n";

}

@dates=uniq(@dates);
@samples=uniq(@samples);
@lanes=uniq(@lanes);
@dates=sort(@dates);
@samples=sort(@samples);
@lanes=sort(@lanes);

if($DEBUG==1){
	print "Identifying lanes ... ";
	print GREEN scalar(@lanes)."\n";
	print "Identifying samples ... ";
	print GREEN scalar(@samples)."\n";
}


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Identify projects and references
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

$DEBUG=0;

%info = ();

for $fq (@fqfiles){
	# Get sample and lane info
	$fq =~ /\/(\d\d\d\d\d\d)_\w\d\d\d\d\d_\d\d\d\d_[^_]+.*\/([^\/]+)_\w\d+_(\w\d\d\d)_\w\d_\d\d\d.fastq.gz$/;
	$project = "";
	$sample = $2;
	$lane = $3;
	if($DEBUG==1) { print YELLOW "$fq\n"; }

	# Identify project
	if($fq =~ /Project_(\w+)\//){
		$project = $1;
	} elsif($fq =~ /(Undetermined)/){
		$project = $1;
	} elsif($fq =~ /\/(\w\d\d\d)-[AKDMNHQ]-\d\d\d/)	{
		$project = $1;
	} else {
		$project = "Unknown";
	}
	if($DEBUG==1) { print YELLOW "$project\n"; }

	$info{$lane}{$sample}{'project'} = $project;
}


if($DEBUG==1) { print CYAN Dumper (%info); }


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Print summary
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

sub get_projects {
	@retval = ();
	for $lane (keys(%info)){
		for $line ($info{$lane}){
			for $sample (keys(%$line)){
				push @retval, $info{$lane}{$sample}{'project'}
			}
		}
	}
	return(@retval);
}

sub get_lanes {
	$search = $_[0];
	@retval = ();
	for $lane (keys(%info)){
		for $line ($info{$lane}){
			for $sample (keys(%$line)){
				if($info{$lane}{$sample}{'project'} eq $search) { push @retval, $lane }
			}
		}
	}
	@retval = uniq(@retval);
	for (@retval) { s/L00//	}
	return(@retval);
}
print "Seqencing run overview:\n";
print '-' x 80; print "\n";
print colored(sprintf("%-2s %-20s %-20s %-20s\n", '','Project','Lane(s)','Samples'),"white");
print '-' x 80; print "\n";

@pp = get_projects;

for $project (sort(uniq(@pp))){
	$pnsamp = grep { $_ eq $project  } @pp;
	$planes = join(",",get_lanes($project));
	print colored(sprintf("%-2s %-20s %-20s %-20s \n", '', $project, $planes, $pnsamp), "white");
}
print '-' x 80; print "\n";


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Prompt to continue
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

sub prompt {
  my ($query) = @_; # take a prompt string as argument
  local $| = 1; # activate autoflush to immediately show the prompt
  print $query;
  chomp(my $answer = <STDIN>);
  return $answer;
}

sub prompt_yn {
  my ($query) = @_;
  my $answer = prompt("$query (Y/N): ");
  return lc($answer) eq 'y';
}


if (prompt_yn("Please confirm this looks right")){

} else {
	exit(0);
}

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Kick off QC runs
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Create output directories
for $lane (@lanes){
	$lane =~ s/L0+/Lane/;
	$lanedir = "$outqcdir/$lane";
	if (! -d "$lanedir") {
		print "Creating output directory ... ";
		print GREEN "$lanedir";
	
		# Setup output directory
		$cmd = "mkdir -p $lanedir";
		system($cmd);
		
		if ($? == -1) {
			print " ... ";
			print RED "ERROR\n";
			exit(1);
		} else {
		    print " ... ";
			print GREEN "DONE\n";
		}
		
	}
}


# Submit jobs to queue
print "Submitting jobs to queue ... \n";
if($DEBUG==1) { print "\n"; }

$jobsrun = 0;
$dryrun = 0;

for $fq (@fqfiles){

	# Get sample and lane info
	$fq =~ /\/(\d\d\d\d\d\d)_\w\d\d\d\d\d_\d\d\d\d_[^_]+.*\/([^\/]+)_\w\d+_(\w\d\d\d)_\w\d_\d\d\d.fastq.gz$/;
	$sample = $2;
	$lane = $3;
	$lane =~ s/L0+/Lane/;

	# Get fastq name
	$fq =~ /\/\d\d\d\d\d\d_\w\d\d\d\d\d_\d\d\d\d_[^_]+.*\/([^\/]+_\w\d+_\w\d\d\d_\w\d_\d\d\d).fastq.gz$/;
	$name = $1;
	
	# Run fqcount
	#$cmd = "queueit.pl -cpus $threads -name $sample\_fqcount -- 'fqcount $fq > $outqcdir/$lane/$name.yield' >/dev/null 2>&1";
	#--export=\"fq=$fq,outqcdir=$outqcdir,lane=$lane,name=$name\"
	$jobname = "$lane-$sample-fqcount";

	$cmd = "sbatch --account=\"$SLURM_ACCOUNT\" --partition=\"$SLURM_PARTITION\" --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --time=\"$SLURM_WALLTIME\" --error=\"$outqcdir/$jobname.err\" --output=\"$jobname.out\" --export=\"fq=$fq,outqcdir=$outqcdir,lane=$lane,name=$name\" $RUNFQCOUNT";
	if($DEBUG==1 || $dryrun==1) { print MAGENTA "$cmd\n"; }
	if($dryrun == 0){
		if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
		else { die "System call '$cmd' failed: $!"; }
	}

	# Run fastqc
	#$cmd = "queueit.pl -cpus $threads -name $sample\_fastqc -- fastqc --outdir $outqcdir/$lane $fq >/dev/null 2>&1";
	#--export=\"fq=$fq,outqcdir=$outqcdir,lane=$lane,name=$name\"
	$jobname = "$lane-$sample-fastqc";

	$cmd = "sbatch --account=\"$SLURM_ACCOUNT\" --partition=\"$SLURM_PARTITION\" --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --time=\"$SLURM_WALLTIME\" --error=\"$outqcdir/$jobname.err\" --output=\"$jobname.out\" --export=\"fq=$fq,outqcdir=$outqcdir,lane=$lane,name=$name\" $RUNFASTQC";
	if($DEBUG==1 || $dryrun==1) { print MAGENTA "$cmd\n"; }
	if($dryrun == 0){
		if(system($cmd) == 0) { $jobsrun = $jobsrun + 1; }
		else { die "System call '$cmd' failed: $!"; }
	}

}

print "\r"; print ' ' x 80;
print "\rJobs submitted to queue ... ";
print GREEN "$jobsrun\n";

print YELLOW "When jobs have complete, run the following command to generate the reports:\n";
print CYAN "quickQCreport -i $outqcdir\n";


