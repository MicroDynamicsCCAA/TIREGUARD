	include	"s12ga_240.sfr"
	include	"s12ga_Switches.sfr"
	title 	"tg4Declarations  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm 	S2.805.xx/y
;------------------------------------------------------------------------------
;Module:	tg4Declarations.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	25.02.2015
;
;Description:	Deklaration der globalen Konstanten und Variablen
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;25.02.2015	Version 4.01
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3Declearations.asm
;
;12.04.2014	Version 4.0 Beta 0
;
;15.10.2013	Version 3.01
;		Korrektur in CHK_ALARM : Umgebungsluftdruck subtrahieren
;18.09.2013	Neu:	Erste Vorversion für TIREGUARD 4 auf TIREGUARD 3a Hardware
;
;02.07.2013	Version 2.60
;20.01.2011	Version 2.50
;05.07.2008	Version 2.10
;27.11.2007	Version 2.00
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;
;29.03.2006	Version 1.12
;21.02.2006	Version 1.11
;08.02.2006	Version 1.10
;11.12.2005	Version 1.00
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
 ifne fDebug
	xdef	TEST_BUF
	xdef	TEST_S1_BUF
	xdef	TEST_CHECKSUM
	xdef	TEST_CTR
	xdef	TEST_VAL
 endif

	xdef	B_FLASH			;roData
	xdef	CONFIG_TBL		;roData
	xdef	LIN_IDENTIFIER_TBL	;roData
	xdef	MSG_IDENTIFIER_TBL	;roData
	xdef	MSG_CTR_TBL		;roData
	xdef	MSG_RX_TBL		;roData
	xdef	SW_IDENT		;roData
	xdef	SW_VERSION		;roData
	xdef	T_FLASH			;roData
					;
	xdef	B_EEPROM		;bssData
	xdef	BOARD_ID		;bssData
	xdef	HW_IDENT		;bssData
	xdef	E_CRC_KEY		;bssData
	xdef	E_CRC_CODE		;bssData
	xdef	E_ANALOG_COEFF_TBL	;bssData
	xdef	E_CAN0_CONFIG_TBL	;bssData
	xdef	E_CAN_MASK		;bssData
	xdef.b	_IDENTIFIERS		;bitMask
	xdef.b	_VALUES			;bitMask
	xdef.b	_STATUS			;bitMask
	xdef.b	_DIAGNOSIS		;bitMask
	xdef	E_CONFIG_TBL		;bssData
	xdef	E_DROP_REF		;bssData
	xdef	E_DROP_PRESSURE		;bssData
	xdef	E_FUN_MODE		;bssData
	xdef.b	_BLINKING		;bitMask
	xdef.b	_CAN_CLOSED		;bitMask
	xdef.b	_USE_NOVALUE		;bitMask
	xdef	E_SENSORS_COEFF_TBL	;bssData
	xdef	E_TIRE_PRESSURE		;bssData
	xdef	E_TIRE_TEMPERATURE	;bssData
	xdef	E_TIRE_XP_REF		;bssData
	xdef	E_CONFIG_CRC		;bssData
	xdef	T_EEPROM		;bssData
					;
	xdef	BOR			;Data
	xdef	TOR			;Data
	xdef	B_RAM			;Data
	xdef	BOV			;Data
	xdef	ALARM			;Data
	xdef	ALARM_CTR		;Data
	xdef	ANALOG_BUF		;Data
	xdef	AB_V_BATTERY		;Data
	xdef	AB_V_WARNLAMP		;Data
	xdef	ANALOG_FLAGS		;Data
	xdef.b	_ADC_ERROR		;bitMask
					;
	xdef	ANALOG_RESULT_BUF	;Data
	xdef	V_BATTERY		;Data
	xdef	V_WARNLAMP		;Data
	xdef	ANALOG_S1_BUF		;Data
					;
	xdef	CAN_BUF			;Data
	xdef	CAN0_MSG0_BUF		;Data
	xdef	CAN0_MSG1_BUF		;Data
	xdef	CAN0_MSG2_BUF		;Data
	xdef	CAN0_MSG3_BUF		;Data
	xdef	CAN0_TIMEOUT_CTR	;Data
	xdef	CAN0_RX_CTR		;Data
	xdef	CHECK_WAIT_CTR		;Data
					;
	xdef	SENSORS_BUF		;Data
	xdef	SB_P_AMBIENT		;Data
	xdef	SB_T_AMBIENT		;Data
	xdef	SB_T_UNIT		;Data
	xdef	SENSORS_S1_BUF		;Data
					;
	xdef	SENSORS_RESULT_BUF	;Data
	xdef	P_AMBIENT		;Data
	xdef	P_TPMS			;Data
	xdef	T_AMBIENT		;Data
	xdef	T_UNIT			;Data
					;
	xdef	COMMUNICATE_FLAGS	;Data
	xdef.b	_LOW_XP_TRIG		;bitMask
	xdef.b	_LOW_XP_FLAG		;bitMask
	xdef.b	_CAN_RFSH_TRIG		;bitMask
					;
	xdef	DROP_ALARM		;Data
	xdef	TICK_CTR		;Data
	xdef	LOOP_FLAGS		;Data
	xdef.b	_LOOP_OV		;bitMask
	xdef.b	_LOOP_OV_CLEAR		;bitMask
	xdef.b	_LOOP_TIMEOUT		;bitMask
					;
	xdef	LAST_RX_POS		;Data
	xdef	LIN_ADC_ADDR		;Data
	xdef	LIN_RX_CTR		;Data
	xdef	MSG_RX_REC		;Data
	xdef	MSG_S1_REC		;Data
	xdef	MEAN_S1_BUF		;Data
					;
	xdef	OUTPUT_FLAGS		;Data
	xdef.b	_ALARM_TOGGLE		;bitMask
					;
	xdef	DIAG_BUF		;Data
	xdef	OUTPUT_FLAGS2		;Data
	xdef	TIRE_SENSOR_CTR_REC	;Data
	xdef	TIRE_DAT_RFSH_CTR	;Data
	xdef	TIRE_ID_RFSH_CTR	;Data
	xdef	XP			;Data
	xdef	TOV			;Data
	xdef	BOS			;Data
	xdef	TOS			;Data
	xdef	T_RAM			;Data
					;
	xdef	ALARM_CT		;Number
	xdef.b	ANALOG_CT		;Number
					;
	xdef	BUS_CLK			;Number
	xdef	BAUDRATE_REL		;Number
	xdef	BD_9600_REL		;Number
	xdef	bt_TIREGUARD4		;Number
					;
	xdef	CAN_BUF_CT		;Number
	xdef	CAN0_RX_CT		;Number
	xdef.b	CONFIG_TBL_CT		;Number
					;
	xdef	CHECK_WAIT_CT		;Number
	xdef	CODE_SIZE		;Number
	xdef	DATA_SIZE		;Number
					;
	xdef.b	SENSORS_CT		;Number
	xdef.b	TIRE_DAT_RFSH_CT	;Number
	xdef.b	TIRE_ID_RFSH_CT		;Number
	xdef	TIRE_SENSOR_CT		;Number
	xdef	MEAN_S1_BUF_CT		;Number
	xdef	LIN_RX_CT		;Number
					;
	xdef.b	oIDENTIFIER		;Number
	xdef.b	oTEMPERATURE		;Number
	xdef.b	oPRESSURE		;Number
	xdef.b	oSTATUS			;Number
					;
	xdef	DEF_NOVALUE		;Number
	xdef	RX_TIMEOUT_CT		;Number
	xdef	TX_TIMEOUT_CT		;Number
					;
	xdef	HW_IDENT_CT		;Number
	xdef	SW_IDENT_CT		;Number
	xdef	SW_VERSION_CT		;Number
	xdef	STACK_SIZE_CT		;Number
	xdef	REGS_SIZE_CT		;Number
	xdef	VAR_SIZE_CT		;Number
	xdef.b	TICK_CT			;Number
	xdef	TICK_REL		;Number
					;
	xdef.b	C_ATD_PRSC		;Number
	xdef.b	C_FDIV			;Number
	xdef.b	C_POSTDIV		;Number
	xdef.b	C_PTPSR			;Number
	xdef.b	C_REFDIV		;Number
	xdef.b	C_SYNR			;Number
					;
