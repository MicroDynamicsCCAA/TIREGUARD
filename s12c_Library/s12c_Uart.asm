	include	"s12c_128.sfr"
	title	"s12c_Uart  Copyright (C) 2009, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_Uart.asm
;
;Copyright:	(C) 2009, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	29.07.2009
;
;Description:	Funktionen f�r die serielle RS232-Kommuniktion �ber SCI0,
;		weitgehend aufrufkompatibel zum Treiber s12c_SoftUart.asm.
;
;------------------------------------------------------------------------------
;Revision History:	Original Version  04.09
;
;29.07.2009	Diverse Korrekturen
;29.06.2009	Funktionen SCI_INT und SCI_TX_INT_? neu
;		Korrektur in SCI_WRITE8
;11.06.2009	Konstante f�r Baudraten-Reloadwert umbenannt
;18.05.2009	Basis
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
	xdef	SCI_INT			;Code

	xdef	SCI_RESET		;Code
	xdef	SCI_READ8		;Code
	xdef	SCI_STATUS		;Code
	xdef	SCI_TX_DISABLE		;Code
	xdef	SCI_TX_ENABLE		;Code
	xdef	SCI_TX_STATUS		;Code

	xdef	SCI_TX_INT_DISABLE	;Code
	xdef	SCI_TX_INT_ENABLE	;Code
	xdef	SCI_TX_INT_STATUS	;Code

	xdef	SCI_WRITE8		;Code
					;
	xdef	SCI_SECTOR_BUF		;Data
	xdef	SCI_SECTOR_CRC		;Data
	xdef	SCI_SECTOR_CTR		;Data
	xdef	SCI_SECTOR_PTR		;Data
					;
	xdef	E_SCI_TIMEOUT		;Number
					;
	xdef	SCI_SECTOR_SIZE		;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
E_SCI_TIMEOUT:		equ	-1	;
					;
;
;begin 29.06.2009
SCI_SECTOR_SIZE:	equ	512	;512 Bytes Sektorbuffer
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section

		align	2		;
BOV:
					;
SCI_SECTOR_BUF:	ds.b	SCI_SECTOR_SIZE	;
SCI_SECTOR_CRC:	ds.w	1		;
SCI_SECTOR_PTR:	ds.w	1		;
SCI_SECTOR_CTR:	ds.w	1		;
					;
SCI_FLAGS:	ds.b	1		;
;
;
;
;
;
;
;
;
					;
TOV:
					;
.text:		section
					;
;
;begin 29.06.2009
;------------------------------------------------------------------------------
;Public: SCI_INT gibt n�chstes Zeichen aus dem Sektorpuffer aus.
;
;Priorit�t:		normal
;Interruptquelle:	SCI0SR1._TC
;Ausl�ser:		Transmit Complete Flag gesetzt
;Initialisierung:       s12c_Uart.asm
;
;Eingangsparameter:	SCI_SECTOR_CTR
;			SCI_SECTOR_PTR
;Ausgangsparameter:	SCI_SECTOR_CTR
;			SCI_SECTOR_PTR
;			SCI0CR2._TCIE
;ver�nderte Register:	keine
;------------------------------------------------------------------------------
					;
SCI_INT:
;
;begin 29.07.2009
	BRCLR	SCI0SR1,_TC,SCI_INT9	;wenn Ausgaberegister frei,
					;
	LDD	SCI_SECTOR_CTR		;und Bytez�hler > 0,
	BEQ	SCI_INT8		;
					;
;end
;
	LDX	SCI_SECTOR_PTR		;dann
	LDAA	1,X+			;  n�chstes Zeichen aus Sektorpuffer lesen
	STX	SCI_SECTOR_PTR		;
	STAA	SCI0DRL			;  und ausgeben
;
;begin 29.07.2009
	LDD	SCI_SECTOR_CTR		;
	SUBD	#1			;  Bytez�hler decrementieren
	STD	SCI_SECTOR_CTR		;  wenn Bytez�hler danach = 0,
	BNE	SCI_INT9		;  dann
					;
SCI_INT8:
	BCLR	SCI0CR2,_TCIE		;    Transmit Complete Interrupts sperren
;end
;
					;
SCI_INT9:
	RTI				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_INT_DISABLE sperrt Uart-Sendeinterrupts.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCI0CR2._TCIE
