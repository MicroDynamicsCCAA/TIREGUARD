	include	"s12ga_240.sfr"
	title	"s12ga_MSCAN  Copyright (C) 2005-2014, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_MSCAN.asm
;
;Copyright:	(C) 2005-2014, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	31.12.2014
;
;Description:	Funktionen für den Zugriff auf das prozessorinterne MSCAN-Modul
;		des Freescale MC9S12GA240
;
;Dieses Programm-Modul wickelt den Informationsaustausch über ein CAN-Netz mit
;einem Basic-CAN MSCAN-Modul eines Microcontrollers aus der
;Freescale HCS12-Reihe ab.
;Über acht Messagepuffer können Kommunikationsobjekte gesendet, empfangen und 
;angefordert werden.
;Durch die Software steht die erweiterte Funktionalität eines Full-CAN Moduls
;zur Verfügung.
;------------------------------------------------------------------------------
;Beispiel für eine funktionsfähige Konfigurationstabelle zur Verwendung in der
;Funktion CAN_CONFIG:
;Die Reihenfolge der Werte ist fest vorgegeben und darf nicht verändert werden.
;
;CANX_CONFIG_TBL:			;500 kbit/s @16MHz Quartz
;					;
;1. Teil: Config
;
;Die vier Konfigurationsbytes sind entsprechend der Konventionen des MSCAN-Modules
;zu ermitteln. Hierbei ist die entsprechende Freescale Dokumentation zu Rate
;zu ziehen.
;
;	dc.b	10000000b		;CANxCTL1: MSCAN enable, Oscillator Clock, Normal Operation
;	dc.b	00000011b		;CANxBTR0: SJW=1, Prescaler=4
;	dc.b	00100011b		;CANxBTR1: SAMP=0, TSEG2=3, TSEG1=4
;					;
;	dc.b	00100000b		;CANxIDAC: acht 8-bit Akzeptanzfilter
;					;
;2. Teil: Descriptors
;
;Die acht Deskriptoren setzen sich jeweils zusammen aus dem fünfmal nach links
;verschobenen (x20h) Botschafts-Identifier und der Anzahl Bytes der Botschaft,
;wenn diese gesendet werden soll. Bei zu empfangenden Botschaften ist als
;Byteanzahl stets Null anzugeben.
;Unbenutzte Deskriptoren sind auf 0FFE0h zu setzen.
;
;	dc.w	07F00h			;Descriptor 0	3F8h, ? Bytes, empfangen
;	dc.w	07F28h			;Descriptor 1	3F9h, 8 Bytes, senden
;	dc.w	0FFE0H			;Descriptor 2
;	dc.w	0FFE0H			;Descriptor 3
;	dc.w	0FFE0h			;Descriptor 4
;	dc.w	0FFE0h			;Descriptor 5
;	dc.w	0FFE0h			;Descriptor 6
;	dc.w	0FFE0h			;Descriptor 7
;					;
;------------------------------------------------------------------------------
;Revision History:	Original Version  01.05
;
;31.12.2014
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: s12p_MSCAN.asm
;
;27.04.2009	Anpassung an MC9S12P128
;
;24.11.2006	Anpassung an MC9S12C128
;		- nur ein MSCAN-Modul -
;		Fehler in CAN_REQUEST korrigiert:
;		Sprung nach CAN_REQUEST3 statt nach CAN_WRITE3
;
;03.04.2006	in CAN_STOP und CAN_START die Zeitgrenzen jetzt in Abhängigkeit
;		von BUS_CLK setzen
;17.07.2005	in CAN_STOP und CAN_START die Zeitgrenzen wesentlich vergrößert
;		CANx_STATUS Bytes neu hinzugefügt und in Funktionen CAN_INIT
;		sowie CAN_STATUS eingebaut
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
	xdef	CAN_READ		;Code
	xdef	CAN_REQUEST		;Code
	xdef	CAN_RESET		;Code
	xdef	CAN_STATUS		;Code
	xdef	CAN_WRITE		;Code
					;
	xdef	CAN0_TX_INT		;Code
	xdef	CAN0_RX_INT		;Code
					;
	xdef.b	_CAN_RXOK		;bitMask
	xdef.b	_CAN_TXOK		;bitMask
	xdef.b	_CAN_RXSTAT		;bitMask
	xdef.b	_CAN_TXSTAT		;bitMask
					;
	xdef.b	E_CAN_TIMEOUT		;Number
	xdef.b	E_CAN_INDEX		;Number
	xdef.b	E_CAN_MESSAGE		;Number
	xdef.b	E_CAN_LENGTH		;Number
	xdef.b	E_CAN_NO_DATA		;Number
					;
;------------------------------------------------------------------------------
;Variables and Constants
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Control Registers
;
CTL0:		equ	00h		;MSCAN	Control	Register 0
CTL1:		equ	01h		;MSCAN	Control	Register 1
BTR0:		equ	02h		;MSCAN	Bus Timing Register 0
BTR1:		equ	03h		;MSCAN	Bus Timing Register 1
RFLG:		equ	04h		;MSCAN	Receiver Flag Register
RIER:		equ	05h		;MSCAN	Receiver Interrupt Enable Register
TFLG:		equ	06h		;MSCAN	Transmitter Flag Register
TIER:		equ	07h		;MSCAN	Transmitter Interrupt Enable Register
TARQ:		equ	08h		;MSCAN	Transmitter Message Abort Request
TAAK:		equ	09h		;MSCAN	Transmitter Message Abort Acknowledge
TBSEL:		equ	0Ah		;MSCAN	Transmit Buffer	Selection
IDAC:		equ	0Bh		;MSCAN	Identifier Acceptance Control Register
					;
