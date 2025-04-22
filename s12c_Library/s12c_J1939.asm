	include	"s12c_128.sfr"
	title	"s12c_J1939  Copyright (C) 2008-2009, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_J1939.asm
;
;Copyright:	(C) 2008-2009, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	18.05.2009
;
;Description:	Funktionen für den Zugriff auf das prozessorinterne MSCAN-Modul
;		des Freescale MC9S12C128
;
;Dieses Programm-Modul wickelt die Kommunikation über ein CAN-Netz nach dem
;SAE J1939 Protokoll ab.
;
;MC9S12Cxx verfügt nur über ein MSCAN-Modul MSCAN0.
;
;========================================================
;Stand 03.08.2008:
;Bus-Arbitrierung / Anmeldung noch nicht implementiert!
;========================================================
;
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
;Beispiel für eine funktionsfähige Konfigurationstabelle zur Verwendung in der
;Funktion CAN_CONFIG:
;
;CANX_CONFIG_TBL:			;250 kbit/s @16MHz Quartz
;					;
;Die vier Konfigurationsbytes sind entsprechend der Konventionen des MSCAN-Modules
;zu ermitteln. Hierbei ist die entsprechende Freescale Dokumentation zu Rate
;zu ziehen.
;
;Die Reihenfolge der Werte ist fest vorgegeben und darf nicht verändert werden.
;
;	dc.b	10000000b		;CANxCTL1: MSCAN enable, Oscillator Clock, Normal Operation
;	dc.b	00000111b		;CANxBTR0: SJW=1, Prescaler=8
;	dc.b	00100011b		;CANxBTR1: SAMP=0, TSEG2=3, TSEG1=4
;					;
;	dc.b	00000000b		;CANxIDAC: zwei 32-bit Akzeptanzfilter
;					;
;------------------------------------------------------------------------------
;Revision History:	Original Version  08.08
;
;18.05.2009	Anpassung an MC9S12C128
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
	xdef	J1939_READ		;Code
	xdef	J1939_RESET		;Code
	xdef	J1939_STATUS		;Code
	xdef	J1939_WRITE		;Code
					;
	xdef	CAN0_TX_INT		;Code
	xdef	CAN0_RX_INT		;Code

					;
	xdef.b	_CAN_RXOK		;bitMask
	xdef.b	_CAN_TXOK		;bitMask
	xdef.b	_CAN_RXSTAT		;bitMask
	xdef.b	_CAN_TXSTAT		;bitMask
					;
	xdef.b	E_J1939_CANNOTRECEIVE	;Number
	xdef.b	E_J1939_CANNOTTRANSMIT	;Number
	xdef.b	E_J1939_INDEX		;Number
	xdef.b	E_J1939_PARAMETER	;Number
	xdef.b	E_J1939_QUEUEEMPTY	;Number
	xdef.b	E_J1939_QUEUEFULL	;Number
	xdef.b	E_J1939_TIMEOUT		;Number
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
					;
;------------------------------------------------------------------------------
					;
E_J1939_TIMEOUT:	equ	-1	;
E_J1939_INDEX:		equ	-2	;
E_J1939_PARAMETER:	equ	-3	;
E_J1939_QUEUEEMPTY:	equ	-4	;
E_J1939_QUEUEFULL:	equ	-4	;
E_J1939_CANNOTTRANSMIT:	equ	-5	;
E_J1939_CANNOTRECEIVE:	equ	-5	;
					;
;------------------------------------------------------------------------------
;CANx_STATUS-bitMasks
;
_CAN_TXOK:	equ	bit0		;1, wenn seit letzter Abfrage Botschaft gesendet
_CAN_RXOK:	equ	bit1		;1, wenn seit letzter Abfrage Botschaft empfangen
_CAN_TXSTAT:	equ	bit2 | bit3	;
_CAN_RXSTAT:	equ	bit4 | bit5	;
;
;------------------------------------------------------------------------------
;CANx_FLAGS-bitMasks
;
_CANNOT_CLAIM_ADDRESS:		equ	bit0
_WAITING_FOR_ADDRESS_CLAIM:	equ	bit1
_GETTING_COMMANDED_ADDRESS:	equ	bit2
_GOT_FIRST_DATA_PACKET:		equ	bit3
_RECEIVED_MESSAGES_DROPPED:	equ	bit4
;
;
;
					;
