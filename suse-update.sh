#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE tumbleweed with the latest packages.
# Version: 1.01
#  Author: Dan Huckson
#    Date: 2017/09/20
###############################################################################

date_time=`date`
start_time=$(date +%s)

echo $date_time >> /tmp/suse-update-timestamps.txt
echo -e "\nStart Time: $date_time\n" > /var/log/suse-update.log

if [ -z "$1" ]; then VERBOSITY=0; else VERBOSITY=$1; fi

if (( $VERBOSITY > 1 )) || (( $VERBOSITY < 0 )); then
    echo "Incorrect value entered."
    exit
fi

if (( $VERBOSITY )); then
    zypper refresh > /dev/nil
    echo Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories
    zypper -v -n update --auto-agree-with-licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //' | tee -a /var/log/suse-update.log
else
    echo -e "\nRefreshing Repositories" | tee -a /var/log/suse-update.log
    echo -e "----------------------------------------" | tee -a /var/log/suse-update.log
    zypper refresh | cut -d"'" -f2 | tee -a /var/log/suse-update.log
    echo -e "----------------------------------------\n" | tee -a /var/log/suse-update.log
    zypper -v -n update --auto-agree-with-licenses | sed "/Unknown media type in type/d;s/^   //;/^Additional rpm output:/d" | sed ':a;N;$!ba;s/\n  / /g' | tee -a /var/log/suse-update.log
fi

s=$[$(date +%s) - $start_time]; h=$[$s / 3600]; s=$[$s - $[$h * 3600]]; m=$[$s / 60]; s=$[$s - $[m * 60]]
[ "$h" != '0' ] && hours=" $h hours" || hours=""
[ "$m" != '0' ] && minutes=" $m minutes and" || minutes=""
echo -e "\nTotal run time$hours$minutes $s seconds." | tee -a /var/log/suse-update.log
