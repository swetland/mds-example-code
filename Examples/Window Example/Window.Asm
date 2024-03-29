; File Window.Asm															MDM
;-------------------------------------------------------------------------
;       Macintosh 68000 Development System -- Programming Example
;-------------------------------------------------------------------------
; Written by Marc Russell Benioff and Ernie Beernink
; Spiritual guidance from Dan Cochran

; This application displays a window within which you can enter and edit
; text. Program control is through three menus: the Apple menu, the File 
; menu, and the Edit menu.

; The Apple menu has the standard desk accessories and an About feature.

; The File menu lets you quit the application.     

; The Edit menu lets you cut, copy, paste, and clear the text in the window
; or in the desk accessories.  Undo is provided for desk accesories only.
; Command key equivalents for undo, cut, copy, and paste are provided.
; Cutting and pasting between the application and the desk accessories is 
; not supported.  This requires use of the Scrap Manager.

; This program requires the use of the resources defined in Window.R .
; After the linker converts the Rel file to code, RMaker incorporates
; it and Window.R to create the application. Note that this is not the
; only way to combine resources and code. See the Sample Example
; for a different method.


;--------------------------------- INCLUDES -------------------------------

Include 	Traps.D		; Use System and ToolBox traps
Include 	ToolEqu.D	; Use ToolBox equates
;----------------------------- Use of Registers ---------------------------

; Operating System and Toolbox calls always preserve D3-D7, and A2-A4.

; Register use: A5-A7 are reserved by the system
;		  D1-D3, A0-A1 are unused
;		  D0 is used as a temp

ModifyReg	EQU	D4 	; D4 holds modifier bits from GetNextEvent 
MenuReg		EQU	D5	; D5 holds menu ID from MenuSelect,MenuKey
MenuItemReg	EQU	D6	; D6 holds item ID from MenuSelect,MenuKey
AppleHReg	EQU	D7	; D7 holds the handle to the Apple Menu

TextHReg	EQU	A2	; A2 is a handle to the TextEdit record
WindowPReg	EQU	A3	; A3 is a pointer to the editing window
EditHReg	EQU	A4	; A4 is a handle to the Edit menu

;--------------------------------- EQUATES --------------------------------

; These are equates associated with the resources
; for the Window example.

AppleMenu 	EQU	1	; First item in MENU resource
  AboutItem	EQU	1	; First item in Apple menu

FileMenu	EQU	2	; Second item in MENU resource
  QuitItem 	EQU	1	; First item in File menu

EditMenu	EQU	3	; Third item in MENU resource
  UndoItem	EQU	1	; Items in Edit menu
  CutItem	EQU	3	; (Item 2 is a line)
  CopyItem	EQU	4
  PasteItem	EQU	5
  ClearItem	EQU	6

AboutDialog	EQU	1	; About dialog is DLOG resource #1
ButtonItem	EQU	1	; First item in DITL used by DLOG #1
ASample		EQU	1	; Sample Window is WIND resource #1

; These are modifier bits returned by the GetNextEvent call.

activeBit	EQU	0	; Bit position of de/activate in Modify
cmdKey		EQU	8	; Bit position of command key in Modify
shiftKey	EQU	9	; Bit position of shift key in Modify

;---------------------------------- XDEFs ---------------------------------

; XDEF all labels that are to be symbolically displayed by debugger.

	XDEF		Start
	XDEF		InitManagers
	XDEF 		OpenResFile
	XDEF		SetupMenu
	XDEF		SetupWindow
	XDEF		SetupTextEdit
	XDEF		Activate
	XDEF		Deactivate
	XDEF		Update
	XDEF		KeyDown
	XDEF		MouseDown
	XDEF		SystemEvent
	XDEF		Content
	XDEF		Drag
	XDEF		InMenu
	XDEF		About
	
;------------------------------- Main Program -----------------------------

Start	

	BSR		InitManagers		; Initialize managers

