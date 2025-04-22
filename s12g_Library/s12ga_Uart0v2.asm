	include	"s12ga_240.sfr"
	include	"s12ga_Uart0v2.sfr"
	title	"s12ga_Uart0v2  Copyright (C) 2009-2020, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_Uart0v2.asm
;
;Copyright:	(C) 2009-2020, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	20.03.2020
;
;Description:	Funktionen für die serielle RS232-Kommunikation über SCI0,
;		aufrufkompatibel zum Treiber s12c_SoftUart.asm.
;------------------------------------------------------------------------------
;Revision History:	Original Version  04.09
;
;03.03.2020	Funktionen SCI_INT, SCI_RX_INT_* und SCI_TX_INT_* neu
;28.09.2016	zur Verwendung mit SCI0
;		Herkunft: s12ga_Uart_1.asm
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
;
;begin 03.03.2020
 if fBlockIO == _true
	xref	CRC16_X25		;
 endif
;end
;
					;
	xref	BUS_CLK			;Number
	xref	BAUDRATE_REL		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
;
;begin 03.03.2020
 if fBlockIO == _true
	xdef	SCI_INT			;Code
 endif
;end
;
					;
	xdef	SCI_RESET		;Code
	xdef	SCI_READ8		;Code
	xdef	SCI_STATUS		;Code
	xdef	SCI_TX_DISABLE		;Code
	xdef	SCI_TX_ENABLE		;Code
	xdef	SCI_TX_STATUS		;Code
					;
;
;begin 03.03.2020
 if fBlockIO == _true
	xdef	SCI_RX_INT_DISABLE	;Code
	xdef	SCI_RX_INT_ENABLE	;Code
	xdef	SCI_RX_INT_STATUS	;Code
	xdef	SCI_TX_INT_DISABLE	;Code
	xdef	SCI_TX_INT_ENABLE	;Code
	xdef	SCI_TX_INT_STATUS	;Code
 endif
;end
;
					;
	xdef	SCI_WRITE8		;Code
					;
;
;begin 03.03.2020
 if fBlockIO == _true
	xdef	SCI_TX_CTR		;Data
	xdef	SCI_TX_PTR		;Data
	xdef	SCI_RX_CTR		;Data
	xdef	SCI_RX_PTR		;Data
	xdef	SCI_RX_CRC16		;Data
 endif
;end
;
					;
	xdef	E_SCI_TIMEOUT		;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
E_SCI_TIMEOUT:	equ	-1
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section

		align	2		;
BOV:
;
;begin 03.03.2020
 if fBlockIO == _true
SCI_TX_PTR:	ds.w	1		;
SCI_TX_CTR:	ds.w	1		;
					;
SCI_RX_PTR:	ds.w	1		;
SCI_RX_CTR:	ds.w	1		;
SCI_RX_CRC16:	ds.w	1		;
 endif
;end
;
TOV:
					;
.text:		section
					;
;
;begin 03.03.2020
 if fBlockIO == _true
;------------------------------------------------------------------------------
;Public: SCI_INT gibt nächstes Zeichen aus dem Blockpuffer aus.
;
;Priorität:		normal
;Interruptquelle:	SCI0SR1._TC
;Auslöser:		Transmission Complete Flag gesetzt
;			Receiver Full Flag gesetzt
;Initialisierung:       s12ga_Uart0v2.asm
;
;Eingangsparameter:	SCI0SR1._TC
;			SCI0SR1._RDRF
;			SCI_TX_CTR
;			SCI_TX_PTR
;			SCI_RX_CTR
;			SCI_RX_PTR
;Ausgangsparameter:	SCI_TX_CTR
;			SCI_TX_PTR
;			SCI_RX_CTR
;			SCI_RX_PTR
;			SCI0SR1._TC
;			SCI0SR1._RDRF
;			SCI0CR2._TCIE
;			SCI0CR2._RIE
;veränderte Register:	keine
;------------------------------------------------------------------------------
					;
