	include	"s12c_128.sfr"
	include	"s12c_COMLINE.sfr"
	title	"s12c_COMLINE  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_COMLINE.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	04.10.2015
;
;Description:	Funktionen der Programmier-Schnittstelle
;
;Folgende Bezeichner sind in s12p_COMLINE.sfr zu definieren:
;
;Switches:	fBlockRead
;		fCalibration
;		fE_CMD_CALLBACK
;		fV_CMD_CALLBACK
;
;------------------------------------------------------------------------------
;Revision History:	Original Version  01.05
;
;04.10.2015	�nderung in D_CMD f�r Konfigurationen > 256 Bytes
;
;28.12.2014	Korrektur in GET_DATA_HANDLE: Am Ende RTS erg�nzt
;
;30.04.2013	Korrektur in COMLINE_TIMEOUTS
;
;20.01.2011	neue Schalter: fBlockRead, fCalibration, fE_CMD_CALLBACK und fV_CMD_CALLBACK
;		Korrektur in GET_DATA_HANDLE: Echo erst am Schluss der Funktion, da
;               anderenfalls der Zeitablauf bei s12c_SoftUart nicht sichergestellt
;28.08.2009	in V_CMD Aufruf von Callbackfunktion V_CMD_EXECUTE neu hinzugef�gt
;
;29.07.2009	function COMLINE_TIMEOUTS neu
;28.07.2009	neue Kommandos: SelectSector und ReadSector
;               Kommandos ReadFirstSector und ReadNextSector restlos wieder entfernt
;29.06.2009	neue Kommandos: ReadFirstSector und ReadNextSector
;24.06.2009	zus�tzlichen Speicherbereich DATA_FLASH ber�cksichtigen
;12.06.2009	8-bit Pr�fsumme durch CRC-16/X25 Pr�fcode ersetzt
;
;24.11.2006	Einbindung der externen SoftUart-Funktionen SCI_???
;20.11.2006	Parameterspeicher im FLASH-Speicher
;08.11.2006	Anpassung an MC9S12C128
;
;03.04.2006	in COMLINE_RESET Sendeleitung stets deaktivieren
;		in O_CMD Wartezeit verl�ngert
;		Zeitgrenzen jetzt in Abh�ngigkeit von BUS_CLK setzen
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
;					;
;Anwendungsprogramm			;
 if fE_CMD_CALLBACK
	xref	COMMAND_EXECUTE		;Code
 endif
 if fBlockRead
	xref	READ_FRAM_SECTOR	;Code
 endif
 if fV_CMD_CALLBACK
	xref	V_CMD_EXECUTE		;Code
 endif
;					;
;s12c_CRC.asm				;
	xref	CREATE_KERMIT		;Code
	xref	CREATE_X25		;Code
;					;
;s12c_FTS.asm				;
	xref	FTS_COPY		;Code
	xref	FTS_FLASH		;Code
	xref	FTS_WRITE8		;Code
	xref	FTS_WRITE16		;Code
;					;
;s12c_Uart.asm				;
	xref	SCI_READ8		;Code
	xref	SCI_RESET		;Code
	xref	SCI_TX_DISABLE		;Code
	xref	SCI_TX_ENABLE		;Code
	xref	SCI_WRITE8		;Code
 if fBlockRead == _true
	xref	SCI_TX_INT_ENABLE	;Code
	xref	SCI_TX_INT_STATUS	;Code
 endif
					;
	xref	CONFIG_TBL		;roData
 					;
 if fCalibration == _true
	xref	E_CALIBRATION_CRC	;rwData
	xref	E_CALIBRATION_TBL	;rwData
 endif
					;
	xref	E_CONFIG_CRC		;bssData
	xref	E_CONFIG_TBL		;bssData
					;
	xref	B_EEPROM		;Data
	xref	T_EEPROM		;Data
 if fCalibration
	xref	B_DATA_FLASH		;Data
	xref	T_DATA_FLASH		;Data
 endif
	xref	B_RAM			;Data
	xref	T_RAM			;Data
					;
 if fBlockRead == _true
	xref	SCI_SECTOR_BUF		;Data
	xref	SCI_SECTOR_CRC		;Data
	xref	SCI_SECTOR_CTR		;Data
	xref	SCI_SECTOR_PTR		;Data
 endif
					;
	xref	BUS_CLK			;Number
 if fCalibration == _true
	xref.b	CALIBRATION_TBL_CNT	;Number
 endif
	xref.b	CONFIG_TBL_CNT		;Number
	xref.b	C_STEP			;Number
	xref	SCI_SECTOR_SIZE		;Number
	xref	RX_TIMEOUT_CT		;Number
	xref	TX_TIMEOUT_CT		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	COMLINE_INPUT		;Code
	xdef	COMLINE_REACTION	;Code
	xdef	COMLINE_RESET		;Code
	xdef	COMLINE_TIMEOUTS	;Code
					;
