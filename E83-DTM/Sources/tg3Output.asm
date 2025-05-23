	include	"s12c_128.sfr"
	title	"tg3Output  Copyright (C) 2005-2006, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TireGuard 3	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg3Output.asm
;
;Copyright:	(C) 2005-2006, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	24.11.2006
;
;Description:	Das Programmmodul OUTPUT steuert die Alarm-LED an.
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an 9s12c128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	SCI_TX_STATUS		;Code
					;
	xref	E_FUN_MODE		;bssData
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
LED_PORT:	equ	PTT		;
_LED_BIT:	equ	bit1		;
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
;			E_FUN_MODE
;Ausgangsparameter:	LEDsOUT
;veraenderte Register:	CCR, A, B
;------------------------------------------------------------------------------
					;
UPDATE_LED:
	JSR	SCI_TX_STATUS		;
	BNE	UPDATE_LED3		;wenn keine serielle Datenausgabe aktiv,

	LDAA	ALARM			;dann
	ORAA	DROP_ALARM		;
	BEQ	UPDATE_LED2		;
	LDAA	E_FUN_MODE		;  wenn E_FUN_MODE.0 = 1
	ANDA	#00000001b		;  dann
	BEQ	UPDATE_LED1		;    Lampe blinkend einschalten
	BRSET	OUTPUT_FLAGS,_ALARM_TOGGLE,UPDATE_LED2
UPDATE_LED1:
	BSET	LED_PORT,_LED_BIT	;
	JMP	UPDATE_LED3		;
					;
UPDATE_LED2:
	BCLR	LED_PORT,_LED_BIT	;
					;
UPDATE_LED3:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end


