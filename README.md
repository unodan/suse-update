# suse-update
This script will update openSUSE tumbleweed with the newest packages. The script will refresh all enabled repositories and preform a system update none-interactively (automatically).

You can setup CRON to run this script once a day if you like. Each time the script is ran though it over writes the log file from the previous run. Logs are located at /var/log/suse-update.log 
