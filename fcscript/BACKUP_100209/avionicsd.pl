#!/usr/bin/perl
#

# JON SOWMAN BALLOON PROJECT
# THIS IS A PERL DAEMON FOR CONTROLLING
# A MICROCONTROLLER CONNECTED VIA SERIAL
# ACCEPTS COMMAND STRINGS ON PORT 7070

use IO::Select;
use IO::File;
use IO::Socket;
use POSIX qw(setsid);

sub open_port {
  my($portdevice, $portspeed) = @_;
  system("/bin/stty -F $portdevice speed $portspeed raw > /dev/null 2>&1");
  my $porthandle = new IO::File("+<$portdevice");
  if ($porthandle) {
    $porthandle->autoflush(1);
  }
  return $porthandle;
}

sub command {
  my @ready;
  my $s, $buf;
  my($porthandle, $command) = @_;
  my $read_set = new IO::Select();
  $read_set->add($porthandle);
  
  print $porthandle $command;
  #syswrite($porthandle,$command);
  if (@ready = $read_set->can_read(2)) {
    foreach $s (@ready) {
      $buf = <$s>;
      return $buf;
    }
  }
  return 0;
}

chdir '/'                 or die "Can't chdir to /: $!";
umask 0;
open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
open STDERR, '>/dev/null' or die "Can't write to /dev/null: $!";
defined(my $pid = fork)   or die "Can't fork: $!";
exit if $pid;
setsid                    or die "Can't start a new session: $!";

$port = open_port("/dev/ttyTS0", "2400");

$socket = new IO::Socket::INET (LocalHost => '127.0.0.1',
                                LocalPort => '7070',
                                Proto     => 'tcp',
                                Listen    => 16,
                                Reuse     => 1,);
die "Could not create socket: $!\n" unless $socket;

$sock_set = new IO::Select($socket);

            $old_fh = select($port);
            $| = 1;
            select($old_fh); 

while (1) {
  @rh_set = $sock_set->can_read();
  foreach $rh (@rh_set) {
    if ($rh == $socket) {
      $ns = $rh->accept();
      $ns->autoflush(1);
      $sock_set->add($ns);
    }
    else {
      $buf = <$rh>;
      if ($buf) {
        $out = command($port, $buf);
        print $rh $out;
      }
      else {
        $sock_set->remove($rh);
        close($rh);
      }
    }
  }
}