HEADER_SIZE:	equ	4		;
DATA_SIZE:	equ	8		;
J1939_MSG_SIZE:	equ	HEADER_SIZE + DATA_SIZE
					;
TX_MSG_BUF_CNT:	equ	16		;Größe des Sendebuffers
RX_MSG_BUF_CNT:	equ	16		;Größe des Empfangsbuffers
					;
.locals:	section
					;
;------------------------------------------------------------------------------
;CAN0:	Reihenfolge und Typen der Variablen dürfen nicht verändert werden!
;
CAN0_VAR:
					;
B_CAN0_TX_BUF:				;Sendebuffer
	ds.b	TX_MSG_BUF_CNT * J1939_MSG_SIZE
T_CAN0_TX_BUF:
					;
pCAN0_TX_RD:
	ds.w	1			;DATA16: Sendebuffer-Lesezeiger
pCAN0_TX_WR:
	ds.w	1			;DATA16: Sendebuffer-Schreibzeiger
					;
	even
B_CAN0_RX_BUF:				;Empfangsbuffer
	ds.b	RX_MSG_BUF_CNT * J1939_MSG_SIZE
T_CAN0_RX_BUF:
					;
pCAN0_RX_RD:
	ds.w	1			;DATA16: Empfangsbuffer-Lesezeiger
pCAN0_RX_WR:
	ds.w	1			;DATA16: Empfangsbuffer-Schreibzeiger
					;
CAN0_STATUS:
	ds.b	1			;DATA8: Status
CAN0_FLAGS:
	ds.b	1			;DATA8: Flags
					;
oB_TX_BUF:	equ	B_CAN0_TX_BUF - CAN0_VAR
oT_TX_BUF:	equ	T_CAN0_TX_BUF - CAN0_VAR
opTX_RD:	equ	pCAN0_TX_RD - CAN0_VAR
opTX_WR:	equ	pCAN0_TX_WR - CAN0_VAR
oB_RX_BUF:	equ	B_CAN0_RX_BUF - CAN0_VAR
oT_RX_BUF:	equ	T_CAN0_RX_BUF - CAN0_VAR
opRX_RD:	equ	pCAN0_RX_RD - CAN0_VAR
opRX_WR:	equ	pCAN0_RX_WR - CAN0_VAR
oSTATUS:	equ	CAN0_STATUS - CAN0_VAR
oFLAGS:		equ	CAN0_FLAGS - CAN0_VAR
					;
.text:		section
					;
;------------------------------------------------------------------------------
;Tabellen mit jeweils MSCAN-Modul-bezogenen Variablenadressen.
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
;//////////////////////////////////////////////////////////////////////////////
;PACK_HEADER setzt Priority, Data Page, Parameter Group Number,
;Source Address sowie einige MSCAN-Modul spezifische bits zum
;32-bit Message-Header zusammen.
;
;Eingangsparameter:	0,X		*Priority/Data Page
;			1,X		*Parameter Group Number
;			3,X		*Source Address
;Ausgangsparameter:	[(0..3),X]	formatierter 32-bit Message-Header
;			X		bleibt unverändert!
;veränderte Register:   CCR, A, B
;//////////////////////////////////////////////////////////////////////////////
					;
PACK_HEADER:
	LDAA	0,X			;[0,Y]/[1,Y] nach A:B
	LDAB	1,X			;
	LSLD				;A:B um zwei bit nach links schieben
	LSLD				;
	ANDA	#01111111b		;
	STAA	0,X			;
	ANDB	#11110000b		;
	ORAB	#00001100b		;MSCAN-Modul spezifische bits SRR=1, IDE=1
	LDAA	1,X			;in PDU Format einbauen
	ANDA	#00000011b		;
	ABA				;
	STAA	1,X			;
	LDD	2,X			;alles um ein bit nach links schieben
	LSLD				;MSCAN-Modul spezifisches bit RTR=0
	STD	2,X			;
	ROL	1,X			;
	ROL	0,X			;
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;UNPACK_HEADER separiert Data Page, Parameter Group Number und
;Source Address aus dem 32-bit Message-Header.
;
;Eingangsparameter:	[(0..3),Y]	formatierter 32-bit Message-Header
;Ausgangsparameter:	0,Y		*Data Page
;			1,Y		*Parameter Group Number
;			3,Y		*Source Address
;			Y		bleibt unverändert!
;veränderte Register:   CCR, A, B
;//////////////////////////////////////////////////////////////////////////////
					;
