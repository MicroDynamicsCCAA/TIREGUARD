	include	"s12ga_240.sfr"
	include	"s12ga_Switches.sfr"
	title	"tg4LIN  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg4LIN.asm
;
;Copyright: 	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	07.01.2015
;
;Description:	LIN Kommunikation mit Triggersendern und Empfangsantennen
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3LIN.asm
;
;12.04.2014	Version 4.0 Beta 0
;
;18.09.2013	Version 0.0 unverändert aus bmLIN.asm
;
;09.07.2012	Version 4.60
;		diverse Korrekturen
;		Schedule Tabellen erheblich umgestaltet

;19.05.2012	Version 4.50
;		Radsender-Statusausgabe in Telegramm 0x721
;25.04.2012	Version 4.40
;               Antennenprüftakt (ANTENNA_CT) von 5 auf 10 Sekunden verlängert
;30.03.2012	Version 4.30
;
;28.02.2011	Version 4.00
;08.02.2011	Integration der TIREGUARD3a- in die POWRGUARD-Firmware
;		aus tg3LIN.asm unverändert übernommen
;
;05.07.2008	Version 2.10
;		Autotransmission OFF, neue zusätzliche Schedule Table
;		wenn mehrere Telegramme im HF-Empfangsbuffer einer Antenne,
;		dann jetzt jedes Telegramm auswerten, nicht nur das letzte
;
;27.11.2007	Version 2.00
;		Ergänzungen für LIN-Empfangsmultiplexer
;
;24.11.2006	Version 1.00
;20.11.2006	Einbindung des Treibers MC33879
;		- Deklaration der Variablen PWS_STATE
;		- Änderung der Schedule Tabellen
;		- Änderungen in Funktion NEXT_FRAME
;08.11.2006	Anpassung an MC9S12C128
;
;09.02.2006
;10.12.2005
;------------------------------------------------------------------------------
					;
_true:		equ	1		;
_false:		equ	0		;
					;
fRXSingle:	equ	_false		;= _true :  es wird nur die Empfangsantenne
					;           an der Triggerposition abgefragt
					;= _false : es werden stets alle Empfangs-
					;	    antennen abgefragt
					;
fWheels:	equ	4		;Anzahl montierter Räder bzw. Antennen
					;zulässiger Wertebereich ist [1..4]
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
 ifne fDebug
	xref	TEST_BUF
	xref	TEST_S1_BUF
	xref	TEST_CHECKSUM
	xref	TEST_CTR
	xref	TEST_VAL
 endif
					;
	xref	CAN_WRITE		;Code
	xref	CLEAR_BUFFER16		;Code
	xref	LIN_READ		;Code
	xref	LIN_REQUEST		;Code
	xref	LIN_RESET		;Code
	xref	LIN_STATUS		;Code
	xref	LIN_WRITE		;Code
	xref	PWS_UPDATE		;Code
	xref	MUX_UPDATE		;Code
					;
	xref	LIN_IDENTIFIER_TBL	;roData
					;
	xref	E_CAN_MASK		;bssData
	xref.b	_DIAGNOSIS		;bitMask
					;
	xref	DIAG_BUF		;Data
					;
	xref	BD_9600_REL		;Number
	xref	oIDENTIFIER		;Number
	xref	oSTATUS			;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	LIN_START		;Code
	xdef	LIN_RUN			;Code
					;
	xdef	LIN_ADC_BUF		;Data
	xdef	LIN_ANT_FLAGS		;Data
	xdef	LIN_CONFIG_BUF		;Data
	xdef	LIN_RX_BUF		;Data
	xdef	LIN_RX_POS		;Data
	xdef	LIN_TIME_CTR		;Data
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
					;Zeitangaben in Einheiten der Programmzykluszeit (10 ms):
CLOCK_CT:	equ	2		;LIN-Takt
ANTENNA_CT:	equ	1000		;Antennenprüfungstakt = 10 Sekunden
					;
;//////////////////////////////////////////////////////////////////////////////
;Hardware dependent constants
;//////////////////////////////////////////////////////////////////////////////
					;
;------------------------------------------------------------------------------
;Versorgungsspannungs-Bitmasken
;
_TX_FR:		equ	bit4		;
_TX_FL:		equ	bit2		;
_TX_RR:		equ	bit3		;
_TX_RL:		equ	bit6		;
					;
;------------------------------------------------------------------------------
;RX-Multiplexer-Positionen
;
;	       _B      _A
;RX_FR		0	1	1
;RX_FL		0	0	0
;RX_RR		1	1	3
;RX_RL		1	0	2
					;
;------------------------------------------------------------------------------
					;
.roData:		section
					;
;------------------------------------------------------------------------------
;Schedule Tables
;
;Jeder Frame-Eintrag umfasst fest 5 Bytes.
;Wenn ein internes Kommando vorliegt (Messager-ID = 80h) oder das
;Schreib-/Lese Flag (Command.7) gesetzt ist, ist zusätzlich die
;Anzahl Datenbytes (Command.[0..3]) zu berücksichtigen.
;
;Byte 0:	Message-ID      0..3Bh	Übertragung von Signalen
;				80h	internes Kommando
;Byte 1:	Command
;		bit[0..3]	1..8	Anzahl Datenbytes
;		bit[4..5]	0..3	RX-Multiplexer-Position
;		bit[6]			reserviert
;		bit[7]			Schreib-/Lese# Flag
;Byte 2:	Delay 			in Anzahl der LIN-Takte
;Bytes [3..4]	DataPointer		Zeiger auf DataField (Command.7 = 1)
;					Zeiger auf Empfangsbuffer (Command.7 = 0)
;Bytes [5..x]	DataField		Botschaft (Command.7 = 1)
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Spannung einschalten
					;
INITIALIZATION_TBL:
					;
;------------------------------------------------------------------------------
					;
