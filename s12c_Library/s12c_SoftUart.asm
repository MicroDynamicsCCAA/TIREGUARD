	include	"s12c_128.sfr"
	include	"s12c_SoftUart.sfr"
	title	"s12c_SoftUart  Copyright (C) 2006, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_SoftUart.asm
;
;Copyright:	(C) 2006, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	24.11.2006
;
;Description:	Funktion für die Full-Duplex serielle RS232-Kommuniktion.
;
;Folgende Bezeichner sind in s12c_SoftUart.sfr zu definieren:
;
;Bits:		_RX
;		_TX
;
;Ports:		RX_DIR
;		RX_PORT
;		TX_DIR
;		TX_PORT
;
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.06
;
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	BUS_CLK			;Number
	xref	BD_9600x4_REL		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	SCI_INT			;Code
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
BIT_CT:		equ	4		;Anzahl Interrupts pro bit
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:
TXSTEP:		ds.b	1		;Transmit Step Register
TXICTR:		ds.b	1		;Transmit Interrupt Counter Register
TXBCTR:		ds.b	1		;Transmit Bit Counter Register
TXSHFT:					;Transmit Shift Register
TXSHFTH:	ds.b	1		;Transmit Shift Register High Byte
TXSHFTL:	ds.b	1		;Transmit Shift Register Low Byte
TXPAR:		ds.b	1		;Transmit Parity Register
					;
RXSTEP:		ds.b	1		;Receive Step Register
RXICTR:		ds.b	1		;Receive Interrupt Counter Register
RXBCTR:		ds.b	1		;Receive Bit Counter Register
RXSHFT:					;Receive Shift Register
RXSHFTH:	ds.b	1		;Receive Shift Register High Byte
RXSHFTL:	ds.b	1		;Receive Shift Register Low Byte
RXPAR:		ds.b	1		;Receive Parity Register
					;
;------------------------------------------------------------------------------
					;
SCIBD:		ds.w	1		;Baudrate Register
SCICR1:		ds.b	1		;Control Register 1
SCICR2:		ds.b	1		;Control Register 2
SCISR1:		ds.b	1		;Status Register
SCITDR:					;Transmit Data Register
SCITDRH:	ds.b	1		;Transmit Data Register High Byte
SCITDRL:	ds.b	1		;Transmit Data Register Low Byte
SCIRDR:					;Receive Data Register
SCIRDRH:	ds.b	1		;Receive Data Register High Byte
SCIRDRL:	ds.b	1		;Receive Data Register Low Byte
TOV:
					;
.text:		section
					;
;------------------------------------------------------------------------------
;SCI_INT		SoftUart-Interrupt
;
;Priorität:		normal
;Interruptquelle:	TFLG1._C6F
;Auslöser:              Timer Channel 6 Compare Event
;Initialisierung:	Module 's12c_SoftUart'
;
;Eingangsparameter:
;Ausgangsparameter:
;Laufzeit:		ca. 6 µs max.	@ 24 MHz
;------------------------------------------------------------------------------
					;
SCI_INT:
					;
;==============================================================================
;Transmitter Bit Clock
					;
	LDAA	TXSTEP			;wenn TXSTEP = 0,
	BEQ	SCI_INT1		;  dann sofort Ausgabe starten
					;
	LDAA	TXICTR			;sonst
	BEQ	SCI_INT1		;  wenn bit-Zeitzähler > 0,
	DECA				;    dann bit-Zeitzähler decrementieren
	STAA	TXICTR			;  wenn bit-Zeitzähler = 0
	BEQ	SCI_INT1		;    dann Ausgabe fortsetzen
					;
	LBRA	SCI_INT3		;sonst sofort zur Eingabefunktion
					;
;==============================================================================
;Transmit Data
					;
SCI_INT1:
	LDAB	TXSTEP			;
	CMPB	#LOW(TX_JMP_TBL_CNT)	;
	BLO	SCI_INT2		;
	LDAB	#LOW(TX_JMP_TBL_CNT-1)	;