UNPACK_HEADER:
	LDAA	0,Y			;
	LDAB	1,Y			;
	LSRD				;alle Register um ein bit nach rechts schieben
	STAA	0,Y			;
	STAB	1,Y			;
	ROR	2,Y			;> [2,Y] : PDU Specific
	ROR	3,Y			;> [3,Y] : Source Address
	LDAA	0,Y			;[0,Y]/[1,Y] nach A:B
	LDAB	1,Y			;
	LSRD				;A:B um zwei bit nach rechts schieben
	LSRD				;
	ANDA	#00000011b		;Data Page maskieren, Priority ignorieren
	STAA	0,Y			;> [0,Y] : Data Page
	ANDB	#11111100b		;PDU Format linken Teil maskieren
	LDAA	1,Y			;
	ANDA	#00000011b		;PDU Format rechten Teil maskieren
	ABA				;beide Teile zusammensetzen
	STAA	1,Y			;> [1,Y] : PDU Format
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;CAN0_TX_INT		CAN0 Sende-Interrupt
;
;Priorität:		normal
;Interruptquelle:	CAN0TFLG._TXE2 | _TXE1 | _TXE0
;Auslöser:              Transmitter Buffer Empty
;Initialisierung:	Module 's12_J1939'
;
;Eingangsparameter:	pCAN0_TX_RD
;Ausgangsparameter:	pCAN0_TX_RD
;			CAN0_STATUS._CAN_TXOK
;Laufzeit:		? µs		@ 16 MHz
;//////////////////////////////////////////////////////////////////////////////
					;
CAN0_TX_INT:
	LDD	R0			;Register retten
	PSHD				;
	BSET	CAN0_STATUS,_CAN_TXOK	;
					;
	LDX	pCAN0_TX_RD		;
	CPX	pCAN0_TX_WR		;wenn Schreibzeiger = Lesezeiger,
	BNE	CAN0_TX_INT1		;dann
	MOVB	#0,CAN0TIER		;  Transmit Interrupts sperren
	LBRA	CAN0_TX_INT9		;
					;
CAN0_TX_INT1:
	LDAA	CAN0TFLG		;sonst
	STAA	CAN0TBSEL		;
	LDAA	CAN0TBSEL		;
	STAA	R1			;  nächsten freien Sendebuffer finden
					;
	LDX	pCAN0_TX_RD		;  Lesezeiger in Sendebuffer
	JSR	PACK_HEADER		;  Message-Header packen
	LDY	#CAN0TXIDR0		;  Zeiger auf 32-bit Identifier
	LDAB	#HEADER_SIZE		;
CAN0_TX_INT2:
	MOVB	1,X+,1,Y+		;  Header eintragen
	DBNE	B,CAN0_TX_INT2		;
					;
	LDY	#CAN0TXDSR0		;  Zeiger auf 64-bit Datenfeld
	LDAB    #DATA_SIZE		;
	ANDB	#00001111b		;
	STAB	CAN0TXDLR		;  Anzahl Bytes der Botschaft eintragen
					;
CAN0_TX_INT3:
	MOVB	1,X+,1,Y+		;  Botschaft eintragen
	DBNE	B,CAN0_TX_INT3		;
					;
	CPX	#T_CAN0_TX_BUF		;  wenn Lesezeiger auf Bufferende zeigt,
	BLO	CAN0_TX_INT4		;  dann
	LDX	#B_CAN0_TX_BUF		;    Lesezeiger auf Bufferanfang setzen
CAN0_TX_INT4:
	STX	pCAN0_TX_RD		;  Lesezeiger ablegen
					;
	CLR	CAN0TXBPR		;  Sendepriorität stets auf null setzen
	MOVB	R1,CAN0TFLG		;  Sendevorgang starten
					;
CAN0_TX_INT9:
	PULD				;Register restaurieren
	STD	R0			;
	RTI				;
					;