;//////////////////////////////////////////////////////////////////////////////
;Definition der Konstanten
;//////////////////////////////////////////////////////////////////////////////
					;
OSC_CLK:	equ	16000		;Quartztakt in kHz

 ifne fUse_PLL
BUS_CLK:	equ	24000		;Bustakt in kHz mit PLL
 else
BUS_CLK:	equ	8000		;Bustakt in kHz ohne PLL
 endif
					;
					;Zeitangaben in ms
LOOPTIME:	equ	10		;Programmlaufzeit
					;
ALARM_PERIOD:	equ	200		;Blink-Periode der Alarm-LED
TIRE_DAT_RFSH_TIME: equ	100		;Zeittakt für Daten CAN-Ausgabe
TIRE_ID_RFSH_TIME: equ	1000		;Zeittakt für Identifier CAN-Ausgabe
					;
					;Zeitangaben in Sekunden
TIRE_SENSOR_TIMEOUT: equ 30		;Radelektronik-Empfangs-Zeitgrenze
CAN_TIMEOUT:	equ	30		;CAN-Empfangs-Zeitgrenze
LIN_TIMEOUT:	equ	30		;LIN-Empfangs-Zeitgrenze
RX_TIMEOUT:	equ	3		;Zeitgrenze für Comline-Echoempfang
TX_TIMEOUT:	equ	3		;Zeitgrenze für Comline-Datenempfang
					;
