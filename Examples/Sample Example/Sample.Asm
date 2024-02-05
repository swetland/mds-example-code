; File Sample.Asm
;--------------------------------------------------------------------------
;       Macintosh 68000 Development System -- Programming Example
;--------------------------------------------------------------------------
; Written by Bud Tribble  17-Feb-85
; Modified for new equates 29-May-86
;
; The purpose of this program is to illustrate various aspects of the
; Macintosh ToolBox and operating system.  The mainline program implements
; the main event loop and desk top support (e.g. desk accessories).
;
; When the user selects a menu item or clicks in the content region of
; the window, the routines "Menu" and "Content" are called (respectively).
; These routines appear in files "SampMenu.Asm" and "SampCont.Asm", and
; are linked with "Sample.Asm" (see "Sample.Job" and "Sample.Link").
;
; For examples of TextEdit and Dialog boxes, see "Window.Asm".
;
	XREF	Menu		; Call this when "Command" item selected
	XREF	Content		; Call this on mouse down in window

;--------------------------------- INCLUDES -------------------------------

Include 	Traps.D		; Use System and ToolBox traps
Include 	ToolEqu.D	; Use ToolBox equates
Include		SysEqu.D	; Use System equates
;

; Offsets for Event Record:
;
what 		EQU	0	; Event number
message		EQU	2	; Additional information
when		EQU	6	; Time event was posted 
point		EQU	10	; Mouse coordinates
modify		EQU	14	; State of keys and button
wWindow		EQU	16	; Find Window's Result

;
; Menu numbers
;
AppleMenu	EQU	1	; First menu (Apple) (not implemented)
FileMenu	EQU	2	; Second menu (File) on menu bar
EditMenu	EQU	3	; Third menu (Edit) (not implemented)
MouseMenu	EQU	4	; Fourth menu (Mouse)
CmdMenu		EQU	5	; Fifth menu (Command)

; Register usage:
;
; D7 - Contains menu handle for Apple menu
;
; A2 - Contains menu handle for Edit menu
; A3 - Contains menu handle for MouseMenu
; A4 - Contains pointer to our window record
;
; A5 - Pointer to Global variables (set by Loader)
;

;------------------------------- Main Program -----------------------------

Start	
	BSR		InitManagers		; Initialize managers
	BSR		SetupMenu		; Add our menu to menu bar
	BSR		SetupWindow		; Draw Window
	JMP		EventLoop		; Go start event loop
	
;------------------------------- InitManagers -----------------------------

InitManagers					; Standard init sequence

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

	
;-------------------------------- Setupmenu -------------------------------

SetupMenu


; Get Menus from resource file
; Apple Menu:
	; FUNCTION	GetMenu ( menu ID:INTEGER): MenuHandle;
	SUBQ		#4,SP			; Space for menu handle
	MOVE 		#AppleMenu,-(SP)	; Menu resource ID
	_GetRMenu				; Get handle to menu
						; Leave on stack for InsertMenu
	MOVE.L		(SP),D7			; Save handle in D7
	MOVE.L		D7,-(SP)		; Copy for AddResMenu	
	; PROCEDURE InsertMenu( theMenu: MenuHandle; beforeID: INTEGER);
	CLR		-(SP)			; beforeID = 0
	_InsertMenu				; Call InsertMenu
	; PROCEDURE AddResMenu( menu: MenuHandle; theType: ResType);
	MOVE.L		#'DRVR',-(SP)		; Load all drivers
	_AddResMenu				; Add to Apple menu
	
; File Menu:
	SUBQ		#4,SP			; Space for menu handle
	MOVE 		#FileMenu,-(SP)		; Menu resource ID
	_GetRMenu				; Get handle to menu
	CLR		-(SP)			; beforeID = 0
	_InsertMenu				; Call InsertMenu

; Edit Menu:
	SUBQ		#4,SP			; Space for menu handle
	MOVE 		#EditMenu,-(SP)		; Menu resource ID
	_GetRMenu				; Get handle to menu
	MOVE.L		(SP),A2			; Save in A2
	CLR		-(SP)			; beforeID = 0
	_InsertMenu				; Call InsertMenu

; Mouse Menu:
	SUBQ		#4,SP			; Space for menu handle
	MOVE 		#MouseMenu,-(SP)		; Menu resource ID
	_GetRMenu				; Get handle to menu
	MOVE.L		(SP),A3			; Save in A3
	CLR		-(SP)			; beforeID = 0
	_InsertMenu				; Call InsertMenu

