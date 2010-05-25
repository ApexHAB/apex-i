#!/usr/bin/perl
#
#
# SCRIPT CHECKS FOR JUMPER 6 AND SHUTS FPC DOWN IF IT FINDS IT
#
$rval = `/root/etc/check6.sh`;
#print $rval."\n";
if ( $rval =~ m/1/ ) {
	system("crontab -r -u root");
	system("/root/hwctl/led11");
	sleep(5);
	system("/root/hwctl/led10");
	system("shutdown -h now");
}
exit(1);