;------------------------------------------------------------------------------
;Variablen und Konstanten
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:
					;
CML_FLAGS:	ds.b	1		;Flags
_TX_FLAG:	equ	bit0		;1, wenn Echo erwartet wird
_RX_FLAG:	equ	bit1		;1, wenn Datenempfang erwartet wird
_COMLINE_ERROR:	equ	bit2		;tempor�rer Kommunikationsfehler
_CMD_MODE_FLAG:	equ	bit3		;1, wenn Kommando aktiv
_GET_DATA_FLAG:	equ	bit4		;1, wenn Datenempfang aktiv
_PUT_DATA_FLAG:	equ	bit5		;1, wenn Datenausgabe aktiv
_COMLINE_FLAG:	equ	bit6		;1, wenn RS232-Kommunikation aktiv
_COMLINE_TRIG:	equ	bit7		;Startflag f�r die RS232-Kommunikation aktiv
					;
CMD_FLAGS:	ds.b	1		;Flags
;
;
;
;
;
;
;
_BLOCKREAD:	equ	bit7		;1, solange Sektor-Blocktransfer l�uft
					;
TX_BUFFER:	ds.b	1		;DATA8: Ausgabebuffer
RX_BUFFER:	ds.b	1		;DATA8: Empfangsbuffer
					;
		even
TX_TIMEOUT:	ds.w	1		;DATA16: Zeitz�hler f�r Sende-Echo
RX_TIMEOUT:	ds.w	1		;DATA16: Zeitz�hler f�r Datenempfang
IO_PTR:		ds.w	1		;DATA16: Zeiger f�r RS232 Kommandos
IO_CTR:		ds.w	1		;DATA16: Bytez�hler f�r RS232 Kommandos
					;
IO_DATA_PTR:	ds.w	1		;DATA16: Zeiger f�r RS232 Kommandos
IO_DATA_CTR:	ds.w	1		;DATA16: Bytez�hler f�r RS232 Kommandos
					;
PARAMETER_BLOCK:
PB_TYPE:	ds.b	1		;DATA8: Speichertyp der Datenquelle
					;	0 : interner RAM-, EEPROM- oder FLASH-Speicher
					;	1 : externer FRAM-Datenspeicher
					;	sonst : nicht definiert
PB_PAGE:	ds.w	1		;DATA16: undefiniert (Type = 0) oder PAGE-Adresse (TYPE = 1)
PB_OFFSET:	ds.w	1		;DATA16: Adresse (TYPE = 0) oder OFFSET-Adresse (TYPE = 1)
PARAMETER_CNT:		equ	* - PARAMETER_BLOCK
					;
TOV:
					;
.text:		section
					;
;-----------------------------------------------------------------------------
;Public: COMLINE_RESET bringt die RS232-Schnittstelle in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR, A, X, Y
;-----------------------------------------------------------------------------
					;
COMLINE_RESET:
	LDY	#BOV			;
	LDX	#(TOV - BOV)		;
	LDAA	#0			;
COMLINE_RESET1:
	STAA	1,Y+			;alle Variablen auf null setzen
	DBNE	X,COMLINE_RESET1	;
					;
	JSR	SCI_RESET		;
	RTS				;
					;
;-----------------------------------------------------------------------------
;Public: COMLINE_TIMEOUTS pr�ft den RS232-Sende- und RS232-Empfangskanal auf
;Wartezeit�berschreitung.
;
;Eingangsparameter:	RX_TIMEOUT
;			TX_TIMEOUT
;Ausgangsparameter:	RX_TIMEOUT
;			TX_TIMEOUT
;			CML_FLAGS._TX_FLAG
;			CML_FLAGS._COMLINE_ERROR
;ver�nderte Register:	CCR, A, B
;-----------------------------------------------------------------------------
					;
COMLINE_TIMEOUTS:
	BRCLR	CML_FLAGS,_CMD_MODE_FLAG,COMLINE_TIMEOUTS8
					;wenn CML_FLAGS._CMD_MODE_FLAG
;
;begin 30.04.2013
					;dann
	BRCLR	CML_FLAGS,_GET_DATA_FLAG,COMLINE_TIMEOUTS1
;end
;
	LDD	RX_TIMEOUT		;  wenn Daten Empfangen aktiv,
	BEQ	COMLINE_TIMEOUTS1	;
	SUBD	#1			;  dann
	STD	RX_TIMEOUT		;    wenn RX_TIMEOUT_abgelaufen,
	BNE	COMLINE_TIMEOUTS1	;    dann
	BSET	CML_FLAGS,_COMLINE_ERROR;      _COMLINE_ERROR setzen
					;
