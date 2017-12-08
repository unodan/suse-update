#!/bin/bash
###############################################################################
#  Script: suse-update.sh
# Purpose: Update openSUSE Linux with the latest packages.
#  Author: Dan Huckson, https://github.com/unodan
###############################################################################
true=1
version=3.0
start_time=`date`
script=$(basename -- "$0")
script_basename=`echo $script | cut -f1 -d.`
distribution=`cat /etc/*-release | grep ^NAME | cut -d'"' -f2`
distribution_version_id=`cat /etc/*-release | grep ^VERSION_ID | cut -d'"' -f2`
log_dir=/var/log/$script_basename && [ ! -d "$log_dir" ] && mkdir $log_dir
log_file=$log_dir/$script_basename.log
pid=`ps -A | grep -m 1 $script | sed 's/^ *//' | cut -d" " -f1`

(( EUID )) && {
    echo -e "Sorry ($script) requires root or sudo to run it.\nUse $script -h for more information.\n"
    exit 5
} || trap cancel_restart INT

function speak { 
    echo -e $1 | espeak -p 50 -s 160 > /dev/null 2>&1; return $?; 
}

function finish {
    finish_time=`date`
    set_time_string $((`date -d"$finish_time" +%Y%m%d%H%M%S` - `date -d"$start_time" +%Y%m%d%H%M%S`))
    echo -e "\nStarted:   $start_time\n\nFinished:  $finish_time\n\nTotal run time$time_string\n" | tee -a $log_file 
}

function is_installed { 
    rpm -q $1 > /dev/null 2>&1; return $?;
}

function cancel_restart { 
    (( audible_warning )) && speak "The scheduled system restart has been canceled"
    zypper ps -s | sed '/No processes using deleted files found/d' | tee -a $log_file
    finish
    echo -e "Restart canceled.\n" | tee -a $log_file
    exit 100
}

function set_time_string {
    unset hours minutes seconds 
    h=$(( $1 / 3600 )); m=$(( ($1 - h * 3600) / 60 )); s=$(( $1 % 60 )); 
    (( h )) && { (( h > 1 )) && hours=" $h hours" || hours=" 1 hour"; }
    (( m )) && { (( m > 1 )) && minutes=" $m minutes" || minutes=" 1 minute"; }
    (( s )) && { (( s > 1 )) && seconds=" $s seconds" || seconds=" 1 second"; }
    time_string=${hours}${minutes}${seconds}
    if [[ ! $time_string ]]; then time_string=" less than 1 second"; fi
    time_string=$time_string.
}

function install_package {
    package=$1;
    echo -e "\nInstalling package ($package)..." 
    zypper -n install $package > /dev/null 2>&1; err=$?
    
    error=0;
    (( err )) && {
        echo -e "\nError (install_package, $err), could not install package ($package)."; error=$true
    } || echo -e "Package ($package) was installed successfully!";
    
    return $error
}

if xhost > /dev/null 2>&1; then gui_mode=$true; fi

while getopts ":aflrvwk:s:h" opt; do
  case $opt in    
    a)  archive_logs=$true;;
    f)  force_restart=$true;;
    l)  auto_agree_with_licenses="--auto-agree-with-licenses"
        accept_licenses=", accepting all licenses."
        ;;
    r)  refresh_repostiories=$true;;
    v)  verbose=$true;;
    w)  audible_warning=$true;;
    s)  restart_timeout=$OPTARG
        if  ! [[ $restart_timeout =~ ^-?[0-9]+$ ]] || [ $restart_timeout -lt 0 ]; then
            echo -e "ERROR: Please enter a positive interger for the number of seconds to wait befrore restarting the system.\nUse $script -h for more information." >&2
            exit 10
        fi
        ;;
    k)  maximum_log_files=$OPTARG
        if [[ $maximum_log_files =~ ^-?[0-9]+$ ]] && [ $maximum_log_files -gt -1 ]; then
            log_file="$log_dir/$script_basename-`date +%Y%m%d-%H%M%S`.log"
        else
            if [ $maximum_log_files ]; then
                echo -e "ERROR: Please enter a positive interger for the maximum number of log files to keep.\nUse $script -h for more information." >&2
                exit 15
            fi
        fi
        ;;
    :)  echo -e "ERROR: Option [ -$OPTARG ] requires an argument.\nUse $script -h for more information." >&2; exit 20;;
   \?)  echo -e "ERROR: Invalid option [ -$OPTARG ]\nUse $script -h for more information." >&2; exit 22;;
    h)  echo -e "
Usage: $script [OPTION]...\n
This script will update $distribution with the latest packages from all enabled repositories. Enabled repositories can be refreshed and updates done none-interactively (automatically). Log files will be over written unless the -k option is used. The -k option accepts a positive integer for the number of log files to keep, older log files are deleted. The -a option must be used with the -k option, archiving happens when the number of log files equals the value supplied to the -k option. Once a log file is achieved it's deleted from the logs directory. After updating is done the system can be restart by using the -s option followed by the number of seconds to wait before restarting, allowing the user time to save their work or cancel the restarting process if needed. The system is only restarted if running processes are using deleted files that were updated during the update process. You can force the system restart by using the -f option. When the -w option is supplied, users are sent an audio beep and a spoken message letting them know that the system is going to be restarted. 

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
 
Example: $script -v -s300 -k30 
  output maximum information, restart the system 300 seconds after updates are finished and keep the latest 30 log files.\n"
        exit 24
        ;;
  esac
