#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE tumbleweed with the latest packages.
# Version: 2.01
#  Author: Dan Huckson
###############################################################################
date=`date`
time=$(date +%s)
script=$(basename -- "$0")
distribution="openSUSE tumbleweed"

name=`echo $script | cut -f1 -d.`
dir=/var/log/$name
log=$dir/$name.log

[ ! -d "$dir" ] && mkdir $dir; 

while getopts ":rlvak:sh" opt; do
  case $opt in
    r)  refresh=1
        ;;
    l)  auto_agree_with_licenses="--auto-agree-with-licenses"
        ;;
    v)  verbosity=1 
        ;;
    a)  number_of_log_files=`ls $dir/$name*.log 2> /dev/null | wc -l`
    
        (( $maximum_log_files )) && (( $number_of_log_files >= $maximum_log_files )) && {
            [ ! -d $dir/archive ] && mkdir -p $dir/archive; 
            
            logs="$name-logs-`date +%Y%m%d-%H%M%S`" 
            ls $dir/*.log | xargs zip -q $dir/archive/$logs.zip
            rm $dir/*.log
        }
        ;;
    k)  maximum_log_files=$OPTARG    
    
        ! [[ $maximum_log_files =~ ^[0-9]+$ ]] && {
            echo -e "ERROR: Please enter a positive interger value for the maximum number of log files to keep.\n" >&2
            echo -e "Example: $script -vrk 30 " >&2
            echo -e "  output maximum info, reboot and keep the latest 30 log files." >&2
            echo -e "\nUse $script -h for more information." >&2
            exit 10
        }
        log="$dir/$name-`date +%Y%m%d-%H%M%S`.log"
        ;;
    s)  reboot=1 
        ;;
    h)  echo -e "\nUsage: $script [OPTION]..."
        echo -e "Update $distribution with the latest packages"
        echo -e "\n\t-r\t Refresh all enabled repostiories"
        echo -e "\t-l\t Auto agree with licenses"
        echo -e "\t-v\t Verbosity (show maximum information)"
        echo -e "\t-a\t Archive the log files"
        echo -e "\t-k\t Maximum number of log files to keep,"
        echo -e "\t\t this option must be supplied with a numeric value"
        echo -e "\t-s\t Restart system after updates"
        echo -e "\t-h\t Display this help message"
        echo -e "\nExample: $script -vsk 30 "
        echo -e "  output maximum info, restart system after updates and keep the latest 30 log files."
        exit 20
        ;;
    \?) echo -e "ERROR: Invalid option [ -$OPTARG ]\nUse $script -h for more information." >&2
        exit 30
        ;;
    :)  echo -e "ERROR: Option [ -$OPTARG ] requires an argument.\nUse $script -h for more information." >&2
        exit 40
        ;;
  esac
done

echo -e "Start: $date" | tee -a $log
(( $auto_agree_with_licenses )) && { 
    echo -e "\nApplying updates without asking to confirm licenses." | tee -a $log 
}

(( $refresh )) && {
    (( $verbosity )) && {
        echo -e "\nRefreshing Repositories" | tee -a $log
        echo -e "----------------------------------------" | tee -a $log
        zypper refresh | cut -d"'" -f2 | tee -a $log
        (( ${PIPESTATUS[0]} )) && { echo "An error occurred with (zypper refresh) exiting script." >&2; exit 50; } 
        echo -e "----------------------------------------\n" | tee -a $log
    } || { 
        zypper refresh > /dev/null; 
        (( $? )) && { echo "An error occurred with (zypper refresh) exiting script." >&2; exit 60; } 
        echo Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories
    }
}

(( $verbosity )) && {
    zypper -v -n update $auto_agree_with_licenses | sed "/Unknown media type in type/d;s/^   //;/^Additional rpm output:/d" | sed ':a;N;$!ba;s/\n  / /g' | sed ':a;N;$!ba;s/\nRetrieving: /, /g' | tee -a $log
    (( ${PIPESTATUS[0]} )) && { echo "An error occurred with (zypper update) exiting script." >&2; exit 55; } 
} || {
    zypper -v -n update $auto_agree_with_licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //' | tee -a $log
    (( ${PIPESTATUS[0]} )) && { echo "An error occurred with (zypper update) exiting script." >&2; exit 65; } 
}

(( $maximum_log_files )) && {
    cd $dir && ls -tp | grep -v '/$' | tail -n +$((maximum_log_files+1)) | xargs -rd '\n' rm -- 
}

s=$[$(date +%s) - $time]; h=$[$s / 3600]; s=$[$s - $[$h * 3600]]; m=$[$s / 60]; s=$[$s - $[m * 60]]
[ "$h" != '0' ] && hours=" $h hours" || hours=""
[ "$m" != '0' ] && minutes=" $m minutes and" || minutes=""

echo -e "\nEnd: `date`\n" | tee -a $log
echo -e "Total run time$hours$minutes $s seconds." | tee -a $log

(( $reboot )) && init 6;
