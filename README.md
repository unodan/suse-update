# suse-update
This script will update openSUSE tumbleweed with the newest packages.  <br>
Enabled repositories can be refreshed and updates done (automatically) none-interactively. <br>

Log files will be over written unless the -k option is used. The -k option accepts an integer for the number of logs to keep, older files are deleted<br>

The -a option must be used with the -k option, it will archive files when value in -k option is met.  

You can restart the system after updating by using -s option followed by the number of seconds to wait before rebooting, allowing the use to cancel the restarting process if need be. <br>
 <br>
Example:
  suse-update.sh -vrk 30 <br>
  output maximum info, reboot and keep the latest 30 log files. <br>
   <br>
Use CRON to run this script at scheduled time.<br>
