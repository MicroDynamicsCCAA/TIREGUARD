	include	"s12ga_240.sfr"
	include	"s12ga_COMLINE.sfr"
	title	"s12ga_COMLINE  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_COMLINE.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	03.10.2015
;
;Description:	Funktionen der Programmier-Schnittstelle
;------------------------------------------------------------------------------
;Revision History:	Original Version  01.05
;
;04.10.2015	Änderung in D_CMD für Konfigurationen > 256 Bytes
;
;29.11.2014	Anpassung an MC9S12GA240
;		Herkunft: s12p_COMLINE.asm
;
;24.03.2013	Korrektur in COMLINE_TIMEOUTS
;
;24.04.2010	Diverse Korrekturen und Erweiterungen
;
;11.05.2009	CONFIG_TBL_CNT in CONFIG_TBL_CT umbenannt
;28.04.2009	Anpassung an MS9S12P128
;
;24.11.2006	Einbindung der externen (Soft)Uart-Funktionen SCI_???
;20.11.2006	Parameterspeicher im FLASH-Speicher
;08.11.2006	Anpassung an MC9S12C128
;
;03.04.2006	in COMLINE_RESET Sendeleitung stets deaktivieren
;		in O_CMD Wartezeit verlängert
;		Zeitgrenzen jetzt in Abhängigkeit von BUS_CLK setzen
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
;					;
;Anwendungsprogramm			;
 if fE_CMD_CALLBACK
	xref	COMLINE_EXECUTE		;Code
 endif
 if fV_CMD_CALLBACK
	xref	V_CMD_EXECUTE		;Code
 endif
;					;
;s12ga_CRC.asm				;
	xref	CREATE_KERMIT		;Code
	xref	CREATE_X25		;Code
;					;
;s12ga_FTMRC.asm			;
	xref	FTMRC_COPY		;Code
	xref	FTMRC_FLASH		;Code
	xref	FTMRC_WRITE8		;Code
	xref	FTMRC_WRITE16		;Code
;					;
;s12ga_Uart_?.asm			;
	xref	SCI_READ8		;Code
	xref	SCI_RESET		;Code
	xref	SCI_TX_DISABLE		;Code
	xref	SCI_TX_ENABLE		;Code
	xref	SCI_WRITE8		;Code
					;
	xref	CONFIG_TBL		;roData
 					;
	xref	E_CONFIG_TBL		;bssData
	xref	E_CONFIG_CRC		;bssData
					;
	xref	B_EEPROM		;Data
	xref	T_EEPROM		;Data
	xref	B_RAM			;Data
	xref	T_RAM			;Data
					;
	xref	BUS_CLK			;Number
	xref.b	CONFIG_TBL_CT		;Number
					;
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
_COMLINE_ERROR:	equ	bit2		;temporärer Kommunikationsfehler
_CMD_MODE_FLAG:	equ	bit3		;1, wenn Kommando aktiv
_GET_DATA_FLAG:	equ	bit4		;1, wenn Datenempfang aktiv
_PUT_DATA_FLAG:	equ	bit5		;1, wenn Datenausgabe aktiv
_COMLINE_FLAG:	equ	bit6		;1, wenn RS232-Kommunikation aktiv
_COMLINE_TRIG:	equ	bit7		;Startflag für die RS232-Kommunikation aktiv
					;
TX_BUFFER:	ds.b	1		;DATA8: Ausgabebuffer
RX_BUFFER:	ds.b	1		;DATA8: Empfangsbuffer
					;
		even
TX_TIMEOUT:	ds.w	1		;DATA16: Zeitzähler für Sende-Echo
RX_TIMEOUT:	ds.w	1		;DATA16: Zeitzähler für Datenempfang
IO_PTR:		ds.w	1		;DATA16: Zeiger für RS232 Kommandos
IO_CTR:		ds.w	1		;DATA16: Bytezähler für RS232 Kommandos
					;
IO_DATA_PTR:	ds.w	1		;DATA16: Zeiger für RS232 Kommandos
IO_DATA_CTR:	ds.w	1		;DATA16: Bytezähler für RS232 Kommandos
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
;veraenderte Register:	CCR, A, X, Y
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
;Public: COMLINE_TIMEOUTS prüft den RS232-Sende- und RS232-Empfangskanal auf
;Wartezeitüberschreitung.
;
;Eingangsparameter:	RX_TIMEOUT
;			TX_TIMEOUT
;Ausgangsparameter:	RX_TIMEOUT
;			TX_TIMEOUT
;			CML_FLAGS._TX_FLAG
;			CML_FLAGS._COMLINE_ERROR
;veränderte Register:	CCR, A, B
;-----------------------------------------------------------------------------
					;