;//////////////////////////////////////////////////////////////////////////////
;CAN0_RX_INT		CAN0 Empfangs-Interrupt
;
;Priorität:		normal
;Interruptquelle:	CAN0RFLG._RXF
;Auslöser:              Receive Buffer Full
;Initialisierung:	Module 's12_J1939'
;
;Eingangsparameter:	pCAN0_RX_WR
;Ausgangsparameter:	pCAN0_RX_WR
;			CAN0_STATUS._CAN_RXOK
;Laufzeit:		? µs		@ 16 MHz
;//////////////////////////////////////////////////////////////////////////////
					;
CAN0_RX_INT:
	LDD	R0			;Register retten
	PSHD				;
	BSET	CAN0_STATUS,_CAN_RXOK	;
					;
	LDX	#CAN0RXIDR0		;Zeiger auf 32-bit Identifier
	LDY	pCAN0_RX_WR		;Schreibzeiger in Empfangsbuffer
	LDAB	#HEADER_SIZE		;
CAN0_RX_INT1:
	MOVB	1,X+,1,Y+		;Header eintragen
	DBNE	B,CAN0_RX_INT1		;
					;
	LDX	#CAN0RXDSR0		;Zeiger auf 64-bit Datenfeld
	LDAB    #DATA_SIZE		;
CAN0_RX_INT2:
	MOVB	1,X+,1,Y+		;Botschaft eintragen
	DBNE	B,CAN0_RX_INT2		;
					;
	LDY	pCAN0_RX_WR		;
	JSR	UNPACK_HEADER		;Message-Header auspacken
;begin hier fehlt noch einiges

	LEAY	J1939_MSG_SIZE,Y	;Schreibzeiger verschieben
	CPY	#T_CAN0_RX_BUF		;wenn Zeiger auf Bufferende zeigt,
	BLO	CAN0_RX_INT4		;dann
	LDY	#B_CAN0_RX_BUF		;  Zeiger auf Bufferanfang setzen
CAN0_RX_INT4:
	STY	pCAN0_RX_WR		;Schreibzeiger ablegen

;end
					;
CAN0_RX_INT9:
	MOVB	#_RXF,CAN0RFLG		;Receive Buffer Full Flag rücksetzen
					;
	PULD				;Register restaurieren
	STD	R0			;
	RTI				;
					;
;------------------------------------------------------------------------------
;NEXT_TX verschiebt den Schreibzeiger des Sendebuffers.
;
;Eingangsparameter:	X		Basisadresse der Variablen
;			Y		Schreibzeiger des Sendebuffers
;Ausgangsparameter:	X		bleibt unverändert!
;			Y		aktualisierter Schreibzeiger
;veränderte Register:   CCR, A, B, R[10..11]
;------------------------------------------------------------------------------
					;
NEXT_TX:
	LEAY	J1939_MSG_SIZE,Y	;Zeiger verschieben
	TFR	X,D			;
	ADDD	#oT_TX_BUF		;
	STD	R10			;
	CPY	R10			;wenn Zeiger jetzt auf Bufferende zeigt,
	BLO	NEXT_TX1		;dann
	LEAY	oB_TX_BUF,X		;  Zeiger auf Bufferanfang setzen
NEXT_TX1:
	RTS				;
					;
;------------------------------------------------------------------------------
;WR_TX_BUF legt ein Telegramm im Sendebuffer ab und verschiebt den Schreibzeiger.
;
;Eingangsparameter:	R1		Priority
;			R2/R6/R7/R8	Header
;			R4/R5		Zeiger auf Datenfeld
;			X		Basisadresse der Variablen
;Ausgangsparameter:	X		bleibt unverändert!
;veränderte Register:   CCR, A, B, Y, R[10..11]
;------------------------------------------------------------------------------
					;
WR_TX_BUF:
	BRCLR	oFLAGS,X,_CANNOT_CLAIM_ADDRESS,WR_TX_BUF1
					;wenn FLAGS._CANNOT_CLAIM_ADDRESS
	LDAA	#E_J1939_CANNOTTRANSMIT	;dann
	JMP	WR_TX_BUF9		;  Fehler: Senden nicht möglich
					;