COMLINE_TIMEOUTS1:
;
;begin 30.04.2013
	BRCLR	CML_FLAGS,_PUT_DATA_FLAG,COMLINE_TIMEOUTS2
;end
;
	LDD	TX_TIMEOUT		;  wenn Daten Senden aktiv,
	BEQ	COMLINE_TIMEOUTS2	;
	SUBD	#1			;  dann
	STD	TX_TIMEOUT		;    wenn TX_TIMEOUT_abgelaufen,
	BNE	COMLINE_TIMEOUTS2	;    dann
	BSET	CML_FLAGS,_COMLINE_ERROR;      _COMLINE_ERROR setzen
	BCLR	CML_FLAGS,_TX_FLAG	;      und _TX_FLAG ruecksetzen
					;
COMLINE_TIMEOUTS2:
	BRA	COMLINE_TIMEOUTS9	;
					;
COMLINE_TIMEOUTS8:
;
;begin 30.04.2013
	LDD	#RX_TIMEOUT_CT		;sonst
	STD	RX_TIMEOUT		;  RX_TIMEOUT auf Startwert
	LDD	#TX_TIMEOUT_CT
	STD	TX_TIMEOUT		;  TX_TIMEOUT auf Startwert
;end
;
					;
COMLINE_TIMEOUTS9:
	RTS				;
					;
;-----------------------------------------------------------------------------
;Public: COMLINE_INPUT nimmt Zeichen vom RS232-Empfangskanal entgegen.
;Es wird zwischen einem Echo eines vorher gesendeten Zeichens und einem
;echt empfangenen Zeichen unterschieden.
;
;Eingangsparameter:	CML_FLAGS._TX_FLAG
;Ausgangsparameter:	CML_FLAGS._TX_FLAG
;			CML_FLAGS._RX_FLAG
;			CML_FLAGS._COMLINE_ERROR
;ver�nderte Register:	CCR, A
;-----------------------------------------------------------------------------
					;
COMLINE_INPUT:
;
;begin 20.01.2011
 if fBlockRead == _true
	BRSET	CMD_FLAGS,_BLOCKREAD,COMLINE_INPUT3
 endif
;end
;
	JSR	SCI_READ8		;wenn neues Zeichen da,
	BCS	COMLINE_INPUT3		;dann
	STAA	RX_BUFFER		;  empfangenes Zeichen lesen
	BRSET	CML_FLAGS,_TX_FLAG,COMLINE_INPUT1
	BSET	CML_FLAGS,_RX_FLAG	;wenn Echoflag r�ckgesetzt,
	JMP	COMLINE_INPUT3		;dann RX_FLAG setzen
COMLINE_INPUT1:
	LDAA	TX_BUFFER		;
	CMPA	RX_BUFFER		;wenn empfangenes <> gesendetem Zeichen,
	BEQ	COMLINE_INPUT2		;dann
	BSET	CML_FLAGS,_COMLINE_ERROR;  Fehler bei der Daten�bertragung
COMLINE_INPUT2:
	BCLR	CML_FLAGS,_TX_FLAG	;Echoflag r�cksetzen
					;
COMLINE_INPUT3:
	RTS				;
					;
;-----------------------------------------------------------------------------
;Public: COMLINE_REACTION wertet empfangene Kommandocodes aus und
;bearbeitet die entsprechenden Aufgaben.
;
;Eingangsparameter:	CML_FLAGS._CMD_MODE_FLAG
;			CML_FLAGS._RX_FLAG
;Ausgangsparameter:	CML_FLAGS._RX_FLAG
;ver�nderte Register:	CCR, A
;-----------------------------------------------------------------------------
					;
COMLINE_REACTION:
;
;begin 20.01.2011
 if fBlockRead == _true
	BRCLR	CMD_FLAGS,_BLOCKREAD,COMLINE_REACTION0
	JSR	SCI_TX_INT_STATUS	;
	BNE	COMLINE_REACTION3	;
	BCLR	CMD_FLAGS,_BLOCKREAD	;
COMLINE_REACTION0:
 endif
;end
;
	BRSET	CML_FLAGS,_CMD_MODE_FLAG,COMLINE_REACTION1
	BRSET	CML_FLAGS,_RX_FLAG,COMLINE_REACTION2
	JMP	COMLINE_REACTION3	;
					;
COMLINE_REACTION1:
	JSR	CMD_EXECUTE		;
	JMP	COMLINE_REACTION3	;Kommando bearbeiten
					;
COMLINE_REACTION2:
	JSR	CMD_DECODE		;Kommandocode entschl�sseln
					;
COMLINE_REACTION3:
	RTS				;
					;