SCI_INT2:
	CLRA				;Code nach A:B
	LSLD				;* 2 ergibt Offset in Adressentabelle
	LDX	#TX_JMP_TBL		;
	JSR	[D,X]			;Aufruf des Unterprogrammes
	LBRA	SCI_INT3		;
					;
TX_JMP_TBL:
	dc.w	STEP0_TX
	dc.w	STEP1_TX
	dc.w	STEP2_TX
	dc.w	STEP3_TX
	dc.w	STEP4_TX
	dc.w	STEP5_TX
	dc.w	ERROR_TX
					;
TX_JMP_TBL_CNT:		equ	(* - TX_JMP_TBL) / 2
					;
;------------------------------------------------------------------------------
;TxD-Step 0
;Check to see if a new byte to transmitted is in the Transmit Data Register.
;Test SCISR1._TDRE = false. If so move Data from Transmit Data Register to
;Transmit Shift Register.
;=> Step 1
					;
STEP0_TX:
	BRCLR	SCISR1,_TC,STEP0_TX9	;wenn _TC gesetzt und _TDRE rückgesetzt,
	BRSET	SCISR1,_TDRE,STEP0_TX9	;dann
	MOVW    SCITDR,TXSHFT		;  Zeichen in Schieberegister laden
	BSET	SCISR1,_TDRE		;  Zeichenübernahme ins Schieberegister quittieren
	BCLR	SCISR1,_TC		;  Datenausgabe starten
	MOVB    #1,TXICTR		;  bit-Zeitzähler auf 1
	MOVB	#1,TXSTEP		;  => Step 1
STEP0_TX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;TxD-Step 1
;Transmit a start bit and prepare data transmission.
;=> Step 2
					;
STEP1_TX:
	BCLR	TX_PORT,_TX		;Port = 0
	MOVB	#0,TXPAR		;Parity Register auf 0
	MOVB    #BIT_CT,TXICTR		;1 bit-Zeit
	BRCLR	SCICR1,_M,STEP1_TX1
	MOVB	#9,TXBCTR		;9 Datenbits
	BRA	STEP1_TX2		;
STEP1_TX1:
	MOVB	#8,TXBCTR		;8 Datenbits
STEP1_TX2:
	MOVB	#2,TXSTEP		;
	RTS				;
					;
;------------------------------------------------------------------------------
;TxD-Step 2
;Transmit data bits. At end either set up for parity or for stop bit
;
					;
STEP2_TX:
	LDD	TXSHFT			;Transmit Shift Register
	LSRD				;nach rechts ins CARRY schieben
	STD	TXSHFT			;
	BCS	STEP2_TX1		;wenn CARRY rückgesetzt
	BCLR	TX_PORT,_TX		;  dann Port = 0
	BRA	STEP2_TX2		;
STEP2_TX1:
	BSET	TX_PORT,_TX		;sonst Port = 1
	INC	TXPAR			;Parity Register incrementieren
STEP2_TX2:
	MOVB	#BIT_CT,TXICTR		;1 bit-Zeit
	DEC	TXBCTR			;Bitzähler decrementieren
	BNE	STEP2_TX9		;
	BRCLR	SCICR1,_PE,STEP2_TX3	;wenn Parity,
	MOVB	#3,TXSTEP		;  dann => Step 3
	BRA	STEP2_TX9		;
STEP2_TX3:
	MOVB	#4,TXSTEP		;  sonst => Step 4
STEP2_TX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;TxD-Step 3
;Transmit parity bit.
;=> Step 4
					;
STEP3_TX:
	LDAA	TXPAR			;
	BRCLR	SCICR1,_PT,STEP3_TX1	;
	COMA				;
STEP3_TX1:
	ANDA	#00000001b		;
	BNE	STEP3_TX2		;
	BCLR	TX_PORT,_TX		;
	BRA	STEP3_TX3		;
STEP3_TX2:
	BSET	TX_PORT,_TX		;
STEP3_TX3:
	MOVB    #BIT_CT,TXICTR		;1 bit-Zeit
	MOVB	#4,TXSTEP		;=> Step 4
	RTS				;
					;
