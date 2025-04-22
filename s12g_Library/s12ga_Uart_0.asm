	include	"s12ga_240.sfr"
	title	"s12ga_Uart_0  Copyright (C) 2009-2016, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_Uart_0.asm
;
;Copyright:	(C) 2009-2016, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	28.09.2016
;
;Description:	Funktionen für die serielle RS232-Kommunikation über SCI0,
;		aufrufkompatibel zum Treiber s12c_SoftUart.asm.
;------------------------------------------------------------------------------
;Revision History:	Original Version  04.09
;
;28.09.2016	zur Verwendung mit SCI0
;		Herkunft: s12ga_Uart_1.asm
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	BUS_CLK			;Number
	xref	BAUDRATE_REL		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	SCI_RESET		;Code
	xdef	SCI_READ8		;Code
	xdef	SCI_STATUS		;Code
	xdef	SCI_TX_DISABLE		;Code
	xdef	SCI_TX_ENABLE		;Code
	xdef	SCI_TX_STATUS		;Code
	xdef	SCI_WRITE8		;Code
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
					;
BOV:
TOV:
					;
.text:		section
					;
;------------------------------------------------------------------------------
;Public: SCI_RESET bringt die Uart-Schnittstelle in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, X, Y
;------------------------------------------------------------------------------
					;
SCI_RESET:
	BCLR	SCI0SR2,_AMAP		;
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