; Command Menu:
	SUBQ		#4,SP			; Space for menu handle
	MOVE 		#CmdMenu,-(SP)		; Menu resource ID
	_GetRMenu				; Get handle to menu
	CLR		-(SP)			; beforeID = 0
	_InsertMenu				; Call InsertMenu



	; SetItemMark (theMenu: MenuHandle; item: INTEGER; markChar: CHAR);
	MOVE.L		A3,-(SP)		; MouseMenu handle in A3
	MOVE		#1,-(SP)		; Checkmark first item
	MOVE		#checkMark,-(SP)
	_SetItmMark
	MOVE		#1,mChecked(A5)		; Initiaze mChecked
	
	_DrawMenuBar				; and draw menu bar
	RTS					; Return
	
;------------------------------ SetupWindow -------------------------------

SetupWindow

; Set up a standard document window.  For an example showing how to use
; GetNewWindow instead of NewWindow, see "Window.Asm".

	; FUNCTION	NewWindow (wStorage: Ptr; boundsRect: Rect;
	;			      title: Str255; visible: BOOLEAN;
	;			      procID: INTEGER; behind: WindowPtr;
	;			      goAwayFlag: BOOLEAN;
	;			      refCon: LongInt) : WindowPtr;
	SUBQ		#4,SP			; Space for function result
	CLR.L		-(SP)			; Storage for window (Heap)
	PEA		boundsRect		; Window position
	PEA		'Sample'		; Window title
	MOVE.B		#1,-(SP)		; Make window visible
	MOVE		#documentProc,-(SP)	; Standard document window
	MOVE.L		#-1,-(SP)		; Make it the fromt window
	CLR.B		-(SP)			; Window has no goAway button
	CLR.L		-(SP)			; Window refCon
	_NewWindow				; Create and draw window
	MOVE.L		(SP),A4			; Save handle for later 
	
	; PROCEDURE	SetPort (gp: GrafPort)	; Pointer still on stack
	_SetPort				; Make it the current port
	RTS

;--------------------------------------------------------------------------
EventLoop					; MAIN PROGRAM LOOP
	_SystemTask				; Give system some time
	; FUNCTION	GetNextEvent(eventMask: INTEGER; 
	;		VAR theEvent: EventRecord) : BOOLEAN
	SUBQ 		#2,SP			; Make space for result
	MOVE 		#$0FFF,-(SP)		; Allow 12 low events
	PEA		eventRecord(A5)		; Place to return results
	_GetNextEvent				; Look for an event
	MOVE		(SP)+,D0		; Get result code
	BEQ  		EventLoop		; No event... Keep waiting
	BSR 		HandleEvent		; Go handle event
	BEQ		EventLoop		; Not Quit, keep going
	RTS					; Quit, exit to Finder

; Note: When an event handler finishes, it returns the Z flag set.  If 
;	Quit was selected, it returns with the Z flag clear.  An RTS is
;	guaranteed to close all files and launch the Finder.
	
;--------------------------------------------------------------------------
HandleEvent

; Use the event number as an index into the Event table.  These 12 events
; are all the things that could spontaneously happen while the program is
; in the main loop.

	MOVE		eventRecord+what(A5),D0	; Get event number
	CMP		#mButDwnEvt,D0		; MouseDown event?
	BEQ		MouseDown		; Yes, handle it
	CMP		#updatEvt,D0		; Update event?
	BEQ		Update			; Yes, handle it
	CMP		#ActivateEvt,D0		; Activate event?
	BEQ		Activate		; Yes, handle it

	BRA		NextEvent		; Else get next event
	
	
;------------------------------ Event Actions -----------------------------


NextEvent	

	MOVEQ #0,D0				; Say that it's not Quit
	RTS					; return to EventLoop
		
Update	

; The window needs to be redrawn.  Normally the window contents would
; be re-drawn, but in this simplified example, the contents is just erased.

	; PROCEDURE	BeginUpdate (theWindow: WindowPtr);
	MOVE.L		A4,-(SP)	; Get pointer to window
	_BeginUpDate				; Begin the update

	; EraseRect (rUpdate: Rect);
	PEA		ViewRect		; Erase visible area
	_EraseRect
	
	; PROCEDURE	EndUpdate (theWindow: WindowPtr);
	MOVE.L		A4,-(SP)		; Get pointer to window
	_EndUpdate				; and end the update
	BRA 		NextEvent		; Go get next event

Activate
; First make sure this is for our window, then check to see
; if it is an activate or deactivate event.
	CMP.L		eventRecord+message(A5),A4 ; Was it our window?
	BNE		NextEvent		; No
	MOVE		eventRecord+modify(A5),D0 ; Get modify bits
	BTST		#ActiveFlag,D0		; Activate?
	BEQ		Deactivate		; no, branch
	
