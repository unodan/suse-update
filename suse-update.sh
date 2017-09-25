#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE tumbleweed with the latest packages.
# Version: 1.26
#  Author: Dan Huckson
###############################################################################
distribution="openSUSE tumbleweed"

date_time=`date`
start_time=$(date +%s)

log_file_name=suse-update
log_directory=/var/log/suse-update
log_file="$log_directory/$log_file_name".log
timestamp_file=/tmp/suse-update-timestamps.txt

if [ ! -d "$log_directory" ]; then mkdir $log_directory; fi

while getopts ":rvhk:" opt; do
  case $opt in
    r)  reboot=1 
        ;;
    v)  verbosity=1 
        ;;
    h)  echo -e "\nUsage: suse-update.sh [OPTION]..."
        echo -e "Update $distribution with the latest packages"
        echo -e "\n\t-r\t Reboot after update"
        echo -e "\t-v\t Verbosity (show maximum information)"
        echo -e "\t-h\t Display this help message"
        echo -e "\t-k\t Maximum number of log files to keep,"
        echo -e "\t\t this option must be supplied with a numeric value"
        echo -e "\nExample:"
        echo -e "  suse-update.sh -vrk 30  output maximum info, reboot and keep the latest 30 log files.\n"
        exit 1
        ;;
    k)  maximum_log_files=$OPTARG
        log_file="$log_directory/$log_file_name-`date +%Y%m%d-%H%M%S`.log"
        if ! [[ $OPTARG =~ ^[0-9]+$ ]]; then
            echo "Please enter an interger value for the maximum number of log files to keep."
            echo "Example: You would use \"suse-update.sh -k 30\" to keep the lastest 30 log files."
            exit 2
        fi
        cd $log_directory && ls -tp | grep -v '/$' | tail -n +$maximum_log_files | xargs -d '\n' -r rm -- 
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 3 
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 4 
        ;;
  esac
done

echo $date_time >> $timestamp_file
echo -e "\nStart Time: $date_time\n" > $log_file

if (( $verbosity )); then
    echo -e "\nRefreshing Repositories" | tee -a $log_file
    echo -e "----------------------------------------" | tee -a $log_file
    zypper refresh | cut -d"'" -f2 | tee -a $log_file
    echo -e "----------------------------------------\n" | tee -a $log_file
    zypper -v -n update --auto-agree-with-licenses | sed "/Unknown media type in type/d;s/^   //;/^Additional rpm output:/d" | sed ':a;N;$!ba;s/\n  / /g' | tee -a $log_file
else
    zypper refresh > /dev/nil
    echo Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories
    zypper -v -n update --auto-agree-with-licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //' | tee -a $log_file
fi

s=$[$(date +%s) - $start_time]; h=$[$s / 3600]; s=$[$s - $[$h * 3600]]; m=$[$s / 60]; s=$[$s - $[m * 60]]
[ "$h" != '0' ] && hours=" $h hours" || hours=""
[ "$m" != '0' ] && minutes=" $m minutes and" || minutes=""
echo -e "\nTotal run time$hours$minutes $s seconds." | tee -a $log_file

if [ $reboot ]; then init 6; fi