COMLINE_TIMEOUTS:
	BRCLR	CML_FLAGS,_CMD_MODE_FLAG,COMLINE_TIMEOUTS8
					;wenn CML_FLAGS._CMD_MODE_FLAG
					;dann
	BRCLR	CML_FLAGS,_GET_DATA_FLAG,COMLINE_TIMEOUTS1
	LDD	RX_TIMEOUT		;  wenn Daten Empfangen aktiv,
	BEQ	COMLINE_TIMEOUTS1	;
	SUBD	#1			;  dann
	STD	RX_TIMEOUT		;    wenn RX_TIMEOUT_abgelaufen,
	BNE	COMLINE_TIMEOUTS1	;    dann
	BSET	CML_FLAGS,_COMLINE_ERROR;      _COMLINE_ERROR setzen
					;
COMLINE_TIMEOUTS1:
	BRCLR	CML_FLAGS,_PUT_DATA_FLAG,COMLINE_TIMEOUTS2
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
	LDD	#RX_TIMEOUT_CT		;sonst
	STD	RX_TIMEOUT		;  RX_TIMEOUT auf Startwert
	LDD	#TX_TIMEOUT_CT
	STD	TX_TIMEOUT		;  TX_TIMEOUT auf Startwert
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
;veraenderte Register:	CCR, A
;-----------------------------------------------------------------------------
					;
COMLINE_INPUT:
	JSR	SCI_READ8		;wenn neues Zeichen da,
	BCS	COMLINE_INPUT3		;dann
	STAA	RX_BUFFER		;  empfangenes Zeichen lesen
	BRSET	CML_FLAGS,_TX_FLAG,COMLINE_INPUT1
	BSET	CML_FLAGS,_RX_FLAG	;wenn Echoflag rückgesetzt,
	JMP	COMLINE_INPUT3		;dann RX_FLAG setzen
COMLINE_INPUT1:
	LDAA	TX_BUFFER		;
	CMPA	RX_BUFFER		;wenn empfangenes <> gesendetem Zeichen,
	BEQ	COMLINE_INPUT2		;dann
	BSET	CML_FLAGS,_COMLINE_ERROR;  Fehler bei der Datenübertragung
COMLINE_INPUT2:
	BCLR	CML_FLAGS,_TX_FLAG	;Echoflag rücksetzen
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
;veraenderte Register:	CCR, A
;-----------------------------------------------------------------------------
					;
COMLINE_REACTION:
	BRSET	CML_FLAGS,_CMD_MODE_FLAG,COMLINE_REACTION1
	BRSET	CML_FLAGS,_RX_FLAG,COMLINE_REACTION2
	JMP	COMLINE_REACTION3	;
					;
COMLINE_REACTION1:
	JSR	CMD_EXECUTE		;
	JMP	COMLINE_REACTION3	;Kommando bearbeiten
					;
COMLINE_REACTION2:
	JSR	CMD_DECODE		;Kommandocode entschlüsseln
					;
COMLINE_REACTION3:
	RTS				;
					;
;-----------------------------------------------------------------------------
;CMD_DECODE
;
;Eingangsparameter:
;Ausgangsparameter:
;veraenderte Register:	CCR, A, B, X
;-----------------------------------------------------------------------------
					;
CMD_DECODE:
	LDAB	RX_BUFFER		;alle Kommandos mit Ausnahme von OPEN
	CMPB	#'O'			;werden nur bei gesetztem _COMLINE_FLAG
	BEQ	CMD_DECODE0		;ausgeführt
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
CMD_DECODE2:
	BSET	CML_FLAGS,_CMD_MODE_FLAG;
					;
CMD_DECODE3:
	BCLR	CML_FLAGS,_RX_FLAG	;
	RTS				;
					;
CMD_TBL:
	dc.w	NO_CMD			;A	SelectSector
	dc.w	NO_CMD			;B	ReadSector
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
	dc.w	NO_CMD			;X	SetCalibrationCRC
	dc.w	NO_CMD			;Y
	dc.w	NO_CMD			;Z
					;
NO_CMD:
	JMP	CMD_DECODE3		;
					;
;-----------------------------------------------------------------------------
;C_CMD	schaltet die TxD-Leitung auf General Purpose IO um.
;-----------------------------------------------------------------------------
					;