; For development purposes, the resource file can be separated
; from the application, in which case you should enable the OpenResFile
; routine.
;	BSR		OpenResFile		; Open the resource file

	BSR		SetupMenu		; Build menus, draw menu bar
	BSR		SetupWindow		; Draw Editing Window
	BSR		SetupTextEdit		; Initialize TextEdit
	
EventLoop					; MAIN PROGRAM LOOP

	_SystemTask				; Update Desk Accessories
	; PROCEDURE	TEIdle (hTE:TEHandle);
	MOVE.L		TextHReg,-(SP)		; Get handle to text record
	_TEIdle					; blink cursor etc.
		
	; FUNCTION	GetNextEvent(eventMask: INTEGER; 
	;		VAR theEvent: EventRecord) : BOOLEAN
	CLR 		-(SP)			; Clear space for result
	MOVE 		#$0FFF,-(SP)		; Allow 12 low events
	PEA		EventRecord		; Place to return results
	_GetNextEvent				; Look for an event
	MOVE		(SP)+,D0		; Get result code
	BEQ  		EventLoop		; No event... Keep waiting
	BSR 		HandleEvent		; Go handle event
	BEQ		EventLoop		; Not Quit, keep going
	RTS					; Quit, exit to Finder

; Note: When an event handler finishes, it returns the Z flag set.  If 
;	Quit was selected, it returns with the Z flag clear.  An RTS is
;	guaranteed to close all files and launch the Finder.
	
;------------------------------- InitManagers -----------------------------

InitManagers

	PEA		-4(A5)			; Quickdraw's global area
	_InitGraf				; Init Quickdraw
	_InitFonts				; Init Font Manager
	MOVE.L		#$0000FFFF,D0		; Flush all events
	_FlushEvents
	_InitWindows				; Init Window Manager
	_InitMenus				; Init Menu Manager
	CLR.L	-(SP)				; No restart procedure
	_InitDialogs				; Init Dialog Manager
	_TEInit					; Init Text Edit
	_InitCursor				; Turn on arrow cursor
	RTS

;------------------------------- OpenResFile -----------------------------
;
; OpenResFile
;
; For development, one can keep the resources in a separate file. In this
; case, RMaker incorporates them into the main code, so that this routine
; is not used.
;
;	FUNCTION	OpenResFile (fileName: str255) : INTEGER;
;	CLR 		-(SP)			; Space for refNum
;	PEA		'Window.Rsrc'		; Name of resource file
;	_OpenResFile				; Open it
;	MOVE 		(SP)+,D0		; Discard refNum 
;	RTS
;
;------------------------------- SetupMenu ------------------------------

SetupMenu

; The names of all the menus and the commands in the menus are stored in the
; resource file.  The way you build a menu for an application is by reading
; each menu in from the resource file and then inserting it into the current
; menu bar.  Desk accessories are read from the system resource file and
; added to the Apple menu.

; Apple Menu Set Up.  

	; FUNCTION	GetMenu (menu ID:INTEGER): MenuHandle;
	CLR.L		-(SP)			; Space for menu handle
	MOVE 		#AppleMenu,-(SP)	; Apple menu resource ID 
	_GetRMenu				; Get menu handle 
	MOVE.L		(SP),AppleHReg		; Save for later comparison
	MOVE.L		(SP),-(SP)		; Copy handle for AddResMenu
	
	; PROCEDURE	InsertMenu (menu:MenuHandle; beforeID: INTEGER);
	CLR 		-(SP)			; Append to menu
	_InsertMenu				; Which is currently empty

; Add Desk Accessories Into Apple menu (Apple menu handle already on stack)

	; PROCEDURE	AddResMenu (menu: MenuHandle; theType: ResType);
	MOVE.L		#'DRVR',-(SP)		; Load all drivers 
	_AddResMenu				; And add to Apple menu

; File Menu Set Up

	; FUNCTION	GetMenu (menu ID:INTEGER): MenuHandle;
	CLR.L		-(SP)			; Space for menu handle
	MOVE 		#FileMenu,-(SP)		; File Menu Resource ID 
	_GetRMenu				; Get File menu handle

	; PROCEDURE	InsertMenu (menu:MenuHandle; beforeID: INTEGER);
	CLR 		-(SP)			; Append to list
	_InsertMenu				; After Apple menu

