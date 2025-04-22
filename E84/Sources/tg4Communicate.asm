	include	"s12ga_240.sfr"
	include	"s12ga_Switches.sfr"
	title	"tg4Communicate  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg4Communicate.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	25.02.2015
;
;Description:	CAN-Kommunikation, RS232-Kommunikation und Ende des Programmzyklusses
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;25.02.2015	Version 4.01
;		in CHK_SENSORS nach Ablauf der Zeitgrenze zugehöriges ANTENNA_FLAG rücksetzen
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3Communicate.asm
;
;15.10.2013	Version 3.01	
;		Korrektur in CHK_ALARM : Umgebungsluftdruck subtrahieren
;18.09.2013	Version 3.0
;
;02.07.2013	Version 2.60
;02.07.2013	aktuell zugeordnete Identifier im Sekundentakt an CAN ausgeben
;20.01.2011	Version 2.50
;20.01.2011	RS232-Timeout-Funktion aufrufen
;05.07.2008	Version 2.10
;27.11.2007	Version 2.00
;27.11.2007	in CHK_IDENTIFIER wird Fixieren desselben Identifiers für mehrere
;		Räder nun unterbunden
;		in CHK_IDENTIFIER den Identifiervergleich in neue Funktion
;		COMPARE_IDENTIFIER ausgelagert
;		in PUT_DATA Rohdatenwerte nach Abzug des Offsets nach unten begrenzt
;		Ergänzungen für LIN-Empfangsmultiplexer
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;
;29.03.2006	Erweiterung in CHK_IDENTIFIER
;21.02.2006	Korrektur in CHECK_SPEED
;08.02.2006
;11.12.2005
;------------------------------------------------------------------------------
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
	xref	CLEAR_BUFFER8		;Code

	xref	CAN_READ		;Code
	xref	CAN_RESET		;Code
	xref	CAN_WRITE		;Code
	xref	COMLINE_INPUT		;Code
	xref	COMLINE_REACTION	;Code
	xref	COMLINE_TIMEOUTS	;Code
;
;begin 25.02.2015
	xref	LIN_DEACTIVATE_ANTENNA	;Code
;end
;
					;
	xref	LIN_IDENTIFIER_TBL	;roData
	xref	MSG_IDENTIFIER_TBL	;roData
	xref	MSG_CTR_TBL		;roData
	xref	MSG_RX_TBL		;roData
					;
	xref	E_CAN0_CONFIG_TBL
	xref	E_CAN_MASK		;bssData
	xref.b	_IDENTIFIERS		;bitMask
	xref.b	_VALUES			;bitMask
	xref.b	_STATUS			;bitMask
	xref	E_DROP_PRESSURE		;bssData
	xref	E_DROP_REF		;bssData
	xref	E_FUN_MODE		;bssData
	xref.b	_USE_NOVALUE		;bitMask
	xref	E_TIRE_PRESSURE		;bssData
	xref	E_TIRE_TEMPERATURE	;bssData
	xref	E_TIRE_XP_REF		;bssData
					;
	xref	ALARM			;Data
	xref	BATTERY_VOLTAGE		;Data
	xref	CAN0_MSG0_BUF		;Data
	xref	CAN0_MSG1_BUF		;Data
	xref	CAN0_MSG2_BUF		;Data
	xref	CAN0_MSG3_BUF		;Data
	xref	CAN0_RX_CTR		;Data
	xref	CHECK_WAIT_CTR		;Data
	xref	COMMUNICATE_FLAGS	;Data
	xref.b	_LOW_XP_TRIG		;bitMask
	xref.b	_LOW_XP_FLAG		;bitMask
	xref.b	_CAN_RFSH_TRIG		;bitMask
					;
	xref	DROP_ALARM		;Data
	xref	LAST_RX_POS		;Data
	xref	LIN_ANT_ADC		;Data
	xref	LIN_ANT_FLAGS		;Data
	xref	LIN_ADC_BUF		;Data
	xref	LIN_RX_BUF		;Data
	xref	LIN_RX_POS		;Data
	xref	LIN_RX_CTR		;Data
	xref	LIN_TIME_CTR		;Data
	xref	LOOP_FLAGS		;Data
	xref.b	_LOOP_TIMEOUT		;bitMask
					;
	xref	MSG_RX_REC		;Data
	xref	MSG_S1_REC		;Data
	xref	OUTPUT_FLAGS2		;Data
	xref	P_AMBIENT		;Data
	xref	P_TPMS			;Data
	xref	TIRE_DAT_RFSH_CTR	;Data
	xref	TIRE_ID_RFSH_CTR	;Data
	xref	TIRE_SENSOR_CTR_REC	;Data
	xref	T_UNIT			;Data
	xref	XP			;Data
					;
	xref	CAN0_RX_CT		;Number
	xref	CHECK_WAIT_CT		;Number
	xref	DEF_NOVALUE		;Number
	xref	LIN_RX_CT		;Number
					;
	xref.b	oIDENTIFIER		;Number
	xref.b	oTEMPERATURE		;Number
	xref.b	oPRESSURE		;Number
	xref.b	oSTATUS			;Number
					;
	xref.b	TIRE_DAT_RFSH_CT	;Number
	xref.b	TIRE_ID_RFSH_CT		;Number
	xref	TIRE_SENSOR_CT		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	COMLINE_EXECUTE		;Callback-Code
					;
	xdef	COMMUNICATE		;Code
					;
.text:		section
					;
;==============================================================================
;COMMUNICATE Modul-Einsprung
;==============================================================================
					;
COMMUNICATE:
	JSR	CAN_IO			;
	JSR	COMLINE_TIMEOUTS	;
					;
	BSET	PTT,bit5		;Ende der aktiven Zyklusphase
					;
COMMUNICATE1:
	JSR	COMLINE_INPUT		;ankommende Zeichen lesen
	JSR	COMLINE_REACTION	;Kommandos auswerten und ausführen
 	BRCLR	LOOP_FLAGS,_LOOP_TIMEOUT,COMMUNICATE1
	RTS				;bis zum Ende der Zykluszeit
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
;GET_MCU_DATA empfängt die Fahrgeschwindigkeit und Analogwerte vom Motorsteuergerät.
;
;Eingangsparameter:	CAN0_RX_CTR
;Ausgangsparameter:	CAN0_RX_CTR
;			XP
;veränderte Register:	CCR, A, B, X, Y, R[0..5]
;------------------------------------------------------------------------------
					;