INIT_TX1:
B_INIT_OFF:
		dc.b	80h, 11h, 4	;Power-Off
		dc.w	PWS_STATE	;
		dc.b	LOW(~ _TX_FL)	;
					;
B_INIT_ON:
		dc.b	80h, 41h, 2	;Power-On
		dc.w	PWS_STATE	;
		dc.b	_TX_FL		;
					;
		dc.b	21h, 84h, 0	;Message-ID = 21h, 4 Bytes senden
		dc.w	*+2		;
		dc.b	0Fh,01h,00h,0FEh;Trigger 1
					;
		dc.b	02h, 82h, 0	;Message-ID = 02h, 2 Bytes senden
		dc.w	*+2		;
					;
oINIT_OFF_ID:	equ	(* - B_INIT_OFF); = 26
oINIT_ON_ID:	equ	(* - B_INIT_ON)	; = 20
					;
		dc.b	01h,64h		;
					;
		dc.b	24h, 04h, 0	;Message-ID = 24h, 4 Bytes empfangen
		dc.w	TX1_CONF	;
					;
INIT_ENTRY_SIZE: equ	(* - INIT_TX1)	; = 33
					;
 if fWheels = 1
INITIALIZATION_END:
 endif
					;
;------------------------------------------------------------------------------
					;
INIT_TX2:	dc.b	80h, 11h, 4	;Power-Off
		dc.w	PWS_STATE	;
		dc.b	LOW(~ _TX_FR)	;
					;
		dc.b	80h, 41h, 2	;Power-On
		dc.w	PWS_STATE	;
		dc.b	_TX_FR		;
					;
		dc.b	21h, 94h, 0	;Message-ID = 21h, 4 Bytes senden
		dc.w	*+2		;
		dc.b	0Fh,02h,00h,0FEh;Trigger 2
					;
		dc.b	02h, 92h, 0	;Message-ID = 02h, 2 Bytes senden
		dc.w	*+2		;
		dc.b	02h,64h		;
					;
		dc.b	24h, 14h, 0	;Message-ID = 24h, 4 Bytes empfangen
		dc.w	TX2_CONF	;
					;
 if fWheels = 2
INITIALIZATION_END:
 endif
					;
;------------------------------------------------------------------------------
					;
INIT_TX3:	dc.b	80h, 11h, 4	;Power-Off
		dc.w	PWS_STATE	;
		dc.b	LOW(~ _TX_RL)	;
					;
		dc.b	80h, 41h, 2	;Power-On
		dc.w	PWS_STATE	;
		dc.b	_TX_RL		;
					;
		dc.b	21h, 0A4h, 0	;Message-ID = 21h, 4 Bytes senden
		dc.w	*+2		;
		dc.b	0Fh,03h,00h,0FEh;Trigger 3
					;
		dc.b	02h, 0A2h, 0	;Message-ID = 02h, 2 Bytes senden
		dc.w	*+2		;
		dc.b	03h,64h		;
					;
		dc.b	24h, 24h, 0	;Message-ID = 24h, 4 Bytes empfangen
		dc.w	TX3_CONF	;
					;
 if fWheels = 3
INITIALIZATION_END:
 endif
					;
;------------------------------------------------------------------------------
					;
INIT_TX4:	dc.b	80h, 11h, 4	;Power-Off
		dc.w	PWS_STATE	;
		dc.b	LOW(~ _TX_RR)	;
					;
		dc.b	80h, 41h, 2	;Power-On
		dc.w	PWS_STATE	;
		dc.b	_TX_RR		;
					;
		dc.b	21h, 0B4h, 0	;Message-ID = 21h, 4 Bytes senden
		dc.w	*+2		;
		dc.b	0Fh,04h,00h,0FEh;Trigger 4
					;
		dc.b	02h, 0B2h, 0	;Message-ID = 02h, 2 Bytes senden
		dc.w	*+2		;
		dc.b	04h,64h		;
					;
		dc.b	24h, 34h, 0	;Message-ID = 24h, 4 Bytes empfangen
		dc.w	TX4_CONF	;
					;
 if fWheels >= 4
INITIALIZATION_END:
 endif
					;
;------------------------------------------------------------------------------
;Messdaten abfragen
					;
REQUEST_DATA_TBL:

;------------------------------------------------------------------------------
					;
REQ_ADC_RX1:
		dc.b	02h, 82h, 0
		dc.w	*+2
		dc.b	01h,085h	;Empfänger 1

		dc.b	05h, 02h, 0
		dc.w	RX1_ADC
					;
REQ_AUTOOFF_TX1:
		dc.b	02h, 82h, 0
		dc.w	*+2
		dc.b	01h,0BAh	;Trigger 1 Triggered Transmission Mode einschalten

		dc.b    3Ah, 88h, 5
		dc.w	*+2
		dc.b	45h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
					;
REQ_DATA_RX1:
		dc.b	21h, 84h, 1	;Trigger 1 einschalten
		dc.w	*+2
		dc.b	01h,01h,00h,43h

		dc.b	21h, 84h, 5	;Trigger 1 ausschalten
		dc.w	*+2
		dc.b	01h,01h,00h,40h
B_READ_CMD:
B_CMD:
		dc.b	02h, 82h, 0
		dc.w	*+2

CMD_SIZE:	equ	(* - B_CMD)	; = 5

		dc.b	01h,037h	;Empfänger 1

		dc.b	37h, 08h, 0
		dc.w	RX_DATA0

		dc.b	38h, 08h, 0
		dc.w	RX_DATA1

		dc.b	39h, 08h, 0
		dc.w	RX_DATA2

