#!/usr/bin/perl

# SGS BALLOON PROJECT
# JON SOWMAN 2008-09

# THIS SCRIPT IS RUN ONCE ON STARTUP
# 1 - CHECKS FOR GPS LOCK
# 2 - GRABS TIME FROM GPS AND SETS PIC CLOCK
# 3 - PINGS PIC TO CHECK CORRECTLY WORKING
# 4 - TURNS LIGHT & SIREN ON FOR A FEW SECONDS TO SHOW BOOT FINISHED

# IF ALL GOES TO PLAN, THIS SCRIPT SHOULD BE SILENT

use IO::Socket;
use IO::Select;
use IO::File;

# send grn led high
system("/root/hwctl/led01");

$DEBUG = 1;   

$host = "127.0.0.1";
$port = "2947";
$avionics_port = "7070";
$errorlogfile = "/root/flight/error.log";

$pic_time_prefix = "C227";
$pic_ping_command = "C141";
$pic_booted_command = "C211";

$pi = atan2(1, 1) * 4;

# GPSD SETUP AND TCP PORT HANDLE SETUP
sub do_command {
  my @ready, $s, $buf;
  my $handle = shift(@_);
  my $command = shift(@_);
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
      return 0;
    }
  }        
}

$opencount  = 0;
while ((! $gpsd) && ($opencount < 30)) {
  $gpsd = new IO::Socket::INET
            (PeerAddr => $host,
             PeerPort => $port,
             Proto    => 'tcp',);
  $opencount++;
  sleep 1;
}
die "Could not create socket: $!\n" unless $gpsd;
$gpsd->autoflush(1);
$opencount  = 0;

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

# OPEN THE FILE HANDLE FOR THE ERROR LOG - APPEND MODE
$errorlog = new IO::File(">>$errorlogfile");
die "Could not open errorlog file: $!\n" unless $errorlog;
$errorlog->autoflush(1);
##########################

# INIT VARIABLES
$gps_okay = 1;
$gps_valid = 0;

# WAIT UNTIL GPS GETS A LOCK
system("/root/hwctl/led11"); # red led on
while($gps_valid == 0) {
	sleep(3);
	$result = do_command($gpsd, "s");
	$result =~ m/GPSD,S=([01])/;
	$gps_valid = $1;
}
system("/root/hwctl/led10"); #red led off

# QUERY FOR LOCK STATUS AND UTC TIME hhmmss
if ($gps_okay = (($result = do_command($gpsd, "s")) ? (1 && $gps_okay) : 0)) {
	$result =~ m/GPSD,S=([01])/;
	$gps_valid = $1;
}
if ($gps_okay = (($result = do_command($gpsd, "d")) ? (1 && $gps_okay) : 0)) {
	$result =~ m/GPSD,D=(\d+)-(\d+)-(\d+)\w(\d+):(\d+):(\d+)\.(\d+)\w/;
	$gps_utc = sprintf("%.2d%.2d%.2d", $4, $5, $6);
	$gps_dat = sprintf("%.2d/%.2d/%.2d", $3, $2, $1);
}
if ($gps_okay = (($result = do_command($gpsd, "p")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,P=(\-?)([\d\.]+) (\-?)([\d\.]+)/; 
    $gps_lat_dir = $1 ? "S" : "N";
    $gps_lon_dir = $3 ? "W" : "E";
    $gps_lat = int($2) . ($2 - int($2)) * 60;
    $gps_lon = int($4) . ($4 - int($4)) * 60;
}
# find bits for startup location writing
if ($gps_okay = (($result = do_command($gpsd, "p")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,P=(\S+)\s+(\S+)/;
	$startlat = $1 * ($pi / 180);
	$startlon = $2 * ($pi / 180);
}

# open file for startup coords
open(STARTP,">/root/etc/startup");
$startuppos = sprintf("%07.2f%s/%08.2f%s", $gps_lat, $gps_lat_dir, $gps_lon, $gps_lon_dir);
$startuptim = "Startup on " . $gps_dat . " at " . $gps_utc;
$startup = $startuptim . ". Location:  " .  $startuppos . ".\n".$startlat."\n".$startlon."\n";
print STARTP $startup; # and write
#print $startup;
close(STARTP); # close

# PING THE PIC (timeout 6 secs)
eval {
	local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	alarm 6;
	$result = do_admon($admon, "$pic_ping_command\n");
	sleep(3);
	alarm 0;
};
if ($@) {     # timed out
	die "Unexpected error!" unless $@ eq "alarm\n";   # propagate unexpected errors
	print $errorlog "boot.pl script terminated: The PIC PING request timed out.\n";
	if($DEBUG) {
		print "boot.pl script terminated: The PIC PING request timed out.\n";
	}
}

if($result !~ m/PONG/) {
	print $errorlog "boot.pl script terminated: The PIC did not respond with PONG to PING.\n";
	if($DEBUG) {
		print "boot.pl script terminated: The PIC did not respond with PONG to PING.\n";
	}
	exit(1);
}
  
# SEND TIME TO AVIONICS SET
if($gps_valid and $gps_okay) {
	$cstr = $pic_time_prefix . $gps_utc;
	if($DEBUG) {
		print "Set time string formatted as: $cstr\n";
	}
	eval {
		local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
		alarm 6;
		$result = do_admon($admon, "$cstr\n"); # set the time
		sleep(3);
		alarm 0;
	};
	if ($@) {     # timed out
		die "Unexpected error!" unless $@ eq "alarm\n";   # propagate unexpected errors
		if($DEBUG) {
			print "Set time command timed out.\n";
		}
	}
} else {
	# write to error log
	print $errorlog "boot.pl script terminated: could not set avionics time, GPS invalid or no lock.\n";
	if($DEBUG) {
		print "boot.pl script terminated: could not set avionics time, GPS invalid or no lock.\n";
	}
	exit(1);
}

if($DEBUG) {
	print "Everything ok, FLASHALL...\n";
}

# IF WE GOT TO HERE, EVERYTHING WENT TO PLAN
# FEW SECONDS OF SIREN/LIGHT TO SIGNAL STARTUP ROUTINES COMPLETE
eval {
	local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	alarm 12; # give it a chance!
	$result = do_admon($admon, "$pic_booted_command\n");
	#$result = do_admon($admon, "C999\n");
	sleep(7);
	alarm 0;
};
if ($@) {     # timed out
	die "Unexpected error!" unless $@ eq "alarm\n";   # propagate unexpected errors
	if($DEBUG) {
		print "FLASHALL command times out.\n";
	}
}

# set up flightc.pl cron
system("crontab -u root -r");
system("crontab -u root /root/cron.cron");
if($DEBUG) {
        print "Cron for root cleared and set\n";
}

system("beacon -s tncx \"SGSBalloon: Startup complete!\"");

if($DEBUG) {
	print "Script complete and successful, quitting...\n";
}

# FLUSH THE BUFFERS
$gpsd->autoflush(1);
$admon->autoflush(1);

# send grn led low and exit
system("/root/hwctl/led00");
