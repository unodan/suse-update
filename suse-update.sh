#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE Linux with the latest packages.
#  Author: Dan Huckson, https://github.com/unodan
###############################################################################
version=2.18
trap cancel_restart INT

function speak {
    echo -e $1 | espeak -p 50 -s 160 > /dev/null 2>&1
}

function cancel_restart { 
    (( $audible_warning )) && speak "The scheduled system restart has been canceled."
    get_time_string $[$(date +%s) - $start_time]
    zypper ps -s | sed '/No processes using deleted files found/d' | tee -a $log_file
    echo -e "Restart Canceled: `date`\n\nTotal run time$time_string.\n" | tee -a $log_file
    exit 100
}

function get_time_string {
    unset time_string hours minutes seconds
    h=$(( $1 / 3600 )); m=$(( ($1 - h * 3600) / 60 )); s=$(( $1 % 60 )); 
    (( $h > 0 )) && { (( $h > 1 )) && hours=" $h hours" || hours=" 1 hour"; }
    (( $m > 0 )) && { (( $m > 1 )) && minutes=" $m minutes" || minutes=" 1 minute"; }
    (( $s > 0 )) && { (( $s > 1 )) && seconds=" $s seconds" || seconds=" 1 second"; }
    time_string=${hours}${minutes}${seconds}
}

true=1
date=`date`
start_time=$(date +%s)
script=$(basename -- "$0")
script_basename=`echo $script | cut -f1 -d.`
distribution=`cat /etc/*-release | grep ^NAME | cut -d'"' -f2`
version_id=`cat /etc/*-release | grep ^VERSION_ID | cut -d'"' -f2`
log_dir=/var/log/$script_basename && [ ! -d "$log_dir" ] && mkdir $log_dir
log_file=$log_dir/$script_basename.log
if xhost > /dev/null 2>&1; then gui_mode=$true; fi

while getopts ":aflrvwk:s:h" opt; do
  case $opt in    
    a)  number_of_log_files=`ls $log_dir/$script_basename*.log 2> /dev/null | wc -l`
    
        (( $maximum_log_files )) && (( $maximum_log_files > 0 )) && (( $number_of_log_files >= $maximum_log_files )) && {
            [ ! -d $log_dir/archive ] && mkdir $log_dir/archive; 
            cd $log_dir && ls *.log | xargs zip -q "archive/$script_basename-logs-`date +%Y%m%d-%H%M%S`.zip" && rm *.log
        }
        ;;
    f)  force_restart=$true;;
    l)  auto_agree_with_licenses="--auto-agree-with-licenses";;
    r)  refresh=$true;;
    v)  verbose=$true;;
    w)  audible_warning=$true
        rpm -q espeak > /dev/null 2>&1
        (( $? )) && {
            echo -e "\nWARNING: The -w option requires that the espeak package be installed.\n" 
            echo -n "Attempting to install package espeak, " 
            zypper -n install espeak > /dev/null 2>&1
            (( $? )) && {
                echo -e "\nError installing the package espeak, remove the -w option or install the package espeak."
                exit 5
            } || { echo "package was installed successfully!"; echo; }
        } 
        ;;
    k)  maximum_log_files=$OPTARG    
    
        ! [[ $maximum_log_files =~ ^[0-9]+$ ]] && {
            echo -e "ERROR: Please enter a positive interger for the maximum number of log files to keep.\nUse $script -h for more information." >&2
            exit 10
        }
        log_file="$log_dir/$script_basename-`date +%Y%m%d-%H%M%S`.log"
        ;;
    s)  restart_timeout=$OPTARG
        
        ! [[ $restart_timeout =~ ^[0-9]+$ ]] && {
            echo -e "ERROR: Please enter a positive interger for the number of seconds to wait befrore restarting the system.\nUse $script -h for more information." >&2
            exit 20
        }
        ;;
    :)  echo -e "ERROR: Option [ -$OPTARG ] requires an argument.\nUse $script -h for more information." >&2; exit 30;;
   \?)  echo -e "ERROR: Invalid option [ -$OPTARG ]\nUse $script -h for more information." >&2; exit 40;;
    h)  echo -e "
Usage: $script [OPTION]...\n
This script will update $distribution with the latest packages from all the enabled repositories. Enabled repositories can be refreshed and updates done none-interactively (automatically). Log files will be over written unless the -k option is used. The -k option accepts a positive integer for the number of log files to keep, older log files are deleted. The -a option must be used with the -k option, archiving happens when the number of log files equals the value supplied to the -k option. Once a log file is achieved it's deleted from the logs directory. After updating is done the system can be restart by using the -s option followed by the number of seconds to wait before restarting, allowing the user time to save their work or cancel the restarting process if needed. The system is only restarted if running processes are using deleted files that were updated during the update process. You can force the system restart by using the -f option. When the -w option is supplied, users are sent an audio beep and a spoken message letting them know that the system is going to be restarted. 

 -a\t Archive log files
 -f\t Force restart after update
 -l\t Auto agree with licenses
 -r\t Refresh all enabled repostiories
 -v\t Verbosity (show maximum information)
 -w\t Enable audio warnings
   \t  (option requires that the espeak package be installed)
 -k\t Maximum number of log files
   \t  (this option must be supplied with the maximum number of log files to keep)
 -s\t Restart system after updates (if needed)
   \t  (this option must be supplied with the number of seconds to wait before restarting the system)
 -h\t Display this help message
 
