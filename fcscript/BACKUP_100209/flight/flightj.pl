#!/usr/bin/perl

# SGS BALLOON PROJECT
# LINUX FLIGHT COMPUTER SCRIPT
# JON SOWMAN 2008-09

use IO::Select;
use IO::File;
use IO::Socket;

system("/root/hwctl/led01");

# set variables
$host = "127.0.0.1";
$port = "2947";
$avionics_port = "7070";
$radioname = "tncx";
$logfile = "/root/flight/aprs.log";
$cutlogfile = "/root/flight/cut.log";
$errorlogfile = "/root/flight/error.log";
$logicfile = "/root/etc/altitude";
$cutfile = "/root/etc/cutdown";
$takepic = "/root/etc/takepic";

# avionics commands
$avionics_req_time = "C121";
$avionics_req_aprs_suffix = "C111";
$avionics_cut_command = "C291";

$logic_down_lim = "10000"; # alt below which light & siren are turned on after having been above the value below
$logic_up_lim = "15000";

$gpsnolocks_max = 5; # no of GPS NOLOCKs before a hardware power cycle
$camcycles_max = 3; # no of minutes between camera power cycles
$pictimeouts_max = 5; # number of TIMEOUTs from PIC before a hardware PIC reset 

$criteria_met = 0;
$lf_exists = 0;
$cf_exists = 0;

#criteria
$max_alt = 80000; # in feet
$max_spd = 100; # in kts
$maxdistance = 60; # in miles

#APRS UNPROTO
$aprspath = "APRS RELAY TRACE3-3";
#$aprspath = "APRS VIA WIDE RELAY";
#$aprspath = "APRS VIA RELAY WIDE";
#$aprspath = "APRS WIDE1-1 WIDE2-2";

# variable init
$aprs_string = "";
$aprs_comment = " Project APEX - balloon.hexoc.com";
$beacon_count = 0;

# STUFF FOR DISTANCE FROM LAUNCH SITE CALCS
$pi = atan2(1, 1) * 4;
$radius = 3963.1;

sub acos {
  my($x) = @_;
  if ((1 - $x**2) <= 0) {
    return atan2(0, $x);
  }
  else {
    return atan2(sqrt(1 - $x**2), $x);
  }
}

open (STARTUPFILE, "/root/etc/startup") or die $!;
$startup_sentence = <STARTUPFILE>;
$startlat = <STARTUPFILE>;
$startlon = <STARTUPFILE>;
close(STARTUPFILE);

# PIC COMMS SUBS HERE

sub piccmd {
	my($pcmd, $pto) = @_;
	$pcmd2 = "perl /root/piccmd.pl \"$pcmd\" \"$pto\"";
	$pret = `$pcmd2`;
	#print $pcmd2.":::".$pret;
	return $pret;
}

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

$aprslog = new IO::File(">>$logfile");
die "Could not open aprslog file: $!\n" unless $aprslog;
$aprslog->autoflush(1);

$cutlog = new IO::File(">>$cutlogfile");
die "Could not open cutlog file: $!\n" unless $cutlog;
$cutlog->autoflush(1);

$errorlog = new IO::File(">>$errorlogfile");
die "Could not open errorlog file: $!\n" unless $errorlog;
$errorlog->autoflush(1);

##########################

sub do_cut {
	my($istr) = @_;
	$towrite = "Cutdown sequence initiated. Cutdown commencing...\n".$istr;
	print $cutlog "$towrite\n\n";
	$| = 1;
	#print "trying cut... with cmd: " . $avionics_cut_command . " and writing to log: " . $towrite; ######### DEBUG
	$utt = piccmd("$avionics_cut_command\n", "12");
}

# CHECK IF FILES EXIST