GET_MCU_DATA:
	MOVB	#0,R0			;
	MOVB	#0,R1			;Descriptor 0 : default 0x6D9
	MOVW	#CAN0_MSG2_BUF,R4	;
	JSR	CAN_READ		;von CAN0 lesen
	BEQ	GET_MCU_DATA2		;wenn keine neuen Daten da,
					;
	LDX	CAN0_RX_CTR		;dann
	BEQ	GET_MCU_DATA1		;  wenn CAN0_RX_CTR <> 0,
	DEX				;  dann
	STX	CAN0_RX_CTR		;    CAN0_RX_CTR decrementieren
	BNE	GET_MCU_DATA9		;
					;
GET_MCU_DATA1:
	LDY	#CAN0_MSG2_BUF		;  wenn CAN0_RX_CTR = 0,
	CLRA				;  dann
	MOVB	#8,R3			;
	JSR	CLEAR_BUFFER8		;    Empfangsbuffer fegen
					;
GET_MCU_DATA2:
					;Byte 1:  Blockzähler
	LDAB	CAN0_MSG2_BUF+1		;Byte 2:  XP Low Byte
	LDAA	CAN0_MSG2_BUF+2		;Byte 3:  XP High Byte
	STD	XP			;Byte 4:  stets = 0
					;Byte 5:  stets = 0
					;Byte 6:  Blockdatenbyte 1 Low Byte
					;Byte 7:  Blockdatenbyte 2 High Byte
					;Byte 8:  - nicht vorhanden -
					;
	MOVW	#CAN0_RX_CT,CAN0_RX_CTR	;Empfangszeitgrenze auf Startwert
					;
GET_MCU_DATA9:
	RTS				;
					;
;==============================================================================
;Reifenüberwachung
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Trustlevel Settings
					;
RELEASE_LEVEL:	equ	1		;
LOCKING_LEVEL:	equ	3		;
MAXIMAL_LEVEL:	equ	16		;
					;
;------------------------------------------------------------------------------
;CHK_SPEED prüft, ob die Fahrgeschwindigkeit kleiner als die Ausblend-
;geschwindigkeit ist. Abhängig davon wird das LOW_XP_FLAG gesetzt oder
;rückgesetzt.
;
;Eingangsparameter:	XP
;			COMMUNICATE_FLAGS._LOW_XP_FLAG
;			E_TIRE_XP_REF
;Ausgangsparameter:	COMMUNICATE_FLAGS._LOW_XP_TRIG
;			COMMUNICATE_FLAGS._LOW_XP_FLAG
;veränderte Register:	CCR, A, B
;------------------------------------------------------------------------------
					;
CHK_SPEED:
	BCLR	COMMUNICATE_FLAGS,_LOW_XP_TRIG
	LDD	E_TIRE_XP_REF		;wenn Geschwindigkeitsgrenze <> 0
	BEQ	CHK_SPEED2		;und Geschwindigkeit < Grenzgeschwindigkeit,
	CPD	XP			;dann
	BLS	CHK_SPEED2		;  wenn _LOW_XP_FLAG rückgesetzt,
	BRSET	COMMUNICATE_FLAGS,_LOW_XP_FLAG,CHK_SPEED1
					;  dann
	BSET	COMMUNICATE_FLAGS,_LOW_XP_TRIG
					;    _LOW_XP_TRIG setzen
CHK_SPEED1:
	BSET	COMMUNICATE_FLAGS,_LOW_XP_FLAG
	BRA	CHK_SPEED3		;  _LOW_XP_FLAG setzen
					;sonst
CHK_SPEED2:
	BCLR	COMMUNICATE_FLAGS,_LOW_XP_FLAG
					;  _LOW_XP_FLAG rücksetzen
CHK_SPEED3:
	RTS				;
					;
;------------------------------------------------------------------------------
;CHK_SENSORS setzt nach Ablauf der durch TIRE_SENSOR_CT festgelegten Zeit die
;jeweiligen Temperatur- und Druckwerte auf Null.
;
;Eingangsparameter:	TIRE_SENSOR_CTR_REC
;Ausgangsparameter:
;			COMMUNICATE_FLAGS._CAN_RFSH_TRIG
;			TIRE_SENSOR_CTR_REC
;			MSG_RX_REC
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
CHK_SENSORS:
	BCLR	COMMUNICATE_FLAGS,_CAN_RFSH_TRIG
	LDY	#MSG_RX_REC		;
	LDX	#TIRE_SENSOR_CTR_REC	;
	MOVB	#4,R3			;vier Radsender
CHK_SENSORS1:
	LDD	0,X			;wenn Zähler <> 0,
	BEQ	CHK_SENSORS2		;dann
	ADDD	#-1			;  Zähler decrementieren
	STD	0,X			;  wenn Zähler danach = 0,
	BNE	CHK_SENSORS3		;  dann
	BSET	COMMUNICATE_FLAGS,_CAN_RFSH_TRIG
					;    _CAN_RFSH_TRIG setzen
CHK_SENSORS2:
;
;begin 25.02.2015
	LDAA	#4			;
	SUBA	R3			;
	JSR	LIN_DEACTIVATE_ANTENNA	;
;end
;
	MOVB	#0,oPRESSURE,Y		;sonst
	MOVB	#0,oTEMPERATURE,Y	;  Druck- und Temperaturwert auf Null setzen
					;
CHK_SENSORS3:
	LEAY	24,Y			;nächsten Radsender prüfen
	LEAX	2,X			;
	DEC	R3			;
	BNE	CHK_SENSORS1		;
	RTS				;
					;
;------------------------------------------------------------------------------
;COMPARE_IDENTIFIER vergleicht zwei Identifier.
;
;Eingangsparameter:	Y		Zeiger auf gespeicherten Identifier
;			R[4..7]		neuer Identifier
;Ausgangsparameter:	Y		bleibt unverändert!
;			R[4..7]		bleibt unverändert!
;			A		0	= Identifier sind gleich
;					0FFh	= Identifier sind verschieden
;veränderte Register:	CCR, A
;------------------------------------------------------------------------------
					;