READ_CMD_SIZE:	equ	(* - B_READ_CMD); = 22
					;
 if fRXSingle = _false

   if fWheels > 1
		dc.b	02h, 92h, 0
		dc.w	*+2

		dc.b	02h,037h	;Empfänger 2

		dc.b	37h, 18h, 0
		dc.w	RX_DATA0

		dc.b	38h, 18h, 0
		dc.w	RX_DATA1

		dc.b	39h, 18h, 0
		dc.w	RX_DATA2
   endif

   if fWheels > 2
		dc.b	02h, 0A2h, 0
		dc.w	*+2
		dc.b	03h,037h	;Empfänger 3

		dc.b	37h, 28h, 0
		dc.w	RX_DATA0

		dc.b	38h, 28h, 0
		dc.w	RX_DATA1

		dc.b	39h, 28h, 0
		dc.w	RX_DATA2
   endif

   if fWheels > 3
		dc.b	02h, 0B2h, 0
		dc.w	*+2
		dc.b	04h,037h	;Empfänger 4

		dc.b	37h, 38h, 0
		dc.w	RX_DATA0

		dc.b	38h, 38h, 0
		dc.w	RX_DATA1

		dc.b	39h, 38h, 0
		dc.w	RX_DATA2
   endif

 endif
					;
 if fWheels = 1
REQUEST_DATA_END:
 endif
					;
;------------------------------------------------------------------------------
					;
REQ_ADC_RX2:
		dc.b	02h, 92h, 0
		dc.w	*+2
		dc.b	02h,085h	;Empfänger 2

		dc.b	05h, 12h, 0
		dc.w	RX2_ADC
					;
REQ_AUTOOFF_TX2:
		dc.b	02h, 92h, 0
		dc.w	*+2
		dc.b	02h,0BAh	;Trigger 2 Triggered Transmission Mode einschalten

		dc.b    3Ah, 98h, 5
		dc.w	*+2
		dc.b	45h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
					;
REQ_DATA_RX2:
		dc.b	21h, 94h, 1	;Trigger 2 einschalten
		dc.w	*+2
		dc.b	02h,02h,00h,43h

		dc.b	21h, 94h, 5	;Trigger 2 ausschalten
		dc.w	*+2
		dc.b	02h,02h,00h,40h


 if fRXSingle = _false

		dc.b	02h, 82h, 0
		dc.w	*+2
		dc.b	01h,037h	;Empfänger 1

		dc.b	37h, 08h, 0
		dc.w	RX_DATA0

		dc.b	38h, 08h, 0
		dc.w	RX_DATA1

		dc.b	39h, 08h, 0
		dc.w	RX_DATA2

 endif

		dc.b	02h, 92h, 0
		dc.w	*+2
		dc.b	02h,037h	;Empfänger 2

		dc.b	37h, 18h, 0
		dc.w	RX_DATA0

		dc.b	38h, 18h, 0
		dc.w	RX_DATA1

		dc.b	39h, 18h, 0
		dc.w	RX_DATA2

 if fRXSingle = _false

   if fWheels > 2
		dc.b	02h, 0A2h, 0
		dc.w	*+2
		dc.b	03h,037h	;Empfänger 3

		dc.b	37h, 28h, 0
		dc.w	RX_DATA0

		dc.b	38h, 28h, 0
		dc.w	RX_DATA1

		dc.b	39h, 28h, 0
		dc.w	RX_DATA2
   endif

   if fWheels > 3
		dc.b	02h, 0B2h, 0
		dc.w	*+2
		dc.b	04h,037h	;Empfänger 4

		dc.b	37h, 38h, 0
		dc.w	RX_DATA0

		dc.b	38h, 38h, 0
		dc.w	RX_DATA1

		dc.b	39h, 38h, 0
		dc.w	RX_DATA2
   endif

 endif
					;
 if fWheels = 2
REQUEST_DATA_END:
 endif
					;
;------------------------------------------------------------------------------
					;
REQ_ADC_RX3:
		dc.b	02h, 0A2h, 0
		dc.w	*+2
		dc.b	03h,085h	;Empfänger 3

		dc.b	05h, 22h, 0
		dc.w	RX3_ADC
					;
REQ_AUTOOFF_TX3:
		dc.b	02h, 0A2h, 0
		dc.w	*+2
		dc.b	03h,0BAh	;Trigger 3 Triggered Transmission Mode einschalten

		dc.b    3Ah, 0A8h, 5
		dc.w	*+2
		dc.b	45h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
					;
REQ_DATA_RX3:
		dc.b	21h, 0A4h, 1	;Trigger 3 einschalten
		dc.w	*+2
		dc.b	03h,03h,00h,43h

		dc.b	21h, 0A4h, 5	;Trigger 3 ausschalten
		dc.w	*+2
		dc.b	03h,03h,00h,40h

 if fRXSingle = _false

		dc.b	02h, 82h, 0
		dc.w	*+2
		dc.b	01h,037h	;Empfänger 1

		dc.b	37h, 08h, 0
		dc.w	RX_DATA0

		dc.b	38h, 08h, 0
		dc.w	RX_DATA1

		dc.b	39h, 08h, 0
		dc.w	RX_DATA2
;---
		dc.b	02h, 92h, 0
		dc.w	*+2
		dc.b	02h,037h	;Empfänger 2

		dc.b	37h, 18h, 0
		dc.w	RX_DATA0

		dc.b	38h, 18h, 0
		dc.w	RX_DATA1

		dc.b	39h, 18h, 0
		dc.w	RX_DATA2

 endif

		dc.b	02h, 0A2h, 0
		dc.w	*+2
		dc.b	03h,037h	;Empfänger 3

		dc.b	37h, 28h, 0
		dc.w	RX_DATA0

		dc.b	38h, 28h, 0
		dc.w	RX_DATA1

		dc.b	39h, 28h, 0
		dc.w	RX_DATA2


 if fRXSingle = _false
   if fWheels > 3
		dc.b	02h, 0B2h, 0
		dc.w	*+2
		dc.b	04h,037h	;Empfänger 4

		dc.b	37h, 38h, 0
		dc.w	RX_DATA0

		dc.b	38h, 38h, 0
		dc.w	RX_DATA1

		dc.b	39h, 38h, 0
		dc.w	RX_DATA2
   endif
 endif
					;
 if fWheels = 3
