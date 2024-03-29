
*
* This is the resource file for the example program called "Window"
*

* Call the program Window, and give it a creator of APPL and a type of ????.
Window.rsrc

*
* MENU Resource #1 specifies the menus used by the Window program.
* For proper support of the Desk accessories, the Apple menu
* should be first, and the Edit menu should be third.  The first 5 items
* in the Edit menu should be identical to those used below.  This makes 
* it possible for the desk accessories to share the Edit menu with your
* application.
*

Type MENU
  ,1
\14
 About This Example...
 (-

  ,2
File
  Quit


  ,3
Edit
  (Undo/Z
  (-
  Cut/X
  Copy/C
  Paste/V
  Clear

* Dialog Resource #1 specifies properties of the About box.  It points
* to Dialog Item List (DITL) Resource #1 as containing its items.

Type DLOG
  ,1
  
100 100 190 400
Visible  NoGoAway
1
0
1

* Dialog Item List Resource #1 specifies the items in the About box.
* By convention, the first item in an item list is the OK button.
* If there is a cancel button, it should be second.  This makes it
* easier to interpret the item number returned by the call to ModalDialog.

Type DITL
  ,1
3

Button
60 230 80 290
OK

StaticText
15 20 36 300
This sample program was written

StaticText
35 20 56 300
just to prove it could be done!

* WIND Resource #1 specifies the title, coordinates, and other status
* for the window in which editing takes place.  It is displayed by a
* call to GetNewWindow.

Type WIND
  ,1
A Sample
50 40 300 450
Visible NoGoAway
0
0