COMPARE_IDENTIFIER:
	LDAA	0,Y			;
	CMPA	R4			;
	BNE	COMPARE_IDENTIFIER8	;gespeicherten mit neuem Identifier
	LDAA	1,Y			;
	CMPA	R5			;vergleichen
	BNE	COMPARE_IDENTIFIER8	;
	LDAA	2,Y			;
	CMPA	R6			;
	BNE	COMPARE_IDENTIFIER8	;
	LDAA	3,Y			;
	CMPA	R7			;
	BNE	COMPARE_IDENTIFIER8	;wenn beide Identifier gleich,
	CLRA				;dann mit A = 0 zurück
	BRA	COMPARE_IDENTIFIER9	;
					;
COMPARE_IDENTIFIER8:
	LDAA	#0FFh			;sonst mit A = 0FFh zurück
					;
COMPARE_IDENTIFIER9:
	RTS				;
					;
;------------------------------------------------------------------------------
;CONFIRM_POSITION ermittelt bei Telegrammen, die selbsttätig von einer Radelektronik
;gesendet wurden, die Radposition, weil die in LIN_RX_POS übergebene Position
;nur zufällig zutreffen kann.

;Eingangsparameter:	LIN_RX_BUF
;			LIN_IDENTIFIER_REC
;Ausgangsparameter:	LIN_RX_POS
;veränderte Register:	CCR, A, B, X, Y, R[2..7]
;------------------------------------------------------------------------------
					;
CONFIRM_POSITION:
	LDX	#LIN_RX_BUF		;
	LDAA	oSTATUS,X		;wenn TriggeredEventSource bit rückgesetzt,
	ANDA	#01000000b		;
	BNE	CONFIRM_POSITION9	;dann
					;
	MOVB	#0,LIN_RX_POS		;zunächst Telegramm verwerfen
					;
	LDD	oIDENTIFIER,X		;
	STD	R4			;neuen Identifier nach R[4..7] laden
	LDD	oIDENTIFIER+2,X		;
	STD	R6			;
	LDAB	#0			;Zeiger in Tabelle der gespeicherten Identifier
	MOVB	#0,R2			;Positionswert
	MOVB	#4,R3			;maximal vier Räder
CONFIRM_POSITION1:
	LDY	#LIN_IDENTIFIER_TBL	;Zeiger auf gespeicherte Identifier
	LEAY	B,Y			;
	LDY	0,Y			;
	JSR	COMPARE_IDENTIFIER	;wenn neuer = gespeichertem Identifier
	BEQ	CONFIRM_POSITION8	;
	INCB				;
	INCB				;
	INC	R2			;
	DEC	R3			;
	BNE	CONFIRM_POSITION1	;
	BRA	CONFIRM_POSITION9	;dann
CONFIRM_POSITION8:
	MOVB	R2,LIN_RX_POS		;  diese Position übernehmen
					;
CONFIRM_POSITION9:
	RTS				;
					;
;------------------------------------------------------------------------------
;ANALYSE_IDENTIFIER untersucht den gespeicherten Identifier einer Radposition
;
;Eingangsparameter:	B
;			R[4..7]		neuer Identifier
;Ausgangsparameter:	B		bleibt unverändert!
;			R[4..7]		bleibt unverändert!
;			A		0	= ok
;					0FFh	= Identifier darf nicht übernommen werden
;veränderte Register:	CCR, X, Y
;------------------------------------------------------------------------------
					;
ANALYSE_IDENTIFIER:
	LDY	#LIN_IDENTIFIER_TBL	;Zeiger auf gespeicherte Identifier
	LEAY	B,Y			;
	LDY	0,Y			;
	JSR	COMPARE_IDENTIFIER	;wenn neuer = gespeichertem Identifier
	BNE	ANALYSE_IDENTIFIER8	;
	LDX	#MSG_CTR_TBL		;
	LEAX	B,X			;
	LDX	0,X			;
	LDAA	0,X			;und Telegramm-Zählerstand
	CMPA	#RELEASE_LEVEL		;des gespeicherten Identifiers >= RELEASE_LEVEL,
	BLO	ANALYSE_IDENTIFIER8	;dann
	LDAA	#0FFh			;  darf neuer Identifier nicht übernommen werden
	BRA	ANALYSE_IDENTIFIER9	;
					;
ANALYSE_IDENTIFIER8:
	CLRA				;sonst ok, mit A = 0 zurück
					;
ANALYSE_IDENTIFIER9:
	RTS				;
					;
;------------------------------------------------------------------------------
;VALIDATE_IDENTIFIER prüft, ob der neue Identifier als aktueller Identifier
;übernommen werden darf.
;
;Eingangsparameter:	R[4..7]		neuer Identifier
;Ausgangsparameter:	R[4..7]		bleibt unverändert!
;			A		0	= ok
;					0FFh	= Identifier darf nicht übernommen werden
;veränderte Register:	CCR, R3
;------------------------------------------------------------------------------
					;
VALIDATE_IDENTIFIER:
	PSHB				;Register retten
	PSHX				;
	PSHY				;
					;
	LDAB	#0			;
	MOVB	#4,R3			;vier Radpositionen untersuchen
VALIDATE_IDENTIFIER1:
	JSR	ANALYSE_IDENTIFIER	;
	BNE	VALIDATE_IDENTIFIER9	;
	INCB				;
	INCB				;
	DEC	R3			;
	BNE	VALIDATE_IDENTIFIER1	;
	CLRA				;
					;
VALIDATE_IDENTIFIER9:
	PULY				;Register restaurieren
	PULX				;
	PULB				;
	RTS				;
					;
;------------------------------------------------------------------------------
;CHK_IDENTIFIER ermittelt die Radpositionen und entscheidet, ob ein empfangenes
;Radsensor-Telegramm verwendet werden darf.
;
;Eingangsparameter:	B		Positionszeiger
;Ausgangsparameter:	B		bleibt unverändert !
;			A		0	= Telegramm auswerten
;					<> 0	= Telegramm ignorieren
;veränderte Register:	CCR, X, Y, R[3..7]
;------------------------------------------------------------------------------
					;