REQUEST_DATA_END:
 endif
					;
;------------------------------------------------------------------------------
					;
REQ_ADC_RX4:
		dc.b	02h, 0B2h, 0
		dc.w	*+2
		dc.b	04h,085h	;Empfänger 4

		dc.b	05h, 32h, 0
		dc.w	RX4_ADC
					;
REQ_AUTOOFF_TX4:
		dc.b	02h, 0B2h, 0
		dc.w	*+2
		dc.b	04h,0BAh	;Trigger 4 Triggered Transmission Mode einschalten

		dc.b    3Ah, 0B8h, 5
		dc.w	*+2
		dc.b	45h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
					;
REQ_DATA_RX4:
		dc.b	21h, 0B4h, 1	;Trigger 4 einschalten
		dc.w	*+2
		dc.b	04h,04h,00h,43h

		dc.b	21h, 0B4h, 5	;Trigger 4 ausschalten
		dc.w	*+2
		dc.b	04h,04h,00h,40h

 if fRXSingle = _false

		dc.b	02h, 82h, 0
		dc.w	*+2
		dc.b	01h,037h	;Empfänger 1

		dc.b	37h, 08h, 0
		dc.w	RX_DATA0

		dc.b	38h, 08h, 0
		dc.w	RX_DATA1

		dc.b	39h, 08h, 0
		dc.w	RX_DATA2
;---
		dc.b	02h, 92h, 0
		dc.w	*+2
		dc.b	02h,037h	;Empfänger 2

		dc.b	37h, 18h, 0
		dc.w	RX_DATA0

		dc.b	38h, 18h, 0
		dc.w	RX_DATA1

		dc.b	39h, 18h, 0
		dc.w	RX_DATA2
;---
		dc.b	02h, 0A2h, 0
		dc.w	*+2
		dc.b	03h,037h	;Empfänger 3

		dc.b	37h, 28h, 0
		dc.w	RX_DATA0

		dc.b	38h, 28h, 0
		dc.w	RX_DATA1

		dc.b	39h, 28h, 0
		dc.w	RX_DATA2

 endif

		dc.b	02h, 0B2h, 0
		dc.w	*+2
		dc.b	04h,037h	;Empfänger 4

		dc.b	37h, 38h, 0
		dc.w	RX_DATA0

		dc.b	38h, 38h, 0
		dc.w	RX_DATA1

		dc.b	39h, 38h, 0
		dc.w	RX_DATA2
					;
 if fWheels >= 4
REQUEST_DATA_END:
 endif
					;
;------------------------------------------------------------------------------
					;
_TRIG_FL:	equ	bit7
_REC_FL:	equ	bit6
_TRIG_FR:	equ	bit5
_REC_FR:	equ	bit4
_TRIG_RL:	equ	bit3
_REC_RL:	equ	bit2
_TRIG_RR:	equ	bit1
_REC_RR:	equ	bit0
					;
ANTENNA_TBL:
		dc.b	_TRIG_FL
		dc.b	_TRIG_FR
		dc.b	_TRIG_RL
		dc.b	_TRIG_RR
		dc.b	_REC_FL
		dc.b	_REC_FR
		dc.b	_REC_RL
		dc.b	_REC_RR
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:
					;
LIN_FLAGS:	ds.b	1
_ACTIVATED:	equ	bit0
_CHECKED:	equ	bit1
_ADC:		equ	bit2
_RUNNING:	equ	bit3
_AUTOOFF:	equ	bit4
_TRIGGERON:	equ	bit5
;
;
					;
SCHEDULE_FLAGS:	ds.b	1
_INTERN:	equ	bit0
_RESPONSE:	equ	bit1
;
;
;
;
;
_BUSY:		equ	bit7
					;
CLOCK_CTR:	ds.b	1
DELAY_CTR:	ds.b	1
					;
		even
ANTENNA_CTR:	ds.w	1		;DATA16:
ANTENNA_POS:	ds.b	1		;DATA8:
					;
LIN_ANT_FLAGS:
ANTENNA_FLAGS:	ds.b	1		;DATA8:
					;
		even
SCHEDULE_PTR:	ds.w	1
SCHEDULE_END:	ds.w	1
RESPONSE_PTR:	ds.w	1
SCHEDULE_CTR:	ds.b	1
					;
		even
LIN_CONFIG_BUF:
TX1_CONF:	ds.b	4
RX1_CONF:	ds.b	4
					;
TX2_CONF:	ds.b	4
RX2_CONF:	ds.b	4
					;
TX3_CONF:	ds.b	4
RX3_CONF:	ds.b	4
					;
TX4_CONF:	ds.b	4
RX4_CONF:	ds.b	4
					;
TX1_DIAG:	ds.b	4
RX1_DIAG:	ds.b	4
					;
TX2_DIAG:	ds.b	4
RX2_DIAG:	ds.b	4
					;
TX3_DIAG:	ds.b	4
RX3_DIAG:	ds.b	4
					;
TX4_DIAG:	ds.b	4
RX4_DIAG:	ds.b	4
					;
		align	16
RX_DATA0:	ds.b	8
RX_DATA1:	ds.b	8
RX_DATA2:	ds.b	8
					;
		align	16
LIN_ADC_BUF:
TX1_ADC:	ds.b	2
RX1_ADC:	ds.b	2
TX2_ADC:	ds.b	2
RX2_ADC:	ds.b	2
TX3_ADC:	ds.b	2
RX3_ADC:	ds.b	2
TX4_ADC:	ds.b	2
RX4_ADC:	ds.b	2
					;
		align	16
TX_DATA0:	ds.b	8
					;
		even
LIN_TIME_CTR:	ds.w	1
TIME_CTR:	ds.w	1
					;
PWS_STATE:	ds.b	1
					;
;------------------------------------------------------------------------------
					;
		align	16
LIN_RX_BUF:	ds.b	24		;DATA
					;
LIN_RX_POS:	ds.b	1		;DATA8:
LIN_TX_POS:	ds.b	1		;DATA8:
					;