oIDENTIFIER:	equ	4		;
oPRESSURE:	equ	8		;
oTEMPERATURE:	equ	9		;
oBATTERY:	equ	10		;
oSTATUS:	equ	11		;
oMOVING:	equ	13		;
					;
CHECK_WAITTIME:	equ	60		;Zeitabstand in Sekunden zwischen der
					;Prüfung der Druckwertabfälle
;------------------------------------------------------------------------------
;abgeleitete Konstanten, die nicht geändert werden sollten
;------------------------------------------------------------------------------
					;
ALARM_CT:	equ	ALARM_PERIOD / (LOOPTIME * 2)
TIRE_DAT_RFSH_CT: equ	TIRE_DAT_RFSH_TIME / LOOPTIME
TIRE_ID_RFSH_CT: equ	TIRE_ID_RFSH_TIME / LOOPTIME
TIRE_SENSOR_CT:	equ	TIRE_SENSOR_TIMEOUT * 1000 / LOOPTIME

CAN0_RX_CT:	equ	CAN_TIMEOUT * 1000 / LOOPTIME
LIN_RX_CT:	equ	LIN_TIMEOUT * 1000 / LOOPTIME
					;
RX_TIMEOUT_CT:	equ	RX_TIMEOUT * 1000 / LOOPTIME
TX_TIMEOUT_CT:	equ	TX_TIMEOUT * 1000 / LOOPTIME
					;
CHECK_WAIT_CT:	equ	CHECK_WAITTIME * 1000 / LOOPTIME
					;
;------------------------------------------------------------------------------
;C_ATD_PRSC: DATA8	vorbereitet für das ATD Control Register 4
;			ATD Clock Prescaler
;Berechnungsvorschrift:
;C_ATD_PRSC:= BUS_CLK / ATD_CLK / 2 - 1
;mit 	BUS_CLK		Bustakt in kHz
;	ATD_CLOCK	AD-Wandler Takt in kHz, max. 2 MHz
;------------------------------------------------------------------------------
					;
ATD_CLK:	equ	2000
C_ATD_PRSC:	equ	BUS_CLK / ATD_CLK / 2 - 1
					;
;------------------------------------------------------------------------------
;CLK_PRESCALER:		Bustakt Vorteilerwert
;C_PTPSR: DATA8		passend für das Precision Timer Prescaler Select Register
;------------------------------------------------------------------------------
					;
CLK_PRESCALER:	equ	BUS_CLK / 1000	;Bustakt-unabhängiger 1 MHz Zähltakt
					;
C_PTPSR:	equ	CLK_PRESCALER - 1
					;
;------------------------------------------------------------------------------
;TICKTIME:
;TICK_CT: DATA8		Anzahl der Ticks in einem Programmzyklus
;Berechnungsvorschrift:
;1. Schritt:
;TICKTIME ist so zu wählen, dass bei gegebener Programmlaufzeit LOOPTIME
;die Berechnung von TICK_CT ein Ergebnis ohne Rest liefert.
;2. Schritt:
;TICK_CT:= LOOPTIME * 1000 / TICKTIME
;mit	LOOPTIME	Programmlaufzeit in ms
;------------------------------------------------------------------------------
					;
TICKTIME:	equ	500		;
TICK_CT:	equ	LOOPTIME * 1000 / TICKTIME

;------------------------------------------------------------------------------
;TICK_REL: DATA16	Timer Startwert zur Festlegung der Programmlaufzeit
;Berechnungsvorschrift:
;TICK_REL:= BUS_CLK * TICKTIME / 1000 / CLK_PRESCALER
;mit	BUS_CLK		Bustakt in kHz
;	CLK_PRESCALER	Bustakt-Vorteiler
;	TICKTIME	Tickzeit in µs
;------------------------------------------------------------------------------
					;
TICK_REL:	equ	BUS_CLK * TICKTIME / 1000 / CLK_PRESCALER
					;
;------------------------------------------------------------------------------
;C_SYNR: DATA8		OSC_CLK Multiplikator
;C_REFDIV: DATA8	OSC_CLK Divisor
;C_POSTDIV: DATA8	VCO_CLK Divisor
;Berechnungsvorschrift:
;VCO_CLK:= OSC_CLK * (C_SYNR+1) / (REFDIV+1)
;PLL_CLK:= VCO_CLK / (POSTDIV+1)
;------------------------------------------------------------------------------
					;
 if BUS_CLK = 32000