CHK_IDENTIFIER:
	LDY	#LIN_IDENTIFIER_TBL	;
	LEAY	B,Y			;
	LDY	0,Y			;Zeiger auf gespeicherten Identifier
					;
	LDX	#LIN_RX_BUF		;
	LEAX	oIDENTIFIER,X		;
	MOVW	0,X,R4			;neuen Identifier nach R[4..7] laden
	MOVW	2,X,R6			;
					;
	LDX	#MSG_CTR_TBL		;
	LEAX	B,X			;
	LDX	0,X			;Zeiger auf Telegrammzähler
					;
	LDAA	0,X			;wenn Zähler = 0
	BNE	CHK_IDENTIFIER1		;
	JSR	VALIDATE_IDENTIFIER	;und nichts gegen den neuen Identifier spricht,
	BNE	CHK_IDENTIFIER1		;dann
	MOVW	R4,0,Y			;  neuen Identifier übernehmen
	MOVW	R6,2,Y			;
	BRA	CHK_IDENTIFIER2		;
					;
CHK_IDENTIFIER1:
	JSR	COMPARE_IDENTIFIER	;gespeicherten mit neuem Identifier vergleichen
	BNE	CHK_IDENTIFIER3		;wenn beide Identifier gleich,
					;
CHK_IDENTIFIER2:
	LDAA	0,X			;dann
	CMPA	#MAXIMAL_LEVEL		;  wenn Zähler < MAXIMAL_LEVEL,
	BHS	CHK_IDENTIFIER4		;  dann
	INCA				;    Zähler incrementieren
	STAA	0,X			;
	CMPA	#LOCKING_LEVEL		;    wenn Zähler = LOCKING_LEVEL,
	BNE	CHK_IDENTIFIER4		;    dann
	LDY	#MSG_IDENTIFIER_TBL	;
	LEAY	B,Y			;
	LDY	0,Y			;      Zeiger auf fixierten Identifier
	MOVW	R4,0,Y			;      neuen Identifier fixieren
	MOVW	R6,2,Y			;
	BRA	CHK_IDENTIFIER4		;
					;
CHK_IDENTIFIER3:
	LDAA	0,X			;sonst
	BEQ	CHK_IDENTIFIER4		;  wenn Zähler > 0,
	DECA				;  dann
	STAA	0,X			;    Zähler decrementieren
					;
CHK_IDENTIFIER4:
	LDY	#MSG_IDENTIFIER_TBL	;
	LEAY	B,Y			;
	LDY	0,Y			;Zeiger auf fixierten Identifier
					;
	JSR	COMPARE_IDENTIFIER	;fixierten mit neuem Identifier vergleichen
	BNE	CHK_IDENTIFIER8		;
	CLRA				;wenn fixierter <> neuem Identifier,
	BRA	CHK_IDENTIFIER9		;dann
					;
CHK_IDENTIFIER8:
	LDAA	#0FFh			;  neues Telegramm ignorieren
					;
CHK_IDENTIFIER9:
	RTS				;
					;
;------------------------------------------------------------------------------
;ADJUST_TEMPERATURE zieht den Temperaturoffset von einem Temperatur_Rohdatenwert ab.
;
;Eingangsparameter:	A		Temperatur-Rohdatenwert
;			B		Unterlauf-Flags
;			R0		Unterlauf-OR-Maske
;			R1		Unterlauf-AND-Maske
;Ausgangsparameter:	A		Temperatur-Messwert
;			B		Unterlauf-Flags
;			R0		bleibt unverändert
;			R1		bleibt unverändert
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
ADJUST_TEMPERATURE:
	BEQ	ADJUST_TEMPERATURE8	;wenn Temperatur-Rohdatenwert <> 0 und <> 0xFF,
	CMPA	#0FFh			;
	BEQ	ADJUST_TEMPERATURE8	;dann
	SUBA	#40			;  den Temperaturoffset von 40°C subtrahieren
	BHI	ADJUST_TEMPERATURE8	;  wenn Ergebnis < 0,
	LDAA	#1			;  dann
	ORAB	R0			;    Wert auf Eins setzen und Unterlaufflag setzen
	BRA	ADJUST_TEMPERATURE9	;
ADJUST_TEMPERATURE8:
	ANDB	R1			;sonst Unterlaufflag rücksetzen
ADJUST_TEMPERATURE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;ADJUST_PRESSURE zieht den gemessenen Umgebungsluftdruckwert von einem Luftdruck-
;Rodatenwert ab.
;
;Eingangsparameter:	A		Druck-Rohdatenwert
;			B		Unterlauf-Flags
;			R0		Unterlauf-OR-Maske
;			R1		Unterlauf-AND-Maske
;Ausgangsparameter:	A		Druck-Messwert
;			B		Unterlauf-Flags
;			R0		bleibt unverändert
;			R1		bleibt unverändert
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
ADJUST_PRESSURE:
	BEQ	ADJUST_PRESSURE8	;wenn Druck-Rohdatenwert <> 0 und <> 0xFF,
	CMPA	#0FFh			;
	BEQ	ADJUST_PRESSURE8	;dann
	SUBA	P_TPMS			;  Umgebungsluftdruck subtrahieren
	BHI	ADJUST_PRESSURE8	;  wenn Ergebnis < 0,
	LDAA	#1			;  dann
	ORAB	R0			;    Wert auf Eins setzen und Unterlaufflag setzen
	BRA	ADJUST_PRESSURE9	;
ADJUST_PRESSURE8:
	ANDB	R1			;sonst Unterlaufflag rücksetzen
ADJUST_PRESSURE9:
	RTS				;
					;
;------------------------------------------------------------------------------
;GET_TIRE_DATA legt empfangene Radsensor-Telegramme im MSG_RX_REC ab.
;
;Eingangsparameter:     LIN_RX_BUF
;Ausgangsparameter:	MSG_RX_REC
;			TIRE_SENSOR_CTR_REC
;veränderte Register:	CCR, A, B, X, Y, R[2..7]
;------------------------------------------------------------------------------
					;
GET_TIRE_DATA:
	JSR	CONFIRM_POSITION	;Verifizierung der Radposition bei selbsttätig
					;von einer Radelektronik gesendeten Telegramm
	LDAB	LIN_RX_POS		;
	BEQ	GET_TIRE_DATA9		;
	CMPB	#4			;wenn Position im Bereich [1..4] liegt,
	BHI	GET_TIRE_DATA9		;dann
	DECB				;  Position decrementieren und mal 2
	LSLB				;  liefert in B Zeiger in Tabelle
					;  mit den MSG_RX_BUF-Basisadressen