TOV:
					;
.text_C000:	section
					;
;------------------------------------------------------------------------------
;Public: LIN_START bringt die LIN-Kommunikation in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
LIN_START:
	LDX	#BOV			;Anfang der Systemvariablen
	LDY	#(TOV - BOV)		;Anzahl Bytes
	LDAA	#0			;Füllwert
LIN_START1:
	STAA	1,X+			;
	DBNE	Y,LIN_START1		;alle Variablen auf Füllwert setzen
					;
	MOVB	#0,SCHEDULE_FLAGS	;
	MOVB	#CLOCK_CT,CLOCK_CTR	;
	MOVW	#ANTENNA_CT,ANTENNA_CTR	;
					;
	MOVW	#BD_9600_REL,R0		;9600 bps
	MOVB	#00000000b,R2		;8 Datenbits, 1 Stoppbit, kein Parity
	JSR	LIN_RESET		;LIN in Grundstellung
	RTS				;
					;
;------------------------------------------------------------------------------
;FMT_RX_STATUS bildet aus dem TP-Sensorstatus aus dem HF-Telegramm den für
;die CAN-Ausgabe vorbereiteten 4-bit Statuswert.
;bit 0,1	Mode indication                 Mode [0..3]
;bit 2		Transmission mode		1 : autotransmission = off
;bit 3		Transmission event source       1 : transmission on LF-command
;bit 4..7	dont care
;
;Eingangsparameter:	A		TP-Sensorstatus
;Ausgangsparameter:	R0		umformatierter Status
;veränderte Register:	CCR, B, R0
;------------------------------------------------------------------------------
					;
FMT_RX_STATUS:
	TAB				;Status nach B retten
	ANDA	#00000011b		;Mode maskieren
	STAA	R0			;und speichern

	TBA				;Status restaurieren
	ANDA	#00010000b		;Transmission mode maskieren
	BEQ	FMT_RX_STATUS1		;
	LDAA	R0			;
	ORAA	#00000100b		;und Ergebnis dazuspeichern
	STAA	R0			;
					;
FMT_RX_STATUS1:
	TBA				;Status restaurieren
	ANDA	#01000000b		;Transmission event source maskieren
	BEQ	FMT_RX_STATUS2		;
	LDAA	R0			;
	ORAA	#00001000b		;und Ergebnis dazuspeichern
	STAA	R0			;
					;
FMT_RX_STATUS2:
	RTS				;
					;
;------------------------------------------------------------------------------
;STO_RX_STATUS speichert TP-Sensorinformationen nach dem Empfang eines
;Datentelegrammes.
;
;Eingangsparameter:	LIN_RX_BUF
;			ANTENNA_POS
;Ausgangsparameter:	DIAG_BUF
;veränderte Register:	CCR, A, B, R0
;------------------------------------------------------------------------------
					;
STO_RX_STATUS:
	LDAB	ANTENNA_POS		;Empfangsantennenposition [1..4]
	ADDB	#3			;[1..4] => [4..7]
	LDAA	#0			;
	ADDD	#DIAG_BUF		;Basisadresse addieren
	TFR	D,Y			;nach Y
	LDX	#LIN_RX_BUF		;
	MOVB	oIDENTIFIER+3,X,0,Y	;Low Byte des Identifiers ablegen
	LDAA	oSTATUS,X		;
	JSR	FMT_RX_STATUS		;TP-Sensorstatus umformen
					;
	LDAB	ANTENNA_POS		;Empfangsantennenposition [1..4]
	DECB				;[1..4] => [0..3]
	CMPB	#4			;
	BHS	STO_RX_STATUS9		;
	CLRA				;
	LSLD				;
	LDX	#RX_TBL			;
	JMP	[D,X]			;
					;
RX_TBL:
	dc.w	RX_FL			;
	dc.w	RX_FR			;
	dc.w	RX_RL			;
	dc.w	RX_RR			;
					;
;------------------------------------------------------------------------------
RX_FL:
	LDY	#DIAG_BUF+2		;
	LDAA	0,Y			;
	ANDA	#00001111b		;
	STAA	0,Y			;
	LDAA	R0			;
	LSLA				;
	LSLA				;
	LSLA				;
	LSLA				;
	ANDA	#11110000b		;
	ORAA	0,Y			;
	BRA	RX_STATUS_ENTRY		;
					;
;------------------------------------------------------------------------------
RX_FR:
	LDY	#DIAG_BUF+2		;
	LDAA	0,Y			;
	ANDA	#11110000b		;
	STAA	0,Y			;
	LDAA	R0			;
	ANDA	#00001111b		;
	ORAA	0,Y			;
	BRA	RX_STATUS_ENTRY		;
					;
;------------------------------------------------------------------------------
RX_RL:
	LDY	#DIAG_BUF+3		;
	LDAA	0,Y			;
	ANDA	#00001111b		;
	STAA	0,Y			;
	LDAA	R0			;
	LSLA				;
	LSLA				;
	LSLA				;
	LSLA				;
	ANDA	#11110000b		;
	ORAA	0,Y			;
	BRA	RX_STATUS_ENTRY		;
					;
;------------------------------------------------------------------------------
RX_RR:
	LDY	#DIAG_BUF+3		;
	LDAA	0,Y			;
	ANDA	#11110000b		;
	STAA	0,Y			;
	LDAA	R0			;
	ANDA	#00001111b		;
	ORAA	0,Y			;
	BRA	RX_STATUS_ENTRY		;
					;
;------------------------------------------------------------------------------
RX_STATUS_ENTRY:
	STAA	0,Y			;umgeformten TP-Sensorstatus ablegen
					;
STO_RX_STATUS9:
	RTS				;
					;
