 	include	"s12ga_240.sfr"
	include	"s12ga_Switches.sfr"
	title	"tg4Reset  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg4Reset.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	07.01.2015
;
;Description:	Das Programmmodul RESET wird einmalig unmittelbar nach dem
;		Einschalten durchlaufen. Es führt die Grundinitialisierungen
;		aller Peripheriekonponenten aus.
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3Reset.asm
;
;20.01.2011	Version 2.50
;20.01.2011	Prüfsummen durch CRC16-Prüfcode ersetzt
;		CRC-16/CCITT-FALSE durch CRC-16/CCITT (KERMIT) ersetzt
;27.11.2007	Version 2.00
;27.11.2007	Ergänzungen für LIN-Empfangsmultiplexer
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;
;08.02.2006	Programmspeicher-, Datenspeicher- und CPU-Test hinzugefügt
;09.12.2005
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	CAN_RESET		;Code

	xref	COMLINE_RESET		;Code
	xref	CREATE_KERMIT		;Code
	xref	DISABLE_INTERRUPTS	;Code
	xref	DIV3232U		;Code
	xref	FTMRC_COPY		;Code
	xref	FTMRC_FLASH		;Code
	xref	FTMRC_RESET		;Code
	xref	FTMRC_WRITE8		;Code
	xref	FTMRC_WRITE16		;Code
	xref	LIN_START		;Code
	xref	MPL_RESET		;Code
	xref	MUX_RESET		;Code
	xref	PWS_RESET		;Code
	xref	PWS_UPDATE		;Code
	xref	SDT_RESET		;Code
	xref	SDT_READ_CONFIG		;Code
	xref	SDT_WRITE_CONFIG	;Code
	xref	VERIFY_KERMIT		;Code
	xref	WATCHDOG_INIT		;Code
					;
	xref	B_FLASH			;roData
	xref	CONFIG_TBL		;roData
					;
	xref	BOARD_ID		;bssData
	xref	HW_IDENT		;bssData
	xref	E_CAN0_CONFIG_TBL	;bssData
	xref	E_CONFIG_TBL		;bssData
	xref	E_CONFIG_CRC		;bssData
	xref	E_CRC_CODE		;bssData
	xref	E_CRC_KEY		;bssData
					;
	xref	B_RAM			;Data
	xref	CAN_BUF			;Data
	xref	LIN_ADC_ADDR		;Data
	xref	LIN_ADC_BUF		;Data
	xref	MEAN_S1_BUF		;Data
					;
	xref	bt_TIREGUARD4		;Number
	xref	CAN_BUF_CT		;Number
	xref.b	CONFIG_TBL_CT		;Number
	xref	CODE_SIZE		;Number
	xref	DATA_SIZE		;Number
	xref.b	MEAN_S1_BUF_CT		;Number
	xref	TICK_REL		;Number
					;
	xref.b	C_SYNR			;Number
	xref.b	C_REFDIV		;Number
	xref.b	C_POSTDIV		;Number
	xref.b	C_PTPSR			;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	RESET			;Code
					;
.text:		section
					;
;==============================================================================
;RESET Modul-Einsprung
;==============================================================================
					;
RESET:
	SEI				;Interrupts sperren
	JSR	RESET_CLOCK		;
	JSR	RESET_PORTS		;
	JSR	RESET_FLASH		;
	JSR	CHK_CODE_MEM		;
	BNE	RESET1			;
	JSR	CHK_DATA_MEM		;
	BNE	RESET1			;
	JSR	CHK_CPU			;
	BNE	RESET1			;
	JSR	RESET_COMLINES		;
	JSR	RESET_CAN		;
	JSR	RESET_LIN		;
	JSR	RESET_SENSORS		;
	JSR	RESET_POWER		;
	JSR	RESET_MUX		;
	JSR	RESET_PARAMS		;
	JSR	RESET_INTERRUPTS	;
	JSR	PREPARE_SYSTEM		;
	CLI				;globale Interruptfreigabe
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
RESET1:
	BRA	RESET1			;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