GET_TIRE_DATA1:
	JSR	CHK_IDENTIFIER		;  nun entscheiden, ob empfangenes Telegramm
	BEQ	GET_TIRE_DATA2		;  verwendet werden darf
	MOVB	#0,LIN_RX_POS		;
	JMP	GET_TIRE_DATA9		;
					;
GET_TIRE_DATA2:
	LDX	#LIN_RX_BUF		;
	LDY	#MSG_RX_TBL		;
	LEAY	B,Y			;
	LDY	0,Y			;  MSG_RX_BUF-Basisadresse aus Tabelle lesen
	MOVB	#24,R3			;  24 Bytes
GET_TIRE_DATA3:
	MOVB	1,X+,1,Y+		;  Daten ablegen
	DEC	R3			;
	BNE	GET_TIRE_DATA3		;
					;
	LDY	#TIRE_SENSOR_CTR_REC	;
	LEAY	B,Y			;
	MOVW	#TIRE_SENSOR_CT,0,Y	;  Timeout-Zähler auf Startwert
					;
GET_TIRE_DATA9:
	RTS				;
					;
;------------------------------------------------------------------------------
;PUT_TIRE_DATA bereitet den Ausgabebuffer mit den Reifentemperatur- und
;Druckwerten vor.
;
;Eingangsparameter:	MSG_RX_REC
;Ausgangsparameter:	CAN0_MSG0_BUF
;veränderte Register:	CCR, A, B, X, Y, R[0..1,3]
;------------------------------------------------------------------------------
					;
PUT_TIRE_DATA:
	LDAB	OUTPUT_FLAGS2		;
					;
	MOVB	#00000001b,R0		;Unterlauf-Masken auf Startwerte
	MOVB	#11111110b,R1		;
	LDX	#MSG_RX_REC		;
	LEAX	oTEMPERATURE,X		;
	LDY	#CAN0_MSG0_BUF		;
	MOVB	#4,R3			;
PUT_TIRE_DATA1:
	LDAA	0,X			;
	JSR	ADJUST_TEMPERATURE	;
	STAA	1,Y+			;
	LEAX	24,X			;
	LSL	R0			;Maske aktualisieren
	SEC				;
	ROL	R1			;Maske aktualisieren
	DEC	R3			;
	BNE	PUT_TIRE_DATA1		;
					;
	LDX	#MSG_RX_REC		;
	LEAX	oPRESSURE,X		;
	MOVB	#4,R3			;
PUT_TIRE_DATA2:
	LDAA	0,X			;
	JSR	ADJUST_PRESSURE		;
	STAA	1,Y+			;
	LEAX	24,X			;
	LSL	R0			;Maske aktualisieren
	SEC				;
	ROL	R1			;Maske aktualisieren
	DEC	R3			;
	BNE	PUT_TIRE_DATA2		;
					;
	STAB	OUTPUT_FLAGS2		;
	RTS				;
					;
;-----------------------------------------------------------------------------
;CKH_ALARM untersucht die Temperatur- und Druckwerte im Ausgabebuffer auf
;Verletzung der absoluten Grenzwerte.
;
;Eingangsparameter:	CAN0_MSG0_BUF
;Ausgangsparameter:	ALARM
;veränderte Register:	CCR, A, B, X, R[0,2..3]
;-----------------------------------------------------------------------------
					;
CHK_ALARM:
	CLRB				;
	MOVB	#00010001b,R0		;Unterlauf-Prüfmaske
					;
	LDX	#CAN0_MSG0_BUF		;
	MOVB	#4,R3			;
CHK_ALARM1:
	LDAA	1,X+			;
	BEQ	CHK_ALARM11		;
	CMPA	#0FFh			;
	BEQ	CHK_ALARM11		;
	PSHA				;
	LDAA	OUTPUT_FLAGS2		;wenn Druckwert- UND Temperaturwertunterlauf,
	ANDA	R0			;dann
	CMPA	R0			;  keinen Alarm auslösen
	PULA				;
	BEQ	CHK_ALARM11		;
	CMPA	E_TIRE_TEMPERATURE	;
	BLS	CHK_ALARM11		;Temperaturwerte untersuchen
					;
	LDAB	#0FFh			;
					;
CHK_ALARM11:
	LSL	R0			;
	DEC	R3			;
	BNE	CHK_ALARM1		;
					;
	MOVB	#00010001b,R0		;Unterlauf-Prüfmaske
	LDAA	E_TIRE_PRESSURE		;
	STAA	R2			;
	MOVB	#4,R3			;
CHK_ALARM2:
	LDAA	1,X+			;
	BEQ	CHK_ALARM21		;
	CMPA	#0FFh			;
	BEQ	CHK_ALARM21		;
	PSHA				;
	LDAA	OUTPUT_FLAGS2		;wenn Druckwert- UND Temperaturwertunterlauf,
	ANDA	R0			;dann
	CMPA	R0			;  keinen Alarm auslösen
	PULA				;
	BEQ	CHK_ALARM21		;
	CMPA	R2			;Druckwerte untersuchen
	BHS	CHK_ALARM21		;
					;
	LDAB	#0FFh			;
					;
CHK_ALARM21:
	LSL	R0			;
	DEC	R3			;
	BNE	CHK_ALARM2		;
					;
	STAB	ALARM			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;PUT_LOW_XP_DATA setzt die Temperatur- und Druckwerte im Ausgabepuffer auf
;Temperatur- und Druckgrenz- oder Ersatzwerte und nimmt einen evtl. Alarm zurück.
;
;Eingangsparameter:	E_FUN_MODE
;Ausgangsparameter:	CAN0_MSG0_BUF
;			ALARM
;veränderte Register:	CCR, A, Y, R3
;-----------------------------------------------------------------------------
					;
PUT_LOW_XP_DATA:
	LDY	#CAN0_MSG0_BUF		;
	BRSET	E_FUN_MODE,_USE_NOVALUE,PUT_LOW_XP_DATA11
	LDAA	E_TIRE_TEMPERATURE	;Temperatur-Grenzwert
	BRA	PUT_LOW_XP_DATA12	;