;------------------------------------------------------------------------------
;Reserved
;
;					;
;					;
					;
;------------------------------------------------------------------------------
;Error Counters
;
RXERR:		equ	0Eh		;MSCAN	Receive	Error Counter Register
TXERR:		equ	0Fh		;MSCAN	Transmit Error Counter Register
					;
;------------------------------------------------------------------------------
;Identifier Filter
;
IDAR0:		equ	10h		;MSCAN	Identifier Acceptance Register 0
IDAR1:		equ	11h		;MSCAN	Identifier Acceptance Register 1
IDAR2:		equ	12h		;MSCAN	Identifier Acceptance Register 2
IDAR3:		equ	13h		;MSCAN	Identifier Acceptance Register 3
IDMR0:		equ	14h		;MSCAN	Identifier Mask	Register 0
IDMR1:		equ	15h		;MSCAN	Identifier Mask	Register 1
IDMR2:		equ	16h		;MSCAN	Identifier Mask	Register 2
IDMR3:		equ	17h		;MSCAN	Identifier Mask	Register 3
					;
IDAR4:		equ	18h		;MSCAN	Identifier Acceptance Register 4
IDAR5:		equ	19h		;MSCAN	Identifier Acceptance Register 5
IDAR6:		equ	1Ah		;MSCAN	Identifier Acceptance Register 6
IDAR7:		equ	1Bh		;MSCAN	Identifier Acceptance Register 7
IDMR4:		equ	1Ch		;MSCAN	Identifier Mask	Register 4
IDMR5:		equ	1Dh		;MSCAN	Identifier Mask	Register 5
IDMR6:		equ	1Eh		;MSCAN	Identifier Mask	Register 6
IDMR7:		equ	1Fh		;MSCAN	Identifier Mask	Register 7
					;
;------------------------------------------------------------------------------
;Receive Buffer
;
RXIDR0:		equ	20h		;MSCAN	Receive	Identifier Register 0
RXIDR1:		equ	21h		;MSCAN	Receive	Identifier Register 1
RXIDR2:		equ	22h		;MSCAN	Receive	Identifier Register 2
RXIDR3:		equ	23h		;MSCAN	Receive	Identifier Register 3
RXDSR0:		equ	24h		;MSCAN	Receive	Data Segment Register 0
RXDSR1:		equ	25h		;MSCAN	Receive	Data Segment Register 1
RXDSR2:		equ	26h		;MSCAN	Receive	Data Segment Register 2
RXDSR3:		equ	27h		;MSCAN	Receive	Data Segment Register 3
RXDSR4:		equ	28h		;MSCAN	Receive	Data Segment Register 4
RXDSR5:		equ	29h		;MSCAN	Receive	Data Segment Register 5
RXDSR6:		equ	2Ah		;MSCAN	Receive	Data Segment Register 6
RXDSR7:		equ	2Bh		;MSCAN	Receive	Data Segment Register 7
RXDLR:		equ	2Ch		;MSCAN	Receive	Data Length Register
;					;
RTSRH:		equ	2Eh		;MSCAN	Receive	Time Stamp Register High Byte
RTSRL:		equ	2Fh		;MSCAN	Receive	Time Stamp Register Low	Byte
					;
;------------------------------------------------------------------------------
;Transmit Buffer
;
TXIDR0:		equ	30h		;MSCAN	Transmit Identifier Register 0
TXIDR1:		equ	31h		;MSCAN	Transmit Identifier Register 1
TXIDR2:		equ	32h		;MSCAN	Transmit Identifier Register 2
TXIDR3:		equ	33h		;MSCAN	Transmit Identifier Register 3
TXDSR0:		equ	34h		;MSCAN	Transmit Data Segment Register 0
TXDSR1:		equ	35h		;MSCAN	Transmit Data Segment Register 1
TXDSR2:		equ	36h		;MSCAN	Transmit Data Segment Register 2
TXDSR3:		equ	37h		;MSCAN	Transmit Data Segment Register 3
TXDSR4:		equ	38h		;MSCAN	Transmit Data Segment Register 4
TXDSR5:		equ	39h		;MSCAN	Transmit Data Segment Register 5
TXDSR6:		equ	3Ah		;MSCAN	Transmit Data Segment Register 6
TXDSR7:		equ	3Bh		;MSCAN	Transmit Data Segment Register 7
TXDLR:		equ	3Ch		;MSCAN	Transmit Data Length Register
TXTBPR:		equ	3Dh		;MSCAN	Transmit Buffer	Priority Register
;					;
					;
E_CAN_TIMEOUT:	equ	-1
E_CAN_INDEX:	equ	-2
E_CAN_MESSAGE:	equ	-3
E_CAN_LENGTH:	equ	-4
E_CAN_NO_DATA:	equ	-5
					;
_CAN_TXOK:	equ	bit0		;1, wenn seit letzter Abfrage Botschaft erfolgreich gesendet
_CAN_RXOK:	equ	bit1		;1, wenn seit letzter Abfrage Botschaft korrekt empfangen
_CAN_TXSTAT:	equ	bit2 | bit3	;
_CAN_RXSTAT:	equ	bit4 | bit5	;
;
;
					;
.locals:	section
					;