WR_TX_BUF1:
	LDY	opTX_WR,X		;
	JSR	NEXT_TX			;Schreibzeiger probeweise verschieben
	CPY	opTX_RD,X		;wenn danach Schreibzeiger = Lesezeiger
	BNE	WR_TX_BUF2		;dann
	LDAA	#E_J1939_QUEUEFULL	;  Fehler: Sendebuffer voll
	JMP	WR_TX_BUF9		;
					;sonst
WR_TX_BUF2:
	LDY	opTX_WR,X		;  Schreibzeiger
	LDAA	R2			;
	LDAB	R1			;  R1 zweimal nach links schieben
	LSLB				;
	LSLB				;
	ABA				;  und dann mit R2 überlagern
	STAA	1,Y+			;  32-bit Header
	LDAA	R6			;
	STAA	1,Y+			;
	LDAA	R7			;
	STAA	1,Y+			;
	LDAA	R8			;
	STAA	1,Y+			;
	PSHX				;  Variablen-Basisadresse retten
	LDX	R4			;
	LDAB	#DATA_SIZE		;
WR_TX_BUF3:
	LDAA	1,X+			;  64-bit Datenfeld
	STAA	1,Y+			;
	DBNE	B,WR_TX_BUF3		;
	PULX				;  Variablen-Basisadresse restaurieren
	LDY	opTX_WR,X		;
	JSR	NEXT_TX			;  Schreibzeiger verschieben
	STY	opTX_WR,X		;
	CLRA				;
					;
WR_TX_BUF9:
	RTS				;
					;
;------------------------------------------------------------------------------
;NEXT_RX verschiebt den Lesezeiger des Empfangsbuffers.
;
;Eingangsparameter:	X		Lesezeiger des Empfangsbuffers
;			Y		Basisadresse der Variablen
;Ausgangsparameter:	X		aktualisierter Lesezeiger
;			Y		bleibt unverändert!
;veränderte Register:   CCR, A, B, R[10..11]
;------------------------------------------------------------------------------
					;
NEXT_RX:
	LEAX	J1939_MSG_SIZE,X	;Zeiger verschieben
	TFR	Y,D			;
	ADDD	#oT_RX_BUF		;
	STD	R10			;
	CPX	R10			;wenn Zeiger jetzt auf Bufferende zeigt,
	BLO	NEXT_RX1		;dann
	LEAX	oB_RX_BUF,Y		;  Zeiger auf Bufferanfang setzen
NEXT_RX1:
	RTS				;
					;
;------------------------------------------------------------------------------
;RD_RX_BUF liest ein Telegramm aus dem Empfangsbuffer und verschiebt den Lesezeiger.
;
;Eingangsparameter:	R4/R5		Zeiger auf Datenfeld
;			Y		Basisadresse der Variablen
;Ausgangsparameter:	R2/R6/R7/R8	Header
;			R4/R5		bleibt unverändert!
;			Y		bleibt unverändert!
;veränderte Register:   CCR, A, B, X, R[10..11]
;------------------------------------------------------------------------------
					;
RD_RX_BUF:
	LDX	opRX_RD,Y		;
	CPX	opRX_WR,Y		;wenn Lesezeiger = Schreibzeiger
	BNE	RD_RX_BUF2		;dann
					;
	BRCLR	oFLAGS,X,_CANNOT_CLAIM_ADDRESS,RD_RX_BUF1
					;  wenn FLAGS._CANNOT_CLAIM_ADDRESS
	LDAA	#E_J1939_CANNOTRECEIVE	;  dann
	JMP	RD_RX_BUF9		;    Fehler: Empfangen nicht möglich
					;  sonst
RD_RX_BUF1:
	LDAA	#E_J1939_QUEUEEMPTY	;    Fehler: Empfangsbuffer leer
	BRA	RD_RX_BUF9		;
					;sonst
RD_RX_BUF2:
	LDX	opRX_RD,Y		;  Lesezeiger
	LDAA	1,X+			;  32-bit Header
	STAA	R2			;
	LDAA	1,X+			;
	STAA	R6			;
	LDAA	1,X+			;
	STAA	R7			;
	LDAA	1,X+			;
	STAA	R8			;
	PSHY				;  Variablen-Basisadresse retten
	LDY	R4			;
	LDAB	#DATA_SIZE		;