PUT_LOW_XP_DATA11:
	LDAA	#LOW(DEF_NOVALUE)	;Ersatzwert
PUT_LOW_XP_DATA12:
	MOVB	#4,R3			;
PUT_LOW_XP_DATA13:
	STAA	1,Y+			;Temperaturwerte auf Grenzwert
	DEC	R3			;
	BNE	PUT_LOW_XP_DATA13	;
					;
	BRSET	E_FUN_MODE,_USE_NOVALUE,PUT_LOW_XP_DATA21
	LDAA	E_TIRE_PRESSURE		;Druck-Grenzwert
	BRA	PUT_LOW_XP_DATA22	;
PUT_LOW_XP_DATA21:
	LDAA	#LOW(DEF_NOVALUE)	;Ersatzwert
PUT_LOW_XP_DATA22:
	MOVB	#4,R3			;
PUT_LOW_XP_DATA23:
	STAA	1,Y+			;Druckwerte auf Grenzwert
	DEC	R3			;
	BNE	PUT_LOW_XP_DATA23	;
					;
	MOVB	#0,ALARM		;Alarm rücksetzen
	RTS				;
					;
;------------------------------------------------------------------------------
;CHK_PRESSURE_DROP prüft die vier Raddruckwerte auf einen unzulässigen
;Druckabfall.
;
;Eingangsparameter:	CHECK_WAIT_CTR
;			MSG_RX_REC
;			MSG_P_REC
;			E_DROP_PRESSURE
;			E_DROP_REF
;Ausgangsparameter:	CHECK_WAIT_CTR
;			MSG_P_REC
;			DROP_ALARM
;veraenderte Register:	CCR, A, B, X, Y, R[3..4]
;------------------------------------------------------------------------------
					;
CHK_PRESSURE_DROP:
	LDD	CHECK_WAIT_CTR		;wenn CHECK_WAIT_CTR <> 0,
	BEQ	CHK_PRESSURE_DROP1	;dann
	ADDD	#-1			;  CHECK_WAIT_CTR decrementieren
	STD	CHECK_WAIT_CTR		;wenn CHECK_WAIT_CTR = 0,
	BNE	CHK_PRESSURE_DROP9	;dann
					;
CHK_PRESSURE_DROP1:
	MOVB	#0,DROP_ALARM		;  DROP_ALARM rücksetzen
					;
;-----------------------------------------------------------------------------
;Druckwerte auf unzulässigen Abfall prüfen
;
	LDX	#MSG_RX_REC		;
	MOVB	#4,R4			;vier Radsender
					;
CHK_PRESSURE_DROP2:
	LDY	#MSG_S1_REC		;
	MOVB	#4,R3			;vier Einträge zur Auswahl
					;
CHK_PRESSURE_DROP3:
	LDAB	#oIDENTIFIER		;Zeiger auf Identifier
	MOVB	#4,R2			;32 bit Identifier
CHK_PRESSURE_DROP4:
	LDAA	B,X			;
	CMPA	B,Y			;Identifier vergleichen
	BNE	CHK_PRESSURE_DROP6	;
	INCB				;
	DEC	R2			;
	BNE	CHK_PRESSURE_DROP4	;
					;
	LDAB	#oPRESSURE		;wenn Identifier gefunden,
	LDAA	B,X			;dann
	BEQ	CHK_PRESSURE_DROP7	;  wenn aktueller Druckwert <> 0,
					;
	ADDA	E_DROP_REF		;  und aktueller Druckwert
	CMPA	B,Y			;  + zulässiger Druckabfall
	BHS	CHK_PRESSURE_DROP7	;  < alter Druckwert
					;
	LDAA	B,X			;
	CMPA	E_DROP_PRESSURE		;  und aktueller Druckwert
	BHS	CHK_PRESSURE_DROP7	;  < Abfall-Druckgrenzwert,
					;
	MOVB	#0FFh,DROP_ALARM	;  dann
	BRA	CHK_PRESSURE_DROP7	;    Druckabfall-Alarm auslösen
					;    weiter mit nächstem Radsender
CHK_PRESSURE_DROP6:
	LEAY	24,Y			;
	DEC	R3			;sonst
	BNE	CHK_PRESSURE_DROP3	;  weitersuchen
					;
CHK_PRESSURE_DROP7:
	LEAX	24,X			;
	DEC	R4			;
	BNE	CHK_PRESSURE_DROP2	;nächster Radsender
					;
;-----------------------------------------------------------------------------
;Datenfeld umspeichern
;
	LDX	#MSG_RX_REC		;Zeiger auf Quelle
	LDY	#MSG_S1_REC		;Zeiger auf Ziel
	MOVB	#4*24,R3		;Anzahl Bytes
CHK_PRESSURE_DROP8:
	MOVB	1,X+,1,Y+		;Datenfeld für nächste Prüfung
	DEC	R3			;umspeichern
	BNE	CHK_PRESSURE_DROP8	;
					;
	MOVW	#CHECK_WAIT_CT,CHECK_WAIT_CTR
					;Zeitzähler auf Startwert
CHK_PRESSURE_DROP9:
	RTS				;
					;
;------------------------------------------------------------------------------
;CHK_TIRES empfängt Botschaften von den Radsendern, prüft die Reifendruck- und
;Temperaturwerte und bereitet den Datenausgabebuffer vor.
;
;Eingangsparameter:	LIN_RX_POS
;			LIN_RX_BUF
;Ausgangsparameter:     ALARM
;			CAN0_MSG0_BUF
;			LIN_RX_POS
;			A		0	= keine CAN-Datenausgabe nötig
;					<> 0	= neue CAN-Datenausgabe gewünscht
;veränderte Register:	CCR, A, B, X, Y, R[0..7]
;------------------------------------------------------------------------------
					;
CHK_TIRES:
	JSR	CHK_SPEED		;Geschwindigkeit prüfen
	JSR	CHK_SENSORS		;Radsender Zeitgrenzen prüfen
	BRCLR	COMMUNICATE_FLAGS,_CAN_RFSH_TRIG,CHK_TIRES1
					;wenn Empfangsunterbrechung erkannt
					;und Datenauswertung aktiv
	BSET	COMMUNICATE_FLAGS,_LOW_XP_FLAG
	JSR	PUT_TIRE_DATA		;dann
	JMP	CHK_TIRES8		;  sofortige Datenausgabe

