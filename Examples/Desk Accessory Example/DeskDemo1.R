* File DeskDemo1.R

* This file is used to create a desk accessory resource (type 'DRVR') from
* a code resource (type 'TEMP', ID = 1), and place it in a Font D/A mover
* file.

* 1. Exec DeskDemo1.Job
* 2. Add the new desk accessory to a System file using Fond D/A Mover.
*    Make sure you try it first on a non-essential disk.
* 3. Boot the disk and find "New Accessory" in the Apple menu.

* The resource ID used for this example is 27.
* Font D/A mover will renumber this ID when this desk accessory is
* installed in a system file.
* (Desk accessories should be written to not depend on fixed ID numbers.)

DeskDemo1
DFILDMOV

TYPE DRVR = PROC
New Accessory ,27 (32)
DeskDemo1.Code


