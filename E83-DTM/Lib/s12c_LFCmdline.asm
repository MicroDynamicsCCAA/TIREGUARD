	include	"s12c_128.sfr"
	include	"s12c_LFCmdline.sfr"
	title	"s12c_LFCmdline  Copyright (C) 2008, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_LFCmdline.asm
;
;Copyright:	(C) 2008, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	04.09.2008
;
;Description:
;
;Folgende Bezeichner sind in s12c_LFCmdline.sfr zu definieren:
;
;Bits:		_LF_CI
;		_LF_CF
;		_TX
;
;Ports:		LF_TC
;		TX_PORT
;		TX_DIR
;
;------------------------------------------------------------------------------
;Revision History:	Original Version  09.08
;
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	BUS_CLK			;Number
					;
	xref	LF_DATA0_CT		;Number
	xref	LF_DATA1_CT		;Number
	xref	LF_PAUSE_CT		;Number
	xref	LF_PREAMBLE_CT		;Number
	xref	LF_TIMEOUT_CT		;Number
	xref	LF_WAKE_CT		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	LF_RESET		;Code
	xdef	LF_READ			;Code
	xdef	LF_WRITE		;Code
					;
	xdef	LF_TX_INT		;Code
					;
	xdef.b	E_LF_CANNOTRECEIVE	;Number
	xdef.b	E_LF_CANNOTTRANSMIT	;Number
	xdef.b	E_LF_CODE		;Number
	xdef	E_LF_TIMEOUT		;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
					;
E_LF_TIMEOUT:		equ	-1	;
E_LF_CODE:		equ	-2	;
E_LF_CANNOTTRANSMIT:	equ	-5	;
E_LF_CANNOTRECEIVE:	equ	-5	;
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:

FLAGS:		ds.b	1
;
;
;
;
;
;
;_TC:		equ	bit6
;_TDRE:		equ	bit7

TXSTEP:		ds.b	1		;Transmit Step Register
TXCCTR:		ds.b	1		;Transmit Character Counter Register
TXBCTR:		ds.b	1		;Transmit Bit Counter Register
TXSHFT:		ds.b	1		;Transmit Shift Register
TXBPR:		ds.w	1		;Transmit Bit Pause Register
					;
	even
pTXBUF:		ds.w	1		;Transmit Data Pointer
TXBUF:		ds.b	16		;Transmit Data Buffer

	even
TOV:
					;
.text:		section
					;
;------------------------------------------------------------------------------
;LF_TX_INT		LF-Code Sendeinterrupt
;
;Priorität:		normal
;Interruptsquelle:	TFLG1._C?F
;Auslöser:		Timer Channel ? Compare Event
;Initialisierung:	Module 's12c_LFCmdline'
;
;Eingangsparameter:	TXSTEP
;			TXCCTR
;			TXBCTR
;			pTXBUF
;Ausgangsparameter:	TXSTEP
;			TXCCTR
;			TXBCTR
;			pTXBUF
;Laufzeit:		ca. ? µs max	@ 24 MHz
;------------------------------------------------------------------------------

LF_TX_INT:
	LDAB	TXSTEP			;
	CMPB	#LOW(TX_JMP_TBL_CNT)	;
	BLO	LF_TX_INT1		;
	LDAB	#LOW(TX_JMP_TBL_CNT-1)	;
LF_TX_INT1:
	CLRA				;Code nach A:B
	LSLD				;*2 ergibt Offset in Adressentabelle
	LDX	#TX_JMP_TBL		;
	JSR	[D,X]			;Aufruf des Unterprogrammes
					;
LF_TX_INT9:
	RTI				;
					;
TX_JMP_TBL:
	dc.w	STEP0_TX
	dc.w	STEP1_TX
	dc.w	STEP2_TX
	dc.w	STEP3_TX
	dc.w	TERMINATE_TX
					;
TX_JMP_TBL_CNT:		equ	(* - TX_JMP_TBL) / 2
					;
;------------------------------------------------------------------------------
;TX-Step 0
;Transmit Wake
;=> Step 1
					;