; Edit Menu Set Up

	; FUNCTION	GetMenu (menu ID:INTEGER): MenuHandle;
	CLR.L		-(SP)			; Space for menu handle
	MOVE 		#EditMenu,-(SP)		; Edit menu resource ID
	_GetRMenu				; Get handle to menu
	MOVE.L		(SP),EditHReg		; Save for later
					        ; Leave on stack for Insert
	; PROCEDURE	InsertMenu (menu:MenuHandle; beforeID: INTEGER);
	CLR 		-(SP)			; Append to list
	_InsertMenu				; After File menu
	_DrawMenuBar				; Display the menu bar
	RTS
	
;------------------------------ SetupWindow ------------------------------

SetupWindow

; The window parameters are stored in our resource file.  Read them from 
; the file and draw the window, then set the port to that window.  Note that
; the window parameters could just as easily have been set using the call
; NewWindow, which doesn't use the resource file.

	; FUNCTION	GetNewWindow (windowID: INTEGER; wStorage: Ptr; 
	;			      behind: WindowPtr) : WindowPtr;
	CLR.L		-(SP)			; Space for window pointer
	MOVE 		#ASample,-(SP)		; Resource ID for window
	PEA		WindowStorage(A5)	; Storage for window
	MOVE.L		#-1,-(SP)		; Make it the top window
	_GetNewWindow				; Draw the window
	MOVE.L		(SP),WindowPReg		; Save for later 
	
	; PROCEDURE	SetPort (gp: GrafPort)	; Pointer still on stack
	_SetPort				; Make it the current port
	RTS
	
;---------------------------- SetupTextEdit --------------------------

SetupTextEdit

; Create a new text record for TextEdit, and define the window within which
; it will be displayed.  Note that if the window boundaries are changed in
; the resource file, DestRect and ViewRect will have to be changed too.

	; PROCEDURE	TENew (destRect,viewRect: Rect): TEHandle;
	CLR.L		-(SP)			; Space for text handle 
	PEA		DestRect		; DestRect Rectangle
	PEA		ViewRect		; ViewRect Rectangle
	_TENew					; New Text Record
	MOVE.L		(SP)+,TextHReg		; Save text handle
	RTS
	
;------------------------- Event Handling Routines -----------------------

HandleEvent

; Use the event number as an index into the Event table.  These 12 events
; are all the things that could spontaneously happen while the program is
; in the main loop.

	MOVE		Modify,ModifyReg	; More useful in a reg
	MOVE		What,D0			; Get event number
	ADD		D0,D0			; *2 for table index
	MOVE		EventTable(D0),D0	; Point to routine offset
	JMP		EventTable(D0)		; and jump to it

EventTable	

	DC.W		NextEvent-EventTable	; Null Event (Not used)
	DC.W		MouseDown-EventTable	; Mouse Down
	DC.W		NextEvent-EventTable	; Mouse Up (Not used)
	DC.W		KeyDown-EventTable	; Key Down
	DC.W		NextEvent-EventTable	; Key Up (Not used)
	DC.W		KeyDown-EventTable	; Auto Key
	DC.W		Update-EventTable	; Update 
	DC.W		NextEvent-EventTable	; Disk (Not used) 
	DC.W		Activate-EventTable	; Activate
	DC.W		NextEvent-EventTable	; Abort (Not used)
	DC.W		NextEvent-EventTable	; Network (Not used)
	DC.W		NextEvent-EventTable	; I/O Driver (Not used)
	
;--------------------------- Event Actions ---------------------------

Activate		

; An activate event is posted by the system when a window needs to be
; activated or deactivated.  The information that indicates which window
; needs to be updated was returned by the NextEvent call.

	CMP.L		Message,WindowPReg	; Was it our window?
	BNE 		NextEvent		; No, get next event
	BTST		#ActiveBit,ModifyReg 	; Activate?
	BEQ 		Deactivate		; No, go do Deactivate