CHK_TIRES1:
	LDAA	LIN_RX_POS		;
	BNE	CHK_TIRES3		;wenn keine neuen Daten da,
					;dann
	LDD	LIN_RX_CTR		;  wenn LIN_RX_CTR <> 0,
	BEQ	CHK_TIRES2		;  dann
	ADDD	#-1			;    LIN_RX_CTR decrementieren
	STD	LIN_RX_CTR		;
	BEQ	CHK_TIRES2		;
	BRSET	COMMUNICATE_FLAGS,_LOW_XP_TRIG,CHK_TIRES4
	CLRA				;
	JMP	CHK_TIRES9		;    A = 0, keine CAN-Datenausgabe
					;
CHK_TIRES2:
	LDY	#CAN0_MSG0_BUF		;    wenn LIN_RX_CTR = 0,
	LDAA	#0FFh			;    dann
	MOVB	#8,R3			;
	JSR	CLEAR_BUFFER8		;      Ausgabebuffer fegen
	LDY	#TIRE_SENSOR_CTR_REC	;
	CLRA				;
	MOVB	#4*2,R3			;
	JSR	CLEAR_BUFFER8		;      Radsender-Timeoutzähler auf Null
	JMP	CHK_TIRES7		;      und ausgeben
					;
CHK_TIRES3:
					;sonst
	BRCLR	COMMUNICATE_FLAGS,_LOW_XP_FLAG,CHK_TIRES5
					;  wenn _LOW_XP_FLAG gesetzt,
CHK_TIRES4:
	JSR	PUT_LOW_XP_DATA		;  dann
	JMP	CHK_TIRES7		;    kein Alarm und keine Datenauswertung
					;
;------------------------------------------------------------------------------
;Auswertung der Botschaft
					;
CHK_TIRES5:
	JSR	GET_TIRE_DATA		;  sonst
	LDAA	LIN_RX_POS		;    Datentelegramm auswerten
	BNE	CHK_TIRES6		;
	CLRA				;    ggf. LIN-Daten ignorieren
	BRA	CHK_TIRES9		;
					;
CHK_TIRES6:
	JSR	PUT_TIRE_DATA		;    neue Daten abholen und
	JSR	CHK_ALARM		;    auf absolute Grenzwerte prüfen
					;
CHK_TIRES7:
	MOVW	#LIN_RX_CT,LIN_RX_CTR	;LIN_RX_CTR auf Startwert
					;
CHK_TIRES8:
	LDAA	#0FFh			;
					;
CHK_TIRES9:
	MOVB	LIN_RX_POS,LAST_RX_POS	;
	MOVB	#0,LIN_RX_POS		;LIN-Daten quittieren
	RTS				;
					;
;------------------------------------------------------------------------------
;PUT_STATUS gibt zyklisch an CAN0 aus:
; - Umgebungsluftdruck
; - vier Radelektronik Telegram Timeoutzähler und Trustlevel
; - Warnlampenstatus
; - Antennenstatus
;
;Eingangsparameter:	E_CAN_MASK,_STATUS
;			Variablenwerte
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y, R[0..2,4..5]
;------------------------------------------------------------------------------
					;
PUT_STATUS:
	BRSET	E_CAN_MASK,_STATUS,PUT_STATUS1
	LBRA	PUT_STATUS9		;wenn E_CAN_MASK,_STATUS,
					;dann
PUT_STATUS1:
	LDD	P_AMBIENT		;  DATA16: Umgebungsluftdruck
	STAB	CAN0_MSG1_BUF+0		;
	STAA	CAN0_MSG1_BUF+1		;
					;
	LDX	#TIRE_SENSOR_CTR_REC	;
					;
;------------------------------------------------------------------------------
					;
	LDAA	0,X			;  nur High Byte lesen
	ANDA	#00001111b		;
					;
	LDY	#MSG_CTR_TBL		;
	LEAY	0,Y			;
	LDY	0,Y			;
	LDAB	0,Y			;
	CMPB	#15			;
	BLS     PUT_STATUS_1		;
	LDAB	#15			;  auf 0..15 begrenzen
PUT_STATUS_1:
	ANDB	#00001111b		;
	ASLB				;
	ASLB				;
	ASLB				;
	ASLB				;
	ABA				;
	STAA	CAN0_MSG1_BUF+2		;
					;
;------------------------------------------------------------------------------
					;
	LDAA	2,X			;  nur High Byte lesen
	ANDA	#00001111b		;
					;
	LDY	#MSG_CTR_TBL		;
	LEAY	2,Y			;
	LDY	0,Y			;
	LDAB	0,Y			;
	CMPB	#15			;
	BLS     PUT_STATUS_2		;
	LDAB	#15			;  auf 0..15 begrenzen
PUT_STATUS_2:
	ANDB	#00001111b		;
	ASLB				;
	ASLB				;
	ASLB				;
	ASLB				;
	ABA				;
	STAA	CAN0_MSG1_BUF+3		;
					;
;------------------------------------------------------------------------------
					;
	LDAA	4,X			;  nur High Byte lesen
	ANDA	#00001111b		;
					;
	LDY	#MSG_CTR_TBL		;
	LEAY	4,Y			;
	LDY	0,Y			;
	LDAB	0,Y			;
	CMPB	#15			;
	BLS     PUT_STATUS_3		;
	LDAB	#15			;  auf 0..15 begrenzen
PUT_STATUS_3:
	ANDB	#00001111b		;
	ASLB				;
	ASLB				;
	ASLB				;
	ASLB				;
	ABA				;
	STAA	CAN0_MSG1_BUF+4		;
					;
;------------------------------------------------------------------------------
					;
	LDAA	6,X			;  nur High Byte lesen
	ANDA	#00001111b		;
					;
	LDY	#MSG_CTR_TBL		;
	LEAY	6,Y			;
	LDY	0,Y			;
	LDAB	0,Y			;
	CMPB	#15			;
	BLS     PUT_STATUS_4		;
	LDAB	#15			;  auf 0..15 begrenzen
