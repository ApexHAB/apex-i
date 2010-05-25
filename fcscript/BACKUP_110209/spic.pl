#!/usr/bin/perl
#

# JON SOWMAN - SGS BALLOON PROJECT
# THIS SCRIPT IS A TEST PROGRAM CONNECTING
# TO THE AVIONICS DAEMON ON TCP 7070

use IO::Socket;
use IO::Select;
use IO::File;

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
$utt = do_admon($admon, "C211\n");
$utt =~ s/\s+$//; #this strips off new

print $utt." is my data\n";
