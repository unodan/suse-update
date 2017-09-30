#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE tumbleweed with the latest packages.
# Version: 1.31
#  Author: Dan Huckson
###############################################################################
date=`date`
time=$(date +%s)
script=$(basename -- "$0")
distribution="openSUSE tumbleweed"

name=`echo $script | cut -f1 -d.`
dir=/var/log/$name
log="$dir/$name".log

if [ ! -d "$dir" ]; then mkdir $dir; fi

while getopts ":rvlhk:" opt; do
  case $opt in
    r)  reboot=1 
        ;;
    v)  verbosity=1 
        ;;
    l)  auto_agree_with_licenses="--auto-agree-with-licenses"
        ;;
    h)  echo -e "\nUsage: $script [OPTION]..."
        echo -e "Update $distribution with the latest packages"
        echo -e "\n\t-r\t Reboot after update"
        echo -e "\t-v\t Verbosity (show maximum information)"
        echo -e "\t-l\t Auto agree with licenses"
        echo -e "\t-h\t Display this help message"
        echo -e "\t-k\t Maximum number of log files to keep,"
        echo -e "\t\t this option must be supplied with a numeric value"
        echo -e "\nExample: $script -vrk 30 "
        echo -e "  output maximum info, reboot and keep the latest 30 log files."
        exit 10
        ;;
    k)  log="$dir/$name-`date +%Y%m%d-%H%M%S`.log"
        if ! [[ $OPTARG =~ ^[0-9]+$ ]]; then
            echo -e "\nPlease enter a positive interger value for the maximum number of log files to keep.\n" >&2
            echo -e "Example: $script -vrk 30 " >&2
            echo -e "  output maximum info, reboot and keep the latest 30 log files." >&2
            echo -e "\nUse $script -h for more information." >&2
            exit 20
        fi
        cd $dir && ls -tp | grep -v '/$' | tail -n +$OPTARG | xargs -rd '\n' rm -- 
        ;;
    \?)
        echo -e "Invalid option: -$OPTARG\nUse $script -h for more information." >&2
        exit 30
        ;;
    :)
        echo -e "Option -$OPTARG requires an argument.\nUse $script -h for more information." >&2
        exit 40
        ;;
  esac
done

echo -e "Start: $date" | tee -a $log
(( $auto_agree_with_licenses )) && { 
    echo -e "\nApplying updates without asking to confirm licenses.\n" >&2; 
}

if (( $verbosity )); then
    echo -e "\nRefreshing Repositories" | tee -a $log
    echo -e "----------------------------------------" | tee -a $log
    zypper refresh | cut -d"'" -f2 | tee -a $log
    (( ${PIPESTATUS[0]} )) && { echo "An error occurred with (zypper refresh) exiting script." >&2; exit 50; } 
    echo -e "----------------------------------------\n" | tee -a $log
    
    zypper -v -n update $auto_agree_with_licenses | sed "/Unknown media type in type/d;s/^   //;/^Additional rpm output:/d" | sed ':a;N;$!ba;s/\n  / /g' | tee -a $log
    (( ${PIPESTATUS[0]} )) && { echo "An error occurred with (zypper update) exiting script."  >&2; exit 55; } 
else
    zypper refresh > /dev/nil
    (( ${PIPESTATUS[0]} )) && { echo "An error occurred with (zypper refresh) exiting script."  >&2; exit 60; } 
    echo Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories
    
    zypper -v -n update $auto_agree_with_licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //' | tee -a $log
    (( ${PIPESTATUS[0]} )) && { echo "An error occurred with (zypper update) exiting script."  >&2; exit 65; } 
fi

s=$[$(date +%s) - $time]; h=$[$s / 3600]; s=$[$s - $[$h * 3600]]; m=$[$s / 60]; s=$[$s - $[m * 60]]
[ "$h" != '0' ] && hours=" $h hours" || hours=""
[ "$m" != '0' ] && minutes=" $m minutes and" || minutes=""

echo -e "\nEnd: `date`\n" | tee -a $log
echo -e "Total run time$hours$minutes $s seconds." | tee -a $log

if (( $reboot )); then init 6; fi
