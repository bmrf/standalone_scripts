# Search all files for a text string, starting at root, and only display the file name, not the contents
grep -Ril "text-to-find-here" /
grep -r "string to be searched" /

# rdesktop to a system with compression (z), bitmap caching (P), in low-bandwidth mode (-x m), with remote sound played through remote speakers
rdesktop hgate.us.to:1338 -g 1450x1250 -z -r sound:remote -x m -P -p <PASSWORD>

# Update all expired apt keys
for K in $(apt-key list | grep expired | cut -d'/' -f2 | cut -d' ' -f1); do sudo apt-key adv --recv-keys --keyserver keys.gnupg.net $K; done

# Matrix text scrolling effect in the terminal
echo -e "\e[1;40m" ; clear ; while :; do echo $LINES $COLUMNS $(( $RANDOM % $COLUMNS)) $(( $RANDOM % 72 )) ;sleep 0.05; done|awk '{ letters="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()"; c=$4; letter=substr(letters,c,1);a[$3]=0;for (x in a) {o=a[x];a[x]=a[x]+1; printf "\033[%s;%sH\033[2;32m%s",o,x,letter; printf "\033[%s;%sH\033[1;37m%s\033[0;0H",a[x],x,letter;if (a[x] >= $1) { a[x]=0; } }}'

# Calculate cost of lines of code in a directory
sloccount ./

# List all services/daemons that run at startup (run level 3)
/sbin/chkconfig --list |grep '3:on'

# Release and renew IP addresses
dhclient -r
dhclient 

# Determine if system is 32 or 64 bits
cat /proc/cpuinfo | grep -Gq "flags.* lm " && echo '64bit' || echo '32bit'

# Get release version
cat /etc/release # red hat and derivatives
cat /etc/issue   # debian and derivatives

# Monitor disk i/o
iostat -x 1

# Disk usage summary by directory
du -chs /*

# Disk usage summary by directory, alternate (sometimes more effective)
du -h / | grep '[0-9\.]\+G'
du -h / | grep '^\s*[0-9\.]\+G'			# only directories larger than 1.0 GB
du -ch -d 1 | sort -hr					# uses util ncdu

# Find average size of all files on the entire drive (/)
find / -type f -print0 | xargs -0 ls -l | gawk '{sum += $5; n++;} END {print "Total Size: " sum/1024/1024 " MB : Avg Size: " sum/n/1024 " KB : Total Files: " n ;}'

# Kill all processes whose name contains this string ("minion" in this example)
kill `ps -A|awk '/minion/{print $1}'`

# Verify no non-root users have UID 0 (root)
awk -F: '($3 == "0") {print}' /etc/passwd

# Follow a log file in real-time
tail -f /var/log/maillog
tail -f /var/log/messages
tail -f /var/log/httpd

# Useful tools for watching NIC traffic/throughput
vnstat -l -i eth1
iptraf
iptraf-ng	# new version
ntop		# Self-contained webGUI traffic monitor, with graphs and detailed tables. Runs by default on port 3000

# Add static route for a specific host
route add -host 192.168.1.83 gw 172.16.1.1    # old version
ip route add 192.168.1.0/24 via 10.0.0.1      # new version
ip route add 192.168.1.0/24 dev eth2          # specifying via interface vs. gateway IP

# Add static route for a specific subnet
route add -net 192.168.1.0/24 gw 172.16.1.1

# Add static route for a specific subnet and specify a metric
route add -net 192.168.1.0/24 gw 172.16.1.1 3

# RHEL/CentOS: Show all installed packages and the date of last update
rpm -qa --qf '%{INSTALLTIME} %-40{NAME} %{INSTALLTIME:date}\n' | sort -n | cut -d' ' -f2-
