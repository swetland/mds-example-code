; File SampMenu.Asm
; Written by Bud Tribble   17-Feb-85
; Modified for new equates 29-May-86

XDef		Menu
XDef		WriteNum

; Include	Traps.d
; The following Traps are explicitly defined in this example to allow 
; assembly using the minimum amount of memory.  You may simply INCLUDE 
; Traps.D if memory is not a consideration.
;
 	.TRAP	_SysBeep	$A9C8
 	.TRAP	_FrontWindow	$A924
 	.TRAP	_NewHandle	$A122    
 	.TRAP	_HLock		$A029
 	.TRAP	_HUnlock	$A02A
 	.TRAP	_DisposHandle	$A023
 	.TRAP	_GetCursor	$A9B9
 	.TRAP	_InitCursor	$A850
 	.TRAP	_SetCursor	$A851
 	.TRAP	_Open		$A000  
 	.TRAP	_GetEOF		$A011 
 	.TRAP	_Read		$A002
 	.TRAP	_Close		$A001
 	.TRAP	_Write		$A003
 	.TRAP	_GetFontInfo	$A88B
 	.TRAP	_EraseRect	$A8A3
 	.TRAP	_MoveTo		$A893
 	.TRAP	_DrawString	$A884
 	.TRAP	_Pack3		$A9EA
 	.TRAP	_Pack7		$A9EE
	
Include		SysEqu.d
Include		ToolEqu.d
Include		QuickEqu.d

Include		PackMacs.Txt	

; Parameter RAM copy Serial Port Configuration byte
; * Released AppleTalk driver only *
; (Port A in high nibble, Port B in low nibble)
;  0 - UseFree  -- Port not configured
;  1 - UseATalk -- Port configured for use by AppleTalk
;  2 - UseAsync -- Port configured for use by async driver
;  3-15 (reserved)
;

; ------------------------ Sample Menu Subroutines ------------------------
;
; This file must be assembled and linked with mainline "Sample.Rel".
; It contains several illustrative subroutines which are called from
; the main event loop within the "Sample" program.  The job file named
; "Sample.Job" may be used to assemble and link all the files for the
; application "Sample", including "SampMenu.Asm" and "SampCont.Asm".
;
; The "Menu" routine is called whenever the user selects an item
; from the Command menu. On entry, D0 contains the item number selected.
;

; --------------------------- Menu Routines -------------------------------
; Dispatch to correct menu command routine. Menu item number in D0.
; (A table is more efficient, but this is more straightforward).

Menu	MOVEM.L		A2-A4/D2-D4,-(SP)	; Save Regs

	CMP		#1,D0
	BEQ		Beep
	CMP		#2,D0
	BEQ		aErase
	CMP		#3,D0
	BEQ		MDrawString
	CMP		#4,D0
	BEQ		Cursors
	CMP		#5,D0
	BEQ		Coordinates
	CMP		#6,D0
	BEQ		StandardFile
	CMP		#7,D0
	BEQ		SerialOut

MenuDone
	MOVEM.L		(SP)+,A2-A4/D2-D4	; Restore Regs
	RTS					; and return
	
; ------------------------------------------------------------------------

Beep
; A very simple routine - beep the speaker when menu item selected.

	; PROCEDURE SysBeep (duration: INTEGER);
	MOVE		#2,-(SP)		; Beep speaker for 2 units
	_SysBeep
	BRA		MenuDone

; -------------------------------------------------------------------------

aErase

; Erase the front window

	JSR		EraseSub		; Erase window
	BRA		MenuDone		; and return
	
EraseSub					; (called elsewhere too)
	; FUNCTION FrontWindow: WindowPtr;
	SUBQ		#4,SP			; Space for result
	_FrontWindow
	MOVE.L		(SP)+,A0		; Get window pointer

	; EraseRect( r: Rect);
	PEA		portRect(A0)		; Push pointer to portRect
	_EraseRect				; and erase it
	RTS					; Return

; -------------------------------------------------------------------------
MDrawString
; Draw a string on the screen
; Shows the structure of a string, and demonstrates how
; to use the Memory Manager to allocate relocatable blocks.
;
CharCount	EQU	26		; Character count
StringLength	EQU	CharCount+1 	; Length of string (bytes)

; First position pen at (10,20)
	; PROCEDURE MoveTo( h,v: INTEGER);
	MOVE		#10,-(SP)
	MOVE		#20,-(SP)
	_MoveTo
	JSR		EraseSub		; And erase screen
	
; Now allocate memory for string, fill it in, and draw it
	MOVE.L		#StringLength,D0	; Size to allocate (bytes)
	_NewHandle				; Get Handle to buffer
	BNE		NoRoom			; Skip it if no room
	MOVE.L		A0,A4			; Save handle in A4
	MOVE.L		(A4),A1			; A1 is pointer to buffer

	MOVE.B		#CharCount,(A1)+	; Store count in string
	MOVE.B		#'A',D0			; First char
	MOVE		#CharCount-1,D1		; Count for DBRA