C_SYNR:		equ	3		;BUS_CLK = 32,0 MHz @ OSC_CLK = 16,0 MHz
C_REFDIV:	equ	11000001b	;
C_POSTDIV:	equ	0		;
 endif
 if BUS_CLK = 24000
C_SYNR:		equ	2		;BUS_CLK = 24,0 MHz @ OSC_CLK = 16,0 MHz
C_REFDIV:	equ	11000001b	;
C_POSTDIV:	equ	0		;
 endif
 if BUS_CLK = 16000
C_SYNR:		equ	1		;BUS_CLK = 16,0 MHz @ OSC_CLK = 16,0 MHz
C_REFDIV:	equ	11000001b	;
C_POSTDIV:	equ	0		;
 endif
 if BUS_CLK = 12000
C_SYNR:		equ	2		;BUS_CLK = 12,0 MHz @ OSC_CLK = 16,0 MHz
C_REFDIV:	equ	11000011b	;
C_POSTDIV:	equ	0		;
 endif
 if BUS_CLK < 12000
C_SYNR:		equ	1		;BUS_CLK = 8,0 MHz @ OSC_CLK = 16,0 MHz
C_REFDIV:	equ	11000001b	;
C_POSTDIV:	equ     0		;
 endif
					;
;------------------------------------------------------------------------------
					;
 if BUS_CLK > 999
C_FDIV:		equ	(BUS_CLK / 1000) - 1
 endif
					;
;------------------------------------------------------------------------------
; Baudraten Reloadwerte für Hardware-UART
;
BD_38400_REL:	equ	BUS_CLK * 1000 / (38400 * 16)
BD_19200_REL:	equ	BUS_CLK * 1000 / (19200 * 16)
BD_14400_REL:	equ	BUS_CLK * 1000 / (14400 * 16)
BD_9600_REL:	equ	BUS_CLK * 1000 / (9600 * 16)
BD_4800_REL:	equ	BUS_CLK * 1000 / (4800 * 16)
BD_2400_REL:	equ	BUS_CLK * 1000 / (2400 * 16)
					;
;------------------------------------------------------------------------------
; Baudraten Reloadwerte für Soft-UART
;
BD_9600x4_REL:	equ	BUS_CLK * 1000 / (9600 * 4 * CLK_PRESCALER)
BD_4800x4_REL:	equ	BUS_CLK * 1000 / (4800 * 4 * CLK_PRESCALER)
BD_2400x4_REL:	equ	BUS_CLK * 1000 / (2400 * 4 * CLK_PRESCALER)
					;
;------------------------------------------------------------------------------
					;
BAUDRATE_REL:	equ	BD_9600_REL	;Baudrate = 9600 bps
					;
;------------------------------------------------------------------------------
					;
DEF_NOVALUE:	equ	0FCFCh		;
					;
;//////////////////////////////////////////////////////////////////////////////
;Definition der Speicheradressen
;//////////////////////////////////////////////////////////////////////////////
					;
B_EEPROM:	equ	00400h		;MC9S12GA240
T_EEPROM:	equ	013FFh		;
					;
B_RAM:		equ	01400h		;
T_RAM:		equ	03FFFh		;
DATA_SIZE:	equ	(T_RAM - B_RAM) + 1
					;
B_FLASH:	equ	04000h		;
T_FLASH:	equ	0FFFFh		;
CODE_SIZE:	equ	(T_FLASH - B_FLASH) + 1
					;
;//////////////////////////////////////////////////////////////////////////////
;Definition der Board-Typen
;//////////////////////////////////////////////////////////////////////////////
					;
bt_TIREGUARD4:	equ	08080h		;TIREGUARD 4
					;
;==============================================================================
;Datendefinitionen im internen Flash-EEPROM Codespeicher
;==============================================================================
					;
.rodata:	section
					;
SW_IDENT:	dc.b	"TIREGUARD 4     " ;jede Zeile umfasst 16 Zeichen
		dc.b	"Copyright ©     " ; (C) = [Alt] + 0169
		dc.b	"2005-2015,      "
		dc.b	"micro dynamics® " ; (R) = [Alt] + 0174
		dc.b	"GmbH, CCAA      "
SW_VERSION:	dc.b	"S2.804.40/B,    " ;das Komma muss(!) angefügt werden
		dc.b	"25.02.2015      "
SW_VERSION_CT:	equ	* - SW_VERSION
SW_IDENT_CT:	equ	* - SW_IDENT
					;