sub fileexists {
	my($thefile) = @_;
	if (-e $thefile) {
		return 1;
	} else {
		return 0;
	}
}

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
  if ($gps_okay = (($result = do_command($gpsd, "t")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,T=([\d\.]+)/;
    $gps_heading = $1;
  }
  if ($gps_okay = (($result = do_command($gpsd, "a")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,A=([\d\.]+)/;
    $gps_alt = $1 * 3.28;
	if($gps_alt > $max_alt) {
		$criteria_met = 1;
	}
  }
  # NOW DO THE DISTANCE FROM STARTUP CALCULATION
  if ($gps_okay = (($result = do_command($gpsd, "p")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,P=(\S+)\s+(\S+)/;
	$lat = $1 * ($pi / 180);
	$lon = $2 * ($pi / 180);
	$distance = &acos(cos($startlat)*cos($startlon)*cos($lat)*cos($lon) + cos($startlat)*sin($startlon)*cos($lat)*sin($lon) + sin($startlat)*sin($lat)) * $radius;
	#print "Dcalc: " . $distance . "\n\n"; #### DEBUG
	if ($distance > $maxdistance) {
		$criteria_met = 1;
	}
  }
  
# GET UTC TIME STRING FROM PIC, IN CASE GPS HAS NO LOCK
$pic_utc = piccmd("$avionics_req_time\n", "1");
if (!$gps_okay or !$gps_valid) {
	$gps_utc = $pic_utc;
}
  
# NOW DO THE APRS STUFF
$| = 1;

$picstring = piccmd("$avionics_req_aprs_suffix\n", "1");
$picstring =~ s/\s+$//; # this strips off new lines from PIC
  
$aprs_string = sprintf("\@%.6dh%07.2f%s/%08.2f%s%s%.3d/%.3d/A=%.6d", $gps_utc, $gps_lat, $gps_lat_dir, $gps_lon, $gps_lon_dir, $map_char, $gps_heading, $gps_speed, $gps_alt);
$aprs_string = $aprs_string.$picstring;
$aprs_string = $aprs_string." NOLOCK" unless $gps_valid;
$aprs_string = $aprs_string." GPSERROR" unless $gps_okay;

print $aprslog "$aprs_string\n";

 # 	now send it out over radio  
$aprs_string = $aprs_string.$aprs_comment;
system("beacon -d \"$aprspath\" -s " . $radioname . " \"$aprs_string\"");
print "/usr/sbin/beacon -d \"$aprspath\" -s " . $radioname . " \"$aprs_string\"\n";
$beacon_count++;

############ APRS STUFF ENDS ######################

###################################################

# FLIGHT LOGIC SCRIPTS

if (fileexists($logicfile) and $gps_alt<=$logic_down_lim) {
	# if the balloon has been above the height and is now below
	# need to turn on siren and light
	$result = piccmd("C211\n", "7");
	#print "Tried to turn on light and siren\n"; ############## DEBUG
} elsif (!fileexists($logicfile) and $gps_alt>=$logic_up_lim) {
	system("touch $logicfile");
	#print "Created $logicfile correctly\n"; ############# DEBUG
}

# take  a piccy
$result = piccmd("C3121\n", "5");

$cut_string = sprintf("\@%.6dh%07.2f%s/%08.2f%s%s/A=%.6d", $gps_utc, $gps_lat, $gps_lat_dir, $gps_lon, $gps_lon_dir, $map_char, $gps_alt);

if($criteria_met or fileexists($cutfile)){ 
	if($gps_okay) {
		if($gps_valid) {
			do_cut($cut_string);
		} else {
			$towrite = "Cutdown sequence initiated. Cutdown aborted: GPS had no lock.\n" . $cut_string;
			print $cutlog "$towrite\n\n";
			print $errorlog "Cutdown error\n";
		}
	} else {
		$towrite = "Cutdown sequence initiated. Cutdown aborted: unknown GPS error - " . $gps_utc . ".";
		print $cutlog "$towrite\n\n";
		print $errorlog "Cutdown error\n";
	}
}

# HARDWARE POWER CYCLING CONTROL
$cycle_gps = 0;
open (GPSNOLOCKS, "/root/etc/gpsnolocks"); #open for reading
$gpsnolocks = <GPSNOLOCKS>;
close (GPSNOLOCKS);
open (GPSNOLOCKS, ">/root/etc/gpsnolocks"); #open for overwrite
if ($gps_okay and $gps_valid) {
	print GPSNOLOCKS "0";
} else {
	if ($gpsnolocks >= $gpsnolocks_max) {
		print GPSNOLOCKS "0";
		$cycle_gps = 1;
	} else {
		$gpsnolocks = $gpsnolocks + 1;
		print GPSNOLOCKS $gpsnolocks;
	}
}
close (GPSNOLOCKS);

$cycle_cam = 0;
open (CAMCYCLE, "/root/etc/camcycle");
$camcycles = <CAMCYCLE>;
close (CAMCYCLE);
open (CAMCYCLE, ">/root/etc/camcycle");
if ($camcycles >= $camcycles_max) {
	print CAMCYCLE "0";
	$cycle_cam = 1;
} else {
	$camcycles = $camcycles + 1;
	print CAMCYCLE $camcycles;
}
close (CAMCYCLE);

$cycle_pic = 0;
open (PICTIMEOUTS, "/root/etc/pictimeouts"); #open for reading
$pictimeouts = <PICTIMEOUTS>;
close (PICTIMEOUTS);
open (PICTIMEOUTS, ">/root/etc/pictimeouts"); #open for overwrite
if ($picstring ne "TIMEOUT") {
	print PICTIMEOUTS "0";
} else {
	if ($pictimeouts >= $pictimeouts_max) {
		print PICTIMEOUTS "0";
		$cycle_pic = 1;
	} else {
		$pictimeouts = $pictimeouts + 1;
		print PICTIMEOUTS $pictimeouts;
	}
}
close (PICTIMEOUTS);

if($cycle_cam) {
	# run camera power cycle script
}

if($cycle_gps) {
	# run GPS power cycle script
}

if($cycle_pic) {
	# run PIC power cycle script
}

$gpsd->autoflush(1);
$admon->autoflush(1);

system("/root/hwctl/led00");