;------------------------------------------------------------------------------
;CAN0: Reihenfolge und Typen der Variablen dürfen nicht verändert werden!
;
CAN0_VAR:
					;
CAN0_RRR:
	ds.b	1			;Receive Ready Register
					;
CAN0_TRSR:
	ds.b	1			;Transmit Request Set Register
					;
CAN0_DESCR0:
	ds.w	1			;Descriptor 0
CAN0_DESCR1:
	ds.w	1			;Descriptor 1
CAN0_DESCR2:
	ds.w	1			;Descriptor 2
CAN0_DESCR3:
	ds.w	1			;Descriptor 3
CAN0_DESCR4:
	ds.w	1			;Descriptor 4
CAN0_DESCR5:
	ds.w	1			;Descriptor 5
CAN0_DESCR6:
	ds.w	1			;Descriptor 6
CAN0_DESCR7:
	ds.w	1			;Descriptor 7
					;
CAN0_MSG0:
	ds.b	8			;Message 0
CAN0_MSG1:
	ds.b	8			;Message 1
CAN0_MSG2:
	ds.b	8			;Message 2
CAN0_MSG3:
	ds.b	8			;Message 3
CAN0_MSG4:
	ds.b	8			;Message 4
CAN0_MSG5:
	ds.b	8			;Message 5
CAN0_MSG6:
	ds.b	8			;Message 6
CAN0_MSG7:
	ds.b	8			;Message 7
					;
CAN0_STATUS:
	ds.b	1			;Status
					;
.text:		section
					;
;------------------------------------------------------------------------------
;CAN0_TX_INT		CAN0 Sende-Interrupt
;
;Priorität:		normal
;Interruptquelle:	CAN0TFLG._TXE2 | _TXE1 | _TXE0
;Auslöser:              Transmitter Buffer Empty
;Initialisierung:	Module 's12ga_MSCAN'
;
;Eingangsparameter:	CAN0_TRSR
;Ausgangsparameter:	CAN0_TRSR
;			CAN0_STATUS._CAN_RXOK
;Laufzeit:		24 µs		@ 8 MHz
;------------------------------------------------------------------------------
					;
CAN0_TX_INT:
	LDD	R0			;Register retten
	PSHD				;
	BSET	CAN0_STATUS,_CAN_TXOK	;
					;
	LDAA	CAN0_TRSR		;wenn keine Transmit Request Flags gesetzt,
	BNE     CAN0_TX_INT1		;dann
	MOVB	#0,CAN0TIER		;  Transmit Interrupts sperren
	JMP	CAN0_TX_INT9		;
					;
CAN0_TX_INT1:
	LDAB	#0			;Ergebnis auf null
	CMPA	#16			;Transmit Request Flags in der Weise
	BLO	CAN0_TX_INT2		;analysieren, dass gesetzte Flags
	ADDB	#4			;von links nach rechts abgearbeitet werden
	LSRA				;
	LSRA				;
	LSRA				;
	LSRA				;
CAN0_TX_INT2:
	ANDA	#00001111b		;
	CMPA	#4			;
	BLO	CAN0_TX_INT3		;
	ADDB	#2			;
	LSRA				;
	LSRA				;
CAN0_TX_INT3:
	ANDA	#00000011b		;
	CMPA	#2			;
	BLO	CAN0_TX_INT4		;
	ADDB	#1			;
CAN0_TX_INT4:
	STAB	R0			;Nummer der nächsten auszugebenden Message
					;
	LDAA	CAN0TFLG		;
	STAA	CAN0TBSEL		;
	LDAA	CAN0TBSEL		;
	STAA	R1			;nächster freier Sendebuffer
					;
	LDAB	R0			;Sendebuffer vorbereiten:
	LSLB				;
	LDX	#CAN0_DESCR0		;
	MOVB	B,X,CAN0TXIDR0		;11-bit Identifier eintragen
	INCB				;
	LDAA	B,X			;
	ANDA	#11110000b		;
	STAA	CAN0TXIDR1		;
	LDAA	B,X			;
	ANDA	#00001111b		;
	STAA	CAN0TXDLR		;Anzahl Bytes der Botschaft eintragen
	BEQ	CAN0_TX_INT6		;wenn Anzahl Bytes > 0,
					;
	LDAB	R0			;dann
	LSLB				;
	LSLB				;
	LSLB				;
	LDX	#CAN0_MSG0		;
	LDY	#CAN0TXDSR0		;
CAN0_TX_INT5:
	MOVB	B,X,1,Y+		;  die eigentliche Botschaft eintragen
	INCB				;
	DBNE	A,CAN0_TX_INT5		;
					;
CAN0_TX_INT6:
	CLR	CAN0TXBPR		;Sendepriorität stets auf null setzen
	MOVB	R1,CAN0TFLG		;Sendevorgang starten
					;
	LDAB	R0			;
	LSLB				;
	LSLB				;
	LDX	#CAN0_TRSR_TBL		;
	LDY	B,X			;
	INCB				;
	INCB				;
	LDAA	B,X			;
	COMA				;
	ANDA	0,Y			; > CLEAR TRANSMIT REQUEST FLAG
	STAA	0,Y			;
					;
CAN0_TX_INT9:
	PULD				;Register restaurieren
	STD	R0			;
	RTI				;
					;
