#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE tumbleweed with the latest packages.
# Version: 1.29
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

while getopts ":rvhk:l" opt; do
  case $opt in
    r)  reboot=1 
        ;;
    v)  verbosity=1 
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
        cd $dir && ls -tp | grep -v '/$' | tail -n +$OPTARG | xargs -d '\n' -r rm -- 
        ;;
    l)  auto_agree_with_licenses="--auto-agree-with-licenses"
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        echo "Use $script -h for more information." >&2
        exit 30
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        echo "Use $script -h for more information." >&2
        exit 40
        ;;
  esac
done

echo $date >> /tmp/$name-datestamp.txt

if (( $verbosity )); then
    echo -e "\nRefreshing Repositories" | tee -a $log
    echo -e "----------------------------------------" | tee -a $log
    zypper refresh | cut -d"'" -f2 | tee -a $log
    echo -e "----------------------------------------\n" | tee -a $log
    
    if [ ! -z $auto_agree_with_licenses ]; then
        echo -e "Applying updates to the system without asking to confirm any licenses.\n" >&2 
    fi
    
    zypper -v -n update $auto_agree_with_licenses | sed "/Unknown media type in type/d;s/^   //;/^Additional rpm output:/d" | sed ':a;N;$!ba;s/\n  / /g' | tee -a $log
else
    zypper refresh > /dev/nil
    echo Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories
    zypper -v -n update $auto_agree_with_licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //' | tee -a $log
fi

s=$[$(date +%s) - $time]; h=$[$s / 3600]; s=$[$s - $[$h * 3600]]; m=$[$s / 60]; s=$[$s - $[m * 60]]
[ "$h" != '0' ] && hours=" $h hours" || hours=""
[ "$m" != '0' ] && minutes=" $m minutes and" || minutes=""
echo -e "Total run time$hours$minutes $s seconds." | tee -a $log

if (( $reboot )); then init 6; fi
