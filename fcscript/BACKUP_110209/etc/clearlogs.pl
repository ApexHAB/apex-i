#!/usr/bin/perl
#
system("rm /root/flight/error.log");
system("rm /root/flight/cut.log");
system("rm /root/flight/aprs.log");

system("touch /root/flight/error.log");
system("touch /root/flight/cut.log");
system("touch /root/flight/aprs.log");

print "Done!\n";