;------------------------------------------------------------------------------
;TxD-Step 4
;Transmit a stop bit.
;=> Step 5
					;
STEP4_TX:
	BSET	TX_PORT,_TX		;Port = 1
	MOVB    #BIT_CT,TXICTR		;1 bit-Zeit
	MOVB	#5,TXSTEP		;=> Step 5
STEP4_TX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;TxD-Step 5
;Cleanup after all bits of a character are transmitted.
;=> Step 0
					;
STEP5_TX:
	BSET	TX_PORT,_TX		;Port = 1
	MOVB	#0,TXICTR		;bit-Zeitzähler auf 0
	MOVB	#0,TXBCTR		;Bitzähler auf 0
	BSET	SCISR1,_TC		;_TC setzen
	MOVB	#0,TXSTEP		;=> Step 0
	RTS				;
					;
;------------------------------------------------------------------------------
;TxD-Error
					;
ERROR_TX:
	BSET	SCISR1,_FE		;Frame Error setzen
	BSET	TX_PORT,_TX		;Port = 1
	MOVB	#0,TXICTR		;bit-Zeitzähler auf 0
	MOVB	#0,TXBCTR		;Bitzähler auf 0
	BSET	SCISR1,_TC		;_TC setzen
	MOVB	#0,TXSTEP		;=> Step 0
	RTS				;
					;
;==============================================================================
;Receiver Bit Clock
					;
SCI_INT3:
	LDAA	RXSTEP			;wenn RXSTEP = 0
	BEQ	SCI_INT4		;  dann sofort auf Startbit prüfen

	LDAA	RXICTR			;sonst
	BEQ	SCI_INT4		;  wenn bit-Zeitzähler > 0,
	DECA				;    dann bit-Zeitzähler decrementieren
	STAA	RXICTR			;  wenn bit-Zeitzähler = 0,
	BEQ	SCI_INT4		;    dann Empfang fortsetzen
					;
	LBRA	SCI_INT9		;sonst sofort zum Funktionsende
					;
;==============================================================================
;Receive Data
					;
SCI_INT4:
	LDAB	RXSTEP			;
	CMPB	#LOW(RX_JMP_TBL_CNT)	;
	BLO	SCI_INT5		;
	LDAB	#LOW(RX_JMP_TBL_CNT-1)	;
SCI_INT5:
	CLRA				;Code nach A:B
	LSLD				;* 2 ergibt Offset in Adressentabelle
	LDX	#RX_JMP_TBL		;
	JSR	[D,X]			;Aufruf des Unterprogrammes
	LBRA	SCI_INT9		;
					;
RX_JMP_TBL:
	dc.w	STEP0_RX
	dc.w	STEP1_RX
	dc.w	STEP2_RX
	dc.w	STEP3_RX
	dc.w	STEP4_RX
	dc.w	ERROR_RX
					;
RX_JMP_TBL_CNT:		equ	(* - RX_JMP_TBL) / 2
					;
;------------------------------------------------------------------------------
;RxD-Step 0
;Wait for 0-Level to begin start bit check.
;=> Step 1
					;
STEP0_RX:
	BRSET	RX_PORT,_RX,STEP0_RX9	;
	MOVB    #(BIT_CT/2),RXICTR	;1/2 bit-Zeit
	MOVB	#1,RXSTEP		;=> Step 1
STEP0_RX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RxD-Step 1
;Validate start bit and set up for data receive
;=> Step 2
					;
STEP1_RX:
	BRSET	RX_PORT,_RX,STEP1_RX8	;
					;gültiges Startbit:
	MOVB    #BIT_CT,RXICTR		;1 bit-Zeit
	MOVB	#0,RXPAR		;Parity Register auf 0
	BRCLR	SCICR1,_M,STEP1_RX1	;
	MOVB	#9,RXBCTR		;9 Datenbits
	BRA	STEP1_RX2		;
STEP1_RX1:
	MOVB	#8,RXBCTR		;8 Datenbits
STEP1_RX2:
	MOVB	#2,RXSTEP		;=> Step 2
	BRA	STEP1_RX9		;
