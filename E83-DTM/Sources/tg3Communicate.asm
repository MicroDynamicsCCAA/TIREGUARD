	include	"s12c_128.sfr"
	include	"s12c_Switches.sfr"
	title	"tg3Communicate  Copyright (C) 2005-2013, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TireGuard 3a	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg3Communicate.asm
;
;Copyright:	(C) 2005-2013, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	02.07.2013
;
;Description:	CAN-Kommunikation, RS232-Kommunikation und Ende des Programmzyklusses
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
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
	xref	CLEAR_BUFFER		;Code

	xref	CAN_READ		;Code
	xref	CAN_WRITE		;Code
	xref	COMLINE_INPUT		;Code
	xref	COMLINE_REACTION	;Code
;
;begin 20.01.2011
	xref	COMLINE_TIMEOUTS	;Code
;end
;
					;
	xref	LIN_IDENTIFIER_TBL	;roData
	xref	MSG_IDENTIFIER_TBL	;roData
	xref	MSG_CTR_TBL		;roData
	xref	MSG_RX_TBL		;roData
					;
	xref	E_BARO_PRESSURE		;bssData
	xref	E_DROP_PRESSURE		;bssData
	xref	E_DROP_REF		;bssData
;
;begin 02.07.2013
	xref	E_FUN_MODE		;bssData
;end
;
	xref	E_PRESSURE		;bssData
	xref	E_TEMPERATURE		;bssData
	xref	E_XP_REF		;bssData
					;
	xref	ALARM			;Data
	xref	BATTERY_VOLTAGE		;Data
	xref	CAN0_MSG0_BUF		;Data
	xref	CAN0_MSG1_BUF		;Data
	xref	CAN0_MSG2_BUF		;Data
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
	xref	SENSOR_CTR_REC		;Data
;
;begin 02.07.2013
	xref	TIRE_RFSH_CTR		;Data
;end
;
	xref	UNIT_TEMPERATURE	;Data
	xref	XP			;Data
					;
	xref	CAN0_RX_CT		;Number
	xref	CHECK_WAIT_CT		;Number
;
;begin 02.07.2013
	xref.b	TIRE_RFSH_CT		;Number
;end
;
	xref	LIN_RX_CT		;Number
					;
	xref.b	oIDENTIFIER		;Number
	xref.b	oTEMPERATURE		;Number
	xref.b	oPRESSURE		;Number
					;
	xref	SENSOR_CT		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
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
;
;begin 20.01.2011
	JSR	COMLINE_TIMEOUTS	;
;end
;
					;
	BSET	PTT,bit7		;Ende der aktiven Zyklusphase
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
;GET_1753_DATA empfängt die Fahrgeschwindigkeit und Analogwerte vom Messsystem.
;
;Eingangsparameter:	CAN0_RX_CTR
;Ausgangsparameter:	CAN0_RX_CTR
;			XP
;veränderte Register:	CCR, A, B, X, Y, R[0..5]
;------------------------------------------------------------------------------
					;
GET_1753_DATA:
	MOVB	#0,R0			;
	MOVB	#2,R1			;Message 2
	MOVW	#CAN0_MSG2_BUF,R4	;
	JSR	CAN_READ		;von CAN0 lesen
	BEQ	GET_1753_DATA2		;wenn keine neuen Daten da,
					;
	LDX	CAN0_RX_CTR		;dann
	BEQ	GET_1753_DATA1		;  wenn CAN0_RX_CTR <> 0,
	DEX				;  dann
	STX	CAN0_RX_CTR		;    CAN0_RX_CTR decrementieren
	BNE	GET_1753_DATA9		;
					;
GET_1753_DATA1:
	LDY	#CAN0_MSG2_BUF		;  wenn CAN0_RX_CTR = 0,
	CLRA				;  dann
	MOVB	#8,R3			;
	JSR	CLEAR_BUFFER		;    Empfangsbuffer fegen
					;
GET_1753_DATA2:
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
GET_1753_DATA9:
	RTS				;
					;
;------------------------------------------------------------------------------
;CHK_SPEED prüft, ob die Fahrgeschwindigkeit kleiner als die Ausblend-
;geschwindigkeit ist. Abhängig davon wird das LOW_XP_FLAG gesetzt oder
;rückgesetzt.
;
;Eingangsparameter:	XP
;			COMMUNICATE_FLAGS._LOW_XP_FLAG
;			E_XP_REF
;Ausgangsparameter:	COMMUNICATE_FLAGS._LOW_XP_TRIG
;			COMMUNICATE_FLAGS._LOW_XP_FLAG
;veränderte Register:	CCR, A, B
;------------------------------------------------------------------------------
					;