;CHK_CODE_MEM bildet den CRC16-Prüfcode des Programmspeichers.
;Wenn der Erkennungsschlüssel nocht nicht vorhanden ist, wird der CRC16-Prüfcode
;neu gebildet und zusammen mit dem Erkennungsschlüssel im EEPROM abgelegt.
;Das ist nach dem erstmaligen Programmstart nach der Neuprogrammierung der Fall.
;Ansonsten wird nur der Prüfcode neu gebildet und mit dem im EEPROM gespeicherten
;verglichen.
;Eingangsparameter:	E_CRC_KEY
;			E_CRC_CODE
;Ausgangsparameter:	E_CRC_KEY
;			E_CRC_CODE
;			A		0	= ok
;					<> 0	= Programmcode inkonsistent
;veränderte Register:	CCR, B, X, Y, R[0..11]
;------------------------------------------------------------------------------
					;
CRC_KEY:	dc.l	55AA9669h	;
					;
CRC_KEY_CNT:	equ	(* - CRC_KEY)
					;
CHK_CODE_MEM:
	LDD	E_CRC_KEY+0		;
	CPD	CRC_KEY+0		;
	BNE	CHK_CODE_MEM1		;
	LDD	E_CRC_KEY+2		;
	CPD	CRC_KEY+2		;
	BEQ	CHK_CODE_MEM2		;wenn E_CRC_KEY noch nicht programmiert,
					;
CHK_CODE_MEM1:
	LDX	#B_FLASH		;dann
	MOVW	#CODE_SIZE,R2		;
	JSR	CREATE_KERMIT		;  CRC-Code neu berechnen
	MOVW	#E_CRC_CODE,R6		;
	JSR	FTMRC_WRITE16		;  und im EEPROM speichern
	MOVW	#CRC_KEY,R4		;
	MOVW	#E_CRC_KEY,R6		;
	MOVB	#CRC_KEY_CNT,R3		;
	JSR	FTMRC_COPY		;  Erkennungsschlüssel im EEPROM speichern
	JSR	FTMRC_FLASH		;
					;
CHK_CODE_MEM2:
	LDX	#B_FLASH		;
	MOVW	#CODE_SIZE,R2		;
	JSR	CREATE_KERMIT		;
	MOVW	E_CRC_CODE,R0		;CRC-Code verifizieren
	JSR	VERIFY_KERMIT		;Prüfungsergebnis wird in A geliefert
	RTS				;
					;
;------------------------------------------------------------------------------
;CHK_DATA_MEM prüft den Schreib-/Lesespeicher der CPU auf Funktionsfähigkeit.
;Die Prüfung verändert den Speicherinhalt nicht.
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0	= ok
;					<> 0	= Fehler im RAM-Speicher
;veränderte Register:	CCR, B, X, Y, R0
;------------------------------------------------------------------------------
					;
CHK_DATA_MEM:
	LDX	#B_RAM			;
	LDY	#DATA_SIZE		;Datenspeicher Bytezähler
					;
CHK_DATA_MEM1:
	LDAA	0,X			;Speicherplatzinhalt lesen
	TAB				;und merken
	COMA				;Wert complementieren
	STAA	0,X			;und in Speicherplatz schreiben
	LDAA	#0FFh			;Datenbus umladen
	LDAA	0,X			;Speicherplatzinhalt lesen
	STAA	R0			;und in Register R0 ablegen
	TBA				;
	EORA	R0			;neuer Wert XOR originaler Wert
	CMPA	#0FFh			;
	BNE	CHK_DATA_MEM8		;wenn ok,
	STAB	0,X			;dann
	INX				;  weiter, bis gesamter RAM-Speicher geprüft
	DBNE	Y,CHK_DATA_MEM1		;
	CLRA				;
	BRA	CHK_DATA_MEM9		;  ok, mit A = 0 zurück
					;
CHK_DATA_MEM8:
	LDAA	#0FFh			;sonst
					;  Fehler passiert
CHK_DATA_MEM9:
	RTS				;
					;
;------------------------------------------------------------------------------
;CHK_CPU prüft die Funktion der CPU. Hierzu wird eine 32/32 bit Division
;durchgeführt und das Ergebnis auf Richtigkeit untersucht.
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0	= ok
;					<> 0	= CPU-Fehler
;veränderte Register:	CCR, B, X, Y, R[0..7,20..23]
;------------------------------------------------------------------------------
					;