@1	MOVE.B		D0,(A1)+		; Store chars A-Z
	ADDQ		#1,D0			; Next char
	DBRA		D1,@1			; Loop until done

; - Some memory manager notes
;
; Before passing a pointer to a relocatable block, it must be locked.
; This is because the location in memory may change as a result of
; heap compaction during a system call. For example, DrawString calls
; the Font Manager which may cause a heap compaction if the desired font
; is not in memory.
;
; Any time a relocatable block is locked (or a non-relocatable block is
; allocated), fragmentation of the heap may occur, greatly reducing the
; amount of usable free memory.  Because of this, it is wise to:
;
; 1. Pre-allocate all non-relocatable or permanently locked storage blocks
;    at the beginning of the program.
; 2. Allocate temporary storage on the stack when possible. (For example,
;    the current string could be copied to the stack before being passed
;    to the DrawString routine).
; 3. If all else fails, make sure the storage block is locked before
;    passing the pointer to a routine. Unlock the block as soon as possible.
;    (This is shown below).
;
	MOVE.L		A4,A0			; Get handle in A0
	_HLock					; Lock it		
	;PROCEDURE DrawString( s: Str255)
	MOVE.L		(A4),-(SP)		; Push pointer to string
	_DrawString				; Draw it	
	MOVE.L		A4,A0			; Get handle in A0
	_HUnlock				; Unlock it

	; When done with the memory block, it should be "disposed" of
	; to release th storage for re-use.
	_DisposHandle				; Handle in A0
	
NoRoom	BRA		MenuDone		; and return

; -------------------------------------------------------------------------
Cursors
; Cycle through the cursors in the system resource file
	
	ADD		#1,cursorID(A5)		; Increment cursor ID
	
	; FUNCTION GetCursor(cursorID: INTEGER): CursHandle;
	SUBQ		#4,SP			; Space for result
	MOVE		cursorID(A5),-(SP)	; Push cursorID
	_GetCursor
	MOVE.L		(SP)+,D0		; Get handle
	BNE		@1			; If not NIL, skip
	; PROCEDURE InitCursor;
	_InitCursor				; Else initialize cursor
	CLR		cursorID(A5)		; and reset cursorID	
	BRA		@2			; then return
	
@1	MOVE.L		D0,A0			; Put handle in A0	
	; PROCEDURE SetCursor(crsr: Cursor);
	MOVE.L		(A0),-(SP)		; Push pointer to cursor
	_SetCursor				; and set it

@2	BRA		MenuDone		; Return	
; -------------------------------------------------------------------------
Coordinates
; Display the portRect and portBits.bounds on the screen.
; Uses local routine "WriteNum".

	JSR		EraseSub		; Erase window
	; FUNCTION FrontWindow: WindowPtr;
	SUBQ		#4,SP			; Space for result
	_FrontWindow
	MOVE.L		(SP)+,A4		; Get window pointer
	LEA		portBits+bounds(A4),A3  ; Point to portBits.bounds
	LEA		portRect(A4),A4		; Point to portRect

	; Write values for portRect on screen
	LEA		'- portRect:',A0	; Heading for portRect
	MOVE		#1,D0			; Line number in D0
	JSR		WriteNum		; Write it on the screen

	LEA		'Top    ',A0		; Top coordinate
	MOVE		#2,D0			; Line number in D0
	MOVE		top(A4),D1		; Value in D1
	JSR		WriteNum		; Write it on the screen

	LEA		'Left   ',A0		; Left coordinate
	MOVE		#3,D0			; Line number in D0
	MOVE		left(A4),D1		; Value in D1
	JSR		WriteNum		; Write it on the screen

	LEA		'Bottom ',A0		; Bottom coordinate
	MOVE		#4,D0			; Line number in D0
	MOVE		bottom(A4),D1		; Value in D1
	JSR		WriteNum		; Write it on the screen

	LEA		'Right  ',A0		; Right coordinate
	MOVE		#5,D0			; Line number in D0
	MOVE		right(A4),D1		; Value in D1
	JSR		WriteNum		; Write it on the screen

	; Write values for portBits.bounds on screen
	LEA		'- portBits.bounds:',A0	; Heading for portBits.bounds
	MOVE		#7,D0			; Line number in D0
	JSR		WriteNum		; Write it on the screen

	LEA		'Top    ',A0		; Top coordinate
	MOVE		#8,D0			; Line number in D0
	MOVE		top(A3),D1		; Value in D1
	JSR		WriteNum		; Write it on the screen

	LEA		'Left   ',A0		; Left coordinate
	MOVE		#9,D0			; Line number in D0
	MOVE		left(A3),D1		; Value in D1
	JSR		WriteNum		; Write it on the screen

	LEA		'Bottom ',A0		; Bottom coordinate
	MOVE		#10,D0			; Line number in D0
	MOVE		bottom(A3),D1		; Value in D1
	JSR		WriteNum		; Write it on the screen

	LEA		'Right  ',A0		; Right coordinate
	MOVE		#11,D0			; Line number in D0
	MOVE		right(A3),D1		; Value in D1
	JSR		WriteNum		; Write it on the screen

	LEA 		'- Select "Coordinates" to update values',A0
	MOVE		#15,D0
	JSR		WriteNum
	
	BRA		MenuDone