;------------------------------------------------------------------------------
;CAN0_RX_INT		CAN0 Empfangs-Interrupt
;
;Priorität:		normal
;Interruptquelle:	CAN0RFLG._RXF
;Auslöser:              Receive Buffer Full
;Initialisierung:	Module 's12ga_MSCAN'
;
;Eingangsparameter:
;Ausgangsparameter:	CAN0_STATUS._CAN_RXOK
;Laufzeit:		28 µs		@ 8 MHz
;------------------------------------------------------------------------------
					;
CAN0_RX_INT:
	LDD	R0			;Register retten
	PSHD				;
	BSET	CAN0_STATUS,_CAN_RXOK	;
					;
	LDX	#CAN0_DESCR0		;Basisadresse der Descriptoren
	LDAB	#0			;Message-Nummer auf null
CAN0_RX_INT1:
	LDAA	0,X			;
	CMPA	CAN0RXIDR0		;
	BNE	CAN0_RX_INT2		;
	LDAA	1,X			;wenn Identifier der empfangenen Botschaft
	ANDA	#11100000b		;gleich dem im Descriptor ist,
	CMPA	CAN0RXIDR1		;dann
	BEQ	CAN0_RX_INT3		;  ist Message-Nummer gefunden
					;
CAN0_RX_INT2:
	LEAX	2,X			;sonst
	INCB				;  solange noch nicht mit sämtlichen
	CMPB	#8			;  Descriptoren verglichen,
	BLO	CAN0_RX_INT1		;  Suche fortsetzen
	JMP	CAN0_RX_INT9		;
					;
CAN0_RX_INT3:
	STAB	R0			;Message-Nummer merken
					;
	LDAA	1,X			;
	ANDA	#11110000b		;
	ORAA	CAN0RXDLR		;Message-Länge im Descriptor ergänzen
	STAA	1,X			;
					;
	LDAA	CAN0RXDLR		;
	BEQ	CAN0_RX_INT5		;
	LDAB	R0			;
	LSLB				;
	LSLB				;
	LSLB				;
	LDX	#CAN0RXDSR0		;
	LDY	#CAN0_MSG0		;
CAN0_RX_INT4:
	MOVB	1,X+,B,Y		;die eigentliche Botschaft auslesen
	INCB				;
	DBNE	A,CAN0_RX_INT4		;
					;
CAN0_RX_INT5:
	LDAB	R0			;
	LSLB				;
	LSLB				;
	LDX	#CAN0_RRR_TBL		;
	LDY	B,X			;
	INCB				;
	INCB				;
	LDAA	B,X			;
	COMA				;
	ORAA	0,Y			; > SET RECEIVE READY FLAG
	STAA	0,Y			;
					;
CAN0_RX_INT9:
	MOVB	#_RXF,CAN0RFLG		;Receive Buffer Full Flag rücksetzen
					;
	PULD				;Register restaurieren
	STD	R0			;
	RTI				;
					;
;------------------------------------------------------------------------------
;CAN_CONFIG stellt die Betriebsart eines MSCAN-Moduls ein.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R4/R5		Zeiger auf Konfigurationsdaten
;Ausgangsparameter:	R4/R5		Zeiger auf Descriptor-Konfigurationsdaten
;veränderte Register:   CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
CAN_CONFIG:
	LDAA	R0			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_BASE_TBL		;
	LDY	A,Y			;MSCANx Register-Basisadresse
	LDX	R4			;Zeiger auf Konfigurationsdaten
					;
	MOVB	1,X+,CTL1,Y		;
	MOVB	1,X+,BTR0,Y		;Konfigurationsdaten
	MOVB	1,X+,BTR1,Y		;in den Registern ablegen
	MOVB	1,X+,IDAC,Y		;
					;
	STX	R4			;Zeiger auf Descriptor-Konfigurationsdaten retten
					;
	LDAB	#0			;
					;
	LDAA	1,X			;
	ANDA	#00001111b		;wenn Anzahl Bytes > 0,
	BNE	CAN_CONFIG1a		;dann
	LDAA	2,X+			;  High Byte des Identifiers
	BRA	CAN_CONFIG1b		;
CAN_CONFIG1a:
	LDAA	#0FFh			;sonst
	LEAX	2,X			;  0FFh
CAN_CONFIG1b:
	STAA	IDAR0,Y			;  als Akzeptanzfilter eintragen
	STAB	IDMR0,Y			;Aktzeptanzmaske stets auf null setzen
					;
	LDAA	1,X			;
	ANDA	#00001111b		;
	BNE	CAN_CONFIG2a		;
	LDAA	2,X+			;
	BRA	CAN_CONFIG2b		;
CAN_CONFIG2a:
	LDAA	#0FFh			;
	LEAX	2,X			;
CAN_CONFIG2b:
	STAA	IDAR1,Y			;
	STAB	IDMR1,Y			;
					;
	LDAA	1,X			;
	ANDA	#00001111b		;
	BNE	CAN_CONFIG3a		;
	LDAA	2,X+			;
	BRA	CAN_CONFIG3b		;
CAN_CONFIG3a:
	LDAA	#0FFh			;
	LEAX	2,X			;
CAN_CONFIG3b:
	STAA	IDAR2,Y			;
	STAB	IDMR2,Y			;
					;
	LDAA	1,X			;
	ANDA	#00001111b		;
	BNE	CAN_CONFIG4a		;
	LDAA	2,X+			;
	BRA	CAN_CONFIG4b		;
CAN_CONFIG4a:
	LDAA	#0FFh			;
	LEAX	2,X			;
