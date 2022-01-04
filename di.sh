#! /bin/sh

clear
echo -e "Overal disk space lookup.\n"
echo -e "\nInodes:"
echo "Filesystem      Inodes  IUsed   IFree IUse% Mounted on" 
df -i|grep -w /
echo -e "\nDistribution:" 
(du -sk /* | sort -nr | awk 'BEGIN{ pref[1]="K"; pref[2]="M"; pref[3]="G"; pref[4]="T";} { total = total + $1; x = $1; y = 1; while( x > 1024 ) { x = (x + 1023)/1024; y++; } printf("%g%s\t%s\n",int(x*10)/10,pref[y],$2); } END { y = 1; while( total > 1024 ) { total = (total + 1023)/1024; y++; } printf("Total: %g%s\n",int(total*10)/10,pref[y]); }'|head -n15) 2> /dev/null
echo -e "\nBiggest files:" 
(find / -type f -size +100M -exec du -shx {} \; | sort -rh | head -n5) 2> /dev/null
echo -e "\nLarge logs (+100M):" 
find / -type f -size +100M \( -name "*_log" -o -name "*.log" \) -exec du -shx {} \; | sort -rh |head -n5

#Results of latest backups
backup_ret=$(egrep -i '(enable|daily|weekly|monthly)' /var/cpanel/backups/config);echo; if [ -n "$(echo $backup_ret | awk '{print $1" "$2}' | grep -i yes)" ];then echo "Results of latest backups:";grep -i "final state" /usr/local/cpanel/logs/cpbackup/*|tail -3;echo;fi

echo -e "\nWant additional info?"
read klk
if [[ $klk == "yes" || $klk == "Yes" || $klk == "YES" || $klk == "y" ]]; then
	(while true; do
		echo -e "\nWrite down a full path:\n"
		read path
		#if path exists, then else ech_o this path does not exists
		(du -sk $path/* | sort -nr | awk 'BEGIN{ pref[1]="K"; pref[2]="M"; pref[3]="G";} { total = total + $1; x = $1; y = 1; while( x > 1024 ) { x = (x + 1023)/1024; y++; } printf("%g%s\t%s\n",int(x*10)/10,pref[y],$2); } END { y = 1; while( total > 1024 ) { total = (total + 1023)/1024; y++; } printf("Total: %g%s\n",int(total*10)/10,pref[y]); }'|head -n15) 2> /dev/null
		echo -e "\nAnother one?"
		read klk2
		if [[ $klk2 == "no" || $klk2 == "NO" || $klk2 == "n" ]]; then
		echo "We're done"
		break
		fi
done
	)
else 
	echo -e "\n\nOk, Done."
fi
