# suse-update
This script will update openSUSE tumbleweed with the newest packages. 
All enabled repositories will be refreshed before doing any updates none-interactively (automatically).
Log files will be over writen unless the -k switch is used.
After the script is finished it reboots the system unless the -r switch is used.

Use CRON to run this script at scheduled times. 

For example put the line below in /etc/crontab it will run the script a 3am and keep logs files for each run.
"0 3 * * * root /home/user/scripts/suse-update.sh -k"
