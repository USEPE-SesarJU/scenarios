#!/usr/bin/perl
$directory = $ARGV[0];
print("Analysing log files in: $directory\n");

$landed = `grep landing ${directory}/USEPEFLIGHT* | wc -l`;
print("Completed flights: $landed");

$conflicts = `grep ,start ${directory}/USEPECONF* | wc -l`;
print("Conflicts started: $conflicts");

$conflicts = `grep ,end ${directory}/USEPECONF* | wc -l`;
print("Conflicts resolved: $conflicts");

$los = `grep start ${directory}/USEPELOS* | wc -l`;
print("LOS events: $los");


# Count number of NMAC events: CPA < 3.75 m
@cpafiles = glob " ${directory}/USEPECPA*";

if (@cpafiles > 1) {
    # decide what to do here if there are no matching files,
    # or multiple matching files
    die("More than 1 LOS log in ${directory}!");
} elsif (@cpafiles > 1) {
    # decide what to do here if there are no matching files,
    # or multiple matching files
    die("No LOS log in ${directory}?");
}
open(FCPA, '<', $cpafiles[0]) or die("Failed to open $losfile[0]");
$nmacs = 0;
while(<FCPA>){
#    print $_;
    if($_ =~ /,(\d+.\d+)$/) {
	#print("CPA is ", $1, "\n");
	if ($1 < 3.75) {
	    $nmacs++;
	}
    }
}
print("NMAC events: $nmacs");
close(FCPA);
print("\n");