done

echo -e "$script, Version:$version, $start_time" | tee $log_file
echo -e "\nCommand: $0 $*" | tee -a $log_file 

(( archive_logs )) && (( maximum_log_files > 0 )) && {
    package=zip
    is_installed $package
    (( $? )) && { 
        install_package $package  
        (( $? )) && {
            echo -e "\nPlease install package $package or remove the -a option.\n" | tee -a $log_file 
            exit 40
        } 
    } 
}

(( audible_warning )) && {
    package=espeak
    is_installed $package
    (( $? )) && { 
        install_package $package
        (( $? )) && {
            echo -e "\nPlease install package $package or remove the -w option.\n" | tee -a $log_file 
            exit 45
        }
    }
}

(( archive_logs )) && (( maximum_log_files > 0 )) && {
    echo | tee -a $log_file
    echo -e "Log Archiving: Enabled" | tee -a $log_file
} || echo -e "Log Archiving: Disabled" | tee -a $log_file

echo -e "\nApplying updates to ($distribution) Version:${distribution_version_id}${accept_licenses}" | tee -a $log_file 

(( refresh_repostiories )) && {
    (( verbose )) && {
        echo -e "\nRefreshing Repositories" | tee -a $log_file
        echo -e "----------------------------------------" | tee -a $log_file
        zypper refresh | cut -d"'" -f2 | tee -a $log_file; err=${PIPESTATUS[0]}
        echo -e "----------------------------------------" | tee -a $log_file
    } || { zypper refresh > /dev/null; err=$?; }

    (( err )) && { echo "An error ( $err ) occurred when refreshing repositories, exiting script." | tee -a $log_file; exit 50; } 
    echo -e "\nRefreshed `zypper repos | grep -e '| Yes ' | cut -d'|' -f3 | wc -l` repositories." | tee -a $log_file 
}

echo | tee -a $log_file;

(( verbose )) && {
    echo -e "Please wait this could take awhile depending on the number of updates needed.\n"
    zypper -v -n update $auto_agree_with_licenses | 
     sed 's/^CommitResult  (/\nCommitResult  (/; s/dracut:/\ndracut:/g' | 
     sed ':a;N;$!ba;s/\n  / /g; s/^   //' | 
     sed ':a;N;$!ba;s/\nRetrieving: /, /g' | 
     sed ':a;N;$!ba;' | 
     sed '/Unknown media type in type/d; /^Verbosity: 1/d; /^Additional rpm output:/d; /^Entering non-interactive mode./d; /^Checking for running processes/d; /^There are some running programs/d' | tee -a $log_file
} || zypper -v -n update $auto_agree_with_licenses | grep -P "^Nothing to do|^CommitResult  \(|The following \d{1}" | sed 's/The following //; /package updates will NOT be installed:/d' | tee -a $log_file

err=${PIPESTATUS[0]}
(( err )) && { echo "An error ( $err ) occurred with ( $script ) exiting script." | tee -a $log_file; exit 55; } 

cd $log_dir
number_of_log_files=`ls $script_basename*.log 2> /dev/null | wc -l`

(( maximum_log_files > 0 )) && {
    (( archive_logs )) && (( number_of_log_files > maximum_log_files )) && {
        [ ! -d archive ] && mkdir archive; 
        ls -t *.log | tail -$maximum_log_files | xargs zip -q "archive/$script_basename-logs-`date +%Y%m%d-%H%M%S`.zip"
        ls -t *.log | tail -$maximum_log_files | xargs -rd '\n' rm --
    }
} 

(( ! archive_logs )) && (( maximum_log_files )) && (( number_of_log_files >= maximum_log_files )) && {
    ls -t $script_basename*.log | tail -$((number_of_log_files-maximum_log_files)) | xargs -rd '\n' rm --
}

if [[ ! -z ${maximum_log_files+x} ]] && (( ! maximum_log_files )); then rm -rf archive $script_basename*.log; fi

zypper ps -s | grep "The following running processes use deleted files" > /dev/null 2>&1; 

(( ! $? )) || (( force_restart )) && {
    (( restart_timeout )) && { 
        set_time_string $restart_timeout 
        warning_message="Attention: Restarting system in$time_string"
        
        cron="$( pstree -s $$ | grep -c cron )"
        (( cron )) && { 
            message+="$warning_message, you can cancel restarting from the console by entering, \"sudo kill $pid\""
        } || { 
            message="\n$warning_message To cancel the restart type [ctrl] c in the console"
            (( gui_mode )) && message+=", or click the cancel button in the popup dialog box." || message+="."
        }
        
        (( audible_warning )) && { 
            speaker-test -p 1 -t sine -f 400 -l 1 > /dev/null 2>&1
            echo -e "$message" 
            speak "$message"
        } || echo $message | wall -n 
        
        (( gui_mode )) && {
            echo -e "\n   $warning_message   \n" | xmessage  -timeout $restart_timeout -button " Restart , Cancel " -file -
            err=$?; (( err == 0 )) || (( err == 101 )) && restart_system=$true || cancel_restart
        } || {
            sleep $restart_timeout
            restart_system=$true
        }
    } || if [[ $restart_timeout == 0 ]]; then restart_system=$true; fi
 
    (( restart_system )) && { 
        finish
        echo -e "System restarted.\n" | tee -a $log_file
        shutdown -r +0; exit 0
    }
}
finish