CAN_CONFIG4b:
	STAA	IDAR3,Y			;
	STAB	IDMR3,Y			;
					;
	LDAA	1,X			;
	ANDA	#00001111b		;
	BNE	CAN_CONFIG5a		;
	LDAA	2,X+			;
	BRA	CAN_CONFIG5b		;
CAN_CONFIG5a:
	LDAA	#0FFh			;
	LEAX	2,X			;
CAN_CONFIG5b:
	STAA	IDAR4,Y			;
	STAB	IDMR4,Y			;
					;
	LDAA	1,X			;
	ANDA	#00001111b		;
	BNE	CAN_CONFIG6a		;
	LDAA	2,X+			;
	BRA	CAN_CONFIG6b		;
CAN_CONFIG6a:
	LDAA	#0FFh			;
	LEAX	2,X			;
CAN_CONFIG6b:
	STAA	IDAR5,Y			;
	STAB	IDMR5,Y			;
					;
	LDAA	1,X			;
	ANDA	#00001111b		;
	BNE	CAN_CONFIG7a		;
	LDAA	2,X+			;
	BRA	CAN_CONFIG7b		;
CAN_CONFIG7a:
	LDAA	#0FFh			;
	LEAX	2,X			;
CAN_CONFIG7b:
	STAA	IDAR6,Y			;
	STAB	IDMR6,Y			;
					;
	LDAA	1,X			;
	ANDA	#00001111b		;
	BNE	CAN_CONFIG8a		;
	LDAA	2,X+			;
	BRA	CAN_CONFIG8b		;
CAN_CONFIG8a:
	LDAA	#0FFh			;
	LEAX	2,X			;
CAN_CONFIG8b:
	STAA	IDAR7,Y			;
	STAB	IDMR7,Y			;
					;
	RTS				;
					;
;------------------------------------------------------------------------------
;CAN_DESCRIPTORS stellt die Betriebsart eines MSCAN-Moduls ein.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R4/R5		Zeiger auf Descriptorendaten
;Ausgangsparameter:	keine
;veränderte Register:   CCR, A, X, Y
;------------------------------------------------------------------------------
					;
CAN_DESCRIPTORS:
	LDAA	R0			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_VAR_TBL		;
	LDY	A,Y			;Zeiger auf Descriptoren
	LDX	R4			;Zeiger auf Descriptor-Konfigurationsdaten
 					;
	MOVB	#0,1,Y+			;Receive Ready Register auf null
	MOVB	#0,1,Y+			;Transmit Request Set Register auf null
					;
	LDAA	#8			;Anzahl der Descriptoren
CAN_DESCRIPTORS1:
	MOVW	2,X+,2,Y+		;Daten ablegen
	DBNE	A,CAN_DESCRIPTORS1	;
	RTS				;
					;
;------------------------------------------------------------------------------
;CAN_STOP unterbricht die CAN-Kommunikation.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehler
;veränderte Register:   CCR, B, Y
;------------------------------------------------------------------------------
					;
CAN_STOP:
	LDAA	R0			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_BASE_TBL		;
	LDY	A,Y			;MSCANx Register-Basisadresse
	BSET	CTL0,Y,_INITRQ		;CTL0._INITRQ setzen
	LDD	#BUS_CLK		;BUS_CLK / 8
	LSRD				;
	LSRD				;
	LSRD				;liefert Zeitgrenze
CAN_STOP1:
	BRCLR	CTL1,Y,_INITAK,CAN_STOP2;warten, bis CTL1._INITAK
	BRSET	CTL0,Y,_INITRQ,CAN_STOP3;und CTL0._INITRQ gesetzt
CAN_STOP2:
	DBNE	D,CAN_STOP1		;wenn Zeitgrenze erreicht,
	LDAA	#E_CAN_TIMEOUT		;dann
	JMP	CAN_STOP9		;  mit A = E_CAN_TIMEOUT zurück
					;
CAN_STOP3:
	CLRA				;wenn ok, dann mit A = 0 zurück
					;
CAN_STOP9:
	RTS				;
					;
;------------------------------------------------------------------------------
;CAN_START startet die CAN-Kommunikation.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehler
;veränderte Register:   CCR, B, Y
;------------------------------------------------------------------------------
					;
CAN_START:
	LDAA	R0			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_BASE_TBL		;
	LDY	A,Y			;MSCANx Register-Basisadresse
	BCLR	CTL0,Y,_INITRQ		;CTL0._INITRQ rücksetzen
	LDD	#BUS_CLK		;BUS_CLK / 8
	LSRD				;
	LSRD				;
	LSRD				;liefert Zeitgrenze
CAN_START1:
	BRSET	CTL1,Y,_INITAK,CAN_START2;warten, bis CTL1._INITAK rückgesetzt,
	BRCLR	CTL0,Y,_SYNCH,CAN_START2; CTL0._SYNCH gesetzt
	BRCLR	CTL0,Y,_INITRQ,CAN_START3;und CTL0._INITRQ rückgesetzt
CAN_START2:
	DBNE	D,CAN_START1		;wenn Zeitgrenze erreicht,
	LDAA	#E_CAN_TIMEOUT		;dann
	JMP	CAN_START9		;  Fehler: Timeout
					;
