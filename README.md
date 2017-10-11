# suse-update
This script will update openSUSE tumbleweed with the newest packages.  <br>
Enabled repositories can be refreshed and updates done (automatically) none-interactively. <br>

Log files will be over written unless the -k option is used. The -k option accepts an integer for the number of logs to keep, older files are deleted.<br>

The -a option must be used with the -k option, it will archive files when value in -k option is met.  

You can restart the system after updating by using the -s option followed by the number of seconds to wait before rebooting, allowing the user time to cancel the restarting process if needed. <br>
 <br>
Example:
  suse-update.sh -v -s 300 -k 30 <br>
  output maximum information, restart the system 300 seconds after updates are finished and keep the latest 30 log files. <br>
   <br>
Use CRON to run this script at scheduled times.<br>
