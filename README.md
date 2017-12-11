# suse-update
This script will update openSUSE Leep/Tumbleweed with the newest packages.  <br>
Enabled repositories can be refreshed and updates done none-interactively (automatically). <br><br>
Log files will be over written unless the -k option is used. The -k option accepts a positive integer for the number of log files to keep, older log files are deleted.<br><br>
The -a option must be used with the -k option, archiving happens when the number of log files equals the value supplied to the -k option. Once a log file is achieved it's deleted from the logs directory.<br><br>
After updating is done the system can be restart by using the -s option followed by the number of seconds to wait before restarting, allowing the user time to save their work or cancel the restarting process if needed. The system is only restarted if running processes are using deleted files that were updated during the update process.<br><br>
You can force the system restart by using the -f option. <br><br>
When the -w option is supplied, users are sent an audio beep and a spoken message letting them know that the system is going to be restarted. <br><br><br>
Example: $script -v -s300 -k30 
  output maximum information, restart the system 300 seconds after updates are finished and keep the latest 30 log files.\n"<br><br><br><br>
