#echo "resetting pic..."
source /root/ts7xxx.subr
led1 1 > /dev/null
dio_dir_set 1 1 > /dev/null
dio_data_set 1 1 > /dev/null
led1 0 > /dev/null
#sleep 1
led1 1 > /dev/null
dio_dir_set 1 1 > /dev/null
dio_data_set 1 0 > /dev/null
led1 0 > /dev/null
# ===
led1 1 > /dev/null
dio_dir_set 2 1 > /dev/null
dio_data_set 2 0 > /dev/null
led1 0 > /dev/null
sleep 5
led1 1 > /dev/null
dio_dir_set 2 1 > /dev/null
dio_data_set 2 1 > /dev/null
led1 0 > /dev/null
echo "pic and gps reset complete"
exit 0