Example: $script -v -s 300 -k 30 
  output maximum information, restart the system 300 seconds after updates are finished and keep the latest 30 log files."
        exit 50
        ;;
  esac
done

rm -f $log_file
echo -e "$script, Version:$version, $date" | tee $log_file
(( $auto_agree_with_licenses )) && agree_with_licenses=", accepting all licenses.\n"
echo -e "\nApplying updates to ($distribution) Version:${version_id}${agree_with_licenses}\n" | tee -a $log_file 

(( $refresh )) && {
    (( $verbose )) && {
        echo -e "Refreshing Repositories" | tee -a $log_file
        echo -e "----------------------------------------" | tee -a $log_file
        zypper refresh | cut -d"'" -f2 | tee -a $log_file; err=${PIPESTATUS[0]}
        echo -e "----------------------------------------" | tee -a $log_file
    } || { zypper refresh > /dev/null; err=$?; }
    
    (( $err )) && { echo "An error ( $err ) occurred when refreshing repositories, exiting script." >&2; exit 60; } 
    echo -e "Refreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories.\n" | tee -a $log_file 
}

(( $verbose )) && {
    echo -e "Please wait this could take awhile depending on the number of updates currently needed!\n"
    zypper -v -n update $auto_agree_with_licenses | 
     sed 's/^   //; s/   dracut:/\ndracut:/g; s/^CommitResult/\nCommitResult/; :a;N;$!ba;s/\n  / /g' | 
     sed ':a;N;$!ba;s/\nRetrieving: /, /g' | 
     sed ':a;N;$!ba;s/Additional rpm output:\n\n\n//g' | 
     sed '/Unknown media type in type/d; /^Verbosity: 1/d; /^Entering non-interactive mode./d; /^Checking for running processes/d; /^There are some running programs/d' | tee -a $log_file
     
    echo -e "\n" | tee -a $log_file
} || zypper -v -n update $auto_agree_with_licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //; /package updates will NOT be installed:/d' | tee -a $log_file
    
err=${PIPESTATUS[0]}
(( $err != 0 )) && { echo "An error ( $err ) occurred with ( $script ) exiting script." >&2; exit 70; } 
(( $maximum_log_files )) && cd $log_dir && ls -tp | grep -v '/$' | tail -n +$((maximum_log_files+1)) | xargs -rd '\n' rm -- 

echo -e "\nStarted:  $date\n\nFinished: `date`\n" | tee -a $log_file

zypper ps -s | grep "The following running processes use deleted files" > /dev/null 2>&1

(( ! $? )) || (( $force_restart )) && {
    (( $restart_timeout )) && { 
        get_time_string $restart_timeout 
        warning_message="Attention: Restarting system in$time_string"
        
        tty > /dev/null
        (( $? == 1 )) && { 
            pid=`ps -A | grep -m 1 $script | sed 's/^ *//' | cut -d" " -f1`   
            message+="$warning_message, you can cancel restarting from the console by entering, \"sudo kill $pid\""
        } || { 
            message="$warning_message, to cancel the scheduled restart type [ctrl] c in the console"
            (( $gui_mode )) && message+=" or click the cancel button in the popup dialog box." || message+="."
        }
        
        (( $audible_warning )) && { 
            speaker-test -p 1 -t sine -f 400 -l 1 > /dev/null 2>&1
            echo -e "$message" | wall -n; speak "$message"
        } || echo -e "$message" | wall -n 
        
        (( $gui_mode )) && {
            echo -e "\n   $warning_message.   \n" | xmessage  -timeout $restart_timeout -button " Restart , Cancel " -file -
            err=$?; (( $err == 0 )) || (( $err == 101 )) && restart_system=$true || cancel_restart
        } || {
            sleep $restart_timeout
            restart_system=$true
        }
    } || if [[ $restart_timeout == 0 ]]; then restart_system=$true; fi

    get_time_string $[$(date +%s) - $start_time]

    (( $restart_system )) && { 
        (( $audible_warning )) && speak "This system is going to restart now." 
        echo -e "Restarted: `date`\n\nTotal run time$time_string.\n" | tee -a $log_file
        init 6
    } || { echo -e "Total run time$time_string.\n" | tee -a $log_file; exit 0; }
} 

zypper ps -s | sed '/No processes using deleted files found/d' | tee -a $log_file
get_time_string $[$(date +%s) - $start_time]
echo -e "Total run time$time_string.\n" | tee -a $log_file
