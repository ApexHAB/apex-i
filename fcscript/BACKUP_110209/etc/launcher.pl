#!/usr/bin/perl

use strict;

my $path = shift; #path to script should we need to relaunch it
my $scriptName = shift; #name of script to look for

my $cmd = "ps aux | grep " . $scriptName;
my $result = `$cmd`;
my @lines = split("\\n", $result);

foreach(@lines) {
	#ignore results for the grep command and this script
	unless ($_  =~ m/grep|launcher/){
		exit;
	}
}

#my $launchCMD = "cd $path; nohup ./$scriptName / -print >/dev/null";
my $launchCMD = "cd $path; nohup ./$scriptName >/dev/null";
system($launchCMD);