STEP1_RX8:
					;Startbit nicht in Ordnung:
	MOVB	#0,RXSTEP		;=> Step 0
STEP1_RX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RxD-Step 2
;Data bit receive, at end set up for parity or stop bit receiption.
;
					;
STEP2_RX:
	LDD	RXSHFT			;
	LSRD				;einmal nach rechts schieben
	BRCLR	RX_PORT,_RX,STEP2_RX1	;
	INC	RXPAR			;RxD-Parity aktualisieren
	ORAA	#00000001b		;empfangenes bit ist '1'
	BRA	STEP2_RX2		;
STEP2_RX1:
	ANDA	#11111110b		;empfangenes bit ist '0'
STEP2_RX2:
	STD	RXSHFT			;
	MOVB	#BIT_CT,RXICTR		;1 bit-Zeit
	DEC	RXBCTR			;
	BNE	STEP2_RX9		;
	BRCLR	SCICR1,_PE,STEP2_RX3	;wenn Parity,
	MOVB	#3,RXSTEP		;  dann => Step 3
	BRA	STEP2_RX9		;
STEP2_RX3:
	MOVB	#4,RXSTEP		;sonst => Step 4
STEP2_RX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RxD-Step 3
;Receive parity bit, at end set up for stop bit receiption
;=> Step 4
					;
STEP3_RX:
	BRCLR	RX_PORT,_RX,STEP3_RX1	;
	LDAA	#00000001b		;empfangenes Parity-bit mit
	BRA	STEP3_RX2		;
STEP3_RX1:
	CLRA				;
STEP3_RX2:
	LDAB	RXPAR			;
	BRCLR	SCICR1,_PT,STEP3_RX3	;
	COMB				;
STEP3_RX3:
	ANDB	#00000001b		;neu gebildetetem Parity-bit vergleichen
	SBA				;
	BEQ	STEP3_RX4		;wenn verschieden
	BSET	SCISR1,_PF		;  dann Parity Error
	BRA	STEP3_RX5		;
STEP3_RX4:
	BCLR	SCISR1,_PF		;sonst Parity ok
STEP3_RX5:
	MOVB	#BIT_CT,RXICTR		;1 bit-Zeit
	MOVB	#4,RXSTEP		;=> Step 4
STEP3_RX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RxD-Step 4
;Receive stop bit.
;=> Step 0
					;
STEP4_RX:
	BRSET	RX_PORT,_RX,STEP4_RX1	;wenn RX_PORT = '0'
	BSET	SCISR1,_FE		;  dann Frame-Fehler setzen
STEP4_RX1:
	BRCLR	SCISR1,_RDRF,STEP4_RX2	;wenn _RDRF gesetzt,
	BSET	SCISR1,_OR		;  dann Überlauf-Fehler setzen
STEP4_RX2:
	LDD	RXSHFT			;
	BRSET	SCICR1,_M,STEP4_RX3	;wenn 8-bit Datenformat
	LSRD				;  dann einmal rechts schieben
STEP4_RX3:
	STD	SCIRDR			;Zeichen in Empfangsregister umspeichern
	MOVB	#0,RXICTR		;bit-Zähler auf 0
	BSET	SCISR1,_RDRF		;_RDRF setzen
	MOVB	#0,RXSTEP		;=> Step 0
STEP4_RX9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RxD-Error
;
;=> Step 0
					;
ERROR_RX:
	BSET	SCISR1,_FE		;Frame Error setzen
	MOVB	#0,RXICTR		;Interruptzähler auf 0
	MOVB	#0,RXBCTR		;Bitzähler auf 0
	BCLR	SCISR1,_RDRF		;_RDRE rücksetzen
	MOVB	#0,RXSTEP		;=> Step 0
	RTS				;
					;
;==============================================================================
					;
SCI_INT9:
	LDD	TC6			;
	ADDD	SCIBD			;
	STD	TC6			;
	BSET	TIE,_C6I		;
	MOVB	#_C6F,TFLG1		;
	RTI				;
					;