; ---------------------------- StandardFile Routine -----------------------
StandardFile
; Call SFGetFile, and write file name and length on the screen.
;
	; PROCEDURE SFGetFile(where: Point; prompt: Str255; fileFilter:
	;	ProcPtr; numTypes: INTEGER; typeList: SFTypeList;
	;	dlgHook: ProcPtr; VAR reply: SFReply);

	MOVE		#82,-(SP)		; where.h
	MOVE		#124,-(SP)		; where.v
	CLR.L		-(SP)			; prompt not used
	CLR.L		-(SP)			; we don't need filter
	MOVE		#-1,-(SP)		; pass all types
	CLR.L		-(SP)			; no typeList
	CLR.L		-(SP)			; no dlgHook
	PEA		sfReply(A5)		; push address of reply record
	_SFGetFile				; call package
	
	LEA		sfReply(A5),A0		; Point to sfReply
	TST.B		rGood(A0)		; If cancel was clicked, return
	BEQ		@1
	; Now open the file
	LEA		diskPBlock(A5),A1	; Point to parameter block
	CLR.L		ioCompletion(A1)	; No completion routine
	LEA		rName(A0),A2		; Point to file name
	MOVE.L		A2,ioFileName(A1)	; Store pointer in diskPBlock
	MOVE		rVolume(A0),ioVRefNum(A1) ; Store vRefNum in diskPBlock
	CLR.B		ioFileType(A1)		; Must set file type = 0
	MOVE.B		#fsRdPerm,ioPermssn(A1)	; Open for read only
	CLR.L		ioOwnBuf(A1)		; Use system buffer
	MOVE.L		A1,A0			; A0 points to diskPBlock
	_Open					; Open the file
	;*********************************************
	; File is ready for reading or writing here  ;
	;*********************************************

	; Print results on screen
	MOVE		D0,-(SP)		; Save ioResult code
	JSR		EraseSub		; Erase screen
	MOVE		(SP)+,D1		; Get ioResult	
	EXT		D1			; Sign extend it
	LEA		'ioResult = ',A0	; Heading string
	MOVE		#1,D0			; Line number in D0
	JSR		WriteNum		; Write ioResult the screen

	LEA		'- File Name: ',A0	; Heading
	MOVE		#2,D0			; Line number in D0
	JSR		WriteNum		; Write it on the screen
	; PROCEDURE DrawString( s: Str255)
	MOVE.L		diskPBlock+ioFileName(A5),-(SP)	; Push pointer to name
	_DrawString				; and write it on screen	

	LEA		diskPBlock(A5),A0	; Point to diskPBlock
	_GetEOF					; Get file length
	MOVE.L		ioLEOF(A0),D1		; into D1
	LEA		'File length = ',A0	; Heading
	MOVE		#3,D0			; Line number in D0
	JSR		WriteNum		; Write it on the screen

	; Read one block from disk just for fun
	LEA		diskPBlock(A5),A0	; Point to param block
	LEA		buffer(A5),A1		; Point to buffer
	MOVE.L		A1,ioBuffer(A0)
	MOVE.L		#512,ioReqCount(A0) 	; Read 512 bytes
	MOVE		#1,ioPosMode(A0)	; Position from start
	CLR.L		ioPosOffset(A0)		; Start of read = byte 0
	_Read

	LEA		diskPBlock(A5),A0		; Close file before returning
	_Close
@1	BRA		MenuDone		; Return