;------------------------------------------------------------------------------
;BEFORE_WRITE wird unmittelbar vor dem Unterprogramm LIN_WRITE ausgeführt.
;
;Eingangsparameter:	R1		Message-ID
;			R3		Anzahl Bytes des Datenobjektes
;			R4/R5		Zeiger auf Datensegment
;Ausgangsparameter:	R1		bleibt unverändert
;			R3		bleibt unverändert
;			R4/R5		Zeiger auf Datensegment
;			LIN_TX_POS
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
BEFORE_WRITE:
	LDAA	R1			;
	CMPA	#02h			;wenn Message-ID = 0x02,
	BNE	BEFORE_WRITE1		;dann
	LDX	R4			;
	LDAA    0,X			;
	STAA	ANTENNA_POS		;  Antennen-Position merken
	LBRA	BEFORE_WRITE9		;
					;
BEFORE_WRITE1:
	CMPA	#21h			;sonst wenn Message-ID = 0x21,
	BNE	BEFORE_WRITE2		;dann
	LDX	R4			;
	LDAA	3,X			;
	CMPA	#43h			;  Kommando: Trigger einschalten
	LBNE	BEFORE_WRITE9		;
	LDAA	0,X			;
	CMPA	1,X			;
	LBNE	BEFORE_WRITE9		;
					;
	STAA	LIN_TX_POS		;  Triggerantennen-Position merken
					;
	LDAA	R1			;  Register retten
	PSHA				;
	LDD	R2			;
	PSHD				;
	LDD	R4			;
	PSHD				;
					;
	BRSET	E_CAN_MASK,_DIAGNOSIS,BEFORE_WRITE11
	BRA	BEFORE_WRITE12		;wenn E_CAN_MASK,_DIAGNOSIS,
					;dann
BEFORE_WRITE11:
	MOVB	#0,R0			;
	MOVB	#6,R1			;  Message 6 : default = 0x721
	MOVB	#0,R2			;
	MOVW	#DIAG_BUF,R4		;
	JSR	CAN_WRITE		;  an CAN0 ausgeben
BEFORE_WRITE12:
	LDY	#DIAG_BUF		;
	MOVB	#4,R3			;
	LDD	#0			;
	JSR	CLEAR_BUFFER16		;  DIAG-Buffer fegen
	MOVB	LIN_TX_POS,DIAG_BUF+0	;  neue Triggersenderposition in DIAG-Buffer eintragen
					;
	PULD				;  Register restaurieren
	STD	R4			;
	PULD				;
	STD	R2			;
	PULA				;
	STAA	R1			;
					;
	BRA	BEFORE_WRITE9		;
					;
BEFORE_WRITE2:
	CMPA	#3Ah			;sonst wenn Message-ID = 0x3A,
	BNE	BEFORE_WRITE9		;dann
	LDX	R4			;
	LDY	#TX_DATA0		;
	LDAB	#8			;  8 Bytes Datenfeld
BEFORE_WRITE21:
	MOVB	1,X+,1,Y+		;  umspeichern
	DBNE	B,BEFORE_WRITE21	;

	LDX	#LIN_IDENTIFIER_TBL	;
	LDAB	ANTENNA_POS		;
	DECB				;  Position decrementieren und mal 2
	LSLB				;  liefert in B Zeiger in Identifierbuffer erster Stufe
	LEAX	B,X			;
	LDX	0,X			;
	LDY	#TX_DATA0		;
	MOVW	0,X,1,Y			;  Radelektronik-Identifier in Datenfeld einfügen
	MOVW	2,X,3,Y			;
	STY	R4			;  Zeiger auf zu sendende Daten
					;
BEFORE_WRITE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;AFTER_READ wird unmittelbar nach dem Unterprogramm LIN_READ ausgeführt.
;
;Eingangsparameter:	R1		Message-ID
;			R3		Anzahl Datenbytes
;Ausgangsparameter:     LIN_RX_BUF
;			LIN_RX_POS
;			LIN_TX_POS
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
AFTER_READ:
	LDX	#ANTENNA_TBL		;
	LDAA	ANTENNA_POS		;letzte Antennen-Position
	DECA				;decrementieren
	LDAA	A,X			;liefert Zeiger in Positionsmaskentabelle
	ORAA	ANTENNA_FLAGS		;zuletzt angesprochene Antenne aktivieren
	STAA	ANTENNA_FLAGS		;
					;
	LDAA	R1			;
	CMPA	#37h			;wenn Message-ID = 0x37: erster Teil des Funktelegrammes
	BNE	AFTER_READ1		;dann
	LDX	RESPONSE_PTR		;  wenn der Ringpuffer leer ist,
	LDAA	0,X			;  [RESPONSE_PTR+0] = 0
	BNE	AFTER_READ01		;  dann
					;
	LDX	SCHEDULE_PTR		;    die Anforderung der beiden folgenden Teile
	LEAX	2*CMD_SIZE,X		;    des Funktelegrammes überspringen
	STX	SCHEDULE_PTR		;
AFTER_READ01:
	BRA	AFTER_READ9		;  Fehlerflags nicht rücksetzen!
					;
AFTER_READ1:
	CMPA	#38h			;sonst wenn Message-ID = 0x38: zweiter Teil des Funktelegrammes
	BNE	AFTER_READ2		;dann
	BRA	AFTER_READ9		;  Fehlerflags nicht rücksetzen!
					;
AFTER_READ2:
	CMPA	#39h			;sonst wenn Message-ID = 0x39: letzter Teil des Funktelegrammes
	BNE	AFTER_READ3		;dann
	JSR	LIN_STATUS		;  Status abfragen und Fehlerflags rücksetzen
	ANDA	#00001111b		;  _E_BREAK ignorieren
					;
 ifne fDebug
	STAA    TEST_VAL
	INC	TEST_CTR
	MOVB	ANTENNA_POS,TEST_BUF+0
	MOVB	LIN_TX_POS,TEST_BUF+1
	MOVB	R1,TEST_CHECKSUM
	CMPA	#0
	BEQ	AFTER_READ20

	BRA	AFTER_READ9