CAN_START3:
	LDAA	R0			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_STATUS_TBL	;
	LDY	A,Y			;
	MOVB	#00000000b,0,Y		;CANx-Status rücksetzen
	LDY	#CANx_BASE_TBL		;
	LDY	A,Y			;MSCANx Register-Basisadresse
        				;
	MOVB	#_RXF,RFLG,Y		;anhängige Empfangs-Interrupts quittieren
	MOVB	#_RXF,RFLG,Y		;
	MOVB	#_RXF,RFLG,Y		;
	MOVB	#_RXF,RFLG,Y		;
	MOVB	#_RXF,RFLG,Y		;
	MOVB	#_RXFIE,RIER,Y		;Empfangs-Interrupts freigeben
	CLRA				;wenn ok, dann mit A = 0 zurück
					;
CAN_START9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: CAN_RESET bringt ein MSCAN-Modul in Grundstellung und startet es.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R4/R5		Zeiger auf Konfigurationsdaten
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehler
;veränderte Register:   CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
CAN_RESET:
	MOVB	#0,R0			;Index stets = 0
					;
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	CAN_RESET1		;dann
	LDAA	#E_CAN_INDEX		;  Fehler: ungültiger Index
	JMP	CAN_RESET9		;
					;
CAN_RESET1:
	JSR	CAN_STOP		;CAN-Controller anhalten
	BNE	CAN_RESET9		;wenn ok,
	JSR	CAN_CONFIG		;dann
	JSR	CAN_DESCRIPTORS		;  CAN-Controller in Grundstellung bringen
	JSR	CAN_START		;  CAN-Controller starten
					;
CAN_RESET9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: CAN_STATUS liefert den Status eines MSCAN-Moduls.
;
;Definition des in A zurückgegebenen Status:
;
;bit0	_CAN_TXOK
;bit1	_CAN_RXOK
;bit2	_CAN_TXSTAT.0
;bit3	_CAN_TXSTAT.1
;bit4	_CAN_RXSTAT.0
;bit5	_CAN_RXSTAT.1
;bit6	- frei -
;bit7	- frei -
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;Ausgangsparameter:	A		MSCAN-Modul Status
;veränderte Register:   CCR, B, X, Y
;------------------------------------------------------------------------------
					;
CAN_STATUS:
	MOVB	#0,R0			;Index stets = 0
					;
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	CAN_STATUS1		;dann
	LDAA	#E_CAN_INDEX		;  Fehler: ungültiger Index
	JMP	CAN_STATUS9		;
					;
CAN_STATUS1:
	LSLA				;
	LDY	#CANx_BASE_TBL		;MSCANx Register-Basisadresse
	LDY	A,Y			;
	LDAB	RFLG,Y			;CANxRFLG-Register lesen
	ANDB	#00111100b		;nur Receiver- und Transmitter-Statusbits übernehmen

	LDY	#CANx_STATUS_TBL	;CANx Status-Adresse
	LDY	A,Y			;
	LDAA	0,Y			;
	ANDA	#11000011b		;CANx-Status lesen
					;
	MOVB	#00000000b,0,Y		;CANx-Status rücksetzen
	ABA				;MSCANx Statusbits und CANx-Statusbits überlagern
					;
CAN_STATUS9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: CAN_READ liest ein Kommunikationsobjekt und legt es im
;Variablenspeicher ab.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R1		Message-Nummer
;			R4/R5		Zeiger auf Variablenspeicher
;Ausgangsparameter:	R3		Länge des empfangenen Kommunikationsobjektes
;			A		0 	= ok
;					<> 0	= Fehler
;veränderte Register:   CCR, B, X, Y
;------------------------------------------------------------------------------
					;
CAN_READ:
	MOVB	#0,R0			;Index stets = 0
					;
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	CAN_READ1		;dann
	LDAA	#E_CAN_INDEX		;  Fehler: ungültiger Index
	JMP	CAN_READ9		;
					;
CAN_READ1:
	LDAA	R1			;
	CMPA	#8			;wenn Message-Nummer > 7,
	BLO	CAN_READ2		;dann
	LDAA	#E_CAN_MESSAGE		;  Fehler: ungültige Message-Nummer
	JMP	CAN_READ9		;
					;
CAN_READ2:
	LDAA	R0			;
	LSLA				;MSCAN-Modul Index * 2
	STAA	R0			;
	LDAA	R1			;
	LSLA				;Message-Nummer * 2
	STAA	R1			;
					;
CAN_READ3:
	LDX	#CANx_RRR_TBL		;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Receive Ready Reset Flags
	LDX	B,X			;
	LDAB	R1			;
	LSLB				;
	LDY	B,X			;Adresse
	INCB				;
	INCB				;
	LDAA	B,X			;Maske
	LDAB	0,Y			;
	ANDA	0,Y			;
	STAA	0,Y			; > RESET RECEIVE READY BIT
					;
	STAA	R3			;
	COM	R3			;
	ANDB	R3			; > RECEIVE READY BIT SET ?
	BNE	CAN_READ4		;
	LDAA	#E_CAN_NO_DATA		;
	JMP	CAN_READ9		;
					;
CAN_READ4:
	LDY	#CANx_DESCR_ADR_TBL	;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Descriptoren
	LDY	B,Y			;
	LDAB	R1			;
	LDY	B,Y			;Zeiger auf Descriptor
	LDAA	1,Y			;Descriptor Low Byte lesen
	ANDA	#00001111b		;
	BEQ	CAN_READ8		;
	CMPA	#9			;wenn Message-Länge > 8,
	BLO	CAN_READ5		;dann
	LDAA	#E_CAN_LENGTH		;  Fehler: ungültige Message-Länge
	JMP	CAN_READ9		;
					;