RD_RX_BUF3:
	LDAA	1,X+			;  64-bit Datenfeld
	STAA	1,Y+			;
	DBNE	B,RD_RX_BUF3		;
	PULY				;  Variablen-Basisadresse restaurieren
	LDX	opRX_RD,Y		;
	JSR	NEXT_RX			;  Lesezeiger verschieben
	STX	opRX_RD,Y		;
	CLRA				;
					;
RD_RX_BUF9:
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;CAN_STOP unterbricht die CAN-Kommunikation.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehler
;veränderte Register:   CCR, B, Y
;//////////////////////////////////////////////////////////////////////////////
					;
CAN_STOP:
	LDAA	R0			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_BASE_TBL		;
	LDY	A,Y			;MSCANx Register-Basisadresse
	BSET	CTL0,Y,_INITRQ		;CTL0._INITRQ setzen
					;
	LDD	#BUS_CLK		;BUS_CLK / 8
	LSRD				;
	LSRD				;
	LSRD				;liefert Zeitgrenze
CAN_STOP1:
	BRCLR	CTL1,Y,_INITAK,CAN_STOP2;warten, bis CTL1._INITAK
	BRSET	CTL0,Y,_INITRQ,CAN_STOP3;und CTL0._INITRQ gesetzt
CAN_STOP2:
	DBNE	D,CAN_STOP1		;wenn Zeitgrenze erreicht,
	LDAA	#E_J1939_TIMEOUT	;dann
	JMP	CAN_STOP9		;  Fehler: Timeout
					;
CAN_STOP3:
	CLRA				;wenn ok, dann mit A = 0 zurück
					;
CAN_STOP9:
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;CAN_CONFIG stellt die Betriebsart eines MSCAN-Moduls ein.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R4/R5		Zeiger auf Konfigurationsdaten
;Ausgangsparameter:
;veränderte Register:   CCR, A, B, X, Y
;//////////////////////////////////////////////////////////////////////////////
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
	LDAB	#0FFh			;
	STAB	IDMR0,Y			;set to: Ignore Acceptance Code Register
	STAB	IDMR1,Y			;
	STAB	IDMR2,Y			;
	STAB	IDMR3,Y			;
	STAB	IDMR4,Y			;
	STAB	IDMR5,Y			;
	STAB	IDMR6,Y			;
	STAB	IDMR7,Y			;
					;
	LDAA	R0			;
	LSLA				;
	LDY	#CANx_VAR_TBL		;
	LDY	A,Y			;
	LEAX	oB_TX_BUF,Y		;
	STX	opTX_WR,Y		;
	STX	opTX_RD,Y		;
	LEAX	oB_RX_BUF,Y		;
	STX	opRX_WR,Y		;
	STX	opRX_RD,Y		;
	LDAA	#0			;
	STAA	oSTATUS,Y		;
	LDAA	#0			;
	STAA	oFLAGS,Y		;
;TEST
;	BSET	oFLAGS,Y,_CANNOT_CLAIM_ADDRESS
;TEST
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;CAN_START startet die CAN-Kommunikation.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehler
;veränderte Register:   CCR, B, Y
;//////////////////////////////////////////////////////////////////////////////
					;
CAN_START:
	LDAA	R0			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_BASE_TBL		;
	LDY	A,Y			;MSCANx Register-Basisadresse
	BCLR	CTL0,Y,_INITRQ		;CTL0._INITRQ rücksetzen
					;
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
	LDAA	#E_J1939_TIMEOUT	;dann
	JMP	CAN_START9		;  Fehler: Timeout
					;
CAN_START3:
	LDAA	R0			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_VAR_TBL		;
	LDY	A,Y			;
	LDAA	#00000000b		;
	STAA	oSTATUS,Y		;CANx-Status rücksetzen
					;
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
;Public: J1939_RESET
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R4/R5		Zeiger auf Konfigurationsdaten
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:   CCR, B, X, Y
;------------------------------------------------------------------------------
					;
J1939_RESET:
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	J1939_RESET1		;dann
	LDAA	#E_J1939_INDEX		;  Fehler: ungültiger Index
	JMP	J1939_RESET9		;
					;
J1939_RESET1:
	JSR	CAN_STOP		;CAN-Controller anhalten
	BNE	J1939_RESET9		;wenn ok,
	JSR	CAN_CONFIG		;dann
	JSR	CAN_START		;  CAN-Controller in Grundstellung und starten
					;