AFTER_READ20:
 else
	BNE	AFTER_READ9		;  wenn keine Fehler ( bis auf _E_BREAK ) passiert,
 endif
					;
	LDX	#RX_DATA0		;  dann
	LDAA	0,X			;
	CMPA	#1			;    wenn mehr als 1 Telegramm im Ringbuffer waren
	BEQ	AFTER_READ21		;    dann
					;
	PSHX				;      Register retten
	LDX	SCHEDULE_PTR		;      zunächst gesamten Ringbuffer auslesen
	LEAX	-READ_CMD_SIZE,X	;      dazu Zeiger in Scheduletabelle entsprechend versetzen
	STX	SCHEDULE_PTR		;
	PULX				;      Register restaurieren
					;
AFTER_READ21:
	LDY	#LIN_RX_BUF		;
	LDAB	#24			;
AFTER_READ22:
	MOVB	1,X+,1,Y+		;    Daten umspeichern
	DBNE	B,AFTER_READ22		;
	LDAA	LIN_TX_POS		;
	STAA	LIN_RX_POS		;    aktuelle Triggerantennen-Position speichern
					;
	JSR	STO_RX_STATUS		;    Empfangsstatus speichern
	BRA	AFTER_READ9		;
					;
AFTER_READ3:
	JSR	LIN_STATUS		;sonst Fehlerflags rücksetzen
					;
AFTER_READ9:
	MOVB	#0,DELAY_CTR		;
	RTS				;
					;
;------------------------------------------------------------------------------
;NEXT_FRAME wertet einen Eintrag der aktuellen Scheduletabelle aus und
;startet die geforderte Aktion.
;
;Eingangsparameter:	SCHEDULE_PTR
;Ausgangsparameter:	DELAY_CTR
;			RESPONSE_PTR
;			SCHEDULE_PTR
;			SCHEDULE_FLAGS._INTERN
;			SCHEDULE_FLAGS._RESPONSE
;			SCHEDULE_FLAGS._BUSY
;veränderte Register:	CCR, A, X, Y, R[1,3..5]
;------------------------------------------------------------------------------
					;
NEXT_FRAME:
	BRCLR	SCHEDULE_FLAGS,_RESPONSE,NEXT_FRAME0
					;wenn angeforderte Anwort ausgeblieben ist,
	LDX	#ANTENNA_TBL		;dann
	LDAA	ANTENNA_POS		;  letzte Antennen-Position
	DECA				;  decrementieren
	LDAA	A,X			;  liefert Zeiger in Positionsmaskentabelle
	COMA				;
	ANDA	ANTENNA_FLAGS		;  zuletzt angesprochene Antenne deaktivieren
	STAA	ANTENNA_FLAGS		;
					;
NEXT_FRAME0:
	LDX	SCHEDULE_PTR		;Schedule-Zeiger lesen
	CPX	SCHEDULE_END		;Zeiger auf Ende der Scheduletabelle
	BLO	NEXT_FRAME1		;
	MOVB	#0,SCHEDULE_FLAGS	;
	LBRA	NEXT_FRAME9		;
					;
NEXT_FRAME1:
	BCLR	SCHEDULE_FLAGS,_RESPONSE;
	BCLR	SCHEDULE_FLAGS,_INTERN	;_INTERN-Flag rücksetzen
					;
	LDAA	0,X			;Message-ID
	CMPA	#80h			;
	BLO	NEXT_FRAME3		;wenn internes Kommando,
	LDAA	1,X			;dann
	ANDA	#11110000b		;
					;
	CMPA	#40h			;  wenn Power-On,
	BNE	NEXT_FRAME1a		;  dann
	BSET	SCHEDULE_FLAGS,_INTERN	;    _INTERN-Flag setzen
					;
	LDY	3,X			;    Portadresse laden
	LDAB	0,Y			;    Portwert lesen
	ORAB	5,X			;    bit mittels bit-Maske setzen
	STAB	0,Y			;    geänderten Portwert schreiben
	LDAA	#0AAh			;
	STD	R0			;
	JSR	PWS_UPDATE		;
					;
	LDY	#ANTENNA_TBL		;
	LDAA	oINIT_ON_ID,X		;    Antennen-Position

	DECA				;    decrementieren
	LDAA	A,Y			;    liefert Zeiger in Positionsmaskentabelle
	ORAA	ANTENNA_FLAGS		;    Antennen-Positionsflag setzen
	STAA	ANTENNA_FLAGS		;
	BRA	NEXT_FRAME2		;
					;
NEXT_FRAME1a:
	CMPA	#10h			;  sonst wenn Power-Off,
	BNE	NEXT_FRAME2		;  dann
	BSET	SCHEDULE_FLAGS,_INTERN	;    _INTERN-Flag setzen
					;
	LDY	#ANTENNA_TBL		;
	LDAA	oINIT_OFF_ID,X		;    Antennenposition

	DECA				;    decrementieren
	LDAA	A,Y			;    liefert Zeiger in Positionsmaskentabelle
	ANDA	ANTENNA_FLAGS		;    wenn Antenne bereits in Funktion,
	BEQ	NEXT_FRAME1b		;    dann
	MOVB	#0,DELAY_CTR		;      Einschaltprozedur für diese Antenne
	LDAA	#INIT_ENTRY_SIZE	;      überspringen
	BRA	NEXT_FRAME6		;
					;
NEXT_FRAME1b:
	LDY	3,X			;    Portadresse laden
	LDAB	0,Y			;    Portwert lesen
	ANDB	5,X			;    bit mittels bit-Maske rücksetzen
	STAB	0,Y			;    geänderten Portwert schreiben
	LDAA	#0AAh			;
	STD	R0			;
	JSR	PWS_UPDATE		;
					;
NEXT_FRAME2:
	LDAA	1,X			;  R/W-Flag und Anzahl Bytes
	BRA	NEXT_FRAME5		;
					;
