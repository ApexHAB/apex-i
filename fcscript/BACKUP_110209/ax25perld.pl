#!/usr/bin/perl
#
# THIS IS MY AX25D ALTERNATIVE
#
# SCRIPT WATCHES THE AX25SPYD TELNET PORT 14091
# AND CHECKS INCOMING DATA FOR A STRING BEGINNING WITH
# tncx: AX25: M6TWO
# AND CARRIES OUT A COMMAND BASED ON WHAT IT SEES
#
# THE DOBEACON() FUNCTION BEACONS A STRING WITH
# A SUITABLE PREFIX SO WE CAN SEE IT COMES FROM THE BALLOON
#
# ALL CHECKING ROUTINES ARE TIMED OUT AFTER 10 SECONDS
# THEN THIS SCRIPT WILL EXIT!
# IT RELIES ON EXTERNAL LAUNCHERS (launcher.pl) TO START AGAIN
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
# THIS IS THE AUTH STRING FOR A CUTDOWN
$cutdownauth = "wu7rUPrazuthuFun";
# AUTH FOR SHUTDOWN FPC
$shutdownauth = "Ye8aqa5U2ruqunEh";
# ALLOW RSX?
$RSX_enable = 0;

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

#root@ts7000:root# tncx: AX25: M3XCQ-3->IDENT <UI> Text
#SGSHELLO

while(1) {      # never gonna end...

	$infotxt = <$remote>;
	$data = <$remote>;

	$infotxt =~ /^(\w+): (.+): (\w+)-(\d{1,2})->(.+)/;
	$rxport = $1;
	$rxproto = $2;
	$rxcall = $3;
	$rxssid = $4;
	$rxunproto = $5;

	#print $rxport . ":::" . $rxproto . ":::" . $rxcall . ":::" . $rxssid . ":::" . $rxunproto . "\n";

	$data =~ /^(\w{3})(\w+) \[(\w+)] *(.*)/;
	$prefl = $1;
	$ctrlcmd = $2;
	$spwd = $3;
	$args = $4;

	# this could fail on several counts, most likely conns. to TCP ports don't work
	#
	# eval/die is req'd - graceful exit is essential to prevent the script crashing
	
	eval {
	
		local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
		alarm 15;
	
		if ( $rxport eq "tncx" and $rxproto eq "AX25" and $rxcall eq $controlcall and $prefl eq $controlprefix and $spwd eq $controlpwd ) {

			if ($ctrlcmd =~ m/HELLO/) {
				dobeacon("Hello from the SGS Weather Balloon!");
			}

			if ($ctrlcmd =~ m/ECHO/) {
				dobeacon("You said: ".$args);
			}

			if ($ctrlcmd =~ m/DAEMONS/) {
				$ax25p = "ps ajx |grep ax25perld";
				$beaconstr = `$ax25p`;
				dobeacon($beaconstr);
				$ax25p = "ps ajx |grep avionicsd";
				$beaconstr = `$ax25p`;
				dobeacon($beaconstr);
			}

			if ($ctrlcmd =~ m/EXEC/) {
				if($RSX_enable){
					$beaconstr = `$args`;
					dobeacon($beaconstr);
				} else {
					dobeacon("RSX is currently disabled.");
				}
			}

			if ($ctrlcmd =~ m/TEST/) {
				$beaconstr = `perl /root/etc/pingpic.pl`;
				dobeacon("PIC Response: ".$beaconstr);
				$beaconstr = `perl /root/etc/pinggps.pl`;
				dobeacon("GPS Response: ".$beaconstr);
			}

			if ($ctrlcmd =~ m/GREP/) {
				$shellc = "ps ajx |grep ".$args;
				$beaconstr = `$shellc`;
				dobeacon($beaconstr);
			}
			
			if ($ctrlcmd =~ m/CYCLE/) {
				$shellc = "/root/hwctl/cyc_all.sh";
				$beaconstr = `$shellc`;
				dobeacon($beaconstr);
			}

			if ($ctrlcmd =~ m/PICTURE/) {
				system("touch /root/etc/takepic");
				dobeacon("Touched /root/etc/takepic");
			}
			
			if ($ctrlcmd =~ m/CUTDOWN/) {
				if ($args eq $cutdownauth) {
					system("touch /root/etc/cutdown");
					dobeacon("Touched /root/etc/cutdown");
				} else {
					dobeacon("Cutdown not authorised");
				}
			}
			
			if ($ctrlcmd =~ m/SHUTDOWN/) {
				if ($args eq $shutdownauth) {
					dobeacon("Shutting down flight computer...");
					sleep(3);
					system("shutdown -h now");	
				} else {
					dobeacon("Flight computer soft shutdown unauthorised");
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
