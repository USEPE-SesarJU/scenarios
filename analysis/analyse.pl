#!/usr/bin/perl
$numArguments = $#ARGV+1;

if ($numArguments != 1 && $numArguments != 3) {
  die ("Usage: analyse.pl DIRECTORY [--area] [AREA IN SQUARE KM]\n");  
}

$directory = $ARGV[0];
if (!-d $directory) {
    die ("$directory is not a directory! Terminating");
}

$area = 0.0;
if($numArguments == 3) {
    if (!($ARGV[1] eq "--area")){
	die ("Usage: analyse.pl DIRECTORY [--area] [AREA IN SQUARE KM]\n");
    }
    $area = $ARGV[2];
    print("Area is $area km2\n");
}

print("Analysing log files in: $directory\n");

# Exclude the airliners and helicopter from the calculations of flighttime / distance / speed
sub includeFlight {
    return index($_[0],"BACKGROUND",0) == 0 ||
	index($_[0],"SURVEILLANCEOP",0) == 0 ||
	index($_[0],"DELIVERY",0) == 0;
}

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
%flightTime;
%flightDistance;
$totalDistance = 0.0;
$totalTime = 0.0;
$simulationEnd = 0.0; # Last observed event in flightlog
while(<FFLIGHT>){
    if($_ =~ /^(\d+.\d+),([\w\d_]+),takeoff,/) {
	if (includeFlight($2)) {
	    if (exists $takeoffTime{$2})
	    {
		#	    print($2, " REPEAT takeoff after ", $1, " seconds\n");
		delete $completed{$2};
	    } else {
		#	    print($2, " FIRST takeoff after ", $1, " seconds\n");
		$flightTime{$2} = 0;
		$flightDistance{$2} = 0; 
	    }
	    $takeoffTime{$2} = $1;
	    $simulationEnd = $1;
	} else {
	    #print("Skipping takeoff for $2!\n");
	}
    }
    if($_ =~ /(\d+.\d+),([\w\d_]+),landing,(\d+.\d+)$/) {
	if (includeFlight($2)) {
	    #	if (exists $completed{$2})
	    #	{
	    #	    print($2, " REPEAT landing after ", $1, " seconds\n");
	    #	} else {
	    #	    print($2, " FIRST landing after ", $1, " seconds\n"); 
	    #	}
	    $time = $1 - $takeoffTime{$2};
	    $completed{$2} = true;
	    $flightTime{$2} += $time;
	    $flightDistance{$2} += $3;
	    $simulationEnd = $1;
	}  else {
	    #print("Skipping landing for $2!\n");
	}
    }
}
close(FFLIGHT);
#print %completed;
$numStarted = scalar(keys(%takeoffTime));
$numLanded =  scalar(keys(%completed));
# Iterate over %completed and sum up time & distance flights
foreach $key ( keys(%completed)) {
    $totalTime += $flightTime{$key};
    $totalDistance += $flightDistance{$key};
}
print("Started flights: $numStarted\n");
print("Completed flights: $numLanded\n");

$avgerageDistance = $totalDistance / $numLanded;
print("Average distance flown (of completed flights): $avgerageDistance\n");

$averageTime = $totalTime / $numLanded;
print("Average flight time (of completed flights): $averageTime\n");

#Calculate total flying time including background flights not completed
foreach $key ( keys(%takeoffTime)) {
    if (!exists($completed{$key})) {
	$airborneTime = $simulationEnd - $takeoffTime{$key};
#	print("Adding $airborneTime seconds for $key\n");
	$totalTime += $airborneTime;
    }
}

print("Total flight time (including non-completed flights): $totalTime\n");
if ($area > 0) {
    $density = $totalTime/$simulationEnd/$area;
    print("Traffic density: $density\n");
}

#Conflicts: Calculate actual number of conflicts, total conflict time and then average conflict time
@conffiles = glob " ${directory}/USEPECONF*";

if (@conffiles > 1) {
    die("More than 1 conflict log in ${directory}! Terminating");
} elsif (@conffiles < 1) {
    die("No conflict log in ${directory}? Terminating");
}
open(FCONS, '<', $conffiles[0]) or die("Failed to open $conffiles[0]");
#Two hash maps to store start & end for each unique conflict pairs
%conflictStart;
%conflictEnd;
#Extra hash map to keep track of ongoing conflicts between repeated conflict pairs
%ongoingRepeatConflicts;
$totalConflictTime = 0.0;
# Join (don't count) repeated conflicts between the same pair if separated by less time than this:
$minimumTimeBetweenConflicts = 20.0;
$joinedConflitcs = 0;
$repeatedConflicts = 0;
while (<FCONS>){
    if ($_ =~ /^(\d+.\d+),([\w\d_]+,[\w\d_]+),start/) {
	if (exists $conflictEnd{$2})
	{
	    if ($1 - $conflictEnd{$2} < $minimumTimeBetweenConflicts)
	    {
		#print($2, " conflict continues ", $1 - $conflictEnd{$2}, " seconds later at ", $1, " seconds\n");
		$joinedConflicts++;
	    } else {
	        #print($2, " REPEATED conflict ", $1 - $conflictEnd{$2}, " seconds later at ", $1, " seconds\n");
		$ongoingRepeatConflicts{$2} = true;
	    }
	} else {
	    #print($2, " conflict starts at ", $conflictStart{$2}, " seconds\n");
	}
	$conflictStart{$2} = $1;
    }
    if($_ =~ /^(\d+.\d+),([\w\d_]+,[\w\d_]+),end/) {
	$conflictEnd{$2} = $1; #Save end time in map, to log ended conflict and potentially check for re-start
	$conflictTime = $conflictEnd{$2} - $conflictStart{$2};
	$totalConflictTime += $conflictTime;
	if (exists $ongoingRepeatConflicts{$2})
	{
	    #print($2, " REPEATED conflict ends after ", $conflictTime, " seconds\n");
	    $repeatedConflicts++;
	    delete $ongoingRepeatConflicts{$2};
	} else {
	    #print($2, " conflict ends after ", $conflictTime, " seconds\n");
	}
    }
}
close(FCONS);
$startConflictPairs = scalar(keys(%conflictStart));
$endConflictPairs = scalar(keys(%conflictEnd));
$totalNumConflicts = $endConflictPairs + $repeatedConflicts;
#print("Unique started conflict pairs: $startConflictPairs\n");
print("Unique ended conflict pairs: $endConflictPairs\n");
#print("(Joined conflicts: $joinedConflicts)\n");
print("Ended repeated conflicts: $repeatedConflicts\n");
print("Consolidated number of conflicts: $totalNumConflicts\n");
$averageConflictTime = 0;
if ($totalNumConflicts > 0)
{
    $averageConflictTime = $totalConflictTime / $totalNumConflicts;
}
print("Average conflict time: $averageConflictTime\n");

#LOS events
$los = `grep start ${directory}/USEPELOS* | wc -l`;
print("LOS events: $los");

# Count number of NMAC events: CPA < 3.75 m
@cpafiles = glob " ${directory}/USEPECPA*";

if (@cpafiles > 1) {
    # decide what to do here if there are no matching files,
    # or multiple matching files
    die("More than 1 CPA log in ${directory}! Terminating");
} elsif (@cpafiles < 1) {
    # decide what to do here if there are no matching files,
    # or multiple matching files
    die("No CPA log in ${directory}? Terminating");
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