CAN_READ5:
	STAA	R3			;
	LDX	#CANx_CAN_ADR_TBL	;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Messagebuffer
	LDX	B,X			;
	LDAB	R1			;
	LDX	B,X			;Zeiger auf Messagebuffer
	LDY	R4			;Zeiger auf Datenziel
CAN_READ6:
	MOVB	1,X+,1,Y+		; > READ DATA SEGMENT
	DBNE	A,CAN_READ6		;
					;
	LDX	#CANx_RRR_TBL		;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Receive Ready Reset Flags
	LDX	B,X			;
	LDAB	R1			;
	LSLB				;
	LDY	B,X			;Adresse
	INCB				;
	INCB				;
	LDAA	B,X			;Maske
	LDAB	0,Y			;
	STAA	R3			;
	COM	R3			;
	ANDB	R3			; > RECEIVE READY BIT SET ?
	BNE	CAN_READ3		;
					;
CAN_READ8:
	CLRA				;ok, mit A = 0 zurück
					;
CAN_READ9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: CAN_WRITE lädt ein Kommunikationsobjekt mit Daten aus dem
;Variablenspeicher.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R1		Message-Nummer
;			R2		 = 0	Message aktualisieren und senden
;					<> 0	Message nur aktualisieren
;			R4/R5		Zeiger auf Variablenspeicher
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehler
;veränderte Register:   CCR, B, X, Y
;------------------------------------------------------------------------------
					;
CAN_WRITE:
	MOVB	#0,R0			;Index stets = 0
					;
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	CAN_WRITE1		;dann
	LDAA	#E_CAN_INDEX		;  Fehler: ungültiger Index
	JMP	CAN_WRITE9		;
					;
CAN_WRITE1:
	LDAA	R1			;
	CMPA	#8			;wenn Message-Nummer > 7,
	BLO	CAN_WRITE2		;dann
	LDAA	#E_CAN_MESSAGE		;  Fehler: ungültige Message-Nummer
	JMP	CAN_WRITE9		;
					;
CAN_WRITE2:
	LDAA	R0			;
	LSLA				;MSCAN-Modul Index * 2
	STAA	R0			;
	LDAA	R1			;
	LSLA				;Message-Nummer * 2
	STAA	R1			;
					;
	LDY	#CANx_DESCR_ADR_TBL	;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Descriptoren
	LDY	B,Y			;
	LDAB	R1			;
	LDY	B,Y			;Zeiger auf Descriptor
	LDAA	1,Y			;Descriptor Low Byte lesen
	ANDA	#00001111b		;
	BEQ	CAN_WRITE5		;
	CMPA	#9			;wenn Message-Länge > 8,
	BLO	CAN_WRITE3		;dann
	LDAA	#E_CAN_LENGTH		;  Fehler: ungültige Message-Länge
	JMP	CAN_WRITE9		;
					;
CAN_WRITE3:
	LDX	R4			;Zeiger auf Datenquelle
	LDY	#CANx_CAN_ADR_TBL	;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Messagebuffer
	LDY	B,Y			;
	LDAB	R1			;
	LDY	B,Y			;Zeiger auf Messagebuffer
CAN_WRITE4:
	MOVB	1,X+,1,Y+		; > WRITE DATA TO DATA SEGMENT
	DBNE	A,CAN_WRITE4		;
					;
CAN_WRITE5:
	LDAA	R2			;
	BEQ	CAN_WRITE6		;
	JMP	CAN_WRITE8		;
					;
CAN_WRITE6:
	LDX	#CANx_TRSR_TBL		;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Transmit Request Set Flags
	LDX	B,X			;
	LDAB	R1			;
	LSLB				;
	LDY	B,X			;Adresse
	INCB				;
	INCB				;
	LDAA	B,X			;Maske
	ORAA	0,Y			;
	STAA	0,Y			; > SET TRANSMIT REQUEST
					;
CAN_WRITE8:
	LDAA	R0			;
	LDY	#CANx_BASE_TBL		;
	LDY	A,Y			;MSCANx Register-Basisadresse
	BSET	TIER,Y,_TXEIE2 | _TXEIE1 | _TXEIE0 ;Transmit Interrupts enable
	CLRA				;ok, mit A = 0 zurück
					;
CAN_WRITE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: CAN_REQUEST fordert Daten für ein Kommunikationsobjekt an.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R1		Message-Nummer
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehler
;veränderte Register:   CCR, B, X, Y
;------------------------------------------------------------------------------
					;
CAN_REQUEST:
	MOVB	#0,R0			;Index stets = 0
					;
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	CAN_REQUEST1		;dann
	LDAA	#E_CAN_INDEX		;  Fehler: ungültiger Index
	JMP	CAN_REQUEST9		;
					;
CAN_REQUEST1:
	LDAA	R1			;
	CMPA	#8			;wenn Message-Nummer > 7,
	BLO	CAN_REQUEST2		;dann
	LDAA	#E_CAN_MESSAGE		;  Fehler: ungültige Message-Nummer
	JMP	CAN_REQUEST9		;
					;
CAN_REQUEST2:
	LDAA	R0			;
	LSLA				;MSCAN-Modul Index * 2
	STAA	R0			;
	LDAA	R1			;
	LSLA				;Message-Nummer * 2
	STAA	R1			;
					;
	LDY	#CANx_DESCR_ADR_TBL	;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Descriptoren
	LDY	B,Y			;
	LDAB	R1			;
	LDY	B,Y			;Zeiger auf Descriptor
	LDAA	1,Y			;Descriptor Low Byte lesen
	ANDA	#00011111b		;
	CMPA	#00010000b		;wenn RTR <> 1 und Message-Länge <> 0,
	BEQ	CAN_REQUEST3		;dann
	LDAA	#E_CAN_LENGTH		;  Fehler: ungültige Message-Länge
	JMP	CAN_REQUEST9		;
					;
