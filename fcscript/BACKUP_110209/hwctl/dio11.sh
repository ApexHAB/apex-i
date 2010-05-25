echo "Sending DIO 1 HIGH as OUTPUT"
source /root/ts7xxx.subr
led1 1 > /dev/null
dio_dir_set 1 1 > /dev/null
dio_data_set 1 1 > /dev/null
led1 0 > /dev/null
exit 0
