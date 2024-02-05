; File SampCont.Asm
; Written by Bud Tribble   17-Feb-85
; Modified for new equates 29-May-86

XDef		Content
XRef		WriteNum

Include		Traps.D
Include		QuickEqu.D

; ---------------------- Sample Contents Subroutines ----------------------
;
; This file must be assembled and linked with mainline "Sample.Rel".
; It contains several illustrative subroutines which are called from
; the main event loop within the "Sample" program.  The job file named
; "Sample.Job" may be used to assemble and link all the files for the
; application "Sample", including "SampMenu.Asm" and "SampCont.Asm".
;
; The "Content" routine is called whenever the user clicks in the
; content region of the window. On entry, A0 contains a pointer to
; the (global) mouse coordinates passed by GetNextEvent. Also, D0 contains
; the value of the current item (1..n) selected from the Mouse menu.
;

; ----------------------------- Content Routines --------------------------
; Called when there is a mouse down event in the content region of the
; window.  On entry, A0 points to the mouse location passed by GetNextEvent,
; (converted to local coordinates), and D0 contains the currently selected
; item from the "Mouse" menu.
;

Content
	
	MOVEM.L		D4/A2-A4,-(SP)		; Save regester
	LEA		point(A5),A4		; A4 points to point
	MOVE.L		(A0),(A4)		; Copy parameter
	MOVE.L		D0,D4			; D4 has menu item number

	; PROCEDURE GetPenState (VAR pnState: PenState);
	PEA		pnState(A5)			; Save pen state
	_GetPenState
; Dispatcher for "Mouse" menu values
	CMP		#1,D4			; First item
	BEQ		Sketch
	CMP		#2,D4
	BEQ		Boxes			; Second item
	CMP		#3,D4
	BEQ		Ovals			; Third item
	CMP		#4,D4
	BEQ		Location		; Fourth item
	JMP		CReturn			; Should'nt get here
	
;-------------------------------- Sketch ----------------------------------	
Sketch	
	;Procedure MoveTo(h,v: INTEGER)
	MOVE		h(A4),-(SP)		; H coordinate
	MOVE		v(A4),-(SP)		; V coordinate
	_MoveTo					; Draw a line

	;Procedure GetMouse (VAR mouseLoc: Point);
@1	PEA		tPoint(A5)		; Point to temp point
	_GetMouse				; Get coordinates
	MOVE.L		tPoint(A5),D0		; into D0
	CMP.L		(A4),D0			; Has point changed?
	BEQ.S		@2			; No, skip, else plot
	MOVE.L		D0,(A4)			; Store new mouse point
	;Procedure LineTo(h,v: INTEGER)
	MOVE		h(A4),-(SP)		; H coordinate
	MOVE		v(A4),-(SP)		; V coordinate
	_LineTo					; Draw a line
	;Function StillDown: BOOLEAN
@2	SUBQ		#2,SP			; Space for result
	_StillDown				; Mouse button still down?
	TST.B		(SP)+			; Check result
	BNE.S		@1			; Loop until button up
	BRA		CReturn			; then return

;------------------------------ Boxes -------------------------------------	
Boxes	
Ovals						; (Ovals drawn here too)
	MOVE		#patXor,-(SP)		; Set pen mode to XOR
	_PenMode

	LEA		oldRect(A5),A2		; Point to oldRect
	MOVE.L		(A4),topLeft(A2)	; Fill in with mouse pt
	MOVE.L		(A4),botRight(A2)
	LEA		newRect(A5),A3		; Same for newRect
	MOVE.L		(A4),topLeft(A3)
	MOVE.L		(A4),botRight(A3)

DrawLoop
	;Function StillDown: BOOLEAN
	SUBQ		#2,SP			; Space for result
	_StillDown				; Mouse button still down?
	TST.B		(SP)+			; Check result
	BNE		@2			; Skip if button down
	MOVE		#patCopy,-(SP)		; Else set pen mode to patCopy
	; PROCEDURE PenMode( mode: INTEGER);
	_PenMode
	JSR		DrawIt			; Draw tRect in copy mode	
	BRA		CReturn			; and return
	
