	include	"s12ga_240.sfr"
	include	"s12ga_LINMaster.sfr"
	title	"s12ga_LINMaster  Copyright (C) 2005-2014, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_LINMaster.asm
;
;Copyright:	(C) 2005-2014, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	01.12.2014
;
;Description:	Funktionen f�r einen LIN Master-Knoten �ber ein prozessor-
;		internes SCI-Modul des Freescale MC9S12GA240
;
;Folgende Bezeichner sind in s12ga_LINMaster.sfr zu definieren:
;
;Ports:		LIN_BD		(SCIxBD)	Baudrate Register
;		LIN_CR1		(SCIxCR1)	Control Register 1
;		LIN_CR2		(SCIxCR2)	Control Register 2
;		LIN_SR1		(SCIxSR1)	Status Register 1
;		LIN_SR2		(SCIxSR2)	Status Register 2
;		LIN_DR		(SCIxDRL)	Data Register
;
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;01.12.2014	Anpassung an MC9S12GA240
;		Herkunft: s12c_LINMASTER.asm
;
;24.11.2006
;08.11.2006	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	BUS_CLK			;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	LIN_INT			;Code
					;
	xdef	LIN_CREATE_PARITY	;Code
	xdef	LIN_READ		;Code
	xdef	LIN_REQUEST		;Code
	xdef	LIN_RESET		;Code
	xdef	LIN_STATUS		;Code
	xdef	LIN_WRITE		;Code
					;
	xdef.b	E_LIN_BUSY		;Number
	xdef.b	E_LIN_INVALID_ID	;Number
	xdef.b	E_LIN_LENGTH		;Number
	xdef.b	E_LIN_NO_DATA		;Number
	xdef.b	E_LIN_OVERRUN		;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
E_LIN_BUSY:		equ	-1
;
E_LIN_INVALID_ID:	equ	-3
E_LIN_LENGTH:		equ	-4
E_LIN_NO_DATA:		equ	-5
E_LIN_OVERRUN:		equ	-6
					;
C_SYNC_BREAK:		equ	00h
C_SYNC_FIELD:		equ	55h	;

;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:
					;
LIN_FLAGS:	ds.b	1		;Flags
_E_OVERRUN:	equ	bit0		;1 bei LIN_REQUEST vor dem Abholen empfangener Daten
_E_BIT:		equ	bit1		;1 nach Bitfehler
_E_FRAME:	equ	bit2		;1 nach allgemeinem �bertragungsfehler
_E_CHKSUM:	equ	bit3		;1 nach Pr�fsummenfehler
_E_BREAK:	equ	bit4		;1 nach Abbruch einer laufenden Frame-�bertragung
_NEWDAT:	equ	bit5		;1, wenn neue Daten abgeholt werden k�nnen
_RX:		equ	bit6		;1, wenn Daten empfangen werden
_BUSY:		equ	bit7		;1, w�hrend der �bertragung eines Datenobjektes
					;
FRAME_STATE:	ds.b	1		;Frame-Ablaufsteuerung
_BREAK:		equ	bit0		;1, wenn SyncBreak gesendet
_SYNC:		equ	bit1		;1, wenn SyncField gesendet
_MSG_ID:	equ	bit2		;1, wenn Message-ID gesendet
_DATA:		equ	bit3		;1, wenn Datensegment gesendet / empfangen
_CHKSUM:	equ	bit4		;1, wenn Pr�fsumme gesendet / empfangen
;					;
;					;
_READBACK:	equ	bit7		;1, wenn Echo auf Bitfehler gepr�ft werden soll
					;
		even
LIN_SYNCRATE:	ds.w	1		;DATA16: Baudraten Reloadwert f�r SyncBreak
LIN_BAUDRATE:	ds.w	1		;DATA16: Standard Baudraten Reloadwert
					;
LIN_MESSAGE_ID:	ds.b	1		;DATA8: Identifier mit Pr�fbits
					;
LIN_DATA_BUF:	ds.b	8		;8*DATA8: Datenbuffer
LIN_DATA_CHKSUM:
		ds.b	1		;DATA8: Pr�fsumme
LIN_DATA_CTR:	ds.b	1		;DATA8: Bytez�hler f�r Daten�bertragung
					;
		even
