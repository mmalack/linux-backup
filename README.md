
# linux-backup

This script can be used to back up directories and databases of a Linux system.

### There are two options

1. Single backup  
   To do this, create a .conf file with the same name as the sh script.  
   This is then automatically read in and processed.

2. Multi backup  
   A folder can be created to back up several projects at the same time.  
   The same name as the script must also be used here.  
   Any number of .conf files can then be stored in this folder.  
   These are then processed one after the other.

It is also possible to exclude directories.  
To do this, an .excludes file with the same name as the .conf file must be created.

> Example  
> my_backup.conf, my_backup.excludes