J1939_RESET9:
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: J1939_STATUS liefert den Status eines MSCAN-Moduls.
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
;//////////////////////////////////////////////////////////////////////////////
					;
J1939_STATUS:
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	J1939_STATUS1		;dann
	LDAA	#E_J1939_INDEX		;  Fehler: ungültiger Index
	JMP	J1939_STATUS9		;
					;
J1939_STATUS1:
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_BASE_TBL		;MSCANx Register-Basisadresse
	LDY	A,Y			;
	LDAB	RFLG,Y			;CANxRFLG-Register lesen
	ANDB	#00111100b		;nur Receiver- und Transmitter-Statusbits übernehmen
					;
	LDY	#CANx_VAR_TBL		;Variablen-Basisadresse
	LDY	A,Y			;
	LDAA	oSTATUS,Y		;
	ANDA	#11000011b		;CANx-Status lesen
					;
	MOVB	#00000000b,0,Y		;CANx-Status rücksetzen
	ABA				;MSCANx Statusbits und CANx-Statusbits überlagern
					;
J1939_STATUS9:
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: J1939_WRITE schreibt eine Botschaft in den Sende-Ringbuffer.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R1		Priority (P) (0..7)
;			R2		Data Page (DP) (0..2)
;			R4/R5		Zeiger auf Datenfeld
;			R6/R7		Parameter Group Number (PGN)
;			R8		Source Address (SA)
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:   CCR, B, X, Y, R[10..11]
;//////////////////////////////////////////////////////////////////////////////
					;
J1939_WRITE:
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	J1939_WRITE1		;dann
	LDAA	#E_J1939_INDEX		;  Fehler: ungültiger Index
	JMP	J1939_WRITE9		;
					;
J1939_WRITE1:
	LDAA	R1			;
	CMPA	#7			;wenn Priority > 7
	BHI	J1939_WRITE2		;
	LDAA	R2			;
	CMPA	#2			;oder Data Page > 2,
	BLS	J1939_WRITE3		;dann
J1939_WRITE2:
	LDAA	#E_J1939_PARAMETER	;  Fehler: ungültiger Parameter
	JMP	J1939_WRITE9		;
					;sonst
J1939_WRITE3:
	LDAA	R0			;
	LSLA				;
	LDX	#CANx_VAR_TBL		;
	LDX	A,X			;
	JSR	WR_TX_BUF		;  Telegramm in Sendebuffer eintragen
	BNE	J1939_WRITE9		;  wenn ok,
					;  dann
	LDAA	R0			;
	LSLA				;    Index * 2 liefert Zeiger in Tabelle
	LDY	#CANx_BASE_TBL		;    MSCANx Register-Basisadresse
	LDY	A,Y			;    enable Transmit Interrupts
	BSET	TIER,Y,_TXEIE2 | _TXEIE1 | _TXEIE0
					;
	CLRA				;    mit A = 0 zurück
					;
J1939_WRITE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: J1939_READ liest eine Botschaft aus dem Empfangs-Ringbuffer.
;
;Eingangsparameter:	R0		MSCAN-Modul Index (0..1)
;			R4/R5		Zeiger auf Datenfeld
;Ausgangsparameter:	R2		Data Page (DP)
;			R4/R5		bleibt unverändert!
;			R6/R7		Parameter Group Number (PGN)
;			R8		Source Address (SA)
;			A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:   CCR, B, X, Y, R[10..11]
;------------------------------------------------------------------------------
					;
J1939_READ:
	LDAA	R0			;
	CMPA	#LOW(CANx_BASE_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	J1939_READ1		;dann
	LDAA	#E_J1939_INDEX		;  Fehler: ungültiger Index
	JMP	J1939_READ9		;
					;sonst
J1939_READ1:
	LDAA	R0			;
	LSLA				;
	LDY	#CANx_VAR_TBL		;
	LDY	A,Y			;
	JSR	RD_RX_BUF		;  Telegramm aus Empfangsbuffer lesen
	BNE	J1939_READ9		;  wenn ok,
					;  dann
	CLRA				;    mit A = 0 zurück
					;
J1939_READ9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end


































