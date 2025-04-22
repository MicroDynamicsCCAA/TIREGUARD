	include	"s12c_128.sfr"
	include	"tg3Switches.sfr"
	include	"s12c_RFRecline.sfr"
	title	"s12c_RFRecline  Copyright (C) 2008, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_RFRECline.asm
;
;Copyright:	(C) 2008, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	15.09.2008
;
;Description:
;
;Folgende Bezeichner sind in s12c_RFRecline.sfr zu definieren:
;
;Bits:		_RF_CI
;		_RF_CF
;
;Ports:		RF_TC
;		RF_TCTL
;
;Data:		C_TCTLVAL
;
;------------------------------------------------------------------------------
;Revision History:	Original Version  09.08
;
;------------------------------------------------------------------------------
					;
 ifne fDebug
	xref	TEST_BUF
	xref	B_TEST_BUF
	xref	T_TEST_BUF
	xref	TEST_CTR
	xref	TEST_VAL
 endif
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	RF_DATA0_CT		;Number
	xref	RF_DATA1_CT		;Number
	xref	RF_DATA_LIM		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	RF_RESET		;Code
	xdef	RF_READ			;Code
	xdef	RF_STATUS		;Code
					;
	xdef	RF_INT			;Code
					;
	xdef.b	E_RF_QUEUEEMPTY		;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
E_RF_QUEUEEMPTY:	equ	-4	;
					;
RC_IGNORE:		equ	-1	;
					;
RX_MSG_SIZE:		equ	10	;
RX_MSG_BUF_CNT:		equ	8	;Größe des Empfangsbuffers
					;
C_RX_BIT0:		equ	00h	;
C_RX_BIT1:		equ	80h	;
					;
C_RX_SYNC:		equ	0FFFEh	;
C_CRC_START:		equ	0000h	;
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:
	even
;
;TEST
		ds.b	1
;TEST
;

RXBUF:		ds.b	RX_MSG_SIZE	;Telegramm-Empfangsbuffer

CRC16:					;DATA16: CRC-Prüfcode
CRC16_HI:	ds.b	1		;
CRC16_LO:	ds.b	1		;

pRXBUF:		ds.w	1		;DATA16: Zeiger in Telegramm-Empfangsbuffer
					;
	even


B_RX_MSG_BUF:				;Telegramm-Ringspeicher
		ds.b	RX_MSG_BUF_CNT * RX_MSG_SIZE
T_RX_MSG_BUF:
					;
pRX_MSG_RD:	ds.w	1		;DATA16: Ringspeicher-Lesezeiger
pRX_MSG_WR:	ds.w	1		;DATA16: Ringspeicher-Schreibzeiger
					;
RX_MSG_CTR:	ds.b	1		;DATA8: aktuelle Anzahl Telegramme im Ringspeicher

RXFLAGS:	ds.b	1		;DATA8: Flags
_HALF:		equ	bit0
;
;
;
;
;
;
;
RXCAPTN0:	ds.w	1		;Data16:
RXCAPTN1:	ds.w	1		;Data16:
RXBITTIME:	ds.w	1		;DATA16:
					;
RXSTEP:		ds.b	1		;DATA8: Receive Step Register
RXCCTR:		ds.b	1		;DATA8: Receive Character Counter Register
RXBCTR:		ds.b	1		;DATA8: Receive Bit Counter Register
RXSHFT:		ds.b	1		;DATA8: Receive Shift Register
RXBIT:		ds.b	1		;DATA8:

REG1:		ds.b	1
REG2:		ds.b	1
					;
;
;TEST
MSG_CTR:	ds.w	1
;TEST
;
					;
	even
TOV:
					;
.text:		section
					;
;------------------------------------------------------------------------------
;SWAP_A tauscht High- und Low-Nibble des A-Registers.
;
;Eingangsparameter:	A
;Ausgangsparameter:	A
;veränderte Register:	CCR, B
;------------------------------------------------------------------------------
					;
SWAP_A:
	LSRD				;
	LSRD				;
	LSRD				;
	LSRD				;
	ANDA	#00001111b		;
	ANDB	#11110000b		;
	ABA				;
	RTS				;
					;
;------------------------------------------------------------------------------
;CRC_UPDATE aktualisiert den CRC16 Prüfcode. Der Berechnung liegt das
;CRC16-CCITT Polynom zugrunde.
;
;Eingangsparameter:	A		Datenbyte
;			CRC16		CRC-Prüfcode
;Ausgangsparameter:	CRC16		CRC-Prüfcode
;veränderte Register:	CCR, B
;------------------------------------------------------------------------------
					;
CRC_UPDATE:
	EORA	CRC16_HI		;
	STAA	REG1			;
	ANDA	#0F0h			;
	STAA	REG2			;
	LDAA	REG1			;
	JSR	SWAP_A			;
	EORA	REG2			;
	STAA	REG1			;
					;