SCI_INT:
	BRCLR	SCI0SR1,_TC,SCI_INT2	;wenn Ausgaberegister frei,
					;
	LDD	SCI_TX_CTR		;und Bytezähler > 0,
	BEQ	SCI_INT1		;
					;
	LDX	SCI_TX_PTR		;dann
	LDAA	1,X+			;  nächstes Zeichen aus dem Blockbuffer lesen
	STX	SCI_TX_PTR		;
	STAA	SCI0DRL			;  und ausgeben
	LDD	SCI_TX_CTR		;
	SUBD	#1			;  Bytezähler decrementieren
	STD	SCI_TX_CTR		;  wenn Bytezähler danach = 0,
	BNE	SCI_INT2		;  dann
					;
SCI_INT1:
	BCLR	SCI0CR2,_TCIE		;    Transmission Complete Interrupts sperren
					;
SCI_INT2:
	BRCLR	SCI0SR1,_RDRF,SCI_INT9	;wenn Empfangsregister voll,
					;
	LDD	SCI_RX_CTR		;und Bytezähler > 0,
	BEQ	SCI_INT4		;
					;
	LDX	SCI_RX_PTR		;dann
	LDAA	SCI0DRL			;  nächstes Zeichen aus dem Empfangsregister lesen
	STAA	1,X+			;
	STX	SCI_RX_PTR		;  und im Blockbuffer ablegen
					;
;
;begin 07.03.2020
;fFaster:	equ	1

; if fFaster = 0
;	LDX	R4			;
;	MOVW	SCI_RX_CRC16,R4		;
;	JSR	CRC16_X25		;  lokalen Prüfcode aktualisieren
;	LDD	SCI_RX_CTR		;
;	CPD	#2			;  letzte beide Bytes (= übertragener Prüfcode)
;	BLS	SCI_INT3		;  nicht bei CRC-Bildung berücksichtigen
;	MOVW	R4,SCI_RX_CRC16		;
;SCI_INT3:
;	STX	R4			;
; else
	LDD	SCI_RX_CTR		;
; endif
;end
;
					;
	SUBD	#1			;  Bytezähler decrementieren
	STD	SCI_RX_CTR		;  wenn Bytezähler danach = 0,
	BNE	SCI_INT9		;  dann

SCI_INT4:
	BCLR	SCI0CR2,_RIE		;    Receiver Full Interrupts sperren
					;
SCI_INT9:
	RTI				;
					;
;------------------------------------------------------------------------------
;Public: SCI_RX_INT_DISABLE sperrt Uart-Empfangsinterrupts.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCI0CR2._RIE
;veränderte Register:	CCR, A, B, X
;------------------------------------------------------------------------------
					;
SCI_RX_INT_DISABLE:
	BCLR	SCI0CR2,_RIE		;Receiver Full Interrupts sperren
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_RX_INT_ENABLE gibt Uart-Empfangsinterrupts frei.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCI0CR2._RIE
;veränderte Register:	CCR, A, B, X
;------------------------------------------------------------------------------
					;
SCI_RX_INT_ENABLE:
	BSET	SCI0CR2,_RIE		;Receiver Full Interrupts freigeben
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_RX_INT_STATUS gibt an, ob Uart-Empfangsinterrupts freigegeben sind.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0 = Receiver Full Interrupts gesperrt
;					<> 0 = Receiver Full Interrupts freigegeben
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_RX_INT_STATUS:
	LDAA	SCI0CR2			;
	ANDA	#_RIE			;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_INT_DISABLE sperrt Uart-Sendeinterrupts.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCI0CR2._TCIE
;veränderte Register:	CCR, A, B, X
;------------------------------------------------------------------------------
					;
SCI_TX_INT_DISABLE:
	BCLR	SCI0CR2,_TCIE		;Transmission Complete Interrupts sperren
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_INT_ENABLE gibt Uart-Sendeinterrupts frei.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCI0CR2._TCIE
;veränderte Register:	CCR, A, B, X
;------------------------------------------------------------------------------
					;
