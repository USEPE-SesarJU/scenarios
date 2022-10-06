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



