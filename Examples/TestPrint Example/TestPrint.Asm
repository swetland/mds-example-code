; File TestPrint.Asm
;--------------------------------------------------------------------------
;       Macintosh 68000 Development System -- Printing Example
;--------------------------------------------------------------------------
; Written by Bud Tribble  17-Feb-85
; Modified for new equates 28-May-86
;
	
;--------------------------------- INCLUDES -------------------------------
	
Include		QuickEqu.D	; Use QuickDraw Equates
Include		PrEqu.Txt	; Use Printing Equates	
; Include	Traps.d
; The following Traps are explicitly defined in this example to allow 
; assembly using the minimum amount of memory.  You may simply INCLUDE 
; Traps.D if memory is not a consideration.
;
	.TRAP	_InitGraf    	$A86E
 	.TRAP	_InitFonts    	$A8FE
 	.TRAP	_FlushEvents	$A032
 	.TRAP	_InitWindows   	$A912
 	.TRAP	_InitMenus    	$A930
 	.TRAP	_InitDialogs   	$A97B
 	.TRAP	_TEInit     	$A9CC
 	.TRAP	_InitCursor    	$A850
 	.TRAP	_FrameOval	$A8B7
 	.TRAP	_TextFont    	$A887
 	.TRAP	_GetFontInfo	$A88B
 	.TRAP	_MoveTo		$A893
 	.TRAP	_DrawString	$A884
 	.TRAP	_NewHandle	$A122
 	.TRAP	_DisposHandle   $A023
Include 	ToolEqu.D	; Use ToolBox equates
Include		SysEqu.D	; Use System equates

charCount	EQU	120	; Chars to print per line (must be even)

;------------------------------- Main Program -----------------------------

Start	
	BSR		InitManagers		; Initialize managers
	; PROCEDURE PrOpen;
	JSR		PrOpen			; Open print manager
	; (Note that for LaserWriter driver, this may consume about
	; 25K bytes of code and data space.)
	
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

; -------------------------------------------------------------------------
MyDrawPage
; Routine to draw one page for printer.
; Called between PrOpenPage and PrClosePage calls to the print manager.
	MOVEM.L		D3-D6/A3-A4,-(SP)	; Save registers
	
	; First draw an oval 5 by 5 inches (nominal)
	; PROCEDURE FrameOval (r: Rect);
	PEA		tRect			; Push tRect
	_FrameOval


	; Now draw some text using Monaco (mono-spaced) font
	;
	; PROCEDURE TextFont(font: INTEGER);
	MOVE		#monaco,-(SP)		; Push Monaco font #
	_TextFont				; Set font (default size)

	; Get font info to determine line spacing
	LINK		A6,#-8			; Make room for fontInfo
	MOVE.L		SP,A4			; A4 points to fontInfo
	; PROCEDURE GetFontInfo( VAR info: fontInfo);
	MOVE.L		A4,-(SP)		; Push pointer to fontInfo
	_GetFontInfo
	MOVE		ascent(A4),D4		; Calculate line height
	ADD		descent(A4),D4
	ADD		leading(A4),D4		; D4 has line height
	
	MOVE.L		hPrintRec(A5),A0	; Point to print record
	MOVE.L		(A0),A0			; (deref handle)
	MOVE		prInfo+rPage+bottom(A0),D6 ; Get page bottom coord.
	SUB		descent(A4),D6		; Adjust for font descent
	
; -------------------------------------------------------------------------	
; Print a page of characters.
;
; A3 Points to print string
;
; D3 has current line position
; D4 has vertical distance between lines
; D5 has current line number
; D6 has bottom (vertical) coordinate of page

	MOVE		#1,D5			; Set initial line no.
	MOVE		D4,D3			; Set initial line position

	LINK		A6,#-(charCount+2)	; Space for char string
	MOVE.L		SP,A3			; A3 points to string
	MOVE.B		#charCount,(A3)		; Set length byte

; Fill print string with characters.
	MOVE		#$20,D0			; ASCII value for space
	MOVE		#charCount-1,D1		; Count-1
	MOVE.L		A3,A0			; Point to string
	ADDQ		#1,A0			; Bump past length byte
@1	MOVE.B		D0,(A0)+		; Fill in string
	ADDQ		#1,D0			; Next char
	DBRA		D1,@1			; Loop until done
	
	; PROCEDURE MoveTo (h,v: INTEGER);
PLoop	MOVE		#0,-(SP)		; MoveTo start of line
	MOVE		D3,-(SP)
	_MoveTo

	; PROCEDURE DrawString (s: Str255);	
	MOVE.L		A3,-(SP)		; Draw string
	_DrawString

	MOVE		#charCount-1,D1		; Count-1
	MOVE.L		A3,A0			; Point to string
	ADDQ		#1,A0			; Bump past length byte
