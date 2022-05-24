#!/usr/bin/perl -w

no warnings 'uninitialized';

use Data::Dumper;
use File::Find::Rule;
use File::Path;
use File::Path qw(make_path);
use Cwd;
use List::MoreUtils qw(uniq);
use Term::ANSIColor qw(:constants);
local $Term::ANSIColor::AUTORESET = 1;
use Getopt::Long;
$|++;

my $QCdir = getcwd();

# Development directories
#$QCdir = "/wgp1/wgp/sequencing/QC/illumina_hiseq/WGP/2018_03_21_QC/";
#$QCdir = "/wgp1/wgp/sequencing/QC/illumina/WGP/2017_06_01_QC/";


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Get list of results.properties files
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

#print CYAN "Finding results.properties in QC directory ... \n";

print "Finding '*yield' files in '$QCdir' .~/.. ";

# find all the subdirectories of a given directory
#my @subdirs = File::Find::Rule->directory->in( $QCdir );

$cmd = "find $QCdir -name \"*yield\"";
@QCfiles = `$cmd`;
chomp(@QCfiles);

@QCfiles = uniq @QCfiles;

$numqc = @QCfiles;
if($numqc gt 0){
	print GREEN "$numqc files\n";
} else {
	print RED "0\n";
	exit(1);
}


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Read data from results.properties files
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

@samples = ();
@lanes = ();
%QCdata = ();

#./QC_hg19/Sample_A10-D-saliva.Lane2/Sample_A10-D-saliva.Lane2.results.properties

@QCfiles = sort(@QCfiles);

foreach $QCfile (@QCfiles){
	$sample=""; $lane=""; $yield=0; $reads=0;

	#print "$QCfile\n";

	# Read in file
	open INFILE, "$QCfile" ;
	@data = <INFILE> ;
	close INFILE ;
	chomp(@data);

	foreach $line (@data){
		if($line =~ m/Number of sequences: (\d+)$/){ $reads = $1; }
		if($line =~ m/Number of bases in sequences: (\d+)$/){ $yield = $1; }
	}

	$sl = "$sample.$lane";
	$QCdata{$sl}{'yield'} = $yield;
	$QCdata{$sl}{'reads'} = $reads;

	#/state/partition1/apps/data/QC/quick/190402_M00766_0208_000000000-BPJG8/X125-M-002_S2_L001_R2_001.yield

	$QCfile =~ m/([^\/_]*)_S\d+_L0+(\d)_(R[12])_\d+.yield/;

	$sample = $1;
	$lane = $2;
	$r12 = $3;

	$sl = "$sample.$lane.$r12";
	$QCdata{$sl}{'yield'} = $yield;
	$QCdata{$sl}{'reads'} = $reads;

	push(@samples, $sample);
	push(@lanes, $lane);

}

@samples = uniq(@samples);
@samples = sort(@samples);
@lanes = uniq(@lanes);
@lanes = sort(@lanes);

#print Dumper (@samples);
#print Dumper (@lanes);
#print Dumper (%QCdata);

print "Determining number of samples ... ";
print GREEN scalar(@samples) ."\n";
print "Determining number of lanes ... ";
print GREEN scalar(@lanes) ."\n";


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Get totals
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

%R1totals = ();
%R2totals = ();
%yieldtotals = ();

foreach $lane (@lanes){
	$R1total = 0;
	$R2total = 0;
	$yieldtotal = 0;
	foreach $sample (@samples){
		$sl = "$sample.$lane.R1";
		if($QCdata{$sl}{'reads'}){ $R1total = $R1total + $QCdata{$sl}{'reads'}; }
		if($QCdata{$sl}{'yield'}){ $yieldtotal = $yieldtotal + $QCdata{$sl}{'yield'}; }
		$sl = "$sample.$lane.R2";
		if($QCdata{$sl}{'reads'}){ $R2total = $R2total + $QCdata{$sl}{'reads'}; }
		if($QCdata{$sl}{'yield'}){ $yieldtotal = $yieldtotal + $QCdata{$sl}{'yield'}; }
	}
	$R1totals{$lane} = $R1total;
	$R2totals{$lane} = $R2total;
	$yieldtotals{$lane} = $yieldtotal;
}