CHK_SPEED:
	BCLR	COMMUNICATE_FLAGS,_LOW_XP_TRIG
	LDD	E_XP_REF		;wenn Geschwindigkeitsgrenze <> 0
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
;CHK_SENSORS setzt nach Ablauf der durch SENSOR_CT festgelegten Zeit die
;jeweiligen Temperatur- und Druckwerte auf Null.
;
;Eingangsparameter:	SENSOR_CTR_REC
;Ausgangsparameter:
;			COMMUNICATE_FLAGS._CAN_RFSH_TRIG
;			SENSOR_CTR_REC
;			MSG_RX_REC
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
CHK_SENSORS:
	BCLR	COMMUNICATE_FLAGS,_CAN_RFSH_TRIG
	LDY	#MSG_RX_REC		;
	LDX	#SENSOR_CTR_REC		;
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
;COMPARE_MESSAGE
;
;Eingangsparameter:	B
;Ausgangsparameter:	B		bleibt unverändert !
;veränderte Register:	CCR, A, X, Y, R3
;------------------------------------------------------------------------------
					;
COMPARE_MESSAGE:
	LDY	#MSG_RX_TBL		;Tabelle mit den MSG_RX_BUF-Basisadressen
	LEAY	B,Y			;
	LDY	0,Y			;MSG_RX_BUF-Basisadresse aus Tabelle lesen
	LDX	#LIN_RX_BUF		;
					;
	LDAA	0,X			;Telegramme, die von mehreren Empfängern
	CMPA	LAST_RX_POS		;parallel empfangen wurden, ignorieren
	BEQ	COMPARE_MESSAGE7	;
					;
	LDAA	3,X+			;Triggerantennen-Position vergleichen
	CMPA	3,Y+			;Zeitoffsets überspringen
	BNE	COMPARE_MESSAGE8	;
	MOVB	#13,R3			;  13 Bytes
COMPARE_MESSAGE1:
	LDAA	1,X+			;
	CMPA	1,Y+			;
	BNE	COMPARE_MESSAGE8	;wenn relevanter Dateninhalt des neuen Telegrammes
	DEC	R3			;identisch mit den bereits vorliegenden Daten ist,
	BNE	COMPARE_MESSAGE1	;dann
					;
COMPARE_MESSAGE7:
	LDAA	#0FFh			;neues Telegramm ignorieren
	BRA	COMPARE_MESSAGE9	;
					;
COMPARE_MESSAGE8:
	CLRA				;
					;
COMPARE_MESSAGE9:
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
;veränderte Register:	CCR
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
	CMPA	#03h			;des gespeicherten Identifiers >= 3,
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
;CHK_IDENTIFIER
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
	CMPA	#20h			;  wenn Zähler < Maximalwert,
	LBHS	CHK_IDENTIFIER4		;  dann
	INCA				;    Zähler incrementieren
	STAA	0,X			;
	CMPA	#08h			;    wenn Zähler = Minimalwert,
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
;GET_DATA legt empfangene Reifensensor-Telegramme im MSG_RX_REC ab.
;
;Eingangsparameter:     LIN_RX_BUF
;Ausgangsparameter:	MSG_RX_REC
;			SENSOR_CTR_REC
;veränderte Register:	CCR, A, B, X, Y, R3
;------------------------------------------------------------------------------
					;
GET_DATA:
	LDAB	LIN_RX_POS		;
	LBEQ	GET_DATA9		;
	CMPB	#4			;wenn Position im Bereich [1..4] liegt,
	LBHI	GET_DATA9		;dann
	DECB				;  Position decrementieren und mal 2
	LSLB				;  liefert in B Zeiger in
					;
	JSR	COMPARE_MESSAGE		;
	BEQ	GET_DATA1		;
	MOVB	#0,LIN_RX_POS		;
	JMP	GET_DATA9		;
					;
GET_DATA1:
	JSR	CHK_IDENTIFIER		;
	BEQ	GET_DATA2		;
	MOVB	#0,LIN_RX_POS		;
	JMP	GET_DATA9		;
					;