@1	ADD.B		#1,(A0)+		; Increment each byte
	DBRA		D1,@1			; Loop until done

	ADD		#1,D5			; Bump current line no.
	ADD		D4,D3			; Bump line position			
	CMP		D6,D3			; Past end of page?
	BLE		PLoop			; No, loop until done.	

	UNLK		A6			; Reclaim stack space	
	UNLK		A6			; (for two LINKs)
	MOVEM.L		(SP)+,D3-D6/A3-A4	; Restore registers
	RTS

; -------------------------------------------------------------------------	
EventLoop					; MAIN PROGRAM
; Normally this would be a loop, but this program just prints (cycling
; through the dialogs) and then quits.

; -------------------------------------------------------------------------	
Init
	MOVE.L		#iPrintSize,D0		; Allocate print record
	_NewHandle
	MOVE.L		A0,hPrintRec(A5)	; Save handle in hPrintRec
	MOVE.L		A0,-(SP)		; Push it
	JSR		PrintDefault		; Call PrintDefault

; -------------------------------------------------------------------------
Style
	SUBQ		#2,SP			; Space for function result
	MOVE.L		hPrintRec(A5),-(SP)	; Push hPrintRec
	JSR		PrStlDialog		; Call PrStlDialog
	MOVE.B		(SP)+,D0		; Pop result

; -------------------------------------------------------------------------
Job
	SUBQ		#2,SP			; Space for function result	
	MOVE.L		hPrintRec(A5),-(SP)	; Push hPrintRec
	JSR		PrJobDialog		; Call PrJobDialog
	MOVE.B		(SP)+,D0		; Pop Result
	BEQ		PrintDone		; Exit to Finder if Cancel

; -------------------------------------------------------------------------
Spool
	; ****** Start of Document ********
	; PROCEDURE PrOpenDoc (hPrint: THPrint; pPrPort: TPPrPort; 
	;			pIOBuf: Ptr): TPPrPort;
	SUBQ		#4,SP			; Space for result
	MOVE.L		hPrintRec(A5),-(SP)	; Push hPrintRec
	CLR.L		-(SP)			; NIL pPrPort
	CLR.L		-(SP)			; NIL pIOBuf
	JSR		prOpenDoc		; Call PrOpenDoc
	MOVE.L		(SP)+,A4		; Get pPrPort in A4

		; ******** Start of Page ********
		; PROCEDURE PrOpenPage (pPrPort: TPPrPort; pPageFrame: TPRect););
		MOVE.L		A4,-(SP)		; Push pPrPort
		CLR.L		-(SP)			; NIL pPageFrame
		JSR		PrOpenPage		; Call PrOpenPage
	
		; ******* Draw Page Here ******** 
		JSR		MyDrawPage
		; *******************************	

		; ********* End of Page *********
		; PROCEDURE PrClosePage (pPrPort: TPPrPort);
		MOVE.L		A4,-(SP)		; Push pPrPort
		JSR		PrClosePage		; Call PrClosePage
	
	; ******* End of Document *********	
	; PROCEDURE PrCloseDoc (pPrPort: TPPrPort);
	MOVE.L		A4,-(SP)		; Push pPrPort
	JSR		PrCloseDoc		; Call PrCloseDoc
	
; -------------------------------------------------------------------------
Print
	; PROCEDURE PrPicFile (hPrint: THPrint; pPrPort: TPPrPort;
	;	pIOBuf: Ptr; pDevBuf: Ptr; VAR prStatus: TPrStatus);
	MOVE.L		hPrintRec(A5),-(SP)	; hPrintRec
	CLR.L		-(SP)			; pPrPort
	CLR.L		-(SP)			; pIOBuf
	CLR.L		-(SP)			; pDevBuf
	PEA		prStatus(A5)		; prStatus
	JSR		PrPicFile		; Call PrPicFile

	MOVE.L		hPrintRec(A5),A0	; Get printRec handle
	_DisposHandle				; Dispose it
	JMP		EventLoop		; Go start over

PrintDone
	; PROCEDURE PrClose;
	JSR		PrClose			; Done. Close print manager,
	RTS					; then exit to Finder


; ---------------------------- Data Constants -----------------------------	
; Remember, only constants should be stored in the code segments.
; The program should never write into its own code segment.

tRect				; temp rectangle (nominal 5 by 5 inches
				; assuming 72 dots per inch)
	DC.W	0		; top		
	DC.W	0		; left
	DC.W	5*72		; bottom
	DC.W	5*72		; right

; ----------------------------- Global Data -------------------------------	
; This data space is allocated relative to A5 (globals pointer)
; All global read/write data should be stored here.

hPrintRec
	DS.L	1		; handle for print record
	
prStatus			; Printer status record
	DS.B	iPrStatSize
	

	END