; --------------------------- SerialOut Routine ---------------------------	
; Routine to write to Serial port B
SerialOut
;
; Check to make sure Serial Port B configured for async driver
; (Do this so we don't kill AppleBus if its connected)
;
	MOVE.B		SPConfig,D0		; Get port config byte
	AND		#$F,D0			; Get low nibble (Port B)
	BNE		@1			; Skip if configured
	BRA.S		@2			; else go open it (see below)
	; (Since the nibble was zero, this Mac is not configured.
	;  It would actually be safer here to ask the user to
	;  make sure AppleTalk was not connected to his Mac.
	;  It is considered bad form to bring down the network
	;  by opening the serial port.)
	
@1	CMP		#useAsync,D0		; Configured for async?
	BEQ.S		@2			; Yes, go open it
	;
	; The serial port is already configured for use by AppleTalk or
	; some other purpose.  Just beep and return.
	JMP		Beep
	
	; Open serial port B (printer port) for output
@2	LEA		serPBlock(A5),A0	; Point to parameter block
	CLR.L		ioCompletion(A0)	; No completion routine
	LEA		'.BOut',A1		; Point to driver name
	MOVE.L		A1,ioFilename(A0)	; Store in param block
	MOVE.B		#FSWrPerm,ioPermssn(A0) ; Write permission
	CLR		ioVRefNum(A0)		; Clear unused params
	CLR.B		ioFileType(A1)
	CLR.L		ioOwnBuf(A0)
	_Open					; Open the driver

	; Write disk block to serial port
	LEA		buffer(A5),A1		; Point to buffer
	MOVE.L		A1,ioBuffer(A0)		; Store in param block
	LEA		diskPBlock,A1		; Get disk param block
	MOVE.L		ioActCount(A1),ioReqCount(A0)  ; Copy count
	MOVE		#1,ioPosMode(A0)	; Position mode 1
	CLR.L		ioPosOffset(A0)		; Offset zero
	_Write					; Write the bytes to port B
	
	BRA		MenuDone		; and return
	
	

; -------------------------------------------------------------------------
; ---------------------- WriteNum Routine ---------------------------------	
;
; This is a local routine called by the above code.
; It writes a string in the current window at a given line number,
; followed by a decimal value.
; The line number is in D0, and A0 points to the string. The value
; to be written is in D1. If the first character in the string is
; - (hyphen), the value in D1 is not written.
;
; The vertical coordinate at which to write the string is given by:
;
;    (font ascent + font descent + font leading) * (line number)
;
; This shows the use of the FontInfo routine to get information
; about a font.
;
WriteNum
	
	MOVEM.L		D4-D5/A4,-(SP)		; Save registers
	MOVE		D0,D4			; Copy line number
	MOVE		D1,D5			; Copy value
	MOVE.L		A0,A4			; Copy string pointer
	
	; PROCEDURE GetFontInfo(VAR info: FontInfo);
	PEA		fontInfo(A5)		; First get font info
	_GetFontInfo

	; Calculate line spacing
	LEA		fontInfo(A5),A0		; Point to fontInfo
	MOVE		ascent(A0),D0
	ADD		descent(A0),D0
	ADD		leading(A0),D0
	MULS		D0,D4			; Get v coord in D4
	
	MOVE		D4,D0			; Calculate erase rect,
	SUB		ascent(A0),D0
	MOVE		D0,tRect+top(A5)	; put in tRect
	MOVE		D4,D0
	ADD		descent(A0),D0
	MOVE		D0,tRect+bottom(A5)
	CLR		tRect+left(A5)
	MOVE		#512,tRect+right(A5)
	; PROCEDURE EraseRect( r: Rect);
	PEA		tRect(A5)		; and erase it!
	_EraseRect
	
	; PROCEDURE MoveTo( h,v: INTEGER);
	MOVE		#20,-(SP)		; Position the pen
	MOVE		D4,-(SP)
	_MoveTo
	; PROCEDURE DrawString( s: Str255);
	MOVE.L		A4,-(SP)		; and draw the string
	_DrawString
	MOVE.B		1(A4),D0		; Get first character
	CMP.B		#'-',D0			; If it is a '-'
	BEQ		@1			; exit,
	; else convert value in D5 to string and draw it
	MOVE		D5,D0			; Get value in D0
	EXT.L		D0			; Sign extend it
	LEA		tString(A5),A0		; Get string variable
	_NumToString				; Convert to string
	; PROCEDURE DrawString( s: Str255);
	MOVE.L		A0,-(SP)		; Push pointer to string
	_DrawString				; and draw it.
	
@1	MOVEM.L		(SP)+,D4-D5/A4		; Restore registers
	RTS					; and return
	
; ------------------------------ Global Data ------------------------------
; This data space is allocated relative to A5 (globals pointer)
; All global read/write data should be stored here.

cursorID 	DS.W	1	; Cursor ID

fontInfo 	DS.W	4	; FontInfo record (ascent,descent,widMax,leading)

tRect		DS.W	4	; temp rectangle

tString		DS.B	16	; String for NumToString

sfReply		DS.B	72	; Standard File reply record
	
diskPBlock	DS.B	ioQelSize	; IO queue element for file system

serPBlock	DS.B	ioQelSize	; IO queue element for serial driver

buffer		DS.B	512	; Disk and serial IO buffer

	END