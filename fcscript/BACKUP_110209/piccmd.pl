#!/usr/bin/perl
#

use IO::Select;
use IO::File;
use IO::Socket;

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

#########

$cstr = $ARGV[0];
$cto = $ARGV[1];
$calarm = $cto + 3;
#$rstr = `$cstr`;
#print $cstr."\n";
#print $rstr."\n";

eval { #TIMEOUTSEQ
		local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
		alarm $calarm;
		$utt = do_admon($admon, "$cstr\n");
		sleep($cto); # wait
		alarm 0;
	};
if ($@) {     # timed out
	die "Unexpected TIMEOUT ERROR" unless $@ eq "alarm\n";   # propagate unexpected errors
	print "TIMEOUT\n";
}

#print $cto . ":::" . $calarm . ":::" . $utt;
print $utt;

$admon->autoflush(1);
