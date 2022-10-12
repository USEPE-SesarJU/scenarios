#!/usr/bin/perl
$directory = $ARGV[0];
if (!-d $directory) {
die ("$directory is not a directory! Terminating");
}
print("Analysing log files in: $directory\n");

# Calculate number of flights, average distance flown and average flight time
@flightfiles = glob " ${directory}/USEPEFLIGHT*";

if (@flightfiles > 1) {
    die("More than 1 flight log in ${directory}! Terminating");
} elsif (@flightfiles < 1) {
    die("No flight log in ${directory}? Terminating");
}
open(FFLIGHT, '<', $flightfiles[0]) or die("Failed to open $flightfiles[0]");
%takeoffTime;
%completed;
$totalDistance = 0.0;
$totalTime = 0.0;
while(<FFLIGHT>){
    if($_ =~ /^(\d+.\d+),([\w\d_]+),takeoff,/) {
	$takeoffTime{$2} = $1;
#	print($2, " takeoff after ", $flights{$2}, " seconds\n");
    }
    if($_ =~ /(\d+.\d+),([\w\d_]+),landing,(\d+.\d+)$/) {
	$flightTime = $1 - $takeoffTime{$2};
#	print($2, " landed after ", $flightTime, " seconds, ", $3, " meters\n");
	$completed{$1} = true;
	$totalTime += $flightTime;
	$totalDistance += $3;
    }
}
close(FFLIGHT);
$numLanded =  scalar(keys(%completed));
print("Completed flights: $numLanded\n");

$avgerageDistance = $totalDistance / $numLanded;
print("Average distance flown: $avgerageDistance\n");

#print("Totaltime: $totalTime\n");
$averageTime = $totalTime / $numLanded;
print("Average flight time: $averageTime\n");

#Conflicts
$conflictsStarted = `grep ,start ${directory}/USEPECONF* | wc -l`;
print("Conflicts started: $conflictsStarted");

$conflictsEnded = `grep ,end ${directory}/USEPECONF* | wc -l`;
print("Conflicts ended: $conflictsEnded");

@conffiles = glob " ${directory}/USEPECONF*";

if (@conffiles > 1) {
    die("More than 1 conflict log in ${directory}! Terminating");
} elsif (@conffiles < 1) {
    die("No conflict log in ${directory}? Terminating");
}
open(FCONS, '<', $conffiles[0]) or die("Failed to open $conffiles[0]");
%conflicts;
$totalConflictTime = 0.0;
while(<FCONS>){
    if($_ =~ /^(\d+.\d+),([\w\d_]+,[\w\d_]+),start/) {
	$conflicts{$2} = $1;
	#print($2, " conflict starts at ", $conflicts{$2}, " seconds\n");
    }
    if($_ =~ /^(\d+.\d+),([\w\d_]+,[\w\d_]+),end/) {
	$conflictTime = $1 - $conflicts{$2};
	#print($2, " conflict ends after ", $conflictTime, " seconds\n");
	$totalConflictTime += $conflictTime;
    }
}
close(FCONS);
$averageConflictTime = $totalConflictTime / $conflictsEnded;
print("Average conflict time: $averageConflictTime\n");

#LOS events
$los = `grep start ${directory}/USEPELOS* | wc -l`;
print("LOS events: $los");

# Count number of NMAC events: CPA < 3.75 m
@cpafiles = glob " ${directory}/USEPECPA*";

if (@cpafiles > 1) {
    # decide what to do here if there are no matching files,
    # or multiple matching files
    die("More than 1 LOS log in ${directory}! Terminating");
} elsif (@cpafiles < 1) {
    # decide what to do here if there are no matching files,
    # or multiple matching files
    die("No LOS log in ${directory}? Terminating");
}
open(FCPA, '<', $cpafiles[0]) or die("Failed to open $losfile[0]");
%cpas;
while(<FCPA>){
   if($_ =~ /([\w\d_]+,[\w\d_]+),(\d+.\d+)$/) {
	#print("CPA for ", $1, " is ", $2, "\n");
	if ($2 < 3.75) {
	    $cpas{$1} = $2;
	    #print("Entry: ", $cpas{$1}, "\n");
	}
    }
}
close(FCPA);
print("NMAC events: ", scalar(keys(%cpas)));
print("\n");