PUT_STATUS_4:
	ANDB	#00001111b		;
	ASLB				;
	ASLB				;
	ASLB				;
	ASLB				;
	ABA				;
	STAA	CAN0_MSG1_BUF+5		;
					;
	LDAA	ALARM			;
	ORAA	DROP_ALARM		;  DATA8: Warnlampenstatus
	STAA	CAN0_MSG1_BUF+6		;
	LDAA	LIN_ANT_FLAGS		;  DATA8: Antennenstatus
	STAA	CAN0_MSG1_BUF+7		;
					;
	MOVB	#0,R0			;
	MOVB	#5,R1			;  Message 5 : default = 0x6F5
	MOVB	#0,R2			;
	MOVW	#CAN0_MSG1_BUF,R4	;  an CAN0 ausgeben
	JSR	CAN_WRITE		;
					;
PUT_STATUS9:
	RTS				;
					;
;------------------------------------------------------------------------------
;PUT_DATA gibt Druck- und Temperaturwerte der Radelektroniken an CAN aus.
;
;Eingangsparameter:	E_CAN_MASK,_VALUES
;			CAN_MSG0_BUF	Druck- und Temperaturwerte
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y, R[0..2,4..5]
;------------------------------------------------------------------------------
					;
PUT_DATA:
	BRSET	E_CAN_MASK,_VALUES,PUT_DATA1
	LBRA	PUT_DATA9		;wenn E_CAN_MASK,_IDENTIFIERS,
					;dann
PUT_DATA1:
	MOVB	#0,R0			;
	MOVB	#4,R1			;Message 4 : default = 0x6F4
	MOVB	#0,R2			;
	MOVW	#CAN0_MSG0_BUF,R4	;an CAN0 ausgeben
	JSR	CAN_WRITE		;
					;
PUT_DATA9:
	RTS				;
					;
;------------------------------------------------------------------------------
;PUT_IDENTIFIERS gibt aktuell erkannte Identifier als 32-bit Werte im
;INTEL-Format (LSB..MSB) an CAN aus.
;
;Eingangsparameter:	E_CAN_MASK,_IDENTIFIERS
;			Identifierwerte
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y, R[0..2,4..5]
;------------------------------------------------------------------------------
					;
PUT_IDENTIFIERS:
	BRSET	E_CAN_MASK,_IDENTIFIERS,PUT_IDENTIFIERS1
	LBRA	PUT_IDENTIFIERS9	;wenn E_CAN_MASK,_IDENTIFIERS,
					;dann
PUT_IDENTIFIERS1:
	LDX	MSG_IDENTIFIER_TBL+0	;  Zeiger auf Identifier vorne links
	LDY	#CAN0_MSG2_BUF+3	;  DATA32:
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	0,X			;
	STAA	0,Y			;
	LDX	MSG_IDENTIFIER_TBL+2	;  Zeiger auf Identifier vorne rechts
	LDY	#CAN0_MSG2_BUF+7	;  DATA32:
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	0,X			;
	STAA	0,Y			;
	MOVB	#0,R0			;
	MOVB	#2,R1			;  Message 2 : default = 0x6F2
	MOVB	#0,R2			;
	MOVW	#CAN0_MSG2_BUF,R4	;  an CAN0 ausgeben
	JSR	CAN_WRITE		;
					;
	LDX	MSG_IDENTIFIER_TBL+4	;  Zeiger auf Identifier hinten links
	LDY	#CAN0_MSG2_BUF+3	;  DATA32:
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	0,X			;
	STAA	0,Y			;
	LDX	MSG_IDENTIFIER_TBL+6	;  Zeiger auf Identifier hinten rechts
	LDY	#CAN0_MSG2_BUF+7	;  DATA32:
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	1,X+			;
	STAA	1,Y-			;
	LDAA	0,X			;
	STAA	0,Y			;
	MOVB	#0,R0			;
	MOVB	#3,R1			;  Message 3 : default = 0x6F3
	MOVB	#0,R2			;
	MOVW	#CAN0_MSG2_BUF,R4	;  an CAN0 ausgeben
	JSR	CAN_WRITE		;
					;
PUT_IDENTIFIERS9:
	RTS				;
					;
;------------------------------------------------------------------------------
;CAN_IO empfängt Botschaften von anderen Netzkoten und sendet Messdaten.
;
;Eingangsparameter:	.
;Ausgangsparameter:	.
;veränderte Register:	CCR, A, B, X, Y, R[0..5]
;------------------------------------------------------------------------------
					;
CAN_IO:
	JSR	GET_MCU_DATA		;Message 0 abfragen
					;
;------------------------------------------------------------------------------
; Reifenüberwachung
					;
	JSR	CHK_TIRES		;
					;
;------------------------------------------------------------------------------
					;
	LDAA	TIRE_DAT_RFSH_CTR	;wenn Data-Telegrammzykluszeit abgelaufen
	DECA				;
	BNE	CAN_IO2			;dann
	JSR	PUT_DATA		;  Messdaten an CAN ausgeben
	LDAA	#TIRE_DAT_RFSH_CT	;  100 ms Daten-Telegrammzykluszeit auf Startwert
CAN_IO2:
	STAA	TIRE_DAT_RFSH_CTR	;
					;
;------------------------------------------------------------------------------
					;
	LDAA	TIRE_ID_RFSH_CTR	;wenn 1 s ID-Telegrammzykluszeit abgelaufen
	DECA				;
	BNE	CAN_IO3			;dann
	JSR	PUT_IDENTIFIERS		;  Radelektroniken-Identifier an CAN ausgeben
	LDAA	#TIRE_ID_RFSH_CT	;  1 s ID-Telegrammzykluszeit auf Startwert
CAN_IO3:
	STAA	TIRE_ID_RFSH_CTR	;
					;
;------------------------------------------------------------------------------
					;
	JSR	CHK_PRESSURE_DROP	;auf Reifendruckabfall prüfen
	JSR	PUT_STATUS		;Reifenüberwachungs-Status an CAN ausgeben
					;
CAN_IO9:
	RTS				;
					;
;------------------------------------------------------------------------------
;COMLINE_EXECUTE : Callback Funktion des Modules s12g_COMLINE
;Anstoßen der Neuinitialisierung des CAN-Modules
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
COMLINE_EXECUTE:
	MOVB	#0,R0			;
	MOVW	#E_CAN0_CONFIG_TBL,R4	;
	JSR	CAN_RESET		;MSCAN0 neu initialisieren
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end


