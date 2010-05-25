#!/usr/bin/perl

# SGS BALLOON PROJECT
# LINUX FLIGHT COMPUTER SCRIPT - CUTDOWN MONITORING
# JON SOWMAN 2008-09

use IO::Select;
use IO::File;
use IO::Socket;

system("/root/hwctl/led01");

# set variables
$host = "127.0.0.1";
$port = "2947";
$avionics_port = "7070";
$cutlogfile = "/root/flight/cut.log";
$errorlogfile = "/root/flight/error.log";
$avionics_cut_command = "C29";

$criteria_met = 0;

#criteria
$max_alt = "70000"; # in feet
$max_spd = "80";

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

# NOW OPEN THE LOG FILE AND SETUP HANDLES

$cutlog = new IO::File(">>$cutlogfile");
die "Could not open cutlog file: $!\n" unless $cutlog;
$cutlog->autoflush(1);
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
    $result =~ m/GPSD,D=(\d+)-(\d+)-(\d+)\w(\d+):(\d+):(\d+)\.(\d+)\w/;
    $gps_utc = sprintf("%.2d%.2d%.2d", $4, $5, $6);
  }
  if ($gps_okay = (($result = do_command($gpsd, "p")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,P=(\-?)([\d\.]+) (\-?)([\d\.]+)/; 
    $gps_lat_dir = $1 ? "S" : "N";
    $gps_lon_dir = $3 ? "W" : "E";
    $gps_lat = int($2) . ($2 - int($2)) * 60;
    $gps_lon = int($4) . ($4 - int($4)) * 60;
  }
  if ($gps_okay = (($result = do_command($gpsd, "v")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,V=([\d\.]+)/; 
    $gps_speed = $1;
	if($gps_speed > $max_spd) {
		$criteria_met = 1;
	}
  }
  if ($gps_okay = (($result = do_command($gpsd, "a")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,A=([\d\.]+)/;
    $gps_alt = $1 * 3.28;
	if($gps_alt > $max_alt) {
		$criteria_met = 1;
	}
  }
  
$cut_string = sprintf("\@%.6dh%07.2f%s/%08.2f%s%s/A=%.6d", $gps_utc, $gps_lat, $gps_lat_dir, $gps_lon, $gps_lon_dir, $map_char, $gps_alt);

if($criteria_met){ 
	if($gps_okay) {
		if($gps_valid) {
			$towrite = "The cutdown criteria were met. Cutdown commencing...\n".$cut_string;
			print $cutlog "$towrite\n\n";
			$| = 1;
			$utt = do_admon($admon, "$avionics_cut_command\n");
		} else {
			$towrite = "The cutdown criteria were met. Cutdown aborted: GPS had no lock.\n".$cut_string;
			print $cutlog "$towrite\n\n";
			print $errorlog "Cutdown error\n";
		}
	} else {
		$towrite = "The cutdown criteria were met. Cutdown aborted: unknown GPS error - " . $gps_utc . ".";
		print $cutlog "$towrite\n\n";
		print $errorlog "Cutdown error\n";
	}
}

print "Script OK, criteria met value of " . $criteria_met . "\n";######### DEBUG

$gpsd->autoflush(1);
$admon->autoflush(1);

system("/root/hwctl/led00");

