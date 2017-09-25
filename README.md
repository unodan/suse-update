# suse-update
This script will update openSUSE tumbleweed with the newest packages. 
All enabled repositories will be refreshed and updates done (automatically) none-interactively.
Log files will be over writen unless the -k switch is used.
You can reboot the system after updating by using -r option.

Example:
  suse-update.sh -vrk 30  output maximum info, reboot and keep the latest 30 log files.
  
Use CRON to run this script at scheduled time. 
"0 3 * * * root /home/user/scripts/suse-update.sh -vrk 30"