STEP0_TX:
	BRCLR	TX_PORT,_TX,STEP0_TX1	;
	BCLR	TX_PORT,_TX		;Port = 0
	LDD	#LF_WAKE_CT		;Wake
	BRA	STEP0_TX9		;
STEP0_TX1:
	BSET	TX_PORT,_TX		;Port = 1
	MOVB	#1,TXSTEP		;=> Step 1
	LDD	#LF_PAUSE_CT		;Pause
					;
STEP0_TX9:
	ADDD	LF_TC			;
	STD	LF_TC			;
	BSET	TIE,_LF_CI		;
	MOVB	#_LF_CF,TFLG1		;
	RTS				;
					;
;------------------------------------------------------------------------------
;TX-Step 1
;Transmit Preamble
;=> Step 2
					;
STEP1_TX:
	BRCLR	TX_PORT,_TX,STEP1_TX1	;
	BCLR	TX_PORT,_TX		;Port = 0
	LDD	#LF_PREAMBLE_CT		;Preamble
	BRA	STEP1_TX9		;
STEP1_TX1:
	BSET	TX_PORT,_TX		;Port = 1
	MOVB	#2,TXSTEP		;=> Step 2
	LDD	#LF_PAUSE_CT		;Pause
					;
STEP1_TX9:
	ADDD	LF_TC			;
	STD	LF_TC			;
	BSET	TIE,_LF_CI		;
	MOVB	#_LF_CF,TFLG1		;
	RTS				;
					;
;------------------------------------------------------------------------------
;TX-Step 2
;Prepare, start and terminate data bits transmission
;=> Step 3
					;
STEP2_TX:
	LDAA	TXCCTR			;
	CMPA	#0			;wenn Telegramm vollständig übertragen
	BNE	STEP2_TX1		;dann
	JSR	TERMINATE_TX		;  Übertragung beenden
	RTS				;
					;
STEP2_TX1:
	LDX	pTXBUF			;sonst
	MOVB	1,X+,TXSHFT		;  nächstes Zeichen in Schieberegister laden
	STX	pTXBUF			;
	LDAA	TXCCTR			;  Zeichenzähler decrementieren
	DECA				;
	STAA	TXCCTR			;
	CMPA	#0			;  wenn Zeichenzähler danach = 0,
	BNE	STEP2_TX2		;  dann
	BSET	FLAGS,_TDRE		;    ist Sendebuffer wieder frei
STEP2_TX2:
	MOVB	#8,TXBCTR		;  Bit-Zähler auf Startwert
	MOVB	#3,TXSTEP		;  => Step 3
					;
;------------------------------------------------------------------------------
;TX-Step 3
;Transmit data bits
;=> Step 2
					;
STEP3_TX:
	BRCLR	TX_PORT,_TX,STEP3_TX7	;
	BCLR	TX_PORT,_TX		;Port = 0
	LDAA	TXSHFT			;Transmit Shift Register
	LSLA				;nach links ins CARRY schieben
	STAA	TXSHFT			;
	BCS	STEP3_TX1		;wenn CARRY rückgesetzt,
	LDD	#LF_DATA0_CT		;  dann DATA0
	BRA	STEP3_TX2		;
STEP3_TX1:
	LDD	#LF_DATA1_CT		;  sonst DATA1
STEP3_TX2:
	BRA	STEP3_TX9		;
					;
STEP3_TX7:
	BSET	TX_PORT,_TX		;Port = 1
	DEC	TXBCTR			;Bitzähler decrementieren
	BNE	STEP3_TX8		;wenn Bitzähler = 0,
	MOVB	#2,TXSTEP		;  dann => Step 2
	LDD	#LF_PAUSE_CT		;  Byte-Pause
	LSLD				;
	BRA	STEP3_TX9		;

STEP3_TX8:
	MOVB	#3,TXSTEP		;  sonst => Step 3
	LDD	#LF_PAUSE_CT		;  Bit-Pause
					;
STEP3_TX9:
	ADDD    LF_TC			;
	STD	LF_TC			;
	BSET	TIE,_LF_CI		;
	MOVB	#_LF_CF,TFLG1		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Ende der Telegrammausgabe