CHK_CPU:
	MOVW	#00AAh,R0		;Dividend = AA55AA
	MOVW	#55AAh,R2		;
	MOVW	#0055h,R4		;Divisor = 552AD5
	MOVW	#2AD5h,R6		;
	JSR	DIV3232U		;
	LDD	R4			;
	CPD	#0			;
	BNE	CHK_CPU8		;
	LDD	R6			;
	CPD	#0			;
	BNE	CHK_CPU8		;wenn Rest = 0,
	LDD	R0			;
	CPD	#0			;
	BNE	CHK_CPU8		;
	LDD	R2			;
	CPD	#2			;
	BNE	CHK_CPU8		;und Ergebnis = 2,
	CLRA				;dann
	BRA	CHK_CPU9		;  ok, mit A = 0 zurück
					;
CHK_CPU8:
	LDAA	#0FFh			;sonst
					;  Fehler passiert
CHK_CPU9:
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_CLOCK stellt die PLL für den gewünschten Bustakt ein und schaltet den
;Takt von direktem Oszillatortakt auf PLL-Takt um.
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
RESET_CLOCK:
	MOVB	#26h,CPMUPROT		;_PROT rücksetzen
					;
	MOVB	#10000000b,CPMUCLKS	;Bustakt auf PLL-Takt umschalten
	MOVB	#10000000b,CPMUOSC	;Externen Oszillator einschalten
					;
	MOVB	#C_SYNR,SYNR		;PLL_CLK = OSC_CLK * (SYNR+1) / (REFDV+1)
	MOVB	#C_REFDIV,REFDIV	;und warten, bis PLL eingeschwungen ist
	MOVB	#C_POSTDIV,POSTDIV	;
					;
RESET_CLOCK1:
	BRCLR	CPMUFLG,_LOCK,RESET_CLOCK1
					;
	MOVB	#0,CPMUPROT		;_PROT setzen
					;
;------------------------------------------------------------------------------
					;
	MOVB	#C_PTPSR,PTPSR		;Precision-Timer Zähltakt-Vorteiler
	MOVB	#10000000b,TIOS		;Timer-Kanal 7 im Output Compare Mode betreiben
	MOVB	#10000000b,TIE		;Compare Interrupt 7 Enable
	MOVB	#11111111b,OCPD		;alle Timer-Kanäle von Output-Pins trennen
					;
	MOVB	#10001000b,TSCR1	;Precision-Timer starten
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_PORTS bringt die MCU-Ports in Grundstellung.
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
RESET_PORTS:
	MOVB	#11111111b,PUCR		;
	MOVB	#11000000b,ECLKCTL	;disable ECLK
	MOVB	#00000011b,PKGCR	;48 LQFP Package
	MOVB	#00000000b,PRR0		;
	MOVB	#00000000b,PRR1		;
					;Port A:
	MOVB	#00000000b,DDRA		;bit.[0..7]	In: - unavailable -
	MOVB	#00000000b,PORTA	;
					;Port B:
	MOVB	#00000000b,DDRB		;bit.[0..7]	In: - unavailable -
	MOVB	#00000000b,PORTB	;
					;Port E:
	MOVB	#00010000b,DDRE		;bit.[0..1]	In: EXTAL, XTAL
	;				;bit.[2..7]	In: - unavailable -
	MOVB	#00000000b,PORTE	;
					;Port T
	MOVB	#00100100b,DDRT		;bit.[0..1]	In: XIRQ#, IRQ#
	;				;bit.[2]	Out: MC33879._CE# = 1
	;				;bit.[3..4]	In: - not connected -
	;				;bit.[5]	Out: Working = 0
	;				;bit.[6..7]	In: - unavailable -
	MOVB	#11111111b,PERT		;
	MOVB	#00000000b,PPST		;
	MOVB	#00000100b,PTT		;
					;Port S:
	MOVB	#11001010b,DDRS		;bit.[0]	In: SCI0._RXD
	;				;bit.[1]	Out: SCI0._TXD
	;				;bit.[2]	In: SCI1._RXD
	;				;bit.[3]	Out: SCI1._TXD, WARNLAMP = 1
	;				;bit.[4]	In: SPI0._MISO
	;				;bit.[5]	In: - not connected -
	;				;bit.[6..7]	Out: SPI0._MOSI, _SCK
	MOVB	#11111111b,PERS		;
	MOVB	#00000000b,PPSS		;
	MOVB	#00000000b,WOMS		;
	MOVB	#11001010b,PTS		;
					;Port M:
	MOVB	#00000010b,DDRM		;bit.[0]	In: MSCAN0.RxD
	;				;bit.[1]	Out: MSCAN0.TxD
	;				;bit.[2..7]	In: - unavailable -
	MOVB	#11111111b,PERM		;
	MOVB	#00000000b,PPSM		;
	MOVB	#00000000b,WOMM		;
	MOVB	#00000010b,PTM		;
					;Port P:
	MOVB	#00111111b,DDRP		;bit.[0..1]	Out: LIN RX Multiplexer = 0 0
	;				;bit.[2]	Out: DS1722._SERMODE = 1 (SPI)
	;				;bit.[3]	Out: DS1722._CE = 0
	;				;bit.[4]	Out: MPL115A1._CE# = 1
	;				;bit.[5]	Out: MPL115A1._SHDN# = 1
	;				;bit.[6..7]	In: - unavailable -
	MOVB	#11111111b,PERP		;
	MOVB	#00000000b,PPSP		;
	MOVB	#00000000b,PIEP		;
	MOVB	#11111111b,PIFP		;
	MOVB	#00110100b,PTP		;
					;Port J:
	MOVB	#00000101b,DDRJ		;bit.[0]	Out: CAN_SW: 0 = open
	;				;bit.[1..2]	In: - not connected -
	;				;bit.[3]	Out: LIN_EN: 1 = enabled
	;				;bit.[4..7]	In: - unavailable -
	MOVB	#11111111b,PERJ		;
	MOVB	#00000000b,PPSJ		;
	MOVB	#00000000b,PIEJ		;
	MOVB	#11111111b,PIFJ		;
	MOVB	#00000100b,PTJ		;
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_FLASH bringt die EEPROM-Speicher Programmierfunktion in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
RESET_FLASH:
	JSR	FTMRC_RESET		;EEPROM Speicher Programmierfunktion in Grundstellung
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_CAN konfiguriert das CAN-Modul MSCAN0.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y, R[0,4..5]
;------------------------------------------------------------------------------
					;