CAN_REQUEST3:
	LDX	#CANx_TRSR_TBL		;Zeiger auf Adressentabelle der
	LDAB	R0			;MSCAN-Modul bezogenen Transmit Request Set Flags
	LDX	B,X			;
	LDAB	R1			;
	LSLB				;
	LDY	B,X			;Adresse
	INCB				;
	INCB				;
	LDAA	B,X			;Maske
	ORAA	0,Y			;
	STAA	0,Y			; > SET TRANSMIT REQUEST
					;
CAN_REQUEST8:
	LDAA	R0			;
	LDY	#CANx_BASE_TBL		;
	LDY	A,Y			;MSCANx Register-Basisadresse
	BSET	TIER,Y,_TXEIE2 | _TXEIE1 | _TXEIE0 ;Transmit Interrupts enable
	CLRA				;ok, mit A = 0 zurück
					;
CAN_REQUEST9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
;Tabellen für CAN_INIT
;
	even
CANx_BASE_TBL:
	dc.w	CAN0_BASE		;
CANx_BASE_TBL_CNT:	equ	(* - CANx_BASE_TBL) / 2
					;
	even
CANx_VAR_TBL:
	dc.w	CAN0_VAR		;
CANx_VAR_TBL_CNT:	equ	(* - CANx_VAR_TBL) / 2
					;
;------------------------------------------------------------------------------
;Tabellen für CAN_INIT und CAN_STATUS
;
	even
CANx_STATUS_TBL:
	dc.w	CAN0_STATUS		;
CANx_STATUS_TBL_CNT:	equ	(* - CANx_STATUS_TBL) / 2
					;
;------------------------------------------------------------------------------
;Tabellen für CAN_READ, CAN_WRITE und CAN_REQUEST
;
	even
CANx_RRR_TBL:
	dc.w	CAN0_RRR_TBL		;
CANx_RRR_TBL_CNT:	equ	(* - CANx_RRR_TBL) / 2
					;
	even
CANx_TRSR_TBL:
	dc.w	CAN0_TRSR_TBL		;
CANx_TRSR_TBL_CNT:	equ	(* - CANx_TRSR_TBL) / 2
					;
	even
CANx_DESCR_ADR_TBL:
	dc.w	CAN0_DESCR_ADR_TBL	;
CANx_DESCR_ADR_TBL_CNT:	equ	(* - CANx_DESCR_ADR_TBL) / 2
					;
	even
CANx_CAN_ADR_TBL:
	dc.w	CAN0_CAN_ADR_TBL	;
CANx_CAN_ADR_TBL_CNT:	equ	(* - CANx_CAN_ADR_TBL) / 2
					;
;------------------------------------------------------------------------------
;Adressen und Masken für MSCAN-Modul 0
;
	even
CAN0_RRR_TBL:
	dc.w	CAN0_RRR		;
	dc.b	11111110b		;
	even
	dc.w	CAN0_RRR		;
	dc.b	11111101b		;
	even
	dc.w	CAN0_RRR		;
	dc.b	11111011b		;
	even
	dc.w	CAN0_RRR		;
	dc.b	11110111b		;
	even
	dc.w	CAN0_RRR		;
	dc.b	11101111b		;
	even
	dc.w	CAN0_RRR		;
	dc.b	11011111b		;
	even
	dc.w	CAN0_RRR		;
	dc.b	10111111b		;
	even
	dc.w	CAN0_RRR		;
	dc.b	01111111b		;
					;
	even
CAN0_TRSR_TBL:
	dc.w	CAN0_TRSR		;
	dc.b	00000001b		;
	even
	dc.w	CAN0_TRSR		;
	dc.b	00000010b		;
	even
	dc.w	CAN0_TRSR		;
	dc.b	00000100b		;
	even
	dc.w	CAN0_TRSR		;
	dc.b	00001000b		;
	even
	dc.w	CAN0_TRSR		;
	dc.b	00010000b		;
	even
	dc.w	CAN0_TRSR		;
	dc.b	00100000b		;
	even
	dc.w	CAN0_TRSR		;
	dc.b	01000000b		;
	even
	dc.w	CAN0_TRSR		;
	dc.b	10000000b		;
					;
	even
CAN0_DESCR_ADR_TBL:
	dc.w	CAN0_DESCR0		;
	dc.w	CAN0_DESCR1		;
	dc.w	CAN0_DESCR2		;
	dc.w	CAN0_DESCR3		;
	dc.w	CAN0_DESCR4		;
	dc.w	CAN0_DESCR5		;
	dc.w	CAN0_DESCR6		;
	dc.w	CAN0_DESCR7		;
					;
	even
CAN0_CAN_ADR_TBL:
	dc.w	CAN0_MSG0		;
	dc.w	CAN0_MSG1		;
	dc.w	CAN0_MSG2		;
	dc.w	CAN0_MSG3		;
	dc.w	CAN0_MSG4		;
	dc.w	CAN0_MSG5		;
	dc.w	CAN0_MSG6		;
	dc.w	CAN0_MSG7		;
					;
;------------------------------------------------------------------------------
	end