C_CMD:
	JSR	SCI_TX_DISABLE		;TxD-Leitung abschalten
	BCLR	CML_FLAGS,_COMLINE_FLAG	;COMLINE_FLAG rücksetzen
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
	MOVW	#CONFIG_TBL_CT,R2	;Anzahl Bytes
D_CMD1:
	JSR	FTMRC_COPY		;Konfiguration schreiben
	TST	R2			;
	BEQ	D_CMD2			;
	DEC	R2			;
	BRA	D_CMD1			;
					;
D_CMD2:
;end
;
					;
	LDX	#E_CONFIG_TBL		;Prüfcode der programmierbaren Werte
	MOVW	#CONFIG_TBL_CT,R2	;
	JSR	CREATE_KERMIT		;neu berechnen
	MOVW	#E_CONFIG_CRC,R6	;
	JSR	FTMRC_WRITE16		;und schreiben
	JSR	FTMRC_FLASH		;EEPROM neu programmieren
					;
	LDAA	#0-'D'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;E_CMD	startet nach dem Empfang von Kommandocode und Parametern die
;Ausführung eines Kommandos.
;-----------------------------------------------------------------------------
					;
E_CMD:

 if fE_CMD_CALLBACK = _true
	JSR	COMLINE_EXECUTE		;Kommando ausführen...
 endif
					;
	LDAA	#0-'E'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;O_CMD	schaltet die TxD-Leitung auf die RS232-Kommunikation um.
;
;Nur dieses Kommando setzt das COMLINE_FLAG.
;Alle sonstigen Kommandos werden bei nicht gesetztem COMLINE_FLAG
;vollständig ignoriert.
;-----------------------------------------------------------------------------
					;
O_CMD_STR:
	dc.b	0FFh, 0-'O'
O_CMD_CT:	equ	(* - O_CMD_STR)
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
	MOVW	#O_CMD_CT-1,IO_CTR	;Anzahl Bytes - 1
	BSET	CML_FLAGS,_PUT_DATA_FLAG;Daten senden
	JMP	CMD_DECODE2		;
					;
;-----------------------------------------------------------------------------
;P_CMD	empfängt die Startadresse für ein folgendes Schreib-/Lesekommando.
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
;S_CMD	empfängt die Byteanzahl für ein folgendes Schreib-/Lesekommando.
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
;V_CMD	aktualisiert den Prüfcode der programmierbaren Einstellungen.
;-----------------------------------------------------------------------------
					;
V_CMD:

 if fV_CMD_CALLBACK == _true
	JSR	V_CMD_EXECUTE		;Aufruf ergänzender Funktionen vor
					;der Prüfcodeberechnung
 endif

	LDX	#E_CONFIG_TBL		;Prüfcode der programmierbaren Werte
	MOVW	#CONFIG_TBL_CT,R2	;
	JSR	CREATE_KERMIT		;neu berechnen
	MOVW	#E_CONFIG_CRC,R6	;
	JSR	FTMRC_WRITE16		;und schreiben
	JSR	FTMRC_FLASH		;D-Flash EEPROM neu programmieren
					;
	LDAA	#0-'V'			;
	JMP	CMD_DECODE1		;
					;
;-----------------------------------------------------------------------------
;W_CMD	empfängt Daten vom PC und schreibt sie.
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
;-----------------------------------------------------------------------------
;CMD_EXECUTE prüft, welche Aktion innerhalb eines RS232-Kommandos als
;nächstes ausgeführt werden muss und verzweigt entsprechend.
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
;veraenderte Register:	CCR, A, B, X, Y
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
	JSR	CHK_CMD_STATUS		;prüfen, ob Kommando fertig bearbeitet
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
;veränderte Register:	CCR, A, B, X
;-----------------------------------------------------------------------------
					;
PUT_DATA_HANDLE:
	BRCLR	CML_FLAGS,_TX_FLAG,PUT_DATA_HANDLE1
	JMP	PUT_DATA_HANDLE9	;wenn _TX_FLAG rückgesetzt
PUT_DATA_HANDLE1:
	BRCLR	CML_FLAGS,_COMLINE_ERROR,PUT_DATA_HANDLE2
	JMP	PUT_DATA_HANDLE9	;und _COMLINE_ERROR rückgesetzt
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
	STD	IO_CTR			;  wenn alle Zeichen übertragen,
	BCC	PUT_DATA_HANDLE9	;  dann
	BCLR	CML_FLAGS,_PUT_DATA_FLAG;    Übertragung beenden
	BRCLR	CML_FLAGS,_COMLINE_TRIG,PUT_DATA_HANDLE9
	BSET	CML_FLAGS,_COMLINE_FLAG	;    wenn _COMLINE_TRIG gesetzt,
	BCLR	CML_FLAGS,_COMLINE_TRIG	;    dann _COMLINE_FLAG setzen
					;
