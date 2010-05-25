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
$ballooncall = "M3SGS";
$logfile = "/root/flight/aprs.log";
$radioname = "tncx";
$aprspath = "APRS RELAY TRACE3-3";
#$aprspath = "APRS VIA WIDE RELAY";
#$aprspath = "APRS VIA RELAY WIDE";
#$aprspath = "APRS WIDE1-1 WIDE2-2";

# variable init
$aprs_string = "";
$aprs_comment = " SGS Balloon Project - balloon.hexoc.com - webmaster\@hexoc.com";
$beacon_count = 0;

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
  }
  if ($gps_okay = (($result = do_command($gpsd, "t")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,T=([\d\.]+)/;
    $gps_heading = $1;
  }
  if ($gps_okay = (($result = do_command($gpsd, "a")) ? (1 && $gps_okay) : 0)) {
    $result =~ m/GPSD,A=([\d\.]+)/;
    $gps_alt = $1 * 3.28;
  }
  
  # GET DATA FROM AVIONICS
$| = 1;
$utt = do_admon($admon, "C111\n");
$utt =~ s/\s+$//; #this strips off new lines from PIC
$picstring = $utt;
  
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

$gpsd->autoflush(1);
$admon->autoflush(1);

system("/root/hwctl/led00");