#print Dumper (%R1totals);
#print Dumper (%R2totals);
#print Dumper (%yieldtotals);

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Create outputs
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

$filename = $QCdir . "/yieldreport.xlsx";

print "Writing outputs to '$filename' ... ";

use Excel::Writer::XLSX;

my $workbook  = Excel::Writer::XLSX->new( "$filename" );
my $worksheet = $workbook->add_worksheet();

my $header = $workbook->add_format(
	bold => 1,
    border => 1,
	bg_color => 'red',
	fg_color => 'white',
);

my $cell = $workbook->add_format(
	bold => 0,
    border => 1,
	color => 'black',
	fg_color => 'white',
);


$row = 0;
$col = 0;
#print CYAN "Sample";
$worksheet->write($row, $col, "Sample", $header); $col++;
foreach $lane (@lanes){
	#print CYAN "\t".$lane."_reads\t".$lane."_yield\t%";
	$worksheet->write($row, $col,  "Lane".$lane."_R1", $header);	$col++;
	$worksheet->write($row, $col,  "Lane".$lane."_R2", $header);	$col++;
	$worksheet->write($row, $col,  "Lane".$lane."_yield", $header);	$col++;
 	$worksheet->write($row, $col,  "%", $header); $col++;
}
#print CYAN "\n";


$row++;
foreach $sample (@samples){
	$col = 0;
	#print CYAN "$sample";
	$worksheet->write($row, $col,  $sample, $cell);
	$col++;

	foreach $lane (@lanes){
		$sl1 = "$sample.$lane.R1";
		$sl2 = "$sample.$lane.R2";

		$reads1=""; $reads2=""; $yield1=""; $yield2="";$yield="";

		if($QCdata{$sl1}{'reads'}){
			$reads1 = $QCdata{$sl1}{'reads'};
		} else { $reads1 = ""; }

		if($QCdata{$sl2}{'reads'}){
			$reads2 = $QCdata{$sl2}{'reads'};
		} else { $reads2 = ""; }

		if($QCdata{$sl1}{'yield'}){
			$yield1 = $QCdata{$sl1}{'yield'};
		} else { $yield1 = 0; }
		if($QCdata{$sl2}{'yield'}){
			$yield2 = $QCdata{$sl2}{'yield'};
		} else { $yield2 = 0; }
		$yield=$yield1+$yield2;

		$pc = $yield / $yieldtotals{$lane} * 100;
		$pc = sprintf "%.1f", $pc;

		#print CYAN "\t$reads\t$yield";
		#print YELLOW "\t$pc";
		$worksheet->write($row, $col, $reads1, $cell); $col++;
		$worksheet->write($row, $col, $reads2, $cell); $col++;
		$worksheet->write($row, $col, $yield, $cell );	$col++;
		$worksheet->write($row, $col, $pc, $cell); $col++;

				#$pc = $reads / $R1totals{$lane} * 100;
			#$reads = sprintf "%.1f", $reads;
			#$pc = sprintf "%.1f", $pc;


	}
	#print CYAN "\n";
	$row++;
}

$col=0;
$worksheet->write($row, $col, "TOTAL", $cell); $col++;
foreach $lane (@lanes){
	$reads1 = sprintf "%.1f", $R1totals{$lane};
	$reads2 = sprintf "%.1f", $R2totals{$lane};
	$yield = sprintf "%.1f", $yieldtotals{$lane};

	#print MAGENTA "\t";
	#print MAGENTA "\t$yield";
	#print MAGENTA "\t";

	$worksheet->write($row, $col, $reads1, $cell); $col++;
	$worksheet->write($row, $col, $reads2, $cell); $col++;
	$worksheet->write($row, $col, $yield, $cell );	$col++;
	$worksheet->write($row, $col, "", $cell );	$col++;

}
#print CYAN "\n";


$workbook->close;

print GREEN "DONE\n";