;-----------------------------------------------------------------------------
;CMD_DECODE
;
;Eingangsparameter:
;Ausgangsparameter:
;ver�nderte Register:	CCR, A, B, X
;-----------------------------------------------------------------------------
					;
CMD_DECODE:
	LDAB	RX_BUFFER		;alle Kommandos mit Ausnahme von OPEN
	CMPB	#'O'			;werden nur bei gesetztem _COMLINE_FLAG
	BEQ	CMD_DECODE0		;ausgef�hrt
	BRCLR	CML_FLAGS,_COMLINE_FLAG,NO_CMD
					;
CMD_DECODE0:
	SUBB	#41h			;
	CMPB	#1Ah			;
	BHS	CMD_DECODE3		;
	CLRA				;
	LSLD				;
	LDX	#CMD_TBL		;
	JMP	[D,X]			;
					;
CMD_DECODE1:
	STAA	TX_BUFFER		;
	JSR	SCI_WRITE8		;
;
;begin 20.01.2011
 if fBlockRead == _true
	BRCLR	CMD_FLAGS,_BLOCKREAD,CMD_DECODE2
	JSR	SCI_TX_INT_ENABLE
 endif
;end
;
					;
CMD_DECODE2:
	BSET	CML_FLAGS,_CMD_MODE_FLAG;
					;
CMD_DECODE3:
	BCLR	CML_FLAGS,_RX_FLAG	;
	RTS				;
					;
CMD_TBL:
;
;begin 20.01.2011
 if fBlockRead == _true
	dc.w	A_CMD			;A	SelectSector
	dc.w	B_CMD			;B	ReadSector
 else
	dc.w	NO_CMD			;A
	dc.w	NO_CMD			;B
 endif
;end
;
	dc.w	C_CMD			;C	Close
	dc.w	D_CMD			;D	Default
	dc.w	E_CMD			;E	Execute
	dc.w	NO_CMD			;F
	dc.w	NO_CMD			;G
	dc.w	NO_CMD			;H
	dc.w	NO_CMD			;I
	dc.w	NO_CMD			;J
	dc.w	NO_CMD			;K
	dc.w	NO_CMD			;L
	dc.w	NO_CMD			;M
	dc.w	NO_CMD			;N
	dc.w	O_CMD			;O	Open
	dc.w	P_CMD			;P	SetPointer
	dc.w	NO_CMD			;Q
	dc.w	R_CMD			;R	Read
	dc.w	S_CMD			;S	SetSize
	dc.w	NO_CMD			;T
	dc.w	NO_CMD			;U
	dc.w	V_CMD			;V	SetConfigCRC
	dc.w	W_CMD			;W	Write
;
;begin 20.01.2011
 if fCalibration == _true
	dc.w	X_CMD			;X	SetCalibrationCRC
 else
	dc.w	NO_CMD			;X
 endif
;end
;
	dc.w	NO_CMD			;Y
	dc.w	NO_CMD			;Z
					;
NO_CMD:
	JMP	CMD_DECODE3		;
					;
;
;begin 20.01.2011
 if fBlockRead == _true
;-----------------------------------------------------------------------------
;A_CMD	empf�ngt Parameter f�r nachfolgende Blockdaten�bertragung an den PC.
;-----------------------------------------------------------------------------
					;
A_CMD:
	MOVW	#PARAMETER_BLOCK,IO_PTR	;Zeiger auf Parameterblock
	MOVW	#PARAMETER_CNT-1,IO_CTR	;Anzahl Bytes - 1
	BSET	CML_FLAGS,_GET_DATA_FLAG;Daten empfangen
					;
	LDAA	#0-'A'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;B_CMD	sendet Blockdaten an den PC.
;-----------------------------------------------------------------------------
					;
B_CMD:
	LDAA	PB_TYPE			;
	ANDA	#00000001b		;
	BNE	B_CMD2			;
					;
;------------------------------------------------------------------------------
;Datenquelle im internen Speicher:
;
	LDX	PB_OFFSET		;
	LDY	#SCI_SECTOR_BUF		;
	STY	SCI_SECTOR_PTR		;Sektor-Lesezeiger auf Startwert
	LDD	#SCI_SECTOR_SIZE	;
	LSRD				; / 2
B_CMD1:
	MOVW	2,X+,2,Y+		;Sektor laden
	DBNE	D,B_CMD1		;
	STX	PB_OFFSET		;n�chste Quelladresse merken
	BRA	B_CMD3			;
					;
