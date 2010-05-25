#!/usr/bin/perl

# SGS BALLOON PROJECT
# SCRIPT SETS AVIONICS TIME FROM GPS
# JON SOWMAN 2008-09

use IO::Select;
use IO::File;
use IO::Socket;

system("/root/hwctl/led01");

# set variables
$host = "127.0.0.1";
$port = "2947";
$avionics_port = "7070";
$errorlogfile = "/root/flight/error.log";

# GPSD SETUP AND TCP PORT CALLS

sub do_command {
  my @ready, $s, $buf;
  my($handle, $command) = @_;
  my $read_set = new IO::Select($handle);
  print $handle "$command\n";
  while (1) {
    if (@ready = $read_set->can_read(2)) {
      foreach $s (@ready) {
        $buf = <$s>;
        if ($buf =~ m/GPSD/) {
          return $buf;
        }
      }
    }
    else {
      return 4;
    }
  }
}

$opencount = 0;
 $gpsd = new IO::Socket::INET
            (PeerAddr => $host,
             PeerPort => $port,
             Proto    => 'tcp',);
 $opencount++;

die "Could not create gpsd socket: $!\n" unless $gpsd;
$gpsd->autoflush(1);
$opencount = 0;

# AVIONICS SETUP AND TCP PORT CALLS

sub do_admon {
  my @ready, $s, $buf, $repcount;
  my($handle, $command) = @_;
  my $read_set = new IO::Select($handle);
  while ($repcount < 3) {
    print $handle "$command";
    if (@ready = $read_set->can_read(2)) {
      foreach $s (@ready) {
        $buf = <$s>;
      }
     return $buf;
    }
    $repcount++;
  }
  return 3;
}

$opencount  = 0;
while ((! $admon) && ($opencount < 30)) {
  $admon = new IO::Socket::INET
             (PeerAddr => '127.0.0.1',
              PeerPort => '7070',
              Proto    => 'tcp',);
  $opencount++;
  sleep 1;
}
die "Could not create socket: $!\n" unless $admon;
$admon->autoflush(1);
$opencount = 0;
$| = 1;

$errorlog = new IO::File(">>$errorlogfile");
die "Could not open errorlog file: $!\n" unless $errorlog;
$errorlog->autoflush(1);
##########################

$gps_okay = 1;

if ($gps_okay = (($result = do_command($gpsd, "s")) ? (1 && $gps_okay) : 0)) {
$result =~ m/GPSD,S=([01])/;
$gps_valid = $1;
}
if ($gps_okay = (($result = do_command($gpsd, "d")) ? (1 && $gps_okay) : 0)) {
#$result =~ m/GPSD,D=(\d+)\/(\d+)\/(\d+) (\d+):(\d+):(\d+)/;
$result =~ m/GPSD,D=(\d+)-(\d+)-(\d+)\w(\d+):(\d+):(\d+)\.(\d+)\w/;
$gps_utc = sprintf("%.2d%.2d%.2d", $4, $5, $6);
#print $gps_utc."\n";
}
  
# SEND TIME TO AVIONICS SET
if($gps_valid && $gps_okay) {
	$| = 1;
	$cstr = "C227" . $gps_utc;
	print "$cstr\n"; ########### DEBUG
	do_admon($admon, "$cstr\n");
} else {
	# write to error log
	print $errorlog "Could not set avionics time, GPS invalid or no lock.\n";
}
 
$gpsd->autoflush(1);
$admon->autoflush(1);

system("/root/hwctl/led00");