RESET_CAN:
	MOVB	#0,R0			;Index = 0: MSCAN0
	MOVW	#E_CAN0_CONFIG_TBL,R4	;
	JSR	CAN_RESET		;MSCAN0 in Grundstellung
					;
	LDY	#CAN_BUF		;
	CLRA				;
	LDX	#CAN_BUF_CT		;
RESET_CAN1:
	STAA	1,Y+			;CAN-Empfangsregister auf Null setzen
	DBNE	X,RESET_CAN1		;
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_LIN konfiguriert und startet den LIN-Master.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, R[0..2]
;------------------------------------------------------------------------------
					;
RESET_LIN:
	JSR	LIN_START		;LIN-Master in Grundstellung
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_COMLINES konfiguriert die serielle Kommunikationsschnittstelle
;SCI0.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A
;------------------------------------------------------------------------------
					;
RESET_COMLINES:
	JSR	COMLINE_RESET		;serielle PC-Schnittstelle in Grundstellung
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_SENSORS konfiguriert Sensor-Schnittstellen.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, Y, R[0,3]
;------------------------------------------------------------------------------
					;
RESET_SENSORS:
	JSR	SDT_RESET		;SPI-Schnittstelle SPI0 in Grundstellung
	JSR	SDT_READ_CONFIG		;DS1722 Thermometer
	MOVB	#11101000b,R0		;12-bit Auflösung, kontinuierliche Messungen
	JSR	SDT_WRITE_CONFIG	;
					;
	JSR	MPL_RESET		;MPL115A1 Drucksensor
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_POWER konfiguriert die serielle Lasttreiber-Schnittstelle.
;
;Eingangsparameter:	R0/R1
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A
;------------------------------------------------------------------------------
					;
RESET_POWER:
	JSR	PWS_RESET		;3-Draht Schnittstelle SPI0 in Grundstellung
					;
	MOVW	#0FF00h,R0		;
	JSR	PWS_UPDATE		;
	MOVW	#0FF00h,R0		;
	JSR	PWS_UPDATE		;alle Ausgänge sperren
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_MUX konfiguriert die serielle Lasttreiber-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, Y
;------------------------------------------------------------------------------
					;
