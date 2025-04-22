	include "s12c_128.sfr"
	title	"tg3Input  Copyright (C) 2005-2006, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TireGuard 3	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg3Input.asm
;
;Copyright: 	(C) 2005-2006, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	24.11.2006
;
;Description:	Abfragen der Analogeingänge
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	SDT_READ_VALUE		;Code
					;
	xref	ANALOG_BUF		;Data
	xref	ANALOG_FLAGS		;Data
	xref.b	_ADC_ERROR		;bitMask
	xref	UNIT_TEMPERATURE	;Data
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	INPUT			;Code
					;
.text:		section
					;
;==============================================================================
;INPUT Modul-Einsprung
;==============================================================================
					;
INPUT:
	JSR	GET_ANALOG_VALUES	;analoge Eingänge abfragen
	JSR	GET_SENSOR_VALUES	;Temperatursensor abfragen
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
;GET_ANALOG_VALUES liest den analogen Eingang.
;Der 1 analoge Eingang werden abgefragt und die Ergebniswerte im
;prozessorinternen RAM abgelegt.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	ANALOG_BUF	Analogeingänge-Rohdaten
;			ADC_ERROR
;veraenderte Register:	CCR, A, X, Y, R[2..3]
;------------------------------------------------------------------------------
					;
GET_ANALOG_VALUES:
	MOVB	#10110000b,ATD0STAT0	;Statusflags quittieren
	LDAA	#10010000b		;Right adjusted, unsigned, single shot, multi-channel
	STAA	ATD0CTL5		;Wandlungssequenz starten
	MOVW	#128,R2			;Timeout-Zähler
GET_ANALOG_VALUES1:
	BRSET	ATD0STAT0,_SCF,GET_ANALOG_VALUES3
GET_ANALOG_VALUES2:
	DEC	R3			;
	BNE	GET_ANALOG_VALUES1	;
	DEC	R2			;warten, bis Wandlungssequenz abgeschlossen
	BNE	GET_ANALOG_VALUES1	;bzw. Zeitgrenze erreicht
	BSET	ANALOG_FLAGS,_ADC_ERROR	;dann mit Fehlermeldung zurück
	JMP	GET_ANALOG_VALUES9	;
					;
GET_ANALOG_VALUES3:
	LDX	#ATD0DR0		;
	LDY	#ANALOG_BUF		;
	MOVB	#1,R3			;
GET_ANALOG_VALUES4:
	MOVW	2,X+,2,Y+		;Ergebnisse von AD-Wandler 0 abholen
	DEC	R3			;
	BNE	GET_ANALOG_VALUES4	;
					;
GET_ANALOG_VALUES9:
	RTS				;
					;
;-----------------------------------------------------------------------------
;GET_SENSOR_VALUES liest den Temperatursensor DS1722 und legt das
;Messergebnis im internen RAM ab.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	UNIT_TEMPERATURE Gerätetemperaturwert
;veränderte Register:	CCR, A, B, R[0..1,3]
;-----------------------------------------------------------------------------
					;
GET_SENSOR_VALUES:
	JSR	SDT_READ_VALUE		;Temperatursensor abfragen
	LDD	R0			;
	STD	UNIT_TEMPERATURE	;Temperaturwert ablegen
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
