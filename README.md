# suse-update
This script will update openSUSE tumbleweed with the newest packages.  <br>
All enabled repositories will be refreshed and updates done (automatically) none-interactively. <br>
Log files will be over writen unless the -k switch is used. <br>
You can reboot the system after updating by using -r option. <br>
 <br>
Example:
  suse-update.sh -vrk 30 <br>
  output maximum info, reboot and keep the latest 30 log files. <br>
   <br>
Use CRON to run this script at scheduled time.<br>
0 3 * * * root /home/user/scripts/suse-update.sh -vrk 30<br>