@2	
;
; A2 points to oldRect
; A3 points to newRect
; A4 points to mouse point
;
	;PROCEDURE GetMouse (VAR mouseLoc: Point);
	MOVE.L		A4,-(SP)		; Point to mouse point
	_GetMouse				; Get coordinates
	MOVE.L		(A4),botRight(A3)	; Fill in newRect
	; FUNCTION EqualRect (rectA, rectB: Rect): BOOLEAN;
	SUBQ		#2,SP			; Space for result
	MOVE.L		A2,-(SP)
	MOVE.L		A3,-(SP)
	_EqualRect				; oldRect = newRect ?
	TST.B		(SP)+			; Check result
	BNE		DrawLoop		; Yes, loop

	MOVE.L		topLeft(A2),tRect+topLeft(A5) ; tRect <-- oldRect
	MOVE.L		botRight(A2),tRect+botRight(A5)
	JSR		DrawIt			; XOR old rect, oval, etc.
	MOVE.L		topLeft(A3),tRect+topLeft(A5) ; tRect <-- newRect
	MOVE.L		botRight(A3),tRect+botRight(A5)
	JSR		DrawIt			; XOR new rect, oval, etc.
	
	MOVE.L		topLeft(A3),topLeft(A2)	; Copy newRect to oldRect
	MOVE.L		botRight(A3),botRight(A2)
	BRA		DrawLoop		; and loop
;
; Local routine to FramRect(tRect) or FrameOval(tRect)
; depending on value in D4
;
DrawIt	
	; tRect has rect to draw
	LEA		tRect(A5),A0		; Point to tRect
	MOVE		bottom(A0),D0		; First, sort v points in rect
	CMP		top(A0),D0
	BGE		@1			; Skip if in order
	MOVE		top(A0),bottom(A0)	; Else swap points
	MOVE		D0,top(A0)

@1	MOVE		right(A0),D0		; Now sort h points
	CMP		left(A0),D0
	BGE		@2			; Skip if in order
	MOVE		left(A0),right(A0)	; Else swap points
	MOVE		D0,left(A0)


@2	MOVE.L		A0,-(SP)		; Push pointer to tRect
	CMP		#2,D4			; Boxes?
	BNE		@3			; No, skip
	JSR		Sync			; Sync with video
	; PROCEDURE FrameRect( r: Rect);	; Else Frame Rect
	_FrameRect
@3	CMP		#3,D4			; Ovals?
	BNE		@9			; No, skip
	JSR		Sync			; Sync with video
	; PROCEDURE FrameOval( r: Rect);	; Else Frame Oval
	_FrameOval

@9	RTS					; and return

; Local routine to synchronize with video
;
Sync	; FUNCTION TickCount: LongInt;
	SUBQ		#4,SP			; Room for result
	_TickCount
@1	SUBQ		#4,SP			; Get it again
	_TickCount
	MOVE.L		(SP)+,D0		; Get tickCount in D0
	CMP.L		(SP),D0			; Has it changed?
	BEQ		@1			; No, loop
	ADDQ		#4,SP			; else pop old tickCount
	RTS					; and return
; -------------------------------- Location -------------------------------	
; Write mouse coordinates on screen.
; (Calls WriteNum in SampMenu.Asm)
;
Location
	;PROCEDURE GetMouse (VAR mouseLoc: Point);
	MOVE.L		A4,-(SP)		; Point to mouse point
	_GetMouse				; Get coordinates
	JSR		Sync			; Sync with video
	MOVE		h(A4),D1		; h location
	MOVE		#13,D0			; Line number
	LEA		'h location: ',A0	; Label string
	JSR		WriteNum		; Write to screen

	JSR		Sync			; Sync with video
	MOVE		v(A4),D1		; h location
	MOVE		#14,D0			; Line number
	LEA		'v location: ',A0	; Label string
	JSR		WriteNum		; Write to screen

	;Function StillDown: BOOLEAN
	SUBQ		#2,SP			; Space for result
	_StillDown				; Mouse button still down?
	TST.B		(SP)+			; Check result
	BNE		Location		; Loop if button down

	BRA		CReturn			; else return

; -------------------------------------------------------------------------	

CReturn	; PROCEDURE SetPenState(pnState: PenState);
	PEA		pnState(A5)			; Restore pen state
	_SetPenState
	MOVEM.L		(SP)+,D4/A2-A4		; Restore register
	RTS					; and return
	
; ------------------------------ Global Data ------------------------------
; This data space is allocated relative to A5 (globals pointer)
; All global read/write data should be stored here.

point	DS.L		1		; mouse point stored here

tPoint	DS.L		1		; Temporary point storage

tRect	DS.W		4		; temp rectangle

oldRect	DS.W		4		; old rectangle				

newRect	DS.W		4		; new rectangle
	
pnState	DS.W		9		; Pen state record

	END