GET_DATA2:
	LDY	#MSG_RX_TBL		;  Tabelle mit den MSG_RX_BUF-Basisadressen
	LEAY	B,Y			;
	LDY	0,Y			;  MSG_RX_BUF-Basisadresse aus Tabelle lesen
	LDX	#LIN_RX_BUF		;

	MOVB	#24,R3			;  24 Bytes
GET_DATA3:
	MOVB	1,X+,1,Y+		;  Daten ablegen
	DEC	R3			;
	BNE	GET_DATA3		;
					;
	LDY	#SENSOR_CTR_REC		;
	LEAY	B,Y			;
	MOVW	#SENSOR_CT,0,Y		;  Timeout-Zähler auf Startwert
					;
GET_DATA9:
	RTS				;
					;
;------------------------------------------------------------------------------
;PUT_DATA bereitet den Ausgabebuffer mit den Temperatur- und Druckwerten vor.
;
;Eingangsparameter:	MSG_RX_REC
;Ausgangsparameter:	CAN0_MSG0_BUF
;veränderte Register:	CCR, A, B, X, Y, R3
;------------------------------------------------------------------------------
					;
PUT_DATA:
	LDX	#MSG_RX_REC		;
	LEAX	oTEMPERATURE,X		;
	LDY	#CAN0_MSG0_BUF		;
	MOVB	#4,R3			;
PUT_DATA1:
	LDAA	0,X			;
	BEQ	PUT_DATA2		;wenn Temperatur-Rohdatenwert <> 0 und <> 0xFF,
	CMPA	#0FFh			;
	BEQ	PUT_DATA2		;dann
	SUBA	#40			;  den Temperaturoffset von 40°C subtrahieren
	BHI	PUT_DATA2		;  ggf. Ergebnis nach unten begrenzen
	LDAA	#1			;
PUT_DATA2:
	STAA	1,Y+			;
	LEAX	24,X			;
	DEC	R3			;
	BNE	PUT_DATA1		;
					;
	LDX	#MSG_RX_REC		;
	LEAX	oPRESSURE,X		;
	MOVB	#4,R3			;
PUT_DATA3:
	LDAA	0,X			;
	BEQ	PUT_DATA4		;wenn Druck-Rohdatenwert <> 0 und <> 0xFF,
	CMPA	#0FFh			;
	BEQ	PUT_DATA4		;dann
	SUBA	E_BARO_PRESSURE		;  Umgebungsdruck subtrahieren
	BHI	PUT_DATA4		;  ggf. Ergebnis nach unten begrenzen
	LDAA	#1			;
PUT_DATA4:
	STAA	1,Y+			;
	LEAX	24,X			;
	DEC	R3			;
	BNE	PUT_DATA3		;
	RTS				;
					;
;-----------------------------------------------------------------------------
;CKH_ALARM untersucht die Temperatur- und Druckwerte im Ausgabebuffer auf
;Verletzung der absoluten Grenzwerte.
;
;Eingangsparameter:	CAN0_MSG0_BUF
;Ausgangsparameter:	ALARM
;veränderte Register:	CCR, A, B, X, R[2..3]
;-----------------------------------------------------------------------------
					;
CHK_ALARM:
	CLRB				;
					;
	LDX	#CAN0_MSG0_BUF		;

 ifne fDebug
	MOVB	#1,R3			;
 else
	MOVB	#4,R3			;
 endif

CHK_ALARM1:
	LDAA	1,X+			;
	BEQ	CHK_ALARM11		;
	CMPA	#0FFh			;
	BEQ	CHK_ALARM11		;
	CMPA	E_TEMPERATURE		;
	BLS	CHK_ALARM11		;Temperaturwerte untersuchen
					;
	LDAB	#0FFh			;
					;
CHK_ALARM11:
	DEC	R3			;
	BNE	CHK_ALARM1		;

 ifne fDebug
	LEAX	3,X
 endif
					;
	LDAA	E_PRESSURE		;
	SUBA	E_BARO_PRESSURE		;
	STAA	R2			;

 ifne fDebug
	MOVB	#1,R3			;
 else
	MOVB	#4,R3			;
 endif

