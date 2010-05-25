#!/usr/bin/perl

use IO::Select;
use IO::File;
use IO::Socket;

$host = "127.0.0.1";
$port = "2947";

$opencount = 0;

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


 $gpsd = new IO::Socket::INET
            (PeerAddr => $host,
             PeerPort => $port,
             Proto    => 'tcp',);
 $opencount++;

die "Could not create socket: $!\n" unless $gpsd;
$gpsd->autoflush(1);
$opencount = 0;

#do_command($gpsd, "s") =~ m/GPSD,S=([01])/;

#do_command($gpsd, "N=0");
#print $buf;

#do_command($gpsd, "R=1");
#print $buf;

do_command($gpsd, "msibk");
print $buf;
do_command($gpsd, "p");
print $buf;
do_command($gpsd, "d");
print $buf;


$gpsd->autoflush(1);