pLIN_DATA:	ds.w	1		;DATA16: Zeiger in Datenbuffer
					;
LIN_READ_CNT:	ds.b	1		;DATA8: Anzahl empfangener Datenbytes nach LIN_REQUEST
LIN_READBACK:	ds.b	1		;DATA8: Datenbyte-Zwischenspeicher f�r Echopr�fung
					;
TOV:
					;
.text:		section
					;
;------------------------------------------------------------------------------
;Public: LIN_INT	LIN-Interrupt Handler
;
;Priorit�t:		normal
;Interruptquelle:	LIN_SR1._RDRF
;Ausl�ser:		Daten wurden vom Empfangs-Schieberegister in das
;			Empfangs-Datenregister �bertragen
;Initialisierung:	Module	's12ga_LINMaster'
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	keine
;Laufzeit:		ca. 18 �s	@ 8 MHz Bustakt
;------------------------------------------------------------------------------
					;
LIN_INT:
	BRCLR	LIN_SR1,_RDRF,LIN_INT9	;nur RDRF-Ereignis behandeln
					;
	JSR	CHECK_READBACK		;gesendete mit zur�ckgelesenen Daten vergleichen
	JSR	FRAME_HANDLE		;Frame-�bertragung fortsetzen
					;
	BRCLR	LIN_SR1,_RDRF |_OR, LIN_INT9
					;wenn jetzt _RDRF oder _OR gesetzt,
	LDAA	LIN_DR			;dann Datenregister lesen
	BRCLR	LIN_SR1,_OR, LIN_INT9	;wenn jetzt _OR gesetzt,
	LDAA	LIN_DR			;dann noch einmal Datenregister lesen
					;
LIN_INT9:
	RTI				;
					;
;------------------------------------------------------------------------------
;CHECK_READBACK vergleicht zur�ckgelesene mit gesendeten Daten und setzt bei
;Ungleichheit ein Fehlerflag.
;
;Eingangsparameter:	LIN_READBACK
;			FRAME_STATE._READBACK
;			LIN_READBACK
;Ausgangsparameter:	LIN_FLAGS._E_BIT
;			FRAME_STATE._READBACK
;ver�nderte Register:	CCR, A
;------------------------------------------------------------------------------
					;
CHECK_READBACK:
	BRCLR	FRAME_STATE,_READBACK,CHECK_READBACK9
					;wenn FRAME_STATE._READBACK Flag gesetzt,
	LDAA	LIN_SR1			;dann
	ANDA	#00000111b		;  wenn _NF, _FE oder _PF gesetzt ist,
	BEQ	CHECK_READBACK1		;  dann
	BSET	LIN_FLAGS,_E_BIT	;    _E_BIT setzen
CHECK_READBACK1:
	LDAA	LIN_DR			;
	CMPA	LIN_READBACK		;  wenn zur�ckgelesene nicht gleich gesendeten Daten,
	BEQ	CHECK_READBACK2		;  dann
	BSET	LIN_FLAGS,_E_BIT	;    _E_BIT setzen
CHECK_READBACK2:
	BCLR	FRAME_STATE,_READBACK	;  FRAME_STATE._READBACK Flag r�cksetzen
					;
CHECK_READBACK9:
	RTS				;
					;
;------------------------------------------------------------------------------
;TRANSMIT_BYTE sendet ein Byte.
;
;Eingangsparameter:	A		Zeichen
;Ausgangsparameter:	LIN_READBACK
;			LIN_FLAGS._E_FRAME
;			FRAME_STATE._READBACK
;			A		Zeichen
;ver�nderte Register:	CCR, X
;------------------------------------------------------------------------------
					;
TRANSMIT_BYTE:
	LDX	#BUS_CLK		;BUS_CLK / 4
	EXG	X,D			;
	LSRD				;
	LSRD				;Timeout maximal ca. 2 ms
	EXG	D,X			;
					;
TRANSMIT_BYTE1:
	BRSET	LIN_SR1,_TDRE,TRANSMIT_BYTE2
	DBNE	X,TRANSMIT_BYTE1	;warten, bis Transmitter bereit
	BSET	LIN_FLAGS,_E_FRAME	;nach Timeout mit Fehler zur�ck
	BRA	TRANSMIT_BYTE9		;
					;
