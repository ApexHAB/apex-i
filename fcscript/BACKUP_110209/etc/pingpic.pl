#!/usr/bin/perl
#
# JON SOWMAN - SGS BALLOON PROJECT
# THIS SCRIPT PINGS THE PIC AND PRINTS
# THE RESULT TO STDOUT
#
use IO::Socket;
use IO::Select;
use IO::File;

$pic_ping_command = "C141";

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

$| = 1;

eval {
	local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	alarm 6;
	$utt = do_admon($admon, "$pic_ping_command\n");
	sleep(3);
	alarm 0;
};
if ($@) {     # timed out
	die "What the...?" unless $@ eq "alarm\n";   # propagate unexpected errors
	$utt = "TOUT";
}
 
$utt =~ s/\s+$//; #this strips off new lines from PIC
if ( $utt eq "PONG" ) {
	print "The PICAXE is alive and kicking\n";
} elsif ( $utt eq "TOUT" ) {
	print "The PICAXE PING request timed out\n";
} else {
	print "The PICAXE did not respond correctly: " . $utt ."\n";
}