;------------------------------------------------------------------------------
;Datenquelle im externen FRAM-Speicher
;
B_CMD2:
	MOVB	PB_PAGE+1,R8		;
	LDX	PB_OFFSET		;
	LDY	#SCI_SECTOR_BUF		;Sektor-Lesezeiger auf Startwert
	STY	SCI_SECTOR_PTR		;
	LDD	#SCI_SECTOR_SIZE	;
	STD	R2			;
	JSR	READ_FRAM_SECTOR	;Sektorpuffer laden
	MOVB	R8,PB_PAGE+1		;n�chste Quelladresse merken
	STX	PB_OFFSET		;
					;
;------------------------------------------------------------------------------
;Pr�fcode bilden, dem Datensektor anh�ngen und mit �bertragen
;
B_CMD3:
	LDX	#SCI_SECTOR_BUF		;
	LDD	#SCI_SECTOR_SIZE	;
	STD	R2			;
	JSR	CREATE_X25		;CRC-16/X25-Pr�fcode berechnen
	MOVW	R0,SCI_SECTOR_CRC	;und speichern
	LDD	#SCI_SECTOR_SIZE	;
	ADDD	#2			; + 2 f�r den Pr�fcode
	STD	SCI_SECTOR_CTR		;Sektor-Bytez�hler auf Startwert
					;
	MOVW	#SCI_SECTOR_BUF,IO_PTR	;Zeiger auf Datenquelle
	LDD	#SCI_SECTOR_SIZE	;
	ADDD	#1			; + 2 f�r den Pr�fcode
	STD	IO_CTR			;Anzahl Bytes - 1
	BSET	CMD_FLAGS,_BLOCKREAD	;Blockdaten ohne Echo
					;
	LDAA	#0-'B'			;
	JMP	CMD_DECODE1		;
 endif
;end
;
					;
;-----------------------------------------------------------------------------
;C_CMD	schaltet die TxD-Leitung auf General Purpose IO um.
;-----------------------------------------------------------------------------
					;
C_CMD:
	JSR	SCI_TX_DISABLE		;TxD-Leitung abschalten
	BCLR	CML_FLAGS,_COMLINE_FLAG	;COMLINE_FLAG r�cksetzen
	JMP	CMD_DECODE3		;
					;
;-----------------------------------------------------------------------------
;D_CMD	setzt alle programmierbaren Einstellungen auf Defaultwerte.
;-----------------------------------------------------------------------------
					;
D_CMD:
	MOVW	#CONFIG_TBL,R4		;Quelladresse
	MOVW	#E_CONFIG_TBL,R6	;Zieladresse
;
;begin 04.10.2015
;	MOVB	#CONFIG_TBL_CNT,R3	;Anzahl Bytes
;	JSR	FTS_COPY		;Konfiguration schreiben
	MOVW	#CONFIG_TBL_CNT,R2	;Anzahl Bytes
D_CMD1:
	JSR	FTS_COPY		;Konfiguration schreiben
	TST	R2			;
	BEQ	D_CMD2			;
	DEC	R2			;
	BRA	D_CMD1			;
					;
D_CMD2:
;end
;
	JSR	FTS_FLASH		;
					;
	LDX	#E_CONFIG_TBL		;Pr�fcode der programmierbaren Werte
	MOVW	#CONFIG_TBL_CNT,R2	;
	JSR	CREATE_KERMIT		;neu berechnen
	MOVW	#E_CONFIG_CRC,R6	;
	JSR	FTS_WRITE16		;und schreiben
	JSR	FTS_FLASH		;EEPROM neu programmieren
					;
	LDAA	#0-'D'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;E_CMD	startet nach dem Empfang von Kommandocode und Parametern die
;Ausf�hrung eines Kommandos.
;-----------------------------------------------------------------------------
					;
E_CMD:
;
;begin 20.01.2011
 if fE_CMD_CALLBACK = _true
	JSR	COMMAND_EXECUTE		;Kommando ausf�hren...
 endif
;end
;
					;
	LDAA	#0-'E'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;O_CMD	schaltet die TxD-Leitung auf die RS232-Kommunikation um.
;
;Nur dieses Kommando setzt das COMLINE_FLAG.
;Alle sonstigen Kommandos werden bei nicht gesetztem COMLINE_FLAG
;vollst�ndig ignoriert.
;-----------------------------------------------------------------------------
					;
O_CMD_STR:
	dc.b	0FFh, 0-'O'
O_CMD_CNT:	equ	(* - O_CMD_STR)
					;
O_CMD:
	JSR	SCI_TX_ENABLE		;TxD-Leitung zuschalten
	BSET	CML_FLAGS,_COMLINE_TRIG	;_COMLINE_TRIG setzen
	LDX	#BUS_CLK		;ca. 10 ms abwarten