TRANSMIT_BYTE2:
	STAA	LIN_DR			;sonst Zeichen ausgeben
	STAA	LIN_READBACK		;und f�r die Echopr�fung merken
	BSET	FRAME_STATE,_READBACK	;
					;
TRANSMIT_BYTE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RECEIVE_BYTE empf�ngt ein Datenbyte.
;Sonderfall: Erster Interrupt zu Beginn des Empfanges eines Datenfeldes
;liefert Echo der Message-ID und noch kein Datenbyte.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		Datenbyte
;			LIN_FLAGS._E_BIT
;			CCR.C		clr	= Datenbyte ist g�ltig
;					set	= noch kein g�ltiges Datenbyte empfangen
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
RECEIVE_BYTE:
	BRSET	LIN_SR1,_RDRF,RECEIVE_BYTE1
	SEC				;kein Zeichen da,
	BRA	RECEIVE_BYTE9		;mit CCR.C zur�ck
					;
RECEIVE_BYTE1:
	LDAA	LIN_SR1			;
	ANDA	#00000111b		;wenn _NF, _FE oder _PF gesetzt ist
	BEQ	RECEIVE_BYTE2		;dann
	BSET	LIN_FLAGS,_E_BIT	;  _E_BIT setzen
					;
RECEIVE_BYTE2:
	LDAA	LIN_DR			;
	CLC				;ok, mit CCR.NC zur�ck
					;
RECEIVE_BYTE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;TRANSMIT_DATA sendet das aus 1 - 8 Bytes bestehende Datenfeld und die
;abschlie�ende Pr�fsumme eines Frames des Slaves im LIN-Masterknoten.
;
;Eingangsparameter:	pLIN_DATA
;			LIN_DATA_CHKSUM
;			LIN_DATA_CTR
;			FRAME_STATE
;Ausgangsparameter:	pLIN_DATA
;			LIN_DATA_CHKSUM
;			LIN_DATA_CTR
;			LIN_FLAGS._BUSY
;			FRAME_STATE
;ver�nderte Register:	CCR, X
;------------------------------------------------------------------------------
					;
TRANSMIT_DATA:
	BRSET	FRAME_STATE,_DATA,TRANSMIT_DATA2
	LDX	pLIN_DATA		;
	LDAA	1,X+			;
	STX	pLIN_DATA		;Zeiger verschieben
	JSR	TRANSMIT_BYTE		;Datenbyte ausgeben
	ADDA	LIN_DATA_CHKSUM		;
	ADCA	#0			;Pr�fsumme aktualisieren
	STAA	LIN_DATA_CHKSUM		;
	DEC	LIN_DATA_CTR		;Z�hler decrementieren
	BNE	TRANSMIT_DATA1		;
	BSET	FRAME_STATE,_DATA	; > SEND DATA SEGMENT
TRANSMIT_DATA1:
	BRA	TRANSMIT_DATA9		;
					;
TRANSMIT_DATA2:
	BRSET	FRAME_STATE,_CHKSUM,TRANSMIT_DATA3
	LDAA	LIN_DATA_CHKSUM		;
	COMA				;
	JSR	TRANSMIT_BYTE		;Pr�fsumme erg�nzen
	BSET	FRAME_STATE,_CHKSUM	; > SEND CHECKSUM
	BRA	TRANSMIT_DATA9		;
					;
TRANSMIT_DATA3:
	BCLR	LIN_FLAGS,_BUSY		; > FRAME COMPLETED
					;
TRANSMIT_DATA9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RECEIVE_DATA empf�ngt das aus 1 - 8 Bytes bestehende Datenfeld und die
;abschlie�ende Pr�fsumme von einem angeschlossenen LIN-Slave.
;
;Eingangsparameter:     pLIN_DATA
;			LIN_DATA_CHKSUM
;			LIN_DATA_CTR
;			LIN_READ_CNT
;Ausgangsparameter:	pLIN_DATA
;			LIN_DATA_CHKSUM
;			LIN_DATA_CTR
;			LIN_READ_CNT
;			LIN_FLAGS._E_CHKSUM
;			LIN_FLAGS,_BUSY
;			FRAME_STATE
;ver�nderte Register:	CCR, Y
;------------------------------------------------------------------------------
					;