PUT_DATA_HANDLE9:
	RTS				;
					;
;-----------------------------------------------------------------------------
;GET_DATA_HANDLE empfängt ein Zeichen von der RS232-Schnittstelle und
;schreibt es ins D-Flash EEPROM oder RAM.
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
;veränderte Register:	CCR, A, B, Y, R[0,6..7]
;-----------------------------------------------------------------------------
					;
GET_DATA_HANDLE:
	BRSET	CML_FLAGS,_RX_FLAG,GET_DATA_HANDLE1
	JMP	GET_DATA_HANDLE9	;wenn _RX_FLAG gesetzt
GET_DATA_HANDLE1:
	BRCLR	CML_FLAGS,_COMLINE_ERROR,GET_DATA_HANDLE2
	JMP	GET_DATA_HANDLE9	;und _COMLINE_ERROR rückgesetzt
					;dann
GET_DATA_HANDLE2:
	LDY	IO_PTR			;
	CPY	#B_EEPROM		;
	BLO	GET_DATA_HANDLE2a	;
	CPY	#T_EEPROM		;
	BHI	GET_DATA_HANDLE2a	;
	STY	R6			;  wenn Zieladresse im D-Flash EEPROM-Bereich,
	MOVB	RX_BUFFER,R0		;  dann
	JSR	FTMRC_WRITE8		;    Zeichen ins D-Flash EEPROM programmieren
	LDAA	RX_BUFFER		;
	JMP	GET_DATA_HANDLE2c	;
					;
GET_DATA_HANDLE2a:
	LDY	IO_PTR			;
	CPY	#B_RAM			;
	BLO	GET_DATA_HANDLE2b	;
	CPY	#T_RAM			;
	BHI	GET_DATA_HANDLE2b	;  sonst wenn Zieladresse im RAM-Bereich,
	LDAA	RX_BUFFER		;  dann
	STAA	0,Y			;    Zeichen im RAM ablegen
	JMP	GET_DATA_HANDLE2c	;
					;
GET_DATA_HANDLE2b:
	LDAA	RX_BUFFER		;  sonst Schreiben nicht möglich!
	COMA				;  Echo invertieren
	STAA	RX_BUFFER		;  und zwischenspeichern
					;
GET_DATA_HANDLE2c:
	LDY	IO_PTR			;
	INY				;  Zeiger incrementieren
	STY	IO_PTR			;
	LDD	#RX_TIMEOUT_CT		;
	STD	RX_TIMEOUT		;  Empfangs-Timeout auf Startwert
	BCLR	CML_FLAGS,_RX_FLAG	;  _RX_FLAG rücksetzen
	LDD	IO_CTR			;
	SUBD	#1			;  Anzahl decrementieren
	STD	IO_CTR			;  wenn alle Zeichen empfangen,
	BCC	GET_DATA_HANDLE8	;  dann
	JSR	FTMRC_FLASH		;    ggf. D-Flash EEPROM neu programmieren
	BCLR	CML_FLAGS,_GET_DATA_FLAG;    Datenempfang beenden
					;
GET_DATA_HANDLE8:
	LDAA	RX_BUFFER		;
	JSR	SCI_WRITE8		;  schließlich Echo senden
					;
GET_DATA_HANDLE9:
	RTS				;
					;
;-----------------------------------------------------------------------------
;CHK_CMD_STATUS untersucht den ordnungsgemäßen Abschluss eines Kommandos
;und deaktiviert dann das _CMD_MODE_FLAG.
;
;Eingangsparameter:	CML_FLAGS._PUT_DATA_FLAG
;			CML_FLAGS._GET_DATA_FLAG
;			CML_FLAGS._COMLINE_ERROR
;Ausgangsparameter:     CML_FLAGS._CMD_MODE_FLAG
;			CML_FLAGS._PUT_DATA_FLAG
;			CML_FLAGS._GET_DATA_FLAG
;			CML_FLAGS._COMLINE_ERROR
;veränderte Register:	CCR, A, X, Y
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
	JSR	COMLINE_RESET		;  Kommandoausführung abbrechen
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