O_CMD1:
	NOP				;	1
	NOP				;	1
	NOP				;	1
	NOP				;	1
	NOP				;	1
	NOP				;	1
	DEX				;	1
	BNE	O_CMD1			;	3
					;
	MOVW	#O_CMD_STR,IO_PTR	;Zeiger auf Antwortstring
	MOVW	#O_CMD_CNT-1,IO_CTR	;Anzahl Bytes - 1
	BSET	CML_FLAGS,_PUT_DATA_FLAG;Daten senden
	JMP	CMD_DECODE2		;
					;
;-----------------------------------------------------------------------------
;P_CMD	empf�ngt die Startadresse f�r ein folgendes Schreib-/Lesekommando.
;-----------------------------------------------------------------------------
					;
P_CMD:
	MOVW	#IO_DATA_PTR,IO_PTR	;Zeiger auf Datenadresse
	MOVW	#1,IO_CTR		;Anzahl Bytes - 1
	BSET	CML_FLAGS,_GET_DATA_FLAG;Daten empfangen
					;
	LDAA	#0-'P'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;R_CMD	sendet Daten an den PC.
;-----------------------------------------------------------------------------
					;
R_CMD:
	MOVW	IO_DATA_PTR,IO_PTR	;Zeiger auf Datenquelle
	MOVW	IO_DATA_CTR,IO_CTR	;Anzahl Bytes - 1
	BSET	CML_FLAGS,_PUT_DATA_FLAG;Daten senden
					;
	LDAA	#0-'R'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;S_CMD	empf�ngt die Byteanzahl f�r ein folgendes Schreib-/Lesekommando.
;-----------------------------------------------------------------------------
					;
S_CMD:
	MOVW	#IO_DATA_CTR,IO_PTR	;Zeiger auf Datenanzahl
	MOVW	#1,IO_CTR		;Anzahl Bytes - 1
	BSET	CML_FLAGS,_GET_DATA_FLAG;Daten empfangen
					;
	LDAA	#0-'S'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;V_CMD	aktualisiert den Pr�fcode der programmierbaren Einstellungen.
;-----------------------------------------------------------------------------
					;
V_CMD:
;
;begin 20.01.2011
 if fV_CMD_CALLBACK == _true
	JSR	V_CMD_EXECUTE		;Aufruf erg�nzender Funktionen vor
					;der Pr�fcodeberechnung
 endif
;end
;
	LDX	#E_CONFIG_TBL		;Pr�fcode der programmierbaren Werte
	MOVW	#CONFIG_TBL_CNT,R2	;
	JSR	CREATE_KERMIT		;neu berechnen
	MOVW	#E_CONFIG_CRC,R6	;
	JSR	FTS_WRITE16		;und schreiben
	JSR	FTS_FLASH		;EEPROM neu programmieren
					;
	LDAA	#0-'V'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;W_CMD	empf�ngt Daten vom PC und schreibt sie.
;-----------------------------------------------------------------------------
					;
W_CMD:
	MOVW	IO_DATA_PTR,IO_PTR	;Zeiger auf Datenziel
	MOVW	IO_DATA_CTR,IO_CTR	;Anzahl Bytes - 1
	BSET	CML_FLAGS,_GET_DATA_FLAG;Daten senden
					;
	LDAA	#0-'W'			;
	JMP	CMD_DECODE1		;
					;
;
;begin 20.01.2011
 if fCalibration == _true
;-----------------------------------------------------------------------------
;X_CMD	aktualisiert den Pr�fcode der Kaliberierungstabellen.
;-----------------------------------------------------------------------------
					;
X_CMD:
	LDX	#E_CALIBRATION_TBL	;Pr�fcode der Kalibrierungstabellen
	MOVW	#CALIBRATION_TBL_CNT,R2	;
	JSR	CREATE_KERMIT		;neu berechnen
	MOVW	#E_CALIBRATION_CRC,R6	;
	JSR	FTS_WRITE16		;und schreiben
	JSR	FTS_FLASH		;EEPROM neu programmieren
					;
	LDAA	#0-'X'			;
	JMP	CMD_DECODE1		;
 endif
;end
;
					;
;-----------------------------------------------------------------------------
;CMD_EXECUTE pr�ft, welche Aktion innerhalb eines RS232-Kommandos als
;n�chstes ausgef�hrt werden muss und verzweigt entsprechend.
;
;Eingangsparameter:	CML_FLAGS,_TX_FLAG
;			CML_FLAGS,_RX_FLAG
;			CML_FLAGS,_COMLINE_ERROR
;			IO_PTR
;			IO_CTR
;Ausgangsparameter:     CML_FLAGS,_TX_FLAG
;			CML_FLAGS,_RX_FLAG
;			CML_FLAGS,_COMLINE_ERROR
;			IO_PTR
;			IO_CTR
;ver�nderte Register:	CCR, A, B, X, Y, R[0..3,8,10]
;-----------------------------------------------------------------------------
					;