; To activate our window, activate TextEdit, and disable Undo since we don't
; support it.  Then set our window as the port since an accessory may have
; changed it.  This activate event was generated by SelectWindow as a result
; of a click in the content region of our window.  If the window had scroll
; bars, we would do ShowControl and HideControl here too.

	; PROCEDURE	TEActivate (hTE: TEHandle);
	MOVE.L		TextHReg,-(SP)		; Move Text Handle To Stack
	_TEActivate				; Activate Text

	; PROCEDURE DisableItem (menu:MenuHandle; item:INTEGER);
	MOVE.L	EditHReg,-(SP)			; Get handle to the menu
	MOVE		#UndoItem,-(SP)		; Enable 1st item (undo)
	_DisableItem

SetOurPort					; used by InAppleMenu

	; PROCEDURE 	SetPort (gp: GraphPort) ; Set the port to us, since
	MOVE.L		WindowPReg,-(SP)	; an accessory might have
	_SetPort				; changed it.

NextEvent	

	MOVEQ #0,D0				; Say that it's not Quit
	RTS					; return to EventLoop
		
Deactivate

; To deactivate our window, turn off TextEdit, and Enable undo for the desk
; accessories (which must be active instead of us).

	; PROCEDURE	TEDeActivate (hTE: TEHandle)
	MOVE.L		TextHReg,-(SP)		; Get Text Handle
	_TeDeActivate				; Un Activate Text

	; PROCEDURE EnableItem (menu:MenuHandle; item:INTEGER);
	MOVE.L		EditHReg,-(SP)		; Get handle to the menu
	MOVE		#UndoItem,-(SP)		; Enable 1st item (undo)
	_EnableItem
	BRA 		NextEvent		; Go get next event
	
Update	

; The window needs to be redrawn.  Erase the window and then call TextEdit
; to redraw it.

	; PROCEDURE	BeginUpdate (theWindow: WindowPtr);
	MOVE.L		WindowPReg,-(SP)	; Get pointer to window
	_BeginUpDate				; Begin the update

	; EraseRect (rUpdate: Rect);
	PEA		ViewRect		; Erase visible area
	_EraseRect
	
	; TEUpdate (rUpdate: Rect; hTE: TEHandle);
	PEA		ViewRect		; Get visible area
	MOVE.L		TextHReg,-(SP)		; and handle to text 
	_TEUpdate				; then update the window

	; PROCEDURE	EndUpdate (theWindow: WindowPtr);
	MOVE.L		WindowPReg,-(SP)	; Get pointer to window
	_EndUpdate				; and end the update
	BRA 		NextEvent		; Go get next event
	
KeyDown	

; A key was pressed.  First check to see if it was a command key.  If so, 
; go do it.  Otherwise pass the key to TextEdit.

	BTST		#CmdKey,ModifyReg	; Is command key down?
	BNE 		CommandDown		; If so, handle command key

	; PROCEDURE	TEKey (key: CHAR; hTE: TEHandle);
	MOVE 		Message+2,-(SP)		; Get character
	MOVE.L		TextHReg,-(SP)		; and text record
	_TEKey					; Give char to TextEdit
	BRA 		NextEvent		; Go get next event
	
CommandDown	

; The command key was down.  Call MenuKey to find out if it was the command 
; key equivalent for a menu command, pass the menu and item numbers to Choices.

	; FUNCTION	MenuKey (ch:CHAR): LongInt;
	CLR.L		-(SP)			; Space for Menu and Item
	MOVE 		Message+2,-(SP)		; Get character
	_MenuKey				; See if it's a command
	MOVE		(SP)+,MenuReg		; Save Menu
	MOVE		(SP)+,MenuItemReg	; and Menu Item
	BRA 		Choices			; Go dispatch command


;--------------------Mouse Down Events And Their Actions----------------------

MouseDown	