RECEIVE_DATA:
	JSR	RECEIVE_BYTE		;
	BCS     RECEIVE_DATA9		;
					;
	BRSET	FRAME_STATE,_DATA,RECEIVE_DATA2
	LDY	pLIN_DATA		;
	STAA	1,Y+			;Datenbyte speichern
	STY	pLIN_DATA		;Zeiger verschieben
	ADDA	LIN_DATA_CHKSUM		;
	ADCA	#0			;Pr�fsumme aktualisieren
	STAA	LIN_DATA_CHKSUM		;
	INC	LIN_READ_CNT		;Z�hler empfangener Datenbytes incrementieren
	DEC	LIN_DATA_CTR		;Z�hler decrementieren
	BNE	RECEIVE_DATA1		;
	BSET	FRAME_STATE,_DATA	; > RECEIVE DATA SEGMENT
RECEIVE_DATA1:
	BRA	RECEIVE_DATA9		;
					;
RECEIVE_DATA2:
	BRSET	FRAME_STATE,_CHKSUM,RECEIVE_DATA4
	COMA				;
	EORA	LIN_DATA_CHKSUM		;Pr�fsumme auswerten
	BEQ	RECEIVE_DATA3		;
	BSET	LIN_FLAGS,_E_CHKSUM	;
RECEIVE_DATA3:
	BSET	FRAME_STATE,_CHKSUM	; > RECEIVE CHECKSUM
	BSET	LIN_FLAGS,_NEWDAT	;
					;
RECEIVE_DATA4:
	BCLR	LIN_FLAGS,_BUSY		; > FRAME COMPLETED
					;
RECEIVE_DATA9:
	RTS				;
					;
;------------------------------------------------------------------------------
;FRAME_HANDLE sendet den Botschafts-Kopf und liefert bzw. empf�ngt das
;Botschafts-Datenfeld.
;
;Eingangsparameter:	FRAME_STATE
;Ausgangsparameter:	FRAME_STATE
;ver�nderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
FRAME_HANDLE:
	BRSET	FRAME_STATE,_BREAK,FRAME_HANDLE1
	MOVW	LIN_SYNCRATE,LIN_BD	;
	LDAA	#C_SYNC_BREAK		;
	JSR	TRANSMIT_BYTE		;
	BSET	FRAME_STATE,_BREAK	; > SLOW BIT-RATE AND SEND 00h
	BRA	FRAME_HANDLE9		;
					;
FRAME_HANDLE1:
	BRSET	FRAME_STATE,_SYNC,FRAME_HANDLE2
	MOVW	LIN_BAUDRATE,LIN_BD	;
	LDAA	#C_SYNC_FIELD		;
	JSR	TRANSMIT_BYTE		;
	BSET	FRAME_STATE,_SYNC	; > RESET BIT_RATE AND SEND 55h
	BRA	FRAME_HANDLE9		;
					;
FRAME_HANDLE2:
	BRSET	FRAME_STATE,_MSG_ID,FRAME_HANDLE3
	LDAA	LIN_MESSAGE_ID		;
	JSR	TRANSMIT_BYTE		;
	BSET	FRAME_STATE,_MSG_ID	; > SEND MESSAGE-ID
	BRA	FRAME_HANDLE9		;
					;
FRAME_HANDLE3:
	BRSET	LIN_FLAGS,_RX,FRAME_HANDLE4
					;
	JSR	TRANSMIT_DATA		; > SEND DATA-FIELD
	BRA	FRAME_HANDLE9		;
					;
FRAME_HANDLE4:
	JSR	RECEIVE_DATA		; > RECEIVE DATA FIELD
					;
FRAME_HANDLE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LIN_RESET bringt das LIN-Modul in Grundstellung und startet es.
;
;Eingangsparameter:	R0/R1		Baudraten-Einstellwert
;			R2		Anzahl Datenbits und Stoppbits, Parity
;Ausgangsparameter:	LIN_BAUDRATE
;			LIN_SYNCRATE
;			LIN_FLAGS
;			FRAME_STATE
;ver�nderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
LIN_RESET:
	LDY	#BOV			;Anfang der Systemvariablen
	LDX	#(TOV - BOV)		;Anzahl Bytes
	LDAA	#0			;F�llwert