CHK_ALARM2:
	LDAA	1,X+			;
	BEQ	CHK_ALARM21		;
	CMPA	#0FFh			;
	BEQ	CHK_ALARM21		;
	CMPA	R2			;Druckwerte untersuchen
	BHS	CHK_ALARM21		;
					;
	LDAB	#0FFh			;
					;
CHK_ALARM21:
	DEC	R3			;
	BNE	CHK_ALARM2		;
					;
	STAB	ALARM			;
	RTS				;
					;
;-----------------------------------------------------------------------------
;PUT_LOW_XP_DATA setzt die Temperatur- und Druckwerte im Ausgabepuffer auf
;deren Überwachungsgrenzen und nimmt einen evtl. Alarm zurück.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	CAN0_MSG0_BUF
;			ALARM
;veränderte Register:	CCR, A, Y, R3
;-----------------------------------------------------------------------------
					;
PUT_LOW_XP_DATA:
	LDY	#CAN0_MSG0_BUF		;
	LDAA	E_TEMPERATURE		;
	MOVB	#4,R3			;
PUT_LOW_XP_DATA1:
	STAA	1,Y+			;Temperaturwerte auf Grenzwert
	DEC	R3			;
	BNE	PUT_LOW_XP_DATA1	;
					;
	LDAA	E_PRESSURE		;
	SUBA	E_BARO_PRESSURE		;
	MOVB	#4,R3			;
PUT_LOW_XP_DATA2:
	STAA	1,Y+			;Druckwerte auf Grenzwert
	DEC	R3			;
	BNE	PUT_LOW_XP_DATA2	;
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
;			MSG_S1_REC
;			E_DROP_PRESSURE
;			E_DROP_REF
;Ausgangsparameter:	CHECK_WAIT_CTR
;			MSG_S1_REC
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
;veränderte Register:	CCR, A, B, X, Y, R[0..5]
;------------------------------------------------------------------------------
					;
CHK_TIRES:
	JSR	CHK_SPEED		;Geschwindigkeit prüfen
	JSR	CHK_SENSORS		;Radsender Zeitgrenzen prüfen
	BRCLR	COMMUNICATE_FLAGS,_CAN_RFSH_TRIG,CHK_TIRES1
					;wenn Empfangsunterbrechung erkannt
					;und Datenauswertung aktiv
	BSET	COMMUNICATE_FLAGS,_LOW_XP_FLAG
	JSR	PUT_DATA		;dann
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
	JSR	CLEAR_BUFFER		;      Ausgabebuffer fegen
	LDY	#SENSOR_CTR_REC		;
	CLRA				;
	MOVB	#4*2,R3			;
	JSR	CLEAR_BUFFER		;      Radsender-Timeoutzähler auf Null
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
	JSR	GET_DATA		;  sonst
	LDAA	LIN_RX_POS		;    Datentelegramm auswerten
	BNE	CHK_TIRES6		;
	CLRA				;    ggf. LIN-Daten ignorieren
	BRA	CHK_TIRES9		;
					;
CHK_TIRES6:
	JSR	PUT_DATA		;    neue Daten abholen und
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
;PUT_1781_DATA gibt zu Testzwecken neue Messdaten aus.
;
;Eingangsparameter:	Variablenwerte
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y, R[0..2,4..5]
;------------------------------------------------------------------------------
					;
PUT_1781_DATA:
					;
 ifne fDebug
	LDAA	TEST_CHECKSUM
	STAA	CAN0_MSG1_BUF+0
	LDAA	TEST_BUF+1
	STAA	CAN0_MSG1_BUF+1

	LDAA	TEST_BUF+0
	STAA	CAN0_MSG1_BUF+2
	LDAA	TEST_VAL
	STAA	CAN0_MSG1_BUF+3
 else
	LDD	BATTERY_VOLTAGE		;DATA16: Batteriespannung
	STD	CAN0_MSG1_BUF+0		;
	LDD	UNIT_TEMPERATURE	;DATA16: Geräteinnentemperatur
	STD	CAN0_MSG1_BUF+2		;
 endif
					;
	LDD	LIN_TIME_CTR		;DATA16: benötigte Zeit für kompletten Abfragezyklus
	STD	CAN0_MSG1_BUF+4		;
	LDAA	ALARM			;
	ORAA	DROP_ALARM		;DATA8: Warnlampenstatus
	STAA	CAN0_MSG1_BUF+6		;
	LDAA	LIN_ANT_FLAGS		;DATA8: Antennenstatus
	STAA	CAN0_MSG1_BUF+7		;
					;
	MOVB	#0,R0			;
	MOVB	#1,R1			;Message 1
	MOVB	#0,R2			;
	MOVW	#CAN0_MSG1_BUF,R4	;an CAN0 ausgeben
	JSR	CAN_WRITE		;
	RTS				;
					;
