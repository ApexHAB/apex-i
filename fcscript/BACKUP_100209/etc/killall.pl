#!/usr/bin/perl
#
system("pkill -f flightc.pl");
system("pkill -f flightj.pl");
system("pkill -f avionicsd.pl");
system("pkill -f ax25perld.pl");
print "DONE\n";
