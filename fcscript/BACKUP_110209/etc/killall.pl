#!/usr/bin/perl
#
system("/root/hwctl/cyc_all.sh");
sleep(6);
system("pkill -f flightc.pl");
system("pkill -f flightj.pl");
system("pkill -f avionicsd.pl");
system("pkill -f ax25perld.pl");
print "DONE\n";