; If the mouse button was pressed, we must determine where the click
; occurred before we can do anything.  Call FindWindow to determine
; where the click was; dispatch the event according to the result.

	; FUNCTION	FindWindow (thePt: Point; 
	;		            VAR whichWindow: WindowPtr): INTEGER;
	CLR 		-(SP)			; Space for result
	MOVE.L		Point,-(SP)		; Get mouse coordinates
	PEA		WWindow			; Event Window
	_FindWindow				; Who's got the click? 
	MOVE 		(SP)+,D0		; Get region number
	ADD		D0,D0			; *2 for index into table
	MOVE		WindowTable(D0),D0	; Point to routine offset
	JMP		WindowTable(D0)		; Jump to routine
	
WindowTable

	DC.W		NextEvent-WindowTable	; In Desk (Not used)
	DC.W		InMenu-WindowTable	; In Menu Bar
	DC.W		SystemEvent-WindowTable ; System Window
	DC.W		Content-WindowTable	; In Content
	DC.W		Drag-WindowTable	; In Drag
	DC.W		NextEvent-WindowTable	; In Grow (Not used)
	DC.W		NextEvent-WindowTable	; In Go Away (Not used)

SystemEvent	

; The mouse button was pressed in a system window.  SystemClick calls the 
; appropriate desk accessory to handle the event.

	; PROCEDURE	SystemClick (theEvent: EventRecord;
	;		             theWindow: WindowPtr);
	PEA		EventRecord		; Get event record
	MOVE.L		WWindow,-(SP)		; and window pointer
	_SystemClick				; Let the system do it
	BRA 		NextEvent		; Go get next event
	
Content	

; The click was in the content area of a window.  If our window was in 
; front, then call Quickdraw to get local coordinates, then pass the 
; coordinates to TextEdit. We also determine whether the shift key was 
; pressed so TextEdit can do shift-clicking. If our window wasn't in 
; front, move it to the front, but don't process click.

	CLR.L		-(SP)			; clear room for result
	_FrontWindow				; get FrontWindow
	MOVE.L		(SP)+,D0		; Is front window pointer
	CMP.L		WindowPReg,D0		; same as our pointer?
	BEQ.S 	@1				; Yes, call TextEdit

; We weren't active, select our window.  This causes an activate event.

	; PROCEDURE	SelectWindow (theWindow: WindowPtr);
	MOVE.L		WWindow,-(SP)		; Window Pointer To Stack
	_SelectWindow				; Select Window
	BRA 		NextEvent		; and get next event

@1	

; We were active, pass the click (with shift) to TextEdit.

	; PROCEDURE	GlobalToLocal (VAR pt:Point);
	PEA		Point			; Mouse Point
	_GlobalToLocal				; Global To Local

	; PROCEDURE 	TEClick (pt: Point; extend: BOOLEAN; hTE: TEHandle);
	MOVE.L		Point,-(SP)		; Mouse Point (GTL)
	BTST		#shiftKey,ModifyReg	; Is shift key down?
	SNE		D0			; True if shift down
	
; Note:  We want the boolean in the high byte, so use MOVE.B.  The 68000
; pushes an extra, unused byte on the stack for us.

	MOVE.B		D0,-(SP)		
	MOVE.L		TextHReg,-(SP)		; Identify Text
	_TEClick				; TEClick
	BRA 		NextEvent		; Go get next event
	
Drag

; The click was in the drag bar of the window.  Draggit.

	; DragWindow (theWindow:WindowPtr; startPt: Point; boundsRect: Rect);
	MOVE.L		WWindow,-(SP)		; Pass window pointer
	MOVE.L		Point,-(SP)		; mouse coordinates
	PEA		Bounds			; and boundaries
	_DragWindow				; Drag Window
	BRA 		NextEvent		; Go get next event
	
InMenu	

; The click was in the menu bar.  Determine which menu was selected, then
; call the appropriate routine.

	; FUNCTION	MenuSelect (startPt:Point) : LongInt;
	CLR.L		-(SP)			; Get Space For Menu Choice
	MOVE.L		Point,-(SP)		; Mouse At Time Of Event
	_MenuSelect				; Menu Select
	MOVE 		(SP)+,MenuReg		; Save Menu
	MOVE		(SP)+,MenuItemReg	; and Menu Item