LIN_RESET1:
	STAA	1,Y+			;
	DBNE	X,LIN_RESET1		;alle Variablen auf F�llwert setzen
					;
	MOVB	#0001111b,FRAME_STATE	;
	MOVB	#0,LIN_FLAGS		;
					;
	LDD	R0			;
	STD	LIN_BAUDRATE		;Baudrate merken
	LSLD				;
	STD	LIN_SYNCRATE		;SyncBreak Baudrate merken
					;
	MOVW	R0,LIN_BD		;Baudrate einstellen
	MOVB	R2,LIN_CR1		;Datenbits, Stoppbits und Parity einstellen
	MOVB	#00001100b,LIN_CR2	;Senden und Empfangen aktiv
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LIN_STATUS liefert den Status des LIN-Modules.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		LIN-Modul Status
;			LIN_STATE._E_OVERRUN
;			LIN_STATE._E_BIT
;			LIN_STATE._E_FRAME
;			LIN_STATE._E_CHKSUM
;			LIN_STATE._E_BREAK
;ver�nderte Register:	CCR, B
;------------------------------------------------------------------------------
					;
LIN_STATUS:
	LDAA	LIN_FLAGS		;LIN-Flags lesen
	TAB				;
	ANDB	#11100000b		;Fehler-Flags r�cksetzen
	STAB	LIN_FLAGS		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LIN_CREATE_PARITY berechnet die Parit�tsbits des Message-Identifiers
;und f�gt sie dort ein.
;
;Berechnungsvorschrift:
;
;P0 = bit0 XOR bit1 XOR bit2 XOR bit4	;gerade Parit�t
;P1# = bit1 XOR bit3 XOR bit4 XOR bit5	;ungerade Parit�t
;
;Eingangsparameter:	R1		Message-Identifier
;Ausgangsparameter:	R1		Message-Identifier mit erg�nzten Pari�tsbits
;ver�nderte Register:	CCR, A, B
;------------------------------------------------------------------------------
					;
LIN_CREATE_PARITY:
	LDAA	R1			;
	ANDA	#00111111b		;Paritybits r�cksetzen
	STAA	R1			;
					;
	LSRD				;---
	LSRD				;
	LSRD				;
	LSRD				;SWAP A
	ANDA	#00001111b		;
	ANDB	#11110000b		;
	ABA				;---
					;
	LDAB	R1			;bereinigter Identifier nach B
					;
	EORA	R1			;get (ID0 xor ID4), (ID1 xor ID5)
	STAA	R1			;1. Teilergebnis nach R1
					;
	LSRA				;
	LSRA				;
	EORA	R1			;get (ID0 xor ID2 xor ID4), (ID1 xor ID3 xor ID5)
	STAA	R1			;2. Teilergebnis nach R1
					;
	TBA				;
	LSRA				;
	EORA	R1			;get (ID0 xor ID1 xor ID2 xor ID4), (ID1 xor ID3 xor ID4 xor ID5)
	STAA	R1			;3. Teilergebnis nach R1
					;
	TBA				;
	ORAA	#10000000b		;
	BRCLR	R1,00001000b,LIN_CREATE_PARITY1
	ANDA	#01111111b		;set P1
LIN_CREATE_PARITY1:
	BRCLR	R1,00000001b,LIN_CREATE_PARITY2
	ORAA	#01000000b		;set P0
					;
LIN_CREATE_PARITY2:
	STAA	R1			;
	RTS				;
					;
;------------------------------------------------------------------------------
;BREAK bricht eine laufende �bertragung ab.
;
;Eingangsparameter:	LIN_FLAGS._RX
;			FRAME_STATE
;Ausgangsparameter:	FRAME_STATE
;ver�nderte Register:	CCR, A, X
;------------------------------------------------------------------------------
					;
BREAK:
	BRCLR	LIN_FLAGS,_RX,BREAK1	;
	LDAA	FRAME_STATE		;
	ANDA	#00000111b		;
	CMPA	#00000111b		;
	BEQ	BREAK9			;wenn LIN-Master sendet
					;