NEXT_FRAME3:
	STAA	R1			;sonst
	LDAA	1,X			;
	ANDA	#00110000b		;  Empfangs-Multiplexer
	LSRA				;
	LSRA				;
	LSRA				;
	LSRA				;  neue Position in A
	JSR	MUX_UPDATE		;  einstellen
	LDAA	1,X			;  R/W-Flag und Anzahl Bytes
	BITA	#10000000b		;
	BNE	NEXT_FRAME4		;  wenn R/W-Flag rückgesetzt,
	BSET	SCHEDULE_FLAGS,_RESPONSE;  dann
	MOVW	3,X,RESPONSE_PTR	;    Zeiger auf Anwortbuffer
	BRA	NEXT_FRAME5		;  sonst
NEXT_FRAME4:
	MOVW	3,X,R4			;    Zeiger auf zu sendende Daten
					;
NEXT_FRAME5:
	ANDA	#00001111b		;Anzahl Datenbytes
	STAA	R3			;
	MOVB	2,X,DELAY_CTR		;Delay auf Startwert
	LDAA	#CMD_SIZE		;
	BRSET	SCHEDULE_FLAGS,_RESPONSE,NEXT_FRAME6
	ADDA	R3			;
NEXT_FRAME6:
	LEAX	A,X			;Schedule-Zeiger auf nächsten Frame-Eintrag setzen
	STX	SCHEDULE_PTR		;Schedule-Zeiger retten
					;
	BRSET	SCHEDULE_FLAGS,_INTERN,NEXT_FRAME9
	BRSET	SCHEDULE_FLAGS,_RESPONSE,NEXT_FRAME8
	JSR	BEFORE_WRITE		;
	JSR	LIN_WRITE		;Daten senden
	BRA	NEXT_FRAME9		;
NEXT_FRAME8:
	JSR	LIN_REQUEST		;Daten anfordern
					;
NEXT_FRAME9:
	RTS				;
					;
;==============================================================================
;LIN Modul-Einsprung
;==============================================================================
					;
;------------------------------------------------------------------------------
;Public: LIN_RUN arbeitet LIN-Scheduletabellen ab.
;
;Eingangsparameter:	CLOCK_CTR
;			SCHEDULE_FLAGS
;			SCHEDULE_PTR
;			SCHEDULE_END
;			DELAY_CTR
;Ausgangsparameter:	CLOCK_CTR
;			SCHEDULE_FLAGS
;			SCHEDULE_PTR
;			SCHEDULE_END
;			DELAY_CTR
;veränderte Register:	CCR, A, B, X. Y, R[1,3..5]
;------------------------------------------------------------------------------
					;
LIN_RUN:
	LDX	TIME_CTR		;Bearbeitungszeit incrementieren
	INX				;
	STX	TIME_CTR		;
					;
	LDX	ANTENNA_CTR		;Antennenprüftakt
	BEQ	LIN_RUN0		;
	DEX				;
	BEQ	LIN_RUN0		;
	STX	ANTENNA_CTR		;
	BRA	LIN_RUN0a		;
					;
LIN_RUN0:
	MOVW	#ANTENNA_CT,ANTENNA_CTR	;
	BCLR	LIN_FLAGS,_ACTIVATED	;
LIN_RUN0a:
	LDAA	CLOCK_CTR		;LIN-Takt
	BEQ	LIN_RUN0b		;
	DECA				;
	BEQ	LIN_RUN0b		;
	STAA	CLOCK_CTR		;
	JMP	LIN_RUN9		;
					;
LIN_RUN0b:
	MOVB	#CLOCK_CT,CLOCK_CTR	;
	BRSET	SCHEDULE_FLAGS,_RESPONSE,LIN_RUN0c
	BRSET	SCHEDULE_FLAGS,_BUSY,LIN_RUN0c
	BRA	LIN_RUN1		;
					;
LIN_RUN0c:
	LBRA	LIN_RUN2		;
					;
;------------------------------------------------------------------------------
;Schedule-Table starten
					;
LIN_RUN1:
	BRSET	LIN_FLAGS,_ACTIVATED,LIN_RUN1a
					;
	MOVW	#INITIALIZATION_TBL,SCHEDULE_PTR
	MOVW	#INITIALIZATION_END,SCHEDULE_END
	BSET	LIN_FLAGS,_ACTIVATED	;
	LBRA	LIN_RUN1z		;
					;
LIN_RUN1a:
	MOVW	TIME_CTR,LIN_TIME_CTR	;Bearbeitungszeit auf 0
	MOVW	#0,TIME_CTR		;
					;
	MOVW	#REQUEST_DATA_TBL,SCHEDULE_PTR
	MOVW	#REQUEST_DATA_END,SCHEDULE_END
	BSET	LIN_FLAGS,_RUNNING	;
	LBRA	LIN_RUN1z		;
					;
LIN_RUN1z:
	MOVB	#0,DELAY_CTR		;
					;
	BCLR	SCHEDULE_FLAGS,_RESPONSE;
	BSET	SCHEDULE_FLAGS,_BUSY	;
					;
;------------------------------------------------------------------------------
;ggf. Slave-Task ausführen
					;
LIN_RUN2:
	BRCLR	SCHEDULE_FLAGS,_RESPONSE,LIN_RUN3
					;
	MOVW    RESPONSE_PTR,R4		;
	JSR	LIN_READ		;empfangene Daten lesen
	BNE	LIN_RUN3		;
	BCLR	SCHEDULE_FLAGS,_RESPONSE;
	JSR	AFTER_READ		;
					;
;------------------------------------------------------------------------------
;Schedule-Table fortsetzen
					;
LIN_RUN3:
	LDAA	DELAY_CTR		;Pausenzeit zwischen zwei Frames
	BEQ	LIN_RUN4		;
	DECA				;
	STAA	DELAY_CTR		;
	BRA	LIN_RUN9		;
					;
LIN_RUN4:
	JSR	NEXT_FRAME		;
					;
LIN_RUN9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
