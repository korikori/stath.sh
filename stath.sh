#!/bin/bash
DOMAIN=""
usage="usage: $0 [ -d DOMAIN ] [ -f ] [ -m ] [ -p] FILE\n\n -d provide a domain name for HTTP logs \n -f search in FTP logs (default is HTTP) \n -m use mtime timestamps (default is ctime) \n -p only consider POST requests in HTTP logs \n"
 
set -e
  
while getopts d:fcmp option
do
case "${option}"
in
d) DOMAIN=${OPTARG};; #username not always included in domain
f) LOG="ftp";;
m) TIME="mtime";; #-m for mtime, otherwise ctime
p) POST=" POST";;
/?) echo -e "$usage";
esac
done
shift $((OPTIND - 1))
FILE=$1
  
if [ -z "$FILE" ]; then
 echo -e "Please enter full path to file.\n"
 echo -e "$usage";
 exit 1;
else
  
  if [ -n "$POST" ]; then
   maybe_post=' grep POST |';
  else
   maybe_post=''
   POST='';
  fi
  
array=( $(stat $FILE --printf='%U\n%y\n%z') )
 
echo -e "################\nIncident Report for $FILE\n################\n"
stat $FILE
 
user=( ${array[0]} )
 
#times
if [ "$TIME" = "mtime" ]; then #mtime
  date=( ${array[1]//-/\/} )
  time=( ${array[2]:0:6} )
  hour=( ${array[2]:0:2} )
  min=( ${array[2]:3:2} )
else #ctime
  date=( ${array[4]//-/\/} )
  time=( ${array[5]:0:6} )
  hour=( ${array[5]:0:2} )
  min=( ${array[5]:3:2} )
fi
 
#paths
htlog=/var/admin/log_archive/httpd/$date/$hour*.log.gz
ftlog=/var/admin/log_archive/ftpd/$date/$hour*.log.gz

  
if [ "$LOG" = "ftp" ]; then
  #time can be before or after ftp log gets truncated, so add one hour
  if [ "$hour" = 23 ]; then #in this case, adding one hour will also make it tomorrow!
    date=( $(date -d "$date + 1 day" +'%Y/%m/%d') )
  fi
  ftlogplus=/var/admin/log_archive/ftpd/$date/$(date -d "$hour today + 1 hour" +'%H')*.log.gz
  
  echo -e "\n################\nFTP log entries for $user at $hour:$min (+1 hour) on $date\n################\n"
  if [ $(date +%F) = ${array[1]} ]; then
    grep $user /var/log/xferlog | grep $time;
  fi
  zgrep $user $ftlog | grep $time
  zgrep $user $ftlogplus | grep $time;
else
  if [ -z "$DOMAIN" ]; then
    string=( $user );
  else
    string=( $DOMAIN );
  fi
    echo -e "\n################\nHTTP$POST log entries for $string at $hour:$min on $date\n################\n"
    if [ $(date +%F) = ${array[1]} ]; then
     eval "grep $string /apache/logs/access_log | $maybe_post grep $time" ;
    fi
    eval "zgrep $string $htlog | $maybe_post grep $time" ;
fi
fi