RESET_MUX:
	JSR	MUX_RESET		;LIN-Empfangsmultiplexer in Grundstellung
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_PARAMS prüft die Parameter im EEPROM auf Konsistenz. Wenn die Parameter
;ungültig sind, werden Standardwerte aus dem Flash-EPROM in das Parameter-EEPROM
;geschrieben.
;
;Eingangsparameter:	Prüfsumme im EEPROM
;Ausgangsparameter:	EEPROM Daten
;veränderte Register:	CCR, A, B, X, Y, R[0..13]
;------------------------------------------------------------------------------
					;
RESET_PARAMS:
					;
;------------------------------------------------------------------------------
;1. Teil: Allgemeine Konfiguration
					;
	LDX	#E_CONFIG_TBL		;Zeiger auf Parameter
	MOVW	#CONFIG_TBL_CT,R2	;Anzahl Bytes
	JSR	CREATE_KERMIT		;
	MOVW	E_CONFIG_CRC,R0		;originaler Prüfcode
	JSR	VERIFY_KERMIT		;wenn Prüfcode nicht in Ordnung,
	BEQ	RESET_PARAMS2		;dann
					;
	MOVW	#CONFIG_TBL,R4		;  Quelladresse
	MOVW	#E_CONFIG_TBL,R6	;  Zieladresse
	MOVW	#CONFIG_TBL_CT,R2	;  Anzahl Bytes
RESET_PARAMS11:
	JSR	FTMRC_COPY		;  Urkonfiguration schreiben
	TST	R2			;
	BEQ	RESET_PARAMS12		;
	DEC	R2			;
	BRA	RESET_PARAMS11		;
					;
RESET_PARAMS12:
	JSR	FTMRC_FLASH		;
					;
	LDX	#E_CONFIG_TBL		;  Prüfcode der programmierbaren Werte
	MOVW	#CONFIG_TBL_CT,R2	;
	JSR	CREATE_KERMIT		;  neu berechnen
	MOVW	#E_CONFIG_CRC,R6	;
	JSR	FTMRC_WRITE16		;  und schreiben
	JSR	FTMRC_FLASH		;  EEPROM programmieren
					;
;------------------------------------------------------------------------------
;2. Teil: Hardware Identcode
					;
RESET_PARAMS2:
	LDD	HW_IDENT		;
	CPD	#bt_TIREGUARD4		;wenn HW_IDENT nicht korrekt,
	BEQ	RESET_PARAMS3		;
					;
RESET_PARAMS21:
	MOVW	#bt_TIREGUARD4,R0	;dann
	MOVW	#BOARD_ID,R6		;  Board-Type eintragen
	JSR	FTMRC_WRITE16		;
					;
RESET_PARAMS3:
	JSR	FTMRC_FLASH		;ggf. EEPROM neu programmieren
	RTS				;
					;
;------------------------------------------------------------------------------
;RESET_INTERRUPTS setzt das Interrupt-System auf Anfangswerte.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	keine
;------------------------------------------------------------------------------
					;
RESET_INTERRUPTS:
	JSR	DISABLE_INTERRUPTS	;nicht benutzte Interrupts sperren
	RTS				;
					;
;------------------------------------------------------------------------------
;PREPARE_SYSTEM setzt einige weitere Systemvariablen auf Anfangswerte.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, X, Y
;------------------------------------------------------------------------------
					;
PREPARE_SYSTEM:
	LDY	#MEAN_S1_BUF		;
	LDAA	#0			;
	LDX	#MEAN_S1_BUF_CT		;
PREPARE_SYSTEM1:
	STAA	1,Y+			;Mittelwertbildungs-Vorgeschichtswerte
	DBNE	X,PREPARE_SYSTEM1	;auf Null setzen
	JSR	WATCHDOG_INIT		;
					;
	LDD	#LIN_ADC_BUF		;Adresse der LIN-Antennen Störpegelwerte
	STD	LIN_ADC_ADDR		;merken
					;
	MOVW	#0,TCNT			;Timer auf 0 setzen
	MOVW	#TICK_REL,TC7		;Ticker Reloadwert laden
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
