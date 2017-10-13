#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE tumbleweed with the latest packages.
# Version: 2.08
#  Author: Dan Huckson
###############################################################################

function get_time_string {
    unset time_string hours minutes seconds
    
    h=$(( $1 / 3600 )); m=$(( ($1 - h * 3600) / 60 )); s=$(( $1 % 60 )); 
    (( $h > 0 )) && { (( $h > 1 )) && hours=" $h hours" || hours=" 1 hour"; }
    (( $m > 0 )) && { (( $m > 1 )) && minutes=" $m minutes" || minutes=" 1 minute"; }
    (( $s > 0 )) && { (( $s > 1 )) && seconds=" $s seconds" || seconds=" 1 second"; }
    
    time_string=${hours}${minutes}${seconds}
}

start_time=$(date +%s)
script=$(basename -- "$0")
distribution="openSUSE tumbleweed"

name=`echo $script | cut -f1 -d.`
logs=/var/log/$name
log=$logs/$name.log

[ ! -d "$logs" ] && mkdir $logs; 

while getopts ":alrvk:s:h" opt; do
  case $opt in    
    a)  number_of_log_files=`ls $logs/$name*.log 2> /dev/null | wc -l`
    
        (( $maximum_log_files != 0 )) && (( $number_of_log_files >= $maximum_log_files )) && {
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
            echo -e "ERROR: Please enter a positive interger for the maximum number of log files to keep.\nUse $script -h for more information." >&2
            exit 10
        }
        log="$logs/$name-`date +%Y%m%d-%H%M%S`.log"
        ;;
    s)  restart_cancel_timeout=$OPTARG
        reboot=1
        
        ! [[ $restart_cancel_timeout =~ ^[0-9]+$ ]] && {
            echo -e "ERROR: Please enter a positive interger for the number of seconds to wait befrore restarting the system.\nUse $script -h for more information." >&2
            exit 15
        }
        ;;
    :)  echo -e "ERROR: Option [ -$OPTARG ] requires an argument.\nUse $script -h for more information." >&2
        exit 40
        ;;
   \?)  echo -e "ERROR: Invalid option [ -$OPTARG ]\nUse $script -h for more information." >&2
        exit 30
        ;;
    h)  echo -e "
Usage: $script [OPTION]...\n
Update $distribution with the latest packages.
Enabled repositories can be refreshed and updates done (automatically) and none-interactively.
Log files will be over written unless the -k option is used. The -k option accepts an integer for the number of log files to keep, older log files are deleted.
The -a option must be used with the -k option, archiving happens when the number of log files equals the value supplied to the -k option. Once the log file is achieved it's deleted from the logs directory. 
You can restart the system after updating by using the -s option followed by the number of seconds to wait before rebooting, allowing the user time to cancel the restarting process if needed.
        
 -a\t Archive the log files
 -l\t Auto agree with licenses
 -r\t Refresh all enabled repostiories
 -v\t Verbosity (show maximum information)
 -k\t Maximum number of log files
   \t  (this option must be supplied with the maximum number of log files to keep)
 -s\t Restart system after updates
   \t  (this option must be supplied with the number of seconds to wait before restarting the system)
 -h\t Display this help message
 
Example: $script -v -s 300 -k 30 
  output maximum information, restart the system 300 seconds after updates are finished and keep the latest 30 log files."
        exit 20
        ;;
  esac
done

echo -e "Start: `date`" | tee -a $log
(( $auto_agree_with_licenses )) && agree_with_licenses=", accepting all licenses."
echo -e "\nApplying updates to ($distribution)$agree_with_licenses" | tee -a $log 

(( $refresh )) && {
    (( $verbosity )) && {
        echo -e "\nRefreshing Repositories" | tee -a $log
        echo -e "----------------------------------------" | tee -a $log
        zypper refresh | cut -d"'" -f2 | tee -a $log; err=${PIPESTATUS[0]}
        echo -e "----------------------------------------" | tee -a $log
    } || zypper refresh > /dev/null; err=$?
    
    (( $err != 0 )) && { echo "An error ( $err ) occurred when refreshing repositories, exiting script." >&2; exit 50; } 
    echo -e "Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories.\n" | tee -a $log 
}

if (( $verbosity )); then 
    zypper -v -n update $auto_agree_with_licenses | sed '/Unknown media type in type/d; s/^   //; /^Additional rpm output:/d; :a;N;$!ba;s/\n  / /g' | sed ':a;N;$!ba;s/\nRetrieving: /, /g' | tee -a $log
    err=${PIPESTATUS[0]}
else
    zypper -v -n update $auto_agree_with_licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //' | tee -a $log
    err=${PIPESTATUS[0]}
fi
(( $err != 0 )) && { echo "An error ( $err ) occurred with ( $script ) exiting script." >&2; exit 60; } 

(( $maximum_log_files )) && cd $logs && ls -tp | grep -v '/$' | tail -n +$((maximum_log_files+1)) | xargs -rd '\n' rm -- 

get_time_string $[$(date +%s) - $start_time]
echo -e "\nEnd: `date`\n\nFinished, total run time$time_string." | tee -a $log

(( $reboot )) && { 
    (( $restart_cancel_timeout > 0 )) && { 
        get_time_string $restart_cancel_timeout
        
        if xhost > /dev/null 2>&1; then 
            echo "System is going to restart in$time_string."
            xmessage "     * * * Warnning restarting the system in$time_string * * *     " -timeout $restart_cancel_timeout -button " Restart , Cancel " &> /dev/null
            err=$?
            (( $err == 0 )) || (( $err == 101 )) && {
                echo -e "1: System was restarted. ($(date))\n" >> $log
                init 6
            } || echo -e "System restart was canceled. ($(date))\n" | tee -a $log
        else 
            echo -e "2: System was restarted. ($(date)\n" >> $log
            echo "* * * Warnning restarting the system in$time_string * * *"
            sleep $restart_cancel_timeout
            init 6
        fi
    } || {
        echo -e "3: System was restarted. ($(date)\n" >> $log
        init 6
    }
} 
exit 0