;ver�nderte Register:	CCR, A, B, X
;------------------------------------------------------------------------------
					;
SCI_TX_INT_DISABLE:
	BCLR	SCI0CR2,_TCIE		;Transmit Complete Interrupts sperren
;
;begin 29.07.2009
;end
;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_INT_ENABLE gibt Uart-Sendeinterrupts frei.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCI0CR2._TCIE
;ver�nderte Register:	CCR, A, B, X
;------------------------------------------------------------------------------
					;
SCI_TX_INT_ENABLE:
	BSET	SCI0CR2,_TCIE		;Transmit Complete Interrupts freigeben
;
;begin 29.07.2009
;end
;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_INT_STATUS gibt an, ob Uart-Sendeinterrupts freigegeben sind.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0 	= TC-Interrupts gesperrt
;					<> 0	= TC-Interrupts freigegeben
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_INT_STATUS:
;
;begin 29.07.2009
	LDAA	SCI0CR2			;
	ANDA	#_TCIE			;
;end
;
	RTS				;
;end
;
					;
;------------------------------------------------------------------------------
;Public: SCI_RESET bringt die Uart-Schnittstelle in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_RESET:
	MOVB	#0,SCI0SR2		;
	MOVW	#BAUDRATE_REL,SCI0BD	;Baudraten-Reloadwert
	MOVB	#00000000b,SCI0CR1	;8 Datenbits, 1 Stoppbit, kein Parity
	LDAA	SCI0CR2			;
	ANDA	#00000100b		;
	ORAA	#00000100b		;RxD aktiv, TxD inaktiv (!)
	STAA	SCI0CR2			;
					;
;
;begin 29.07.2009
	MOVW	#0,SCI_SECTOR_CTR	;Blockausgabe-Zeichenz�hler auf null
;end
;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_STATUS liefert den Status der Uart-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		Funktionsstatus
;			B		Portstatus
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_STATUS:
	LDAA	SCI0SR1			;Status lesen
	TAB				;
	ANDB	#11110000b		;Fehler-Flags r�cksetzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_DISABLE sperrt den Sendeausgang der Uart-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCICR2._TE
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_DISABLE:
	BCLR	SCI0CR2,_TE		;_TE r�cksetzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_ENABLE aktiviert den Sendeausgang der Uart-Schnittstelle
;und setzt ihn auf '1'.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	TX_DIR._TX
;			TX_PORT._TX
;			SCICR2._TE
;ver�nderte Register:	CCR
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
;ver�nderte Register:	CCR
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
;Eingangsparameter:	SCISR1._RDRF
;Ausgangsparameter:	SCISR1._RDRF
;			CCR.C		clr 	= Zeichen empfangen
;					set 	= kein neues Zeichen
;  wenn CCR.C = clr	A		empfangenes Zeichen
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_READ8:
;
;begin 29.07.2009
					;wenn neues Zeichen da,
	BRCLR	SCI0SR1,_RDRF,SCI_READ8_8
					;dann
	LDAA	SCI0DRL			;  Zeichen nach A
;end
;
	CLC				;  mit CCR.C = 0 zur�ck
	BRA	SCI_READ8_9		;
					;
SCI_READ8_8:
	SEC				;kein neues Zeichen, mit CCR.C = 1 zur�ck
					;
SCI_READ8_9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_WRITE8 schreibt ein Zeichen in das Uart-Senderegister.
;
;Eingangsparameter:	A		zu sendendes Zeichen
;			SCI0SR1._TC
;Ausgangsparameter:	SCI0SR1._TC
;			A		0	= ok
;					<> 0	= Fehlercode
;ver�nderte Register:	CCR, B, X
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
;
;begin 29.06.2009
	BRSET	SCI0SR1,_TC,SCI_WRITE8_2;
;end
;
	DBNE	X,SCI_WRITE8_1		;warten, bis Transmitter bereit
	LDAA	#E_SCI_TIMEOUT		;
	BRA	SCI_WRITE8_9		;nach Timeout mit Fehler zur�ck
					;
SCI_WRITE8_2:
	STAA	SCI0DRL			;sonst Zeichen ausgeben
;
;begin 29.06.2009
;end
;
	CLRA				;ok, mit A = 0 zur�ck
					;
SCI_WRITE8_9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