PARAM_ADDR:	dc.w	E_CONFIG_TBL	;Zeiger auf einstellbare Parameter
PARAM_SIZE:	dc.w    CONFIG_TBL_CT	;
					;
RESULT_ADDR:	dc.w	RESULT_BUF	;Zeiger auf Ergebnisdaten
RESULT_SIZE:	dc.w	RESULT_BUF_CT	;
					;
;==============================================================================
;
;Beginn der programmierbaren Werte
;
;==============================================================================
					;
CONFIG_TBL:
					;
;------------------------------------------------------------------------------
;FUN_MODE legt die Betriebsweise des Gerätes fest.
;
_BLINKING:	equ	bit0		;Alarm-LED	0  im Alarmfall LED statisch einschalten
					;		1  LED-Alarmblinken
_USE_NOVALUE:	equ	bit1		;XP < XP_REF	0  T = TIRE_TEMPERATURE, P = TIRE_PRESSURE
					;		1  T = P = NoValue = 0xFC
_CAN_CLOSED:	equ	bit7		;CAN-Abschluss	0  offen
					;		1  120 Ohm
;------------------------------------------------------------------------------
					;
FUN_MODE:
		dc.b	00000011b	;LED-Alarmblinken,
					;NoValues bei XP < XP_LIM,
					;CAN-Abschluss offen
					;
;------------------------------------------------------------------------------
;CAN_MASK bestimmt, welche CAN-Botschaften gesendet werden.
;
_IDENTIFIERS:	equ	bit2		;Identifier	1  Identifiertelegramme senden
					;		0  keine Identifiertelegramme
_VALUES:	equ	bit4		;LIN-Data	1  Messdatentelegramm senden
					;		0  kein Messdatentelegramm
_STATUS:	equ	bit5		;LIN-Status	1  Statustelegramm senden
					;		0  kein Statustelegramm
_DIAGNOSIS:	equ	bit6		;LIN-Diagnose	1  Diagnosetelegramm senden
					;		0  kein Diagnosetelegramm
;------------------------------------------------------------------------------
					;
CAN_MASK:
		dc.b	00110000b	;Daten- und Statustelegramme senden
					;
;------------------------------------------------------------------------------
;TIRE_TEMPERATURE maximal zulässige Temperatur
;
;Skalierfaktor	1.0
;Offset		0
;------------------------------------------------------------------------------
					;
TIRE_TEMPERATURE:
		dc.b	120		;120 °C
					;
;------------------------------------------------------------------------------
;TIRE_PRESSURE minimal zulässiger absoluter Reifendruck
;
;Skalierfaktor	0.025
;Offset		0
;------------------------------------------------------------------------------
					;
TIRE_PRESSURE:
		dc.b	52		;1,3 bar
					;
;------------------------------------------------------------------------------
;DROP_PRESSURE absoluter Reifendruckwert fuer Druckabfall-Überwachung
;
;Skalierfaktor	0.025
;Offset		0
;------------------------------------------------------------------------------
					;
DROP_PRESSURE:
		dc.b	68		;1,7 bar
					;
;------------------------------------------------------------------------------
;DROP_REF maximal tolerierter Druckabfall / min
;
;Skalierfaktor	0.025
;Offset		0
;------------------------------------------------------------------------------
					;
DROP_REF:
		dc.b	8		;0,2 bar / min
					;
;------------------------------------------------------------------------------
;XP_REF untere Geschwindigkeitsgrenze fuer die Reifenüberwachung
;
;Skalierfaktor	0.1
;Offset		0
;------------------------------------------------------------------------------
					;
XP_REF:
		dc.w	0		;0 km/h ( = Geschwindigkeitsmaskierung ausschalten )
					;
;-----------------------------------------------------------------------------
;Reserved
;-----------------------------------------------------------------------------
					;
		dc.l	0000000Fh	;
		dc.l	0FFFFFFF0h	;
					;
;------------------------------------------------------------------------------
;CAN0_CONFIG_TBL enthält Einstellungen fuer den CAN-Controller
;------------------------------------------------------------------------------
					;
CAN0_CONFIG_TBL:			;
					;1 Mbit/s @16MHz Quartz
;Config
	 	dc.b	10000000b	;CANxCTL1: MSCAN enable, Oscillator Clock, Normal Operation
		dc.b	00000001b	;CANxBTR0: SJW=1, Prescaler=2
		dc.b	00010100b	;CANxBTR1: SAMP=0, TSEG2=2, TSEG1=5
					;
		dc.b	00100000b	;CANxIDAC: acht 8-bit Akzeptanzfilter
					;