; To activate our window, disable edit commands and set graphport
; to our port.
	; PROCEDURE DisableItem (menu: MenuHandle; item: INTEGER);
	MOVE.L		A2,-(SP)		; Push Edit menu handle
	CLR		-(SP)			; Item 0 for entire menu
	_DisableItem
	
; PROCEDURE SetPort (gp: Graphport)
	MOVE.L		A4,-(SP)		; Push window pointer
	_SetPort				; and set our port
	
	BRA		NextEvent		; Go get next event

Deactivate
; Enable Edit menu for desk accessories

	; PROCEDURE EnableItem (menu: MenuHandle; item: INTEGER);
	MOVE.L		A2,-(SP)		; Push Edit menu handle
	CLR		-(SP)			; Item 0 for entire menu
	_EnableItem
	BRA		NextEvent		; Go get next event
	
;------------------Mouse Down Events And Their Actions---------------------

MouseDown	

; If the mouse button was pressed, we must determine where the click
; occurred before we can do anything.  Call FindWindow to determine
; where the click was; dispatch the event according to the result.

	; FUNCTION	FindWindow (thePt: Point; 
	;		            VAR whichWindow: WindowPtr): INTEGER;
	SUBQ		#2,SP			; Space for result
	MOVE.L		eventRecord+point(A5),-(SP) ; Get mouse coordinates
	PEA		eventRecord+wWindow(A5)	; Event Window
	_FindWindow				; Who's got the click? 
	MOVE 		(SP)+,D0		; Get region number
	CMP		#inSysWindow,D0		; In System window?
	BEQ		SysWindow		; Yes, go process it
	CMP		#inMenuBar,D0		; In menu bar?
	BEQ		MenuBar			; Yes, handle it
	CMP		#inContent,D0		; In content region?
	BEQ		DoContent		; Yes, handle it
	CMP		#inDrag,D0		; In drag region
	BEQ		DragWind		; Yes, drag window
	BRA		NextEvent		; Else get next event

SysWindow
; Call SystemClick to process this event
	; PROCEDURE SystemClick (theEvent: EventRecord; theWindow: WindowPtr);
	PEA		eventRecord(A5)
	MOVE.L		eventRecord+wWindow(A5),-(SP) ; Push which window
	_SystemClick				; Let system process it
	BRA		NextEvent		; Then go get next event
	
DragWind

; The click was in the drag region.

	; PROCEDURE DragWindow(theWindow: WindowPtr; startPt: Point;
	;				dragBounds: Rect);
	MOVE.L		eventRecord+wWindow(A5),-(SP)		; Push window pointer
	MOVE.L		eventRecord+point(A5),-(SP) ; Push start point
	PEA		dragBounds		; Push pointer to dragBounds
	_DragWindow				; Drag the window
	BRA		NextEvent
		
DoContent	

; The click was in the content area of the window. 
; If our window is not the front window, call SelectWindow to
; activate ourselves (causes an activate event)
	JSR		OtherWindow		; Are we top window?
	BEQ.S		@1			; Yes, skip
	; If we weren't active, make ourselves active
	; PROCEDURE SelectWindow(theWindow: WindowPtr)
	MOVE.L		A4,-(SP)		; Push our window pointer
	_SelectWindow				; Make it the front window
	BRA		NextEvent		; Go get next event	

; Call routine to handle contents click. "point" contains mouse-down
; point in global coords.
@1	; PROCEDURE	GlobalToLocal (VAR pt:Point);
	PEA		eventRecord+point(A5)	; Convert to local coordinates
	_GlobalToLocal

	LEA		eventRecord+point(A5),A0 ; Pass pointer to point in A0
	MOVE		mChecked(A5),D0		; Pass mChecked in D0
	JSR		Content
	BRA 		NextEvent		; Go get next event

MenuBar

; The click was in the menu bar.

	; FUNCTION MenuSelect(startPt: Point): LongInt
	SUBQ		#4,SP			; Space for function result
	MOVE.L		eventRecord+point(A5),-(SP) ; Push startPt
	_MenuSelect				; Call MenuSelect
	MOVE		(SP)+,D1		; Get Menu ID
	MOVE		(SP)+,D0		; Get Menu Item number
	TST		D1			; If no item selected,
	BEQ		NextEvent		; go get next event

	CMP		#AppleMenu,D1		; Apple menu selected?
	BEQ		DoAppleMenu		; Yes, go do it
	
	CMP		#EditMenu,D1		; Edit menu selected?
	BEQ		DoEdit			; Yes, go do it

	CMP		#MouseMenu,D1		; Mouse menu selected?
	BEQ		SetMChecked		; Yes, set mChecked
	
	CMP		#CmdMenu,D1		; Command menu selected?
	BEQ		DoMenuItem		; Yes, go do it

	
; If we get here, the "Quit" item was selected
	MOVE		#-1,D0			; Set quit flag
	RTS					; and return