;High Byte
	TAB				;
	LSLD				;
	ANDA	#01Fh			;
	EORA	CRC16_LO		;
	STAA	CRC16_HI		;
	LDAA	REG1			;
	ANDA	#0F0h			;
	TAB				;
	EORA	CRC16_HI		;
	STAA	CRC16_HI		;
					;
;Low Byte
	TBA				;
	ABA				;
	STAA	CRC16_LO		;
	LDAA	REG1			;
	JSR	SWAP_A			;
	EORA	CRC16_LO		;
	STAA	CRC16_LO		;
	RTS				;
					;
;------------------------------------------------------------------------------
;DETECT_BIT

;Eingangsparameter:	keine
;Ausgangsparameter:	A
;veränderte Register:	CCR, B
;------------------------------------------------------------------------------

DETECT_BIT:
	LDD	RF_TC			;Capture Register lesen
	STD	RXCAPTN0		;und Wert speichern
	SUBD	RXCAPTN1		;Differenz zu letztem Capture-Wert bilden
	STD	RXBITTIME		;neuen bit-Zeitwert retten
					;
	BRSET	RXFLAGS,_HALF,DETECT_BIT2
					;
;------------------------------------------------------------------------------
;Test auf 1
;
					;
	LDD	RXBITTIME		;
	SUBD	#RF_DATA1_CT		;'1'-bit-Zeit von gemessener Zeit subtrahieren
	BCC	DETECT_BIT1		;wenn Ergebnis negativ,
	COMA				;dann
	COMB				;  2er-Komplement bilden
	ADDD	#1			;
DETECT_BIT1:
	CPD	#RF_DATA_LIM		;wenn gültige '1'-bit-Zeit
	BHI	DETECT_BIT2		;dann
					;
	MOVB	#C_RX_BIT1,RXBIT	;  gültiges '1'-bit empfangen
	BCLR	RXFLAGS,_HALF		;
	CLRA				;  ok, mit A = 0 zurück
	BRA	DETECT_BIT9		;
					;
;------------------------------------------------------------------------------
;Test auf 0
;
DETECT_BIT2:
	LDD	RXBITTIME		;
	SUBD	#RF_DATA0_CT		;'0'-halb-bit-Zeit von gemessener Zeit subtrahieren
	BCC	DETECT_BIT3		;wenn Ergebnis negativ,
	COMA				;dann
	COMB				;  2er-Komplement bilden
	ADDD	#1			;
DETECT_BIT3:
	CPD	#RF_DATA_LIM		;wenn gültige '0'-halb-bit-Zeit,
	BHI	DETECT_BIT8		;dann
					;
	BRSET	RXFLAGS,_HALF,DETECT_BIT4
					;  nach erster Takthälfte:
	BSET	RXFLAGS,_HALF		;
	LDAA	#RC_IGNORE		;    RXFLAGS._HALF setzen
	BRA	DETECT_BIT9		;    und zweite bit-Hälfte abwarten
					;  nach zweiter Takthälfte:
DETECT_BIT4:
	MOVB	#C_RX_BIT0,RXBIT	;    gültiges '0'-bit empfangen
					;
	BCLR	RXFLAGS,_HALF		;    RXFLAGS._HALF rücksetzen
	CLRA				;    ok, mit A = 0 zurück
	BRA	DETECT_BIT9		;
					;
;------------------------------------------------------------------------------
;Fehler
;
DETECT_BIT8:
	JSR	TERMINATE_RX		;Telegramm-Empfang abbrechen
	LDAA	#RC_IGNORE		;
					;
DETECT_BIT9:
	MOVW	RXCAPTN0,RXCAPTN1	;alten mit neuem Capture-Wert überschreiben
	MOVB	#_RF_CF,TFLG1		;Capture Interrupt quittieren
	BSET	TIE,_RF_CI		;Interrupts freigeben
	RTS				;

;------------------------------------------------------------------------------
;RF_INT			Pegelwechsel 0/1 oder 1\0 Interrupt
;
;Priorität:		normal
;Interruptsquelle:	TFLG1._C?F
;Auslöser:		Timer Channel ? Capture Event
;Initialisierung:	Module 's12c_RFRecline'
;
;Eingangsparameter:	RXSTEP
;			RXCCTR
;			RXBCTR
;			pRXBUF
;Ausgangsparameter:	RXSTEP
;			RXCCTR
;			RXBCTR
;			pRXBUF
;			TIE._RF_CI
;Laufzeit:		ca. ? µs max	@ 24 MHz
;------------------------------------------------------------------------------
					;
RF_INT:
	JSR	DETECT_BIT		;wenn gültiges Datembit empfangen,
	CMPA	#0			;
	BNE	RF_INT9			;dann
					;
	LDAB	RXSTEP			;
	CMPB	#LOW(RX_JMP_TBL_CNT)	;
	BLO	RF_INT1			;
	CMPB	#LOW(RX_JMP_TBL_CNT-1)	;
RF_INT1:
	CLRA				;  Code nach A:B
	LSLD				;  *2 ergibt Offset in Adressentabelle
	LDX	#RX_JMP_TBL		;
	JSR	[D,X]			;  Aufruf des Unterprogrammes
					;