;Descriptors
		dc.w	0DB20h		;Descriptor 0	6D9h, 7 Bytes, empfangen
		dc.w	0FFE0h		;Descriptor 1
		dc.w	0DE48H		;Descriptor 2	6F2h, 8 Bytes, senden		DTM
		dc.w	0DE68h		;Descriptor 3	6F3h, 8 Bytes, senden		DTM
		dc.w	0DE88h		;Descriptor 4	6F4h, 8 Bytes, senden
		dc.w	0DEA8H		;Descriptor 5	6F5h, 8 Bytes, senden
		dc.w	0E428h		;Descriptor 6	721h, 8 Bytes, senden		Diagnose
		dc.w	0FFE0h		;Descriptor 7
					;
CAN0_CONFIG_TBL_CT:	equ	(* - CAN0_CONFIG_TBL)
CAN0_CONFIG_CT:	equ	CAN0_CONFIG_TBL_CT
					;
;------------------------------------------------------------------------------
;x_COEFF_TBL enthält Urdaten für die Mittelwertberechnung.
;Die Tabelle umfasst je einen Eintrag für einen Eingang.
;
;Der Tabellenwert liefert die Anzahl der Eingangswerte, über die gemittelt
;wird.
;------------------------------------------------------------------------------
					;
ANALOG_COEFF_TBL:
		dc.b	5		;Batteriespannung
		dc.b	3		;Warnlampenspannung
		dc.b	0,0,0,0,0	; - nicht benutzt -
ANALOG_COEFF_TBL_CT:	equ	(* - ANALOG_COEFF_TBL)
ANALOG_CT:	equ	ANALOG_COEFF_TBL_CT
					;
SENSORS_COEFF_TBL:
		dc.b	3		;Gerätetemperatur
		dc.b	5		;Umgebungsluftdruck
		dc.b	3		;Umgebungstemperatur
		dc.b	0,0,0,0		; - nicht benutzt -
SENSORS_COEFF_TBL_CT:	equ	(* - SENSORS_COEFF_TBL)
SENSORS_CT:	equ	SENSORS_COEFF_TBL_CT
					;
CONFIG_TBL_CT:	equ	(* - CONFIG_TBL)
					;
;==============================================================================
;
;Ende der programmierbaren Werte
;
;==============================================================================
					;
LIN_IDENTIFIER_TBL:
		dc.w	LIN_ID_FL
		dc.w	LIN_ID_FR
		dc.w	LIN_ID_RL
		dc.w	LIN_ID_RR
					;
MSG_IDENTIFIER_TBL:
		dc.w	MSG_ID_FL
		dc.w	MSG_ID_FR
		dc.w	MSG_ID_RL
		dc.w	MSG_ID_RR
					;
MSG_CTR_TBL:
		dc.w	MSG_CTR_FL
		dc.w	MSG_CTR_FR
		dc.w	MSG_CTR_RL
		dc.w	MSG_CTR_RR
					;
MSG_RX_TBL:
		dc.w	MSG_RX_BUF_FL
		dc.w	MSG_RX_BUF_FR
		dc.w	MSG_RX_BUF_RL
		dc.w	MSG_RX_BUF_RR
					;
;==============================================================================
;Speicherplatzbelegung im internen EEPROM
;==============================================================================
					;
.bss:		section
					;
		align	1024
HW_IDENT:
					;
;------------------------------------------------------------------------------
;Der nachfolgende Identifier beschreibt die TIREGUARD 4 Hardware-Konfiguration.
;
; ! Die Reihenfolge der Werte darf nicht verändert werden !
;
BOARD_ID:	ds.l	1		;DATA32:
					;
HW_IDENT_CT:	equ	* - HW_IDENT
					;
;------------------------------------------------------------------------------
					;
E_CRC_KEY:
		ds.l	1		;DATA32: Erkennungsschlüssel
E_CRC_CODE:
		ds.w	1		;DATA16: CRC16-Prüfcode
					;
;------------------------------------------------------------------------------
					;
E_CONFIG_TBL:
					;extern programmierbare Werte
					;
E_FUN_MODE:
		ds.b	1		;
					;
E_CAN_MASK:
		ds.b	1		;
					;
E_TIRE_TEMPERATURE:
		ds.b	1		;
					;
E_TIRE_PRESSURE:
		ds.b	1		;
					;
E_DROP_PRESSURE:
		ds.b	1		;
					;
E_DROP_REF:
		ds.b	1
					;
E_TIRE_XP_REF:
		ds.w	1		;
					;
		ds.l	2		; - reserved -
					;
E_CAN0_CONFIG_TBL:
		ds.b	CAN0_CONFIG_TBL_CT
					;
E_ANALOG_COEFF_TBL:
		ds.b	ANALOG_COEFF_TBL_CT
					;
E_SENSORS_COEFF_TBL:
		ds.b	SENSORS_COEFF_TBL_CT
					;
		ds.b	HW_IDENT + 126 - *