CMD_EXECUTE:
	BRSET	CML_FLAGS,_PUT_DATA_FLAG,CMD_EXECUTE1
	BRSET	CML_FLAGS,_GET_DATA_FLAG,CMD_EXECUTE2
	JMP	CMD_EXECUTE3		;
					;
CMD_EXECUTE1:
	JSR	PUT_DATA_HANDLE		;Daten senden
	JMP	CMD_EXECUTE3		;
					;
CMD_EXECUTE2:
	JSR	GET_DATA_HANDLE		;Daten empfangen
					;
					;
CMD_EXECUTE3:
	JSR	CHK_CMD_STATUS		;pr�fen, ob Kommando fertig bearbeitet
	RTS				;
					;
;-----------------------------------------------------------------------------
;PUT_DATA_HANDLE gibt ein Zeichen an der RS232-Schnittstelle aus.
;
;Eingangsparameter:	CML_FLAGS,_TX_FLAG
;			CML_FLAGS,_COMLINE_ERROR
;			CML_FLAGS,_COMLINE_TRIG
;			IO_PTR
;			IO_CTR
;			TX_TIMEOUT
;Ausgangsparameter:     CML_FLAGS,_COMLINE_TRIG
;			CML_FLAGS,_COMLINE_FLAG
;			CML_FLAGS,_PUT_DATA_FLAG
;			IO_PTR
;			IO_CTR
;			TX_TIMEOUT
;ver�nderte Register:	CCR, A, B, X
;-----------------------------------------------------------------------------
					;
PUT_DATA_HANDLE:
	BRCLR	CML_FLAGS,_TX_FLAG,PUT_DATA_HANDLE1
	JMP	PUT_DATA_HANDLE9	;wenn _TX_FLAG r�ckgesetzt
PUT_DATA_HANDLE1:
	BRCLR	CML_FLAGS,_COMLINE_ERROR,PUT_DATA_HANDLE2
	JMP	PUT_DATA_HANDLE9	;und _COMLINE_ERROR r�ckgesetzt
					;dann
PUT_DATA_HANDLE2:
	LDX	IO_PTR			;
	LDAA	0,X			;  Zeichen aus internem Speicher lesen
	INX				;  Zeiger incrementieren
	STX	IO_PTR			;
	STAA	TX_BUFFER		;  Zeichen merken
	JSR	SCI_WRITE8		;  und ausgeben
	BSET	CML_FLAGS,_TX_FLAG	;  Ausgabeflag setzen
	LDD	#TX_TIMEOUT_CT		;
	STD	TX_TIMEOUT		;  Echo-Timeout auf Startwert
	LDD	IO_CTR			;
	SUBD	#1			;  Anzahl decrementieren
	STD	IO_CTR			;  wenn alle Zeichen �bertragen,
	BCC	PUT_DATA_HANDLE9	;  dann
	BCLR	CML_FLAGS,_PUT_DATA_FLAG;    �bertragung beenden
	BRCLR	CML_FLAGS,_COMLINE_TRIG,PUT_DATA_HANDLE9
	BSET	CML_FLAGS,_COMLINE_FLAG	;    wenn _COMLINE_TRIG gesetzt,
	BCLR	CML_FLAGS,_COMLINE_TRIG	;    dann _COMLINE_FLAG setzen
					;
PUT_DATA_HANDLE9:
	RTS				;
					;
;-----------------------------------------------------------------------------
;GET_DATA_HANDLE empf�ngt ein Zeichen von der RS232-Schnittstelle und
;schreibt es ins EEPROM, DATA-FLASH oder RAM.
;
;Eingangsparameter:	CML_FLAGS,_RX_FLAG
;			CML_FLAGS,_COMLINE_ERROR
;			IO_PTR
;			IO_CTR
;			RX_TIMEOUT
;Ausgangsparameter:     CML_FLAGS,_RX_FLAG
;			CML_FLAGS,_GET_DATA_FLAG
;			IO_PTR
;			IO_CTR
;			RX_TIMEOUT
;ver�nderte Register:	CCR, A, B, Y, R[0,6..7]
;-----------------------------------------------------------------------------
					;
GET_DATA_HANDLE:
	BRSET	CML_FLAGS,_RX_FLAG,GET_DATA_HANDLE1
	JMP	GET_DATA_HANDLE9	;wenn _RX_FLAG gesetzt
GET_DATA_HANDLE1:
	BRCLR	CML_FLAGS,_COMLINE_ERROR,GET_DATA_HANDLE2
	JMP	GET_DATA_HANDLE9	;und _COMLINE_ERROR r�ckgesetzt
					;dann