BREAK1:
	LDAA	FRAME_STATE		;dann
	ORAA	#00011111b		;  evtl. laufende �bertragung abbrechen
	STAA	FRAME_STATE		;
					;
	LDX	#BUS_CLK		;  BUS_CLK / 4
	EXG	X,D			;
	LSRD				;
	LSRD				;  Timeout maximal ca. 2 ms
	EXG	D,X			;
					;
BREAK2:
	BRCLR	LIN_SR1,_TC,BREAK3	;
	BRCLR	FRAME_STATE,_READBACK,BREAK9
BREAK3:
	DBNE	X,BREAK2		;  warten, bis LIN_SR1._TC gesetzt
					;  und FRAME_STATE._READBACK r�ckgesetzt
	BSET	LIN_FLAGS,_E_FRAME	;  nach Timeout mit Fehler zur�ck
					;
BREAK9:
	RTS				;
					;
;------------------------------------------------------------------------------
;PREPARE_FRAME bereitet einen Frame f�r die �bertragung vor.
;
;Eingangsparameter:	R1		Message-Identifier
;			R3		Anzahl Bytes des folgenden Datenobjektes
;			LIN_FLAGS._BUSY
;			LIN_FLAGS._NEWDAT
;Ausgangsparameter:	LIN_MESSAGE_ID
;			LIN_DATA_CHKSUM
;			LIN_DATA_CTR
;			LIN_STATE._E_BREAK
;			LIN_STATE._E_OVERRUN

;			LIN_FLAGS._BREAK
;			LIN_FLAGS._SYNC
;			LIN_FLAGS._MSG_ID
;			LIN_FLAGS._BUSY
;			A		0	= ok
;					<> 0	= Fehlercode
;ver�nderte Register:	CCR, B, X
;------------------------------------------------------------------------------
					;
PREPARE_FRAME:
	BRCLR	LIN_FLAGS,_BUSY,PREPARE_FRAME1
	BSET	LIN_FLAGS,_E_BREAK	;
	JSR	BREAK			;
					;
PREPARE_FRAME1:
	BRCLR	LIN_FLAGS,_NEWDAT,PREPARE_FRAME2
	BSET	LIN_FLAGS,_E_OVERRUN	;
					;
PREPARE_FRAME2:
	BCLR	LIN_FLAGS,_BUSY | _NEWDAT
	MOVB	#0,FRAME_STATE		;Flags r�cksetzen
					;
	LDAA	R1			;
	CMPA	#3Fh			;wenn Message-Identifier > 63,
	BLS	PREPARE_FRAME3		;dann
	LDAA	#E_LIN_INVALID_ID	;  Fehler: ung�ltiger Identifier
	BRA	PREPARE_FRAME9		;
					;
PREPARE_FRAME3:
	LDAA	R3			;
	BEQ	PREPARE_FRAME4		;
	CMPA	#8			;wenn Message-L�nge = 0 oder > 8,
	BLS	PREPARE_FRAME5		;dann
PREPARE_FRAME4:
	LDAA	#E_LIN_LENGTH		;  Fehler: ung�ltige Message-L�nge
	BRA	PREPARE_FRAME9		;
					;
PREPARE_FRAME5:
	JSR	LIN_CREATE_PARITY	;
	MOVB	R1,LIN_MESSAGE_ID	;Message-Identifier
	MOVW	#LIN_DATA_BUF,pLIN_DATA	;Zeiger auf Startwerte
	MOVB	#0,LIN_DATA_CHKSUM	;Pr�fsumme auf Null
	MOVB	#0,LIN_READ_CNT		;Anzahl empfangener Datenbytes
	MOVB	R3,LIN_DATA_CTR		;Anzahl zu �bertragender Datenbytes
	BCLR	LIN_CR2,_TCIE | _TIE | _ILIE
	BSET	LIN_CR2,_RIE		;nur RDRF-Interrupt freigeben
	CLRA				;ok, mit A = 0 zur�ck
					;
PREPARE_FRAME9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LIN_READ liest ein Datenobjekt aus dem Empfangsbuffer und legt es
;im Variablenspeicher ab.
;
;Eingangsparameter:	R4/R5		Zeiger auf Variablenspeicher
;			LIN_MESSAGE_ID
;			LIN_DATA_BUF
;			LIN_DATA_CTR
;			LIN_FLAGS._NEWDAT
;Ausgangsparameter:	R1		Message-Identifier
;			R3		Anzahl Bytes des empfangenen Datenobjektes
;			LIN_FLAGS._NEWDAT
;			A		0	= ok
;					<> 0	= Fehlercode
;ver�nderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
LIN_READ:
	BRSET	LIN_FLAGS,_NEWDAT,LIN_READ1
	LDAA	#E_LIN_NO_DATA		; > NEWDAT BIT SET ?
	BRA	LIN_READ9		;
					;
