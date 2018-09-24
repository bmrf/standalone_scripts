# SCP a file from one system to another
scp username@destination_host:/path/to/file /path/to/destination

# List all services/daemons that run at startup (run level 3)
/sbin/chkconfig --list |grep '3:on'

# Release and renew IP addresses
dhclient -r
dhclient 

# Determine if system is 32 or 64 bits
cat /proc/cpuinfo | grep -Gq "flags.* lm " && echo '64bit' || echo '32bit'

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
ntop		# Self-contained webGUI traffic monitor, with graphs and detailed tables. Runs by default on port 3000

# Add static route for a specific host
route add -host 192.168.1.83 gw 172.16.1.1

# Add static route for a specific subnet
route add -net 192.168.1.0/24 gw 172.16.1.1

# Add static route for a specific subnet and specify a metric
route add -net 192.168.1.0/24 gw 172.16.1.1 3

# RHEL/CentOS: Show all installed packages and the date of last update
rpm -qa --qf '%{INSTALLTIME} %-40{NAME} %{INSTALLTIME:date}\n' | sort -n | cut -d' ' -f2-