GET_DATA_HANDLE2:
	LDY	IO_PTR			;
	CPY	#B_EEPROM		;
	BLO	GET_DATA_HANDLE2a	;
	CPY	#T_EEPROM		;
	BHI	GET_DATA_HANDLE2a	;
	STY	R6			;  wenn Zieladresse im EEPROM-Bereich,
	MOVB	RX_BUFFER,R0		;  dann
	JSR	FTS_WRITE8		;    Zeichen ins EEPROM programmieren
	LDAA	RX_BUFFER		;
	JMP	GET_DATA_HANDLE2d	;
					;
GET_DATA_HANDLE2a:
	LDY	IO_PTR			;
	CPY	#B_RAM			;
	BLO	GET_DATA_HANDLE2b	;
	CPY	#T_RAM			;
	BHI	GET_DATA_HANDLE2b	;  sonst wenn Zieladresse im RAM-Bereich,
	LDAA	RX_BUFFER		;  dann
	STAA	0,Y			;    Zeichen im RAM ablegen
	JMP	GET_DATA_HANDLE2d	;
					;
GET_DATA_HANDLE2b:
;
;begin 20.01.2011
 if fCalibration
	LDY	IO_PTR			;
	CPY	#B_DATA_FLASH		;
	BLO	GET_DATA_HANDLE2c	;
	CPY	#T_DATA_FLASH		;
	BHI	GET_DATA_HANDLE2c	;
	STY	R6			;  wenn Zieladresse im DATA-FLASH-Bereich,
	MOVB	RX_BUFFER,R0		;  dann
	JSR	FTS_WRITE8		;    Zeichen ins DATA-FLASH programmieren
	LDAA	RX_BUFFER		;
	JMP	GET_DATA_HANDLE2d	;
 endif
;end
;
					;
GET_DATA_HANDLE2c:
	LDAA	RX_BUFFER		;  sonst Schreiben nicht m�glich!
	COMA				;  Echo invertieren
;
;begin 20.01.2011
	STAA	RX_BUFFER		;  und zwischenspeichern
;end
;
					;
GET_DATA_HANDLE2d:
;
;begin 20.01.2011
;end
;
	LDY	IO_PTR			;
	INY				;  Zeiger incrementieren
	STY	IO_PTR			;
	LDD	#RX_TIMEOUT_CT		;
	STD	RX_TIMEOUT		;  Empfangs-Timeout auf Startwert
	BCLR	CML_FLAGS,_RX_FLAG	;  _RX_FLAG r�cksetzen
	LDD	IO_CTR			;
	SUBD	#1			;  Anzahl decrementieren
	STD	IO_CTR			;  wenn alle Zeichen empfangen,
;
;begin 20.01.2011
	BCC	GET_DATA_HANDLE8	;  dann
	JSR	FTS_FLASH		;    ggf. EEPROM neu programmieren
	BCLR	CML_FLAGS,_GET_DATA_FLAG;    Datenempfang beenden
					;
GET_DATA_HANDLE8:
	LDAA	RX_BUFFER		;
	JSR	SCI_WRITE8		;  Echo senden
;end
;
					;
GET_DATA_HANDLE9:
;
;begin 28.12.2014
	RTS				;
;end
;
					;
;-----------------------------------------------------------------------------
;CHK_CMD_STATUS untersucht den ordnungsgem��en Abschluss eines Kommandos
;und deaktiviert dann das _CMD_MODE_FLAG.
;
;Eingangsparameter:	CML_FLAGS._PUT_DATA_FLAG
;			CML_FLAGS._GET_DATA_FLAG
;			CML_FLAGS._COMLINE_ERROR
;Ausgangsparameter:     CML_FLAGS._CMD_MODE_FLAG
;			CML_FLAGS._PUT_DATA_FLAG
;			CML_FLAGS._GET_DATA_FLAG
;			CML_FLAGS._COMLINE_ERROR
;ver�nderte Register:	CCR, A, X, Y
;-----------------------------------------------------------------------------
					;
CHK_CMD_STATUS:
	BRSET	CML_FLAGS,_PUT_DATA_FLAG,CHK_CMD_STATUS1
	BRSET	CML_FLAGS,_GET_DATA_FLAG,CHK_CMD_STATUS1
	BCLR	CML_FLAGS,_CMD_MODE_FLAG;
					;
CHK_CMD_STATUS1:
	BRCLR	CML_FLAGS,_COMLINE_ERROR,CHK_CMD_STATUS9
	LDAA	CML_FLAGS		;wenn COMLINE_ERROR,
	ANDA	#_COMLINE_FLAG		;dann
	PSHA				;  CML_FLAGS._COMLINE_FLAG retten
	JSR	COMLINE_RESET		;  Kommandoausf�hrung abbrechen
	PULA				;  CML_FLAGS._COMLINE_FLAG restaurieren
					;
CHK_CMD_STATUS9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