;
;=> Step 0
					;
TERMINATE_TX:
	BSET	TX_PORT,_TX		;Port = 1
	MOVB	#0,TXCCTR		;Zeichenzähler auf 0
	MOVB	#0,TXBCTR		;Bit-Zähler auf 0
	BSET	FLAGS,_TDRE | _TC	;_TC und _TDRE setzen
	MOVB	#0,TXSTEP		;=> Step 0
	BCLR	TIE,_LF_CI		;Interrupt sperren
	MOVB	#_LF_CF,TFLG1		;schwebenden Interrupt quittieren
	RTS				;
					;
;------------------------------------------------------------------------------
;Start der Telegrammausgabe
;------------------------------------------------------------------------------
					;
START_TX:
	BSET	TX_PORT,_TX		;Port = 1
	LDD	#LF_PAUSE_CT		;
					;
	ADDD	TCNT			;
	STD	LF_TC			;Compare Register auf Startwert
	BSET	TIE,_LF_CI		;Interrupt freigeben
	MOVB	#_LF_CF,TFLG1		;schwebenden Interrupt quittieren
	BCLR	FLAGS,_TDRE	| _TC	;_TC und _TDRE rücksetzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LF_RESET
;
;Eingangsparameter:	keine

;Ausgangsparameter:	keine

;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
LF_RESET:
	LDY	#BOV			;Anfang der Systemvariablen
	LDX	#(TOV - BOV)		;Anzahl Bytes
	LDAA	#0			;Füllwert
LF_RESET1:
	STAA	1,Y+			;
	DBNE	X,LF_RESET1		;alle Variablen auf Füllwert setzen
					;
	BSR	TERMINATE_TX		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LF_READ
;
;Eingangsparameter:	R4/R5		Zeiger auf Datenfeld
;Ausgangsparameter:	R1		LF-Code
;			R4/R5		bleibt unverändert!
;			A		0	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR,
;------------------------------------------------------------------------------
					;
LF_READ:
	;
	LDAA	#E_LF_CANNOTRECEIVE	;currently not supported
	;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LF_WRITE
;
;Eingangsparameter:	R1		LF-Code
;			R4/R5		Zeiger auf Datenfeld
;Ausgangsparameter:     A		0	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR,
;------------------------------------------------------------------------------
					;
LF_WRITE:
	BRSET	FLAGS,_TC,LF_WRITE1	;
	LDAA	#E_LF_CANNOTTRANSMIT	;
	LBRA	LF_WRITE9		;
					;
LF_WRITE1:
	LDAB	R1			;
	CMPB	#LOW(LF_CODE_TX_JMP_TBL_CNT)
	BLO	LF_WRITE2		;
	LDAB	#LOW(LF_CODE_TX_JMP_TBL_CNT-1)
LF_WRITE2:
	CLRA				;Code nach A:B
	LSLD				;* 2 ergibt Offset in Adressentabelle
	LDX	#LF_CODE_TX_JMP_TBL	;
	JSR	[D,X]			;Aufruf des Unterprogrammes
	CMPA	#0			;
	LBNE	LF_WRITE9		;
					;
	STAB	TXCCTR			;
	STAA	TXSTEP			;
	MOVW	#TXBUF,pTXBUF		;
	JSR	START_TX		;
	CLRA				;ok, mit A = 0 zurück
					;
LF_WRITE9:
	RTS				;
					;
LF_CODE_TX_JMP_TBL:
	dc.w	LF_CODE0_TX
	dc.w	LF_ERROR_TX
	dc.w	LF_CODE2_TX
	dc.w	LF_CODE3_TX
	dc.w	LF_CODE4_TX
	dc.w	LF_CODE5_TX
	dc.w	LF_CODE6_TX
	dc.w	LF_CODE7_TX
	dc.w	LF_CODE8_TX
	dc.w	LF_ERROR_TX
	dc.w	LF_ERROR_TX
	dc.w	LF_ERROR_TX
	dc.w	LF_CODE12_TX
	dc.w	LF_ERROR_TX
					;