SCI_TX_INT_ENABLE:
	BSET	SCI0CR2,_TCIE		;Transmission Complete Interrupts freigeben
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_INT_STATUS gibt an, ob Uart-Sendeinterrupts freigegeben sind.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0 = Transmission Complete Interrupts gesperrt
;					<> 0 = Transmission Complete Interrupts freigegeben
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_INT_STATUS:
	LDAA	SCI0CR2			;
	ANDA	#_TCIE			;
	RTS				;
					;
 endif
;end
;
;------------------------------------------------------------------------------
;Public: SCI_RESET bringt die Uart-Schnittstelle in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A
;------------------------------------------------------------------------------
					;
SCI_RESET:
;
;begin 03.03.2020
	MOVB	#0,SCI0SR2		;
;end
;
	MOVW	#BAUDRATE_REL,SCI0BD	;Baudraten-Reloadwert
	MOVB	#00000000b,SCI0CR1	;8 Datenbits, 1 Stoppbit, kein Parity
	LDAA	SCI0CR2			;
	ANDA	#00000100b		;
	ORAA	#00000100b		;RxD aktiv, TxD inaktiv (!)
	STAA	SCI0CR2			;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_STATUS liefert den Status der Uart-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		Funktionsstatus
;			B		Portstatus
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_STATUS:
	LDAA	SCI0SR1			;Status lesen
	TAB				;
	ANDB	#11110000b		;Fehler-Flags rücksetzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_DISABLE sperrt den Sendeausgang der Uart-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCI0CR2._TE
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_DISABLE:
	BCLR	SCI0CR2,_TE		;_TE rücksetzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_ENABLE aktiviert den Sendeausgang der Uart-Schnittstelle
;und setzt ihn auf '1'.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	TX_DIR._TX
;			TX_PORT._TX
;			SCI0CR2._TE
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_ENABLE:
	BSET	SCI0CR2,_TE		;_TE setzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_STATUS liefert den Ein-/Ausschaltzustand des Sendeausganges
;der Uart-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0	= gesperrt
;					<> 0	= aktiv
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_STATUS:
	LDAA	SCI0CR2			;
	ANDA	#_TE			;_TE abfragen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_READ8 liest ein Zeichen aus dem Uart-Empfangsregister.
;
;Eingangsparameter:	SCI0SR1._RDRF
;Ausgangsparameter:	SCI0SR1._RDRF
;			CCR.C		clr 	= Zeichen empfangen
;					set 	= kein neues Zeichen
;  wenn CCR.C = clr	A		empfangenes Zeichen
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_READ8:
					;wenn neues Zeichen da,
	BRCLR	SCI0SR1,_RDRF,SCI_READ8_8
					;dann
	LDAA	SCI0DRL			;  Zeichen nach A
	CLC				;  mit CCR.C = 0 zurück
	BRA	SCI_READ8_9		;
					;
SCI_READ8_8:
	SEC				;kein neues Zeichen, mit CCR.C = 1 zurück
					;
SCI_READ8_9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_WRITE8 schreibt ein Zeichen in das Uart-Senderegister.
;
;Eingangsparameter:	A		zu sendendes Zeichen
;			SCI0SR1._TDRE
;Ausgangsparameter:	SCI0SR1._TDRE
;			A		0	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, X
;------------------------------------------------------------------------------
					;
SCI_WRITE8:
	LDX	#BUS_CLK		;
	EXG	D,X			;
	LSRD				;
	LSRD				;Timeout maximal ca. 2 ms
	EXG	D,X			;
					;
SCI_WRITE8_1:
	BRSET	SCI0SR1,_TC,SCI_WRITE8_2
	DBNE	X,SCI_WRITE8_1		;warten, bis Transmitter bereit
	LDAA	#E_SCI_TIMEOUT		;
	BRA	SCI_WRITE8_9		;nach Timeout mit Fehler zurück
					;
SCI_WRITE8_2:
	STAA	SCI0DRL			;sonst Zeichen ausgeben
	CLRA				;ok, mit A = 0 zurück
					;
SCI_WRITE8_9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