;
;begin 02.07.2013
;------------------------------------------------------------------------------
;PUT_IDENTIFIER_DATA gibt aktuell erkannte Identifier an CAN aus.
;
;Eingangsparameter:	Identifierwerte
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y, R[0..2,4..5]
;------------------------------------------------------------------------------
					;
PUT_IDENTIFIER_DATA:
	LDX	MSG_IDENTIFIER_TBL+0	;Zeiger auf Identifier vorne links
	LDY	#CAN0_MSG1_BUF+3	;DATA32:
	LDAA	1,X+
	STAA	1,Y-
	LDAA	1,X+
	STAA	1,Y-
	LDAA	1,X+
	STAA	1,Y-
	LDAA	0,X
	STAA	0,Y
	LDX	MSG_IDENTIFIER_TBL+2	;Zeiger auf Identifier vorne rechts
	LDY	#CAN0_MSG1_BUF+7	;DATA32:
	LDAA	1,X+
	STAA	1,Y-
	LDAA	1,X+
	STAA	1,Y-
	LDAA	1,X+
	STAA	1,Y-
	LDAA	0,X
	STAA	0,Y
	MOVB	#0,R0			;
	MOVB	#3,R1			;Message 3
	MOVB	#0,R2			;
	MOVW	#CAN0_MSG1_BUF,R4	;an CAN0 ausgeben
	JSR	CAN_WRITE		;
					;
	LDX	MSG_IDENTIFIER_TBL+4	;Zeiger auf Identifier hinten links
	LDY	#CAN0_MSG1_BUF+3	;DATA32:
	LDAA	1,X+
	STAA	1,Y-
	LDAA	1,X+
	STAA	1,Y-
	LDAA	1,X+
	STAA	1,Y-
	LDAA	0,X
	STAA	0,Y
	LDX	MSG_IDENTIFIER_TBL+6	;Zeiger auf Identifier hinten rechts
	LDY	#CAN0_MSG1_BUF+7	;DATA32:
	LDAA	1,X+
	STAA	1,Y-
	LDAA	1,X+
	STAA	1,Y-
	LDAA	1,X+
	STAA	1,Y-
	LDAA	0,X
	STAA	0,Y
	MOVB	#0,R0			;
	MOVB	#4,R1			;Message 4
	MOVB	#0,R2			;
	MOVW	#CAN0_MSG1_BUF,R4	;an CAN0 ausgeben
	JSR	CAN_WRITE		;
	RTS				;
;end
;
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
	JSR	GET_1753_DATA		;Message 2 abfragen
	JSR	CHK_TIRES		;
;
;begin 02.07.2013
					;
	CMPA	#0			;wenn neue Reifendaten vorhanden
	BEQ	CAN_IO1			;dann
					;
	MOVB	#0,R0			;
	MOVB	#0,R1			;
	MOVB	#0,R2			;
	MOVW	#CAN0_MSG0_BUF,R4	;  Message 0 ausgeben
	JSR	CAN_WRITE		;
					;
CAN_IO1:
	LDAA	E_FUN_MODE		;
	ANDA	#00010000b		;wenn E_FUN_MODE.4 = 0
	BNE	CAN_IO9			;dann
					;
	LDAA	TIRE_RFSH_CTR		;  wenn 1 s Telegrammzykluszeit abgelaufen
	DECA				;
	BNE	CAN_IO2			;  dann
	JSR	PUT_IDENTIFIER_DATA	;    Identifier an CAN ausgeben
	LDAA	#TIRE_RFSH_CT		;    Telegrammzykluszeit auf Startwert
CAN_IO2:
	STAA	TIRE_RFSH_CTR		;
					;
CAN_IO9:
	JSR	CHK_PRESSURE_DROP	;auf Reifendruckabfall prüfen
	JSR	PUT_1781_DATA		;Diagnosedaten ausgeben
;end
;
	RTS				;
					;
;
;begin 20.01.2011
;end
;
	dcb.b	6, 0FFh			;
	SWI				;
					;
	end
