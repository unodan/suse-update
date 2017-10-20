#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE tumbleweed with the latest packages.
# Version: 2.11
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
distribution=`cat /etc/*-release | grep ^NAME | cut -d'"' -f2`
version_id=`cat /etc/*-release | grep ^VERSION_ID | cut -d'"' -f2`
name=`echo $script | cut -f1 -d.`
logs=/var/log/$name && [ ! -d "$logs" ] && mkdir $logs; 
log=$logs/$name.log

while getopts ":alrvk:s:h" opt; do
  case $opt in    
    a)  number_of_log_files=`ls $logs/$name*.log 2> /dev/null | wc -l`
    
        (( $maximum_log_files )) && (( $maximum_log_files > 0 )) && (( $number_of_log_files >= $maximum_log_files )) && {
            [ ! -d $logs/archive ] && mkdir -p $logs/archive; 
            cd $logs && ls *.log | xargs zip -q "archive/$name-logs-`date +%Y%m%d-%H%M%S`.zip" && rm *.log
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
    s)  restart_timeout=$OPTARG
        
        ! [[ $restart_timeout =~ ^[0-9]+$ ]] && {
            echo -e "ERROR: Please enter a positive interger for the number of seconds to wait befrore restarting the system.\nUse $script -h for more information." >&2
            exit 20
        }
        ;;
    :)  echo -e "ERROR: Option [ -$OPTARG ] requires an argument.\nUse $script -h for more information." >&2
        exit 30
        ;;
   \?)  echo -e "ERROR: Invalid option [ -$OPTARG ]\nUse $script -h for more information." >&2
        exit 40
        ;;
    h)  echo -e "
Usage: $script [OPTION]...\n
This script will update $distribution with the latest packages from all the enabled repositories. Enabled repositories can be refreshed and updates done none-interactively (automatically).
Log files will be over written unless the -k option is used. The -k option accepts a positive integer for the number of log files to keep, older log files are deleted.
The -a option must be used with the -k option, archiving happens when the number of log files equals the value supplied to the -k option. Once a log file is achieved it's deleted from the logs directory. 
You can restart the system after updating by using the -s option followed by the number of seconds to wait before rebooting, allowing the user time to save their work or cancel the restarting process if needed.
        
 -a\t Archive log files
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
        exit 50
        ;;
  esac
done

echo -e "Start: `date`" > $log
(( $auto_agree_with_licenses )) && agree_with_licenses=", accepting all licenses.\n"
echo -e "\nApplying updates to ($distribution) Version:${version_id}${agree_with_licenses}" | tee -a $log 

(( $refresh )) && {
    (( $verbosity )) && {
        echo -e "\nRefreshing Repositories" | tee -a $log
        echo -e "----------------------------------------" | tee -a $log
        zypper refresh | cut -d"'" -f2 | tee -a $log; err=${PIPESTATUS[0]}
        echo -e "----------------------------------------" | tee -a $log
    } || zypper refresh > /dev/null; err=$?
    
    (( $err != 0 )) && { echo "An error ( $err ) occurred when refreshing repositories, exiting script." >&2; exit 60; } 
    echo -e "Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories.\n" | tee -a $log 
}

if (( $verbosity )); then 
    zypper -v -n update $auto_agree_with_licenses | sed '/Unknown media type in type/d; s/^   //; /^Additional rpm output:/d; :a;N;$!ba;s/\n  / /g' | sed ':a;N;$!ba;s/\nRetrieving: /, /g' | tee -a $log
    err=${PIPESTATUS[0]}
else
    zypper -v -n update $auto_agree_with_licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //' | tee -a $log
    err=${PIPESTATUS[0]}
fi

(( $err != 0 )) && { echo "An error ( $err ) occurred with ( $script ) exiting script." >&2; exit 70; } 
(( $maximum_log_files )) && cd $logs && ls -tp | grep -v '/$' | tail -n +$((maximum_log_files+1)) | xargs -rd '\n' rm -- 

sed -i 's/   dracut:/\ndracut:/g; s/^CommitResult/\n\nCommitResult/; /^Checking for running processes/d; /^There are some running programs/d' $log

get_time_string $[$(date +%s) - $start_time]
echo -e "\nEnd: `date`\n\nTotal run time$time_string." | tee -a $log

(( $restart_timeout )) && { 
    get_time_string $restart_timeout
    
    wall -n "* * * Warnning restarting the system in$time_string * * *"
    if xhost > /dev/null 2>&1; then 
        xmessage "     * * * Warnning restarting the system in$time_string * * *     " -timeout $restart_timeout -button " Restart , Cancel " &> /dev/null
        err=$?
        (( $err == 0 )) || (( $err == 101 )) && {
            echo -e "1: System was restarted. ($(date))\n" >> $log
            init 6
        }
        echo | tee -a $log
        zypper ps -s | sed '/No processes using deleted files found/d' | tee -a $log
        echo -e "System restart was canceled. ($(date))\n" | tee -a $log
    else 
        sleep $restart_timeout
        echo -e "2: System was restarted. ($(date))\n" >> $log
        init 6
    fi
} || {
    if [[ $restart_timeout == 0 ]]; then
        if xhost > /dev/null 2>&1; then gui=3; else gui=4; fi
        echo -e "$gui: System was restarted. ($(date))\n" >> $log
        init 6
    fi
}

true