MenuDone		; All menu operations come here when done
	; PROCEDURE HiliteMenu (MenuID: INTEGER);
	CLR		-(SP)			; Un-highlight all menus
	_HiliteMenu				
	BRA		NextEvent		; Go get next event
	
DoAppleMenu
; An Apple menu item was selected. Open the selected desk accessory

	; PROCEDURE GetItem (menu MenuHandle; item: INTEGER;
	;  			VAR itemString: Str255);
	MOVE.L		D7,-(SP)		; Push menu handle
	MOVE		D0,-(SP)		; Push item #
	PEA		deskName(A5)		; Storage for name
	_GetItem				; Get item string
	
	; FUNCTION OpenDeskAcc (theAcc: Str255): INTEGER;
	SUBQ		#2,SP			; Space for result
	PEA		deskName(A5)		; Name string
	_OpenDeskAcc				; Open it
	ADDQ		#2,A7			; Pop off result

	
	; PROCEDURE SetPort (gp: Graphport)
	MOVE.L		A4,-(SP)		; Push window pointer
	_SetPort				; and make sure our port set
	BRA		MenuDone		; Go get next event
	
DoEdit

; Edit menu was selected.  We don't use it, but if a desk accessory is
; active, we still get menu events.  SysEdit lets the desk
; accessory take care of it

	; FUNCTION SystemEdit (editCmd: INTEGER): BOOLEAN;
	SUBQ		#2,SP			; Space for result
	MOVE		D0,-(SP)		; Push menu item #
	SUBQ		#1,(SP)			; SysEdit is off by 1!
	_SysEdit				; Give it to desk accessory
	TST.B		(SP)+			; Zero if NOT handled
						; (But we don't care)
	BRA		MenuDone		; Go get next event
	
SetmChecked	

; A Mouse menu item was selected.  Un-check old item and check new item,
; and set mChecked to the menu item number (which is in D0)

	JSR		OtherWindow		; Some other window on top?
	BNE		MenuDone		; Yes, ignore selection
						; else...
	MOVE		D0,D4			; Save item #
	; SetItemMark ( theMenu: MenuHandle; item: INTEGER; markChar: Char);
	MOVE.L		A3,-(SP)		; Push handle to MouseMenu	
	MOVE		mChecked(A5),-(SP)	; Push old item #
	MOVE		#noMark,-(SP)		; Remove checkmark from item
	_SetItmMark

	; SetItemMark ( theMenu: MenuHandle; item: INTEGER; markChar: Char);
	; (Copy of theMenu handle is already on stack)
	MOVE.L		A3,-(SP)		; Push handle to Mouse Menu	
	MOVE		D4,-(SP)		; Push new item #
	MOVE		#checkMark,-(SP)	; Checkmark the item
	_SetItmMark
		
	MOVE		D4,mChecked(A5)		; Store menu item #
	BRA		MenuDone		; Go get next event
	
DoMenuItem
; A Command menu item was selected.  Call routine to handle it
; and then un-highlight menu item.
; The Menu item number (1..n) is in D0

	JSR		OtherWindow		; Some other window on top?
	BNE		MenuDone		; Yes, ignore selection
						; else...

	JSR		Menu			; Call Menu routine
	BRA		MenuDone		; Go get next event

; ------------------------------ OtherWindow ------------------------------
; OtherWindow routine -- Returns non-zero cond code if our
; window is not the top window.
OtherWindow
	MOVEM.L		D0-D2/A0-A2,-(SP)	; Save regs
	; FUNCTION FrontWindow: WindowPtr;
	SUBQ		#4,SP			; Space for result
	_FrontWindow				; Get frontWindow
	MOVE.L		(SP)+,D0		; Put it in D0
	CMP.L		A4,D0			; Same as our window?
	MOVEM.L		(SP)+,D0-D2/A0-A2	; Restore regs
	RTS					; and return
	
; ----------------------------- Data Constants ----------------------------
; Remember, only constants should be stored in the code segments.
; The program should never write into its own code segments.

boundsRect					; Bounding rect for window
			DC.W	60,20,330,500	; (global coordinates)
dragBounds					; Bounding rect for dragging
			DC.W	24,24,338,508	; (global coordinates)
viewRect					; Content rect for window
			DC.W	0,0,300-40,500-40 ; (local coordinates)

; ------------------------------ Global Data ------------------------------
; This data space is allocated relative to A5 (globals pointer)
; All global read/write data should be stored here.

mChecked		DS.W	0		; Currently selected  item
						; (from Mouse menu)						
deskName		DS.B	32		; Max desk acc. name 31 chars

eventRecord		DS.B 	20		; NextEvent's Record

	End