;------------------------------------------------------------------------------
;Public: SCI_RESET bringt die SoftUart-Schnittstelle in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, X, Y
;------------------------------------------------------------------------------
					;
SCI_RESET:
	LDY	#BOV			;Anfang der Systemvariablen
	LDX	#(TOV - BOV)		;Anzahl Bytes
	LDAA	#0			;Füllwert
SCI_RESET1:
	STAA	1,Y+			;
	DBNE	X,SCI_RESET1		;alle Variablen auf Füllwert setzen
					;
	MOVW	#BD_9600x4_REL,SCIBD	;9600 bps
	MOVB	#00000000b,SCICR1	;8 Datenbits, 1 Stoppbit, kein Parity

	BCLR	RX_DIR,_RX		;Empfangsleitung auf Eingang schalten
	LDAA	SCICR2			;
	ANDA	#00000100b		;
	ORAA	#00000100b		;RxD aktiv, TxD inaktiv (!)
	STAA	SCICR2			;
	BSET	SCISR1,_TDRE | _TC	;
					;
	LDD	TCNT			;
	ADDD	SCIBD			;Compare Register 6 für nächsten bit-Takt aktualisieren
	STD	TC6			;
	BSET	TIE,_C6I		;Compare Channel 6 Interrupt-Flag rücksetzen
	MOVB	#_C6F,TFLG1		;schwebenden Timer Channel 6 Interrupt quittieren
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_STATUS liefert den Status der SoftUart-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		Funktionsstatus
;			B		Portstatus
;			SCISR1._OR
;			SCISR1._NF
;			SCISR1._FE
;			SCISR1._PF
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_STATUS:
	LDAA	SCISR1			;Status lesen
	TAB				;
	ANDB	#11110000b		;Fehler-Flags rücksetzen
	STAB	SCISR1			;Status
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_DISABLE sperrt den Sendeausgang der SoftUart-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	SCICR2._TE
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_DISABLE:
	BCLR	SCICR2,_TE		;_TE rücksetzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_ENABLE aktiviert den Sendeausgang der SoftUart-Schnittstelle
;und setzt ihn auf '1'.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	TX_DIR._TX
;			TX_PORT._TX
;			SCICR2._TE
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_ENABLE:
	BSET	TX_DIR,_TX		;Sendeleitung auf Ausgang schalten
	BSET	TX_PORT,_TX		;und auf '1'
	BSET	SCICR2,_TE		;_TE setzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_TX_STATUS liefert den Ein-/Ausschaltzustand des Sendeausganges
;der SoftUart-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0	= gesperrt
;					<> 0	= aktiv
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_TX_STATUS:
	LDAA	SCICR2			;
	ANDA	#_TE			;_TE abfragen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SCI_READ8 liest ein Zeichen aus dem SoftUart-Empfangsregister.
;
;Eingangsparameter:	SCISR1._RDRF
;Ausgangsparameter:	SCISR1._RDRF
;			CCR.C		clr 	= Zeichen empfangen
;					set 	= kein neues Zeichen
;  wenn CCR.C = clr	A		empfangenes Zeichen
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
SCI_READ8:
	BRCLR	SCISR1,_RDRF,SCI_READ8_8
					;wenn neues Zeichen da,
	LDAA	SCIRDRL			;dann
	BCLR	SCISR1,_RDRF		;  Zeichen nach A, _RDRF rücksetzen
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
;Public: SCI_WRITE8 schreibt ein Zeichen in das SoftUart-Senderegister.
;
;Eingangsparameter:	A		zu sendendes Zeichen
;			SCISR1._TDRE
;Ausgangsparameter:	SCISR1._TDRE
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
	BRSET	SCISR1,_TDRE,SCI_WRITE8_2
	DBNE	X,SCI_WRITE8_1		;warten, bis Transmitter bereit
	LDAA	#E_SCI_TIMEOUT		;
	BRA	SCI_WRITE8_9		;nach Timeout mit Fehler zurück
					;
SCI_WRITE8_2:
	STAA	SCITDRL			;sonst Zeichen ausgeben
	BCLR	SCISR1,_TDRE		;und _TDRE rücksetzen
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
