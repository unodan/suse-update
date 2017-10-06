#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE tumbleweed with the latest packages.
# Version: 2.04
#  Author: Dan Huckson
###############################################################################
date=`date`
time=$(date +%s)
script=$(basename -- "$0")
distribution="openSUSE tumbleweed"

name=`echo $script | cut -f1 -d.`
logs=/var/log/$name
log=$logs/$name.log

[ ! -d "$logs" ] && mkdir $logs; 

while getopts ":alrvk:s:h" opt; do
  case $opt in    
    a)  number_of_log_files=`ls $logs/$name*.log 2> /dev/null | wc -l`
    
        (( $maximum_log_files )) && (( $number_of_log_files >= $maximum_log_files )) && {
            [ ! -d $logs/archive ] && mkdir -p $logs/archive; 
            cd $logs
            ls *.log | xargs zip -q "archive/$name-logs-`date +%Y%m%d-%H%M%S`.zip" && rm *.log
        }
        ;;
    l)  auto_agree_with_licenses="--auto-agree-with-licenses"
        ;;
    r)  refresh=1
        ;;
    v)  verbosity=1 
        ;;
    k)  maximum_log_files=$OPTARG    
    
        ! [[ $maximum_log_files =~ ^[0-9]+$ ]] && {
            echo -e "ERROR: Please enter a positive interger for the maximum number of log files to keep.\n" >&2
            echo -e "\nUse $script -h for more information." >&2
            exit 10
        }
        log="$logs/$name-`date +%Y%m%d-%H%M%S`.log"
        ;;
    s)  restart_cancel_timeout=$OPTARG
        reboot=1 
        
        ! [[ $restart_cancel_timeout =~ ^[0-9]+$ ]] && {
            echo -e "ERROR: Please enter a positive interger for the number of seconds to wait befrore restarting the system." >&2
            echo -e "\nUse $script -h for more information." >&2
            exit 15
        }
        ;;
    h)  echo -e "\nUsage: $script [OPTION]..."
        echo -e "Update $distribution with the latest packages"
        echo -e "\n\t-a\t Archive the log files"
        echo -e "\t-l\t Auto agree with licenses"
        echo -e "\t-r\t Refresh all enabled repostiories"
        echo -e "\t-v\t Verbosity (show maximum information)"
        echo -e "\t-k\t Maximum number of log files to keep"
        echo -e "\t\t (this option must be supplied with a positive number)"
        echo -e "\t-s\t Restart system after updates"
        echo -e "\t\t (this option must be supplied with a positive number,"
        echo -e "\t\t for the number of seconds to wait before restarting the system)"
        echo -e "\t-h\t Display this help message"
        echo -e "\nExample: $script -vsk 30 "
        echo -e "  output maximum info, restart system after updates and keep the latest 30 log files."
        exit 20
        ;;
   \?)  echo -e "ERROR: Invalid option [ -$OPTARG ]\nUse $script -h for more information." >&2
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
        err=${PIPESTATUS[0]}
        (( $err )) && { 
            echo "An error ( $err ) occurred when refreshing repositories, exiting script." >&2; exit 50; 
        } 
        echo -e "----------------------------------------\n" | tee -a $log
    } || { 
        zypper refresh > /dev/null; 
        err=$?
        (( $err )) && { 
            echo "An error ( $err ) occurred when refreshing repositories, exiting script." >&2; exit 55; 
        } 
        echo "Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories."
    }
}

if (( $verbosity )); then 
    zypper -v -n update $auto_agree_with_licenses | sed "/Unknown media type in type/d;s/^   //;/^Additional rpm output:/d" | sed ':a;N;$!ba;s/\n  / /g' | sed ':a;N;$!ba;s/\nRetrieving: /, /g' | tee -a $log
    err=${PIPESTATUS[0]}
    (( $err )) && { echo "An error ( $err ) occurred with ( $script ) exiting script." >&2; exit 60; } 
else
    zypper -v -n update $auto_agree_with_licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //' | tee -a $log
    err=${PIPESTATUS[0]}
    (( $err )) && { echo "An error ( $err ) occurred with ( $script ) exiting script." >&2; exit 65; } 
fi

(( $maximum_log_files )) && {
    cd $logs && ls -tp | grep -v '/$' | tail -n +$((maximum_log_files+1)) | xargs -rd '\n' rm -- 
}

s=$[$(date +%s) - $time]; h=$[$s / 3600]; s=$[$s - $[$h * 3600]]; m=$[$s / 60]; s=$[$s - $[m * 60]]
[ "$h" != '0' ] && hours=" $h hours" || hours=""
[ "$m" != '0' ] && minutes=" $m minutes and" || minutes=""

echo -e "\nEnd: `date`\n" | tee -a $log
echo -e "Finished, total run time$hours$minutes $s seconds." | tee -a $log

(( $reboot )) && { 
    if xhost 1&> /dev/null; then 
        echo "Waiting for system to restart..."
        xmessage "     * * * Warnning restarting the system in $(( restart_cancel_timeout / 60 )) minutes * * *     " -timeout $restart_cancel_timeout -button " Restart , Cancel " &> /dev/null
        err=$?
        (( ! $err )) || (( $err == 101 )) && {
            echo "System has been restarted." | tee -a $log
            init 6;
        } || echo "System restart has been canceled!" | tee -a $log
    else 
        echo -e "System has been restarted.\n" | tee -a $log
        shutdown -r $(( restart_cancel_timeout / 60 )) "     * * * Warnning restarting the system in $(( restart_cancel_timeout / 60 )) minutes * * *"
    fi
} 

exit 0