LF_CODE_TX_JMP_TBL_CNT:		equ	(* - LF_CODE_TX_JMP_TBL) / 2
					;
;-----------------------------------------------------------------------------
;LF_CODE0:	Transmission Request
;Structure:	Wake + P
;-----------------------------------------------------------------------------
					;
LF_CODE0_TX:
	LDD	#0			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_CODE2:	Transition mode 0a to mode Tb
;Structure:	Wake + P + Command (0x1E) + Identifier
;-----------------------------------------------------------------------------
					;
LF_CODE2_TX:
	LDAA	#1Eh			;
	STAA	TXBUF+0			;Command
	LDX	R4			;
	LDY	#TXBUF+1		;
	MOVW	2,X+,2,Y+		;Identifier
	MOVW	0,X,0,Y			;
	LDD	#5			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_CODE3:	Transition mode 0a/1a/1b/1c to mode Tc
;		Trigger in mode 2
;		Transition mode 1d to 1c
;Structure:	Wake + P + Command (0x2D)
;-----------------------------------------------------------------------------
					;
LF_CODE3_TX:
	LDAA	#2Dh			;
	STAA	TXBUF+0			;Command
	LDD	#1			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_CODE4:	Transmission mode 0a to mode Td
;Structure:	Wake + P + Command (0x3C) + Identifier
;-----------------------------------------------------------------------------
					;
LF_CODE4_TX:
	LDAA	#3Ch			;
	STAA	TXBUF+0			;Command
	LDX	R4			;
	LDY	#TXBUF+1		;
	MOVW	2,X+,2,Y+		;Identifier
	MOVW	0,X,0,Y			;
	LDD	#5			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_CODE5:	Transmission mode 1a/1b to mode 1c
;Structure:	Wake + P + Command (0x4B) + Identifier
;-----------------------------------------------------------------------------
					;
LF_CODE5_TX:
	LDAA	#4Bh			;
	STAA	TXBUF+0			;Command
	LDX	R4			;
	LDY	#TXBUF+1		;
	MOVW	2,X+,2,Y+		;Identifier
	MOVW	0,X,0,Y			;
	LDD	#5			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_CODE6:	Transmission mode 1c to mode 1a
;Structure:	Wake + P + Command (0x5A) + Identifier
;-----------------------------------------------------------------------------
					;
LF_CODE6_TX:
	LDAA	#5Ah			;
	STAA	TXBUF+0			;Command
	LDX	R4			;
	LDY	#TXBUF+1		;
	MOVW	2,X+,2,Y+		;Identifier
	MOVW	0,X,0,Y			;
	LDD	#5			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_CODE7:	Transmission mode 1a/1b/1c to mode 1e
;Structure:	Wake + P + Command (0x69) + Identifier
;-----------------------------------------------------------------------------
					;
LF_CODE7_TX:
	LDAA	#69h			;
	STAA	TXBUF+0			;Command
	LDX	R4			;
	LDY	#TXBUF+1		;
	MOVW	2,X+,2,Y+		;Identifier
	MOVW	0,X,0,Y			;
	LDD	#5			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_CODE8:	Transmission mode 0a to mode ParaWrite data set 1.
;Structure:
;   Part 1:	Wake + P + Command (0x78)
;		Pause
;   Part 2:	Wake + P + Command (0x78) + 15 Bytes data set 1
;-----------------------------------------------------------------------------
					;
LF_CODE8_TX:
	;				;
	LDAA	#E_LF_CODE		;currently not supported
	;				;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_CODE12:	Transmission mode 0a/1a/1b/1c to mode ParaRead data set 1.
;Structure:	Wake + P + Command (0xB4) + Identifier
;-----------------------------------------------------------------------------
					;
LF_CODE12_TX:
	LDAA	#0B4h			;
	STAA	TXBUF+0			;Command
	LDX	R4			;
	LDY	#TXBUF+1		;
	MOVW	2,X+,2,Y+		;Identifier
	MOVW	0,X,0,Y			;
	LDD	#5			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;LF_ERROR:
;-----------------------------------------------------------------------------
					;
LF_ERROR_TX:
	LDAA	#E_LF_CODE		;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