; On entry to Choices, the resource ID of the Menu is saved in the low
; word of a register, and the resource ID of the MenuItem in another.
; The routine MenuKey, used when a command key is pressed, returns the same 
; info.

Choices						; Called by command key too

	CMP 		#AppleMenu,MenuReg	; Is It In Apple Menu?
	BEQ 		InAppleMenu		; Go do Apple Menu
	CMP 		#FileMenu,MenuReg	; Is It In File Menu?
	BEQ 		InFileMenu		; Go do File Menu
	CMP 		#EditMenu,MenuReg	; Is It In Edit Menu?
	BEQ 		InEditMenu		; Go do Edit Menu
	
ChoiceReturn

	BSR		UnHiliteMenu		; Unhighlight the menu bar
	BRA 		NextEvent		; Go get next event
		
InFileMenu

; If it was in the File menu, just check for Quit since that's all there is.

	CMP		#QuitItem,MenuItemReg	; Is It Quit?
	BNE.S 		ChoiceReturn		; No, Go get next event
	BSR		UnHiliteMenu		; Unhighlight the menu bar
	MOVE		#-1,D0			; say it was Quit
	RTS
	
InEditMenu

; First, call SystemEdit.  If a desk accessory is active that uses the Edit
; menu (such as the Notepad) this lets it use our menu.
; Decide whether it was cut, copy, paste, or clear.  Ignore Undo since we
; didn't implement it.

	BSR		SystemEdit		; Desk accessory active?
	BNE.S 		ChoiceReturn		; Yes, SystemEdit handled it
	CMP		#CutItem,MenuItemReg	; Is It Cut?
	BEQ 		Cut			; Yes, go handle it
	CMP		#CopyItem,MenuItemReg	; Is it Copy?
	BEQ 		Copy			; Yes, go handle it
	CMP		#PasteItem,MenuItemReg	; Is it Paste?
	BEQ 		Paste			; Yes, go handle it
	CMP		#ClearItem,MenuItemReg	; Is it Clear?
	BEQ 		ClearIt			; Yes, go handle it
	BRA.S 		ChoiceReturn		; Go get next event
	
InAppleMenu

; It was in the Apple menu.  If it wasn't About, then it must have been a 
; desk accessory.  If so, open the desk accessory.  

	CMP		#AboutItem,MenuItemReg	; Is It About?
	BEQ 		About			; If So Goto About...
	
	; PROCEDURE	GetItem (menu: MenuHandle; item: INTEGER; 
	;                        VAR itemString: Str255);
	MOVE.L		AppleHReg,-(SP)		; Look in Apple Menu
	MOVE 		MenuItemReg,-(SP)	; What Item Number?
	PEA		DeskName		; Get Item Name
	_GetItem				; Get Item

	; FUNCTION	OpenDeskAcc (theAcc: Str255) : INTEGER;
	CLR 		-(SP)			; Space For Opening Result
	PEA		DeskName		; Open Desk Acc
	_OpenDeskAcc				; Open It
	MOVE 		(SP)+,D0		; Pop result
	
GoSetOurPort

	BSR 		SetOurPort		; Set port to us 
	BRA.S		ChoiceReturn		; Unhilite menu and return
						
;--------------------------- Text Editing Routines ------------------------

Cut						; CUT

	; PROCEDURE	TECut (hTE: TEHandle);
	MOVE.L		TextHReg,-(SP)		; Identify Text
	_TECut					; Cut it and copy it
	BRA.S 		ChoiceReturn		; Go get next event

Copy						; COPY

	; PROCEDURE	TECopy (hTE: TEHandle);
	MOVE.L		TextHReg,-(SP)		; Identify Text
	_TECopy					; Copy text to clipboard
	BRA.S 		ChoiceReturn		; Go get next event

Paste						; PASTE

	; PROCEDURE	TEPaste (hTE: TEHandle);
	MOVE.L	TextHReg,-(SP)			; Identify Text
	_TEPaste				; Paste
	BRA.S 	ChoiceReturn			; Go get next event