E_CONFIG_CRC:
		ds.w	1		;DATA16: CRC16-Prüfcode
					;
;==============================================================================
;Speicherplatzbelegung im internen RAM
;==============================================================================
					;
.regs:		section			;
					;
BOR:
		even
REGS:		ds.b	32		;32 Bytes globale Register R[0..31]

TOR:
REGS_SIZE_CT:	equ	TOR - BOR
					;
.data:		section			;
					;
BOV:					;Beginn der Systemvariablen
					;
;------------------------------------------------------------------------------
;Analogeingänge

ANALOG_FLAGS:	ds.b	1		;DATA8:
;
_ADC_ERROR:	equ	bit1		;
;
;
;
;
;
;     
					;
		even
ANALOG_BUF:				;7*DATA16:
AB_V_BATTERY:	ds.w	1		;
AB_V_WARNLAMP:	ds.w	1		;
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;

SENSORS_BUF:				;7*DATA16:
SB_T_UNIT:	ds.w	1		;
SB_P_AMBIENT:	ds.w	1		;
SB_T_AMBIENT:	ds.w	1		;
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;
					;
;==============================================================================
;
;Begin der extern abrufbaren Werte
;
;==============================================================================
					;
RESULT_BUF:
					;
;------------------------------------------------------------------------------
;Die Reihenfolge der Werte in diesem Bereich darf nicht verändert werden.
;Sonst funktioniert das PC-Programm nicht.
					;
ANALOG_RESULT_BUF:			;maximal 7 Analogwerte
V_BATTERY:	ds.w	1		;DATA16: Batteriespannung
V_WARNLAMP:	ds.w	1		;DATA16: Warnlampenspannung
					;
		ds.w	1		;5 x DATA16: Reserve
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;
					;
SENSORS_RESULT_BUF:			;maximal 7 sonstige Messwerte
T_UNIT:		ds.w	1		;DATA16: Gerätetemperatur
P_AMBIENT:	ds.w	1		;DATA16: Umgebungsluftdruck in Einheiten von 1 mbar
T_AMBIENT:	ds.w	1		;DATA16: Umgebungstemperatur in Einheiten von 0.125°C
					;
		ds.w	1		;4 x DATA16: Reserve
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;
					;
P_TPMS:		ds.b	1		;DATA8: Umgebungsluftdruck in Einheiten von 25 mbar
		ds.b	1		;
					;
XP:		ds.w	1		;DATA16: Fahrgeschwindigkeit
					;
ALARM:		ds.b	1		;DATA8:
DROP_ALARM:	ds.b	1		;DATA8:
					;
RESULT_BUF_CT:	equ	(* - RESULT_BUF)
					;
		even
LIN_ADC_ADDR:	ds.w	1		;DATA16: Adresse der LIN-Antennen Störpegelwerte
					;
		ds.w	1		;
		ds.w	1		;
		ds.w	1		;
					;
MSG_RX_REC:	equ	*
					;
MSG_RX_BUF_FL:	ds.b	24		;DATA
MSG_RX_BUF_FR:	ds.b	24		;DATA
MSG_RX_BUF_RL:	ds.b	24		;DATA
MSG_RX_BUF_RR:	ds.b	24		;DATA
					;
;==============================================================================
;
;Ende der extern abrufbaren Werte
;
;==============================================================================
					;
LIN_IDENTIFIER_REC: equ	*
					;
LIN_ID_FL:	ds.l	1		;DATA32:
LIN_ID_FR:	ds.l	1		;DATA32:
LIN_ID_RL:	ds.l	1		;DATA32:
LIN_ID_RR:	ds.l	1		;DATA32:
					;
MSG_CTR_REC:	equ	*
					;
MSG_CTR_FL:	ds.b	1		;DATA8:
MSG_CTR_FR:	ds.b	1		;DATA8:
MSG_CTR_RL:	ds.b	1		;DATA8:
MSG_CTR_RR:	ds.b	1		;DATA8:
					;
		even
MSG_IDENTIFIER_REC: equ	*
					;
MSG_ID_FL:	ds.l	1		;DATA32:
MSG_ID_FR:	ds.l	1		;DATA32:
MSG_ID_RL:	ds.l	1		;DATA32:
MSG_ID_RR:	ds.l	1		;DATA32:
					;
		even
MSG_S1_REC:	equ	*
					;
MSG_S1_BUF_FL:	ds.b	24		;DATA
MSG_S1_BUF_FR:	ds.b	24		;DATA
MSG_S1_BUF_RL:	ds.b	24		;DATA
MSG_S1_BUF_RR:	ds.b	24		;DATA
					;
