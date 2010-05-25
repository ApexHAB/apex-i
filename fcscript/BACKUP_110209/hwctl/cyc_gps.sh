echo "resetting gps..."
source /root/ts7xxx.subr
led1 1 > /dev/null
dio_dir_set 2 1 > /dev/null
dio_data_set 2 0 > /dev/null
led1 0 > /dev/null
sleep 5
led1 1 > /dev/null
dio_dir_set 2 1 > /dev/null
dio_data_set 2 1 > /dev/null
led1 0 > /dev/null
exit 0