ClearIt						;CLEAR

	; PROCEDURE	TEDelete (hTE: TEHandle);
	MOVE.L		TextHReg,-(SP)		; Point to text
	_TEDelete				; Clear without copying
	BRA.S 		ChoiceReturn		; Go get next event

; SystemEdit does undo, cut, copy, paste, and clear for desk accessories.
; It returns False (BEQ) if the active window doesn't belong to a
; desk accessory.

SystemEdit
	
	; FUNCTION	SystemEdit (editCmd:INTEGER): BOOLEAN;
	CLR 		-(SP)			; Space for result
	MOVE		MenuItemReg,-(SP)	; Get item in Edit menu
	SUBQ		#1,(SP)			; SystemEdit is off by 1
	_SysEdit				; Do It 
	MOVE.B 	(SP)+,D0			; Pop result
	RTS 					; BEQ if NOT handled

UnhiliteMenu
	
	; PROCEDURE	HiLiteMenu (menuID: INTEGER);
	CLR		-(SP)			; All Menus
	_HiLiteMenu				; UnHilite Them All
	RTS
	

;---------------------------------Misc Routines---------------------------

About

; Call GetNewDialog to read the dialog box parameters from the resource file
; and display the box.  Set the port to the box, then wait for the proper 
; click or keypress.  Finally, close the dialog box and set the pointer to us.

	; FUNCTION	GetNewDialog (dialogID: INTEGER; dStorage: Ptr; 
	;                             behind: WindowPtr) : DialogPtr
	CLR.L		-(SP)			; Space For dialog pointer
	MOVE 		#AboutDialog,-(SP)	; Identify dialog rsrc #
	PEA		DStorage		; Storage area
	MOVE.L		#-1,-(SP)		; Dialog goes on top
	_GetNewDialog				; Display dialog box
	MOVE.L		(SP),-(SP)		; Copy handle for Close

	; PROCEDURE	SetPort (gp: GrafPort)	; Handle already on stack
	_SetPort				; Make dialog box the port

	; PROCEDURE	TEDeActivate (hTE: TEHandle)
	MOVE.L		TextHReg,-(SP)		; Identify Text
	_TEDeActivate				; Deactivate Text

WaitOK

	; PROCEDURE	ModalDialog (filterProc: ProcPtr; 
	;			     VAR itemHit: INTEGER);
	CLR.L		-(SP)			; Clear space For handle
	PEA		ItemHit			; Storage for item hit
	_ModalDialog				; Wait for a response

	MOVE		ItemHit,D0		; Look to see what was hit
	CMP		#ButtonItem,D0		; was it OK?
	BNE  		WaitOK			; No, wait for OK
	
	; PROCEDURE	CloseDialog (theDialog: DialogPtr);
	_CloseDialog				; Handle already on stack
	 BRA		GoSetOurPort		; Set port to us and return
	 
; ---------------------------- Data Starts Here -------------------------

EventRecord					; NextEvent's Record
 What: 			DC 	0		; Event number
 Message:		DC.L	0		; Additional information
 When:			DC.L	0		; Time event was posted 
 Point:			DC.L	0		; Mouse coordinates
 Modify:		DC 	0		; State of keys and button
 WWindow:		DC.L	0		; Find Window's Result

DStorage		DCB.W	DWindLen,0	; Storage For Dialog
DeskName		DCB.W	16,0		; Desk Accessory's Name
Bounds			DC 	28,4,308,508	; Drag Window's Bounds
ViewRect		DC 	5,4,245,405	; Text Record's View Rect
DestRect		DC 	5,4,245,405	; Text Record's Dest Rect
ItemHit			DC	0		; Item clicked in dialog

;------------------------- Nonrelocatable Storage -----------------------

; Variables declared using DS are placed in a global space relative to
; A5.  When these variables are referenced, A5 must be explicitly mentioned.

WindowStorage		DS.W	WindowSize	; Storage for Window

End