;------------------------------------------------------------------------------
;Modul LIN
					;
LAST_RX_POS:	ds.b	1		;DATA8:
					;
		even
LIN_RX_CTR:	ds.w	1		;DATA16:
					;
		align	16
DIAG_BUF:	ds.b	8		;Messagebuffer für CAN-Diagnose-Telegramm 0x721
					;
;------------------------------------------------------------------------------
;Modul SCALE
					;
MEAN_S1_BUF:
					;
ANALOG_S1_BUF:	ds.b	ANALOG_CT*3	;7*DATA24
SENSORS_S1_BUF:	ds.b	SENSORS_CT*3	;7*DATA24
MEAN_S1_BUF_CT:	equ	(* - MEAN_S1_BUF)
					;
;------------------------------------------------------------------------------
;Modul OUTPUT
					;
OUTPUT_FLAGS:	ds.b	1		;DATA8:
;
;
;
;
;
;
;
_ALARM_TOGGLE:	equ	bit7		;
					;
ALARM_CTR:	ds.b	1		;
					;
OUTPUT_FLAGS2:	ds.b	1		;DATA8:
_C_TEMP_VL:	equ	bit0		;1, wenn Temperaturwert VL Offsetkorrekturunterlauf
_C_TEMP_VR:	equ	bit1		;1, wenn Temperaturwert VR Offsetkorrekturunterlauf
_C_TEMP_HL:	equ	bit2		;1, wenn Temperaturwert HL Offsetkorrekturunterlauf
_C_TEMP_HR:	equ	bit3		;1, wenn Temperaturwert HR Offsetkorrekturunterlauf
_C_PRESS_VL:	equ	bit4		;1, wenn Druckwert VL Offsetkorrekturunterlauf
_C_PRESS_VR:	equ	bit5		;1, wenn Druckwert VR Offsetkorrekturunterlauf
_C_PRESS_HL:	equ	bit6		;1, wenn Druckwert HL Offsetkorrekturunterlauf
_C_PRESS_HR:	equ	bit7		;1, wenn Druckwert HR Offsetkorrekturunterlauf
					;
;------------------------------------------------------------------------------
;Modul COMMUNICATE
					;
COMMUNICATE_FLAGS:
		ds.b	1		;DATA8:
_LOW_XP_TRIG:	equ	bit0
_LOW_XP_FLAG:	equ	bit1
;
;
_CAN_RFSH_TRIG:	equ	bit4
;
;
;
					;
		even
CAN_BUF:	equ	*
					;
CAN0_MSG0_BUF:	ds.b	8		;
CAN0_MSG1_BUF:	ds.b	8		;
CAN0_MSG2_BUF:	ds.b	8		;
CAN0_MSG3_BUF:	ds.b	8		;
					;
CAN_BUF_CT:	equ	(* - CAN_BUF)
					;
					;
CAN0_RX_CTR:	ds.w	1		;DATA16:
					;
		even
TIRE_SENSOR_CTR_REC:
		ds.w	4		;4*DATA16
					;
CHECK_WAIT_CTR:	ds.w	1		;DATA16: Zeitzähler für Prüfzeitraster
					;
TIRE_DAT_RFSH_CTR: ds.b	1		;DATA8: Zähler für Reifendaten-Ausgabezykluszeit
TIRE_ID_RFSH_CTR: ds.b	1		;DATA8: Zähler für Reifenidentifier-Ausgabezykluszeit
					;
CAN0_TIMEOUT_CTR:
		ds.b	1		;DATA8:
					;
;------------------------------------------------------------------------------
;sonstige Variable
					;
TICK_CTR:	ds.b	1		;DATA8: Tickzähler für Programmzykluszeit
LOOP_FLAGS:	ds.b	1		;DATA8:
;
;
;
_LOOP_OV:	equ	bit3		;1, wenn Programmzyklus 'verschluckt' wurde
_LOOP_OV_CLEAR:	equ	bit4		;1, wenn _LOOP_OV rückgesetzt werden soll
;
;
_LOOP_TIMEOUT:	equ	bit7		;1, wenn Programmzyklus beendet ist
					;
					;
 ifne fDebug
		align	16
TEST_BUF:	ds.b	1024
TEST_S1_BUF:	ds.b	12
TEST_CHECKSUM:	ds.b	1
TEST_CTR:	ds.b	1
TEST_VAL:	ds.b	1
 endif

TOV:

VAR_SIZE_CT:	equ	TOV - BOV

		even
BOS:		ds.b	0100h		;256 Bytes Stack
TOS:					;Anfangswert des Stackpointers

STACK_SIZE_CT:	equ	TOS - BOS
					;
;------------------------------------------------------------------------------
	end
