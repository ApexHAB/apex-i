#!/usr/bin/perl
#

use IO::Socket;
use IO::Select;
use IO::File;

$DEBUG = 0;   

$host = "127.0.0.1";
$port = "2947";

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

$gps_valid = 0;
$check_count = 0;

# send red led high
system("/root/hwctl/led11");

while($gps_valid == 0) {
	sleep(5);
	$result = do_command($gpsd, "s");
	$result =~ m/GPSD,S=([01])/;
	$gps_valid = $1;
	$check_count++;
	#print $gps_valid."\n";
}

#send red led low and exit
system("/root/hwctl/led10");