LIN_READ1:
	LDX	#LIN_DATA_BUF		;
	LDY	R4			;
	LDAA	LIN_READ_CNT		;
	BEQ	LIN_READ2		;wenn Anzahl empfangener Bytes = 0 oder > 8,
	CMPA	#8			;
	BLS	LIN_READ3		;dann
LIN_READ2:
	BSET	LIN_FLAGS,_E_FRAME	;  Fehler: allgemeiner �bertragungsfehler
	BRA	LIN_READ5		;
					;
LIN_READ3:
	MOVB	LIN_READ_CNT,R3		;
LIN_READ4:
	MOVB	1,X+,1,Y+		; > READ DATA SEGMENT
	DEC	R3			;
	BNE	LIN_READ4		;
					;
	LDAA	LIN_MESSAGE_ID		;
	ANDA	#00111111b		;Parity-bits maskieren
	STAA	R1			;
	MOVB	LIN_READ_CNT,R3		;
					;
LIN_READ5:
	BCLR	LIN_FLAGS,_NEWDAT	; > RESET NEWDAT BIT
	CLRA				;ok, mit A = 0 zur�ck
					;
LIN_READ9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LIN_WRITE sendet ein Datenobjekt.
;
;Eingangsparameter:	R1		Message-Identifier
;			R3		Anzahl Bytes des Datenobjektes
;			R4/R5		Zeiger auf Variablenspeicher
;			LIN_FLAGS._BUSY
;			LIN_FLAGS,_NEWDAT
;Ausgangsparameter:	LIN_MESSAGE_ID
;			LIN_DATA_BUF
;			LIN_DATA_CHKSUM
;			LIN_DATA_CTR
;			LIN_FLAGS._E_BREAK
;			LIN_FLAGS._E_OVERRUN
;			LIN_FLAGS._BUSY
;			LIN_FLAGS._RX
;			FRAME_STATE
;			A		0	= ok
;					<> 0	= Fehlercode
;ver�nderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
LIN_WRITE:
	JSR	PREPARE_FRAME		;Message vorbereiten
	BNE	LIN_WRITE9		;
					;
	LDX	R4			;
	LDY	#LIN_DATA_BUF		;
LIN_WRITE1:
	MOVB	1,X+,1,Y+		;Daten in Sendbuffer eintragen
	DEC	R3			;
	BNE	LIN_WRITE1		;
					;
	BCLR	LIN_FLAGS,_RX		;
	BSET	LIN_FLAGS,_BUSY		;
	JSR	FRAME_HANDLE		;
	CLRA				;ok, mit A = 0 zur�ck
					;
LIN_WRITE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: LIN_REQUEST fordert ein Datenobjekt an.
;
;Eingangsparameter:	R1		Message-Identifier
;			R3		Anzahl Bytes des Datenobjektes
;			LIN_FLAGS._BUSY
;			LIN_FLAGS,_NEWDAT
;Ausgangsparameter:	LIN_MESSAGE_ID
;			LIN_DATA_CHKSUM
;			LIN_DATA_CTR
;			LIN_FLAGS._E_BREAK
;			LIN_FLAGS._E_OVERRUN
;			LIN_FLAGS._BUSY
;			LIN_FLAGS._RX
;			FRAME_STATE
;			A		0	= ok
;					<> 0	= Fehlercode
;ver�nderte Register:	CCR, A, B, Y
;------------------------------------------------------------------------------
					;
LIN_REQUEST:
	JSR	PREPARE_FRAME		;Message vorbereiten
	BNE	LIN_REQUEST9		;
					;
	BSET	LIN_FLAGS,_RX		;
	BSET	LIN_FLAGS,_BUSY		;
	JSR	FRAME_HANDLE		;
	CLRA				;ok, mit A = 0 zur�ck
					;
LIN_REQUEST9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
