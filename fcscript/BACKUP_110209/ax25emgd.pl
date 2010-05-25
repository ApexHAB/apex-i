#!/usr/bin/perl
#
# THIS IS MY AX25D EMERGENCY DAEMON
#
# RUNS KILL ALL WHEN SGSKILLALL <auth> IS SUPPLIED
#
# SCRIPT WATCHES THE AX25SPYD TELNET PORT 14091
# AND CHECKS INCOMING DATA FOR A STRING BEGINNING WITH
# tncx: AX25: M6TWO
# AND CARRIES OUT A COMMAND BASED ON WHAT IT SEES
#
# THE DOBEACON() FUNCTION BEACONS A STRING WITH
# A SUITABLE PREFIX SO WE CAN SEE IT COMES FROM THE BALLOON
#
#
# PARAMETERS
#
#  HOST TO WATCH AX25SPYD ON
$spyhost = "127.0.0.1";
# PORT TO WATCH AX25SPYD ON
$spyport = "14091";
# COMMAND MUST COME FROM THIS CALLSIGN (DO NOT INCLUDE SSID)
$controlcall = "M6TWO";
# COMMAND MUST START WITH THIS STRING
$controlprefix = "SGS";
# THIS PASSWORD MUST BE SUPPLIED FOR AUTHENTICATION
$controlpwd = "ballooncat9";
# AUTH FOR KILLALL
$killallauth = "xe8r4Je3Ayudre8e";

# NO EDITING BELOW THIS LINE
##############################

use IO::Socket;
use POSIX qw(setsid);

# now set up socket
$remote = IO::Socket::INET->new(
		Proto    => "tcp",
		PeerAddr => $spyhost,
		PeerPort => $spyport,
	    )
or die "cannot connect to daytime port at localhost";

# this beacons the string you send it
sub dobeacon {
	my($bstring) = @_;
	system("beacon -s tncx \"SGSBalloon: ".$bstring."\"");
}

#daemonize now
chdir '/'                 or die "Can't chdir to /: $!";
umask 0;
open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
#open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
open STDERR, '>/dev/null' or die "Can't write to /dev/null: $!";
defined(my $pid = fork)   or die "Can't fork: $!";
exit if $pid;
setsid                    or die "Can't start a new session: $!";

while(1) {      # never gonna end...

	$infotxt = <$remote>;
	$data = <$remote>;

	$infotxt =~ /^(\w+): (.+): (\w+)-(\d{1,2})->(.+)/;
	$rxport = $1;
	$rxproto = $2;
	$rxcall = $3;
	$rxssid = $4;
	$rxunproto = $5;

	$data =~ /^(\w{3})(\w+) \[(\w+)] *(.*)/;
	$prefl = $1;
	$ctrlcmd = $2;
	$spwd = $3;
	$args = $4;

	# not quite sure why this would ever fail.. but try/catch anyway
	
	eval {
	
		local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
		alarm 15;
	
		if ( $rxport eq "tncx" and $rxproto eq "AX25" and $rxcall eq $controlcall and $prefl eq $controlprefix and $spwd eq $controlpwd ) {

			if ($ctrlcmd =~ m/KILLALL/) {
				if ($args eq $killallauth) {
					dobeacon("Starting kill...");
					sleep(1);
					system("perl /root/etc/killall.pl");
				} else {
					dobeacon("Killall unauthorised");
				}
			}

		}
		
	alarm 0;
	};
	
	# and catch
	if ($@){
		die "Unexpected TIMEOUT ERROR" unless $@ eq "alarm\n";   # propagate unexpected errors 
		dobeacon("ax25perld function timed out. exiting...");
		sleep(1);
        exit(1);
    };

	# clear the vars
	$infotxt = "";
	$data = "";
	$rxport = "";
	$rxproto = "";
	$rxcall = "";
	$rxssid = "";
	$rxunproto = "";
	$prefl = "";
	$ctrlcmd = "";
	$spwd = "";
	$args = "";

}