RF_INT9:
	RTI				;
					;
RX_JMP_TBL:
	dc.w	STEP0_RX
	dc.w	STEP1_RX
	dc.w	TERMINATE_RX
					;
RX_JMP_TBL_CNT:		equ	(* - RX_JMP_TBL) / 2
					;
;------------------------------------------------------------------------------
;RX-Step 0
;Receive Synchron Word (= 0FFFEh)
;=> Step 1
					;
STEP0_RX:
	LSL	RXBIT			;neues Bit ins Carry und
	ROL	RXSHFT			;von da ins Empfangsregister schieben
	LDAA	RXSHFT			;wenn Empfangsregister das Low Byte
	CMPA	#LOW(C_RX_SYNC)		;des Synchronwortes enthält,
	BNE	STEP0_RX9		;dann
					;
	MOVW	#RXBUF,pRXBUF		;  Zeiger auf Anfang des Telegramm-Empfangsbuffers
	MOVW	#C_CRC_START,CRC16	;  CRC-Prüfcode auf Startwert
	MOVB	#RX_MSG_SIZE,RXCCTR	;  Zeichenzähler auf Startwert: 10 Bytes Datentelegramm
	MOVB	#8,RXBCTR		;  Bitzähler auf Startwert
					;
	MOVB	#1,RXSTEP		;  mit Step 1 fortfahren
					;
STEP0_RX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RX-Step 1
;Receive Data Telegram
;=> Step 0
					;
STEP1_RX:
	LSL	RXBIT			;neues Bit ins Carry und
	ROL	RXSHFT			;von da ins Empfangsregister schieben
	DEC	RXBCTR			;Bitzähler decrementieren
	BNE	STEP1_RX9		;wenn Bitzähler danach = 0,
					;
	LDY	pRXBUF			;dann
	LDAA	RXSHFT			;  empfangenes Byte
	STAA	1,Y+			;  im Telegramm-Empfangsbuffer ablegen und
	STY	pRXBUF			;  Zeiger in Telegramm-Empfangsbuffer verschieben
	JSR	CRC_UPDATE		;  CRC-Prüfcode aktualisieren
	MOVB	#0,RXSHFT		;  Empfangsregister fegen
	MOVB	#8,RXBCTR		;  Bitzähler auf Startwert
	DEC	RXCCTR			;  Zeichenzähler decrementieren
	BNE	STEP0_RX9		;  wenn danach Zeichenzähler = 0,
					;  dann
	LDD	CRC16
	BNE	STEP1_RX8

;hier noch umspeichern und Flag setzen

	LDY	MSG_CTR
	INY
	STY	MSG_CTR

STEP1_RX8:
	MOVB	#0,RXSTEP		;    auf nächstes Telegramm warten...
					;
STEP1_RX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;TERMINATE_RX
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
TERMINATE_RX:
	MOVB	#0,RXCCTR
	MOVB	#0,RXBCTR
	MOVB	#0,RXSHFT
	MOVB	#0,RXSTEP
	MOVB	#0,RXFLAGS

	MOVW	#RXBUF,pRXBUF

	LDD	#B_RX_MSG_BUF		;
	STD	pRX_MSG_RD		;
	STD	pRX_MSG_WR		;

	MOVB	#C_TCTLVAL,RF_TCTL	;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: RF_RESET
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
RF_RESET:
	LDY	#BOV			;Anfang der Systemvariablen
	LDX	#(TOV - BOV)		;Anzahl Bytes
	LDAA	#0			;Füllwert
RF_RESET1:
	STAA	1,Y+			;
	DBNE	X,RF_RESET1		;alle Variablen auf Füllwert setzen
					;
;
;TEST
	LDY	#RXBUF
	LDAA	#0BDh
	LDAB	#RX_MSG_SIZE
RF_RESET2:
	STAA	1,Y+
	DBNE	B,RF_RESET2
;TEST
;
	JSR	TERMINATE_RX		;
					;
	MOVB	#_RF_CF,TFLG1		;
	BSET	TIE,_RF_CI		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: RF_STATUS liefert den Status des RF-Moduls.
;
;Definition des in A zurückgegebenen Status:
;
;bit0-3	aktuelle Anzahl der im Ringspeicher befindlichen RF-Empfangstelegramme
;bit4
;bit5
;bit6
;bit7
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		RF-Modul Status
;veränderte Register:	CCR, B
;------------------------------------------------------------------------------
					;
RF_STATUS:
	LDAA	RX_MSG_CTR		;
	ANDA	#00001111b		;

	LDAB	RXFLAGS
	ANDB	#11110000b
	ABA

	RTS				;
					;
;------------------------------------------------------------------------------
;Public: RF_READ
;
;Eingangsparameter:	R4/R5		Zeiger auf Datenfeld
;Ausgangsparameter:	R4/R5		bleibt unverändert!
;			A		0	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, X, Y
;------------------------------------------------------------------------------
					;
RF_READ:

	;
	LDAA	#E_RF_QUEUEEMPTY
	;

RF_READ9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
