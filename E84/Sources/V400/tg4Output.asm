	include	"s12ga_240.sfr"
	title	"tg4Output  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg4Output.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	07.01.2015
;
;Description:	Das Programmmodul OUTPUT steuert die Alarm-LED an.
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3Output.asm
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	SCI_TX_STATUS		;Code
					;
	xref	E_FUN_MODE		;bssData
	xref.b	_BLINKING		;bitMask
	xref.b	_CAN_CLOSED		;bitMask
					;
	xref	ALARM			;Data
	xref	ALARM_CTR		;Data
	xref	DROP_ALARM		;Data
	xref	OUTPUT_FLAGS		;Data
	xref.b	_ALARM_TOGGLE		;bitMask
					;
	xref.b	ALARM_CT		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	OUTPUT			;Code
					;
;//////////////////////////////////////////////////////////////////////////////
;Hardware dependent constants
;//////////////////////////////////////////////////////////////////////////////
					;
LED_PORT:	equ	PTS		;TIREGUARD 4
_LED_BIT:	equ	bit3		;

DRIVER_PORT:	equ	PTJ		;
_CAN_SW:	equ	bit0		;
					;
.text:		section
					;
;==============================================================================
;OUTPUT Modul-Einsprung
;==============================================================================
					;
OUTPUT:
	JSR	ALARM_CTR_UPDATE	;Blinktakt f�r Alarm-LED
	JSR	UPDATE_LED		;
	JSR	SET_CAN_TERMINATION	;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
;ALARM_CTR_UPDATE gibt den Blinktakt f�r die Alarm-LED vor.
;
;Eingangsparameter:	ALARM_CTR
;			ALARM_CT
;			OUTPUT_FLAGS._ALARM_TOGGLE
;Ausgangsparameter:	ALARM_CTR
;			PUTPUT_FLAGS._ALARM_TOGGLE
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
ALARM_CTR_UPDATE:
	LDAA	ALARM_CTR		;wenn ALARM_CTR noch nicht abgelaufen
	BEQ	ALARM_CTR_UPDATE1	;dann
	CMPA	#ALARM_CT		;  pr�fen, ob Wert im zul�ssigen Bereich
	BHI	ALARM_CTR_UPDATE1	;
	DECA				;  ALARM_CTR decrementieren
	JMP	ALARM_CTR_UPDATE2	;
					;
ALARM_CTR_UPDATE1:
	LDAA	OUTPUT_FLAGS		;sonst
	EORA	#_ALARM_TOGGLE		;  _ALARM_TOGGLE umschalten
	STAA	OUTPUT_FLAGS		;
	LDAA	#ALARM_CT		;  ALARM_CTR auf Startwert setzen
					;
ALARM_CTR_UPDATE2:
	STAA	ALARM_CTR		;
	RTS				;
					;
;------------------------------------------------------------------------------
;UPDATE_LED steuert die Alarm-LED an.
;
;Eingangsparameter:	ALARM
;			DROP_ALARM
;			E_FUN_MODE,_BLINKING
;Ausgangsparameter:	keine
;veraenderte Register:	CCR, A, B
;------------------------------------------------------------------------------
					;
UPDATE_LED:
	JSR	SCI_TX_STATUS		;wenn keine serielle Datenausgabe aktiv,
	BNE	UPDATE_LED3		;dann
	LDAA	ALARM			;  wenn ALARM oder DROP_ALARM,
	ORAA	DROP_ALARM		;  dann
	BEQ	UPDATE_LED2		;    wenn E_FUN_MODE._BLINKING = 0
	BRCLR	E_FUN_MODE,_BLINKING,UPDATE_LED1
	BRSET	OUTPUT_FLAGS,_ALARM_TOGGLE,UPDATE_LED2
UPDATE_LED1:
	BSET	LED_PORT,_LED_BIT	;    dann LED statisch einschalten
	JMP	UPDATE_LED3		;
					;
UPDATE_LED2:
	BCLR	LED_PORT,_LED_BIT	;    sonst LED blinkend einschalten
					;
UPDATE_LED3:
	RTS				;
					;
;------------------------------------------------------------------------------
;SET_CAN_TERMINATION schaltet den CAN-Abschlusswiderstand abh�ngig von
;E_FUN_MODE._CAN_CLOSED ein oder aus.
;
;Eingangsparameter:	E_FUN_MODE._CAN_CLOSED
;Ausgangsparameter:     keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
SET_CAN_TERMINATION:
	BRSET	E_FUN_MODE,_CAN_CLOSED,SET_CAN_TERMINATION1
	BCLR	DRIVER_PORT,_CAN_SW	;_CAN_SW r�cksetzen : CAN-Termination open, R = infinite
	BRA	SET_CAN_TERMINATION9	;
					;
SET_CAN_TERMINATION1:
	BSET	DRIVER_PORT,_CAN_SW	;_CAN_SW setzen : CAN-Termination closed, R = 120 Ohms
					;
SET_CAN_TERMINATION9:
	RTS				;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end


