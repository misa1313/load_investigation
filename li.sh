#!/bin/sh

clear
uptime=$(uptime)
nproc=$(nproc)
date=$(date '+%d')

echo "This is a script to give you an idea of any load issues the server may have. Want to proceed?"

read klk

if [[ $klk == "yes" || $klk == "Yes" || $klk == "YES" || $klk == "y" ]]; then
	(echo -e "\n-Uptime:\n$uptime" 
	echo -e "\n-Cores:\n$nproc" 
	
	#OOM?
	echo -e "\n-OOMs?" 
	oom=$(grep -o 'Out of memory:' /var/log/messages* | wc -l) 	
	echo -e "$oom times recently." 
	
	#Load averages
        echo -e "\n-Today's loads \n--:--:--      runq-sz  plist-sz   ldavg-1   ldavg-5  ldavg-15   blocked"  
        sar -q 

	#Swap memory
        echo -e "\n-Today's swap usage. \n--:--:-- - kbswpfree kbswpused  %swpused  kbswpcad   %swpcad"  
        sar -S| tail -n 35

        #Disk I/O usage
        echo -e "\n-Today's Disk I/O usage. \n--:--:-- --       DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util"  
        sar -d| tail -n 35 
	echo -e "\nToday's Disk I/O wait. \n00:00:01    CPU    %iowait" 
        sar -s| awk '{ print $1"    " $2"    "$6 }'|tail -n 35

	#Memory Limit
	phpv=$(php -v|grep cli| awk {'print $1 " " $2 '})
        echo -e "\nPPH version: $phpv"
	echo -e "\n-PHP Memory limit x Apache MaxRequestWorkers." 
	phploc=$(php --ini|grep -ia "loaded configuration file"| awk {'print $4'})	
	phpmem=$(cat $phploc |grep -ia "memory_limit"|awk {'print $3'}|cut -d "M" -f 1)
	echo -e "Memory limit: $phpmem M" 
	maxrw=$(cat /etc/apache2/conf/httpd.conf|grep -ai "MaxRequestWorkers"| awk {'print $2'})
	echo -e "MaxRequestWorkers $maxrw" 
	maxphp=$(expr $phpmem \* $maxrw)
	maxphp=$(echo "scale=2;$maxphp/1000"|bc)
	echo -e "Maximum amount of memory php processes can allocate = $maxphp G" 
	ram=$(free -mht|grep Mem|awk {'print $2'})
	echo -e "RAM available: $ram" 

	#MYSQL
	echo -e "\n-MYSQL" 
	mysqladmin version|grep -i "server version"
	mysqladmin version|grep -i "threads"
	echo -e "Service   Mem_usage   RAM_usage" 
	ps faux | grep -i mysql|grep ^mysql|awk {'print $1"     "$5 "K""      " $6 "K"'} 
	echo -e "\nTotal Index Sizes by Engine." 
	mysql -Bse 'show variables like "datadir";'|awk '{print $2}'|xargs -I{} find {} -type f -printf "%s %f\n"|awk -F'[ ,.]' '{print $1, $NF}'|awk '{array[$2]+=$1} END {for (i in array) {printf("%-15s %s\n", sprintf("%.3f MB", array[i]/1048576), i)}}' | egrep '(MYI|ibd)' 

	#Values for innodb_buffer and key_buffer
	db1=$(mysql -Bse 'show variables like "datadir";'|awk '{print $2}'|xargs -I{} find {} -type f -printf "%s %f\n"|awk -F'[ ,.]' '{print $1, $NF}'|awk '{array[$2]+=$1} END {for (i in array) {printf("%-15s %s\n", sprintf("%.3f MB", array[i]/1048576), i)}}' | egrep '(MYI|ibd)'| awk 'FNR== 1 {print $1}')
	db2=$(mysql -Bse 'show variables like "datadir";'|awk '{print $2}'|xargs -I{} find {} -type f -printf "%s %f\n"|awk -F'[ ,.]' '{print $1, $NF}'|awk '{array[$2]+=$1} END {for (i in array) {printf("%-15s %s\n", sprintf("%.3f MB", array[i]/1048576), i)}}' | egrep '(MYI|ibd)'| awk 'FNR== 2 {print $1}')
	db3=$(mysql -Bse 'show variables like "datadir";'|awk '{print $2}'|xargs -I{} find {} -type f -printf "%s %f\n"|awk -F'[ ,.]' '{print $1, $NF}'|awk '{array[$2]+=$1} END {for (i in array) {printf("%-15s %s\n", sprintf("%.3f MB", array[i]/1048576), i)}}' | egrep '(MYI|ibd)'| awk 'FNR== 3 {print $1}')
	keyb=$(echo "scale=2;$db1 * 1.10"|bc)
	innobp=$(echo "scale=2;$db2 + $db3"|bc)
	innobp=$(echo "scale=2;$innobp * 1.20"|bc)
	echo -e "For key_buffer_size $keyb MB and for innodb_buffer_pool_size $innobp MB." 
	
	#APACHE 
	echo -e "\n-Max MaxRequestWorkers for this server: "
	ram=$(free -mht|grep Mem|awk {'print $2'}|cut -d G -f 1)
	ram=$(echo "escale=2;$ram*1000"|bc)
	mylim=$(cat /etc/my.cnf|grep -ai "max_allowed_packet"|cut -d "=" -f 2)
	mylim=$(echo "scale=2;$mylim/1000000"|bc)
	maxwor=$(echo "scale=2;$ram - $mylim"|bc)
	maxwor=$(echo "scale=2;$maxwor/$phpmem"|bc)
	echo "[RAM - MYSQL memory_limit] / PHP memory_limit = $maxwor" 

	#Top 15 processes.
	echo -e "\n-Top 15 processes consuming resources:"
	ps aux | sort -nrk 3,4 | head -n 15 	

	#La nema
	echo -e "\n-Sites stadistics:" 
	echo -e "\nNumber of requests by domain:" ; find /usr/local/apache/domlogs/ -maxdepth 1 -type f|xargs grep $(date +%d/%b/%Y)|awk '{print $1}'|cut -d':' -f1|sort |uniq -c|sort -n|tail -n5; echo; echo "Number of POST requests by domain:";find /usr/local/apache/domlogs/ -maxdepth 1 -type f|xargs grep $(date +%d/%b/%Y)|grep POST|awk '{print $1}'|cut -d':' -f1|sort |uniq -c|sort -n|tail -n5;echo;echo "IP's with most requests:";find /usr/local/apache/domlogs/ -maxdepth 1 -type f|xargs grep $(date +%d/%b/%Y) |awk '{print $1}'|cut -d':' -f2|sort |uniq -c|sort -n|tail ;echo;echo "URLs with most requests:";find /usr/local/apache/domlogs/ -maxdepth 1 -type f|xargs grep $(date +%d/%b/%Y) |awk '{print $7}'|sort|uniq -c|sort -n | tail;echo;echo "IPs with most HTTP connections currently:";netstat -nt 2>/dev/null | egrep ':80|:443'| awk '{print $5}' | awk -F: 'BEGIN { OFS = ":"} {$(NF--)=""; print}' | awk '{print substr($0, 1, length($0)-1)}' | sort | uniq -c | sort -rn | head
	
	echo -e "\nIP's host:" && for each in `(find /usr/local/apache/domlogs/ -maxdepth 1 -type f|xargs grep $(date +%d/%b/%Y) |awk '{print $1}'|cut -d':' -f2|sort |uniq -c|sort -n|tail)| awk {'print $2'}`; do host $each; done
	echo '') > loadinv

	#Yesterdays
        echo -e "\n-Want yesterday's stats?"
        read klk3
        if [[ $klk3 == "yes" || $klk3 == "Yes" || $klk3 == "YES" || $klk3 == "y" ]]; then

	(echo -e "\n-Yesterday's loads \n--:--:--      runq-sz  plist-sz   ldavg-1   ldavg-5  ldavg-15   blocked" 
        date2=$(date -d '-1 day' '+%d')
        sar -q -f /var/log/sa/sa$date2| tail -n 35
		
	echo -e "\n-Yesterday's Swap usage \n--:--:-- - kbswpfree kbswpused  %swpused  kbswpcad   %swpcad"
        sar -S -f /var/log/sa/sa$date2| tail -n 35

	echo -e "\n-Yesterday's Disk I/O usage \n--:--:-- --       DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util" 
        sar -d -f /var/log/sa/sa$date2| tail -n 35
	echo -e "\nYesterday's Disk I/O wait. \n00:00:01    CPU    %iowait" 
        sar -s -f /var/log/sa/sa$date2| awk '{ print $1"    " $2"    "$6 }'|tail -n 35) >> loadinv

else
        echo "Ok, only today's."
fi

	echo -e "\nWe're done. To see results, check 'loadinv' file."

else
        echo "Ok, hablamo."

fi
