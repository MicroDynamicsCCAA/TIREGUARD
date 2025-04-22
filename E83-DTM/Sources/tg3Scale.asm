	include "s12c_128.sfr"
	title	"tg3Scale  Copyright (C) 2005-2006, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TireGuard 3	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg3Scale.asm
;
;Copyright: 	(C) 2005-2006, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	24.11.2006
;
;Description:	Bearbeitung der Rohdaten in Form von digitaler Filterung
;		analoger Signale.
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
	xref	MEAN16			;Code
					;
	xref	E_ANALOG_COEFF_TBL	;bssData
					;
	xref	ANALOG_BUF		;Data
	xref	ANALOG_RESULT_BUF	;Data
	xref	ANALOG_S1_BUF		;Data
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	SCALE			;Code
					;
.text:		section
					;
;==============================================================================
;SCALE Modul-Einsprung
;==============================================================================
					;
SCALE:
	JSR	SCALE_ANALOG		;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
;SCALE_ANALOG filtert ggf. die analogen Messwerte.
;
;Eingangsparameter:	ANALOG_BUF
;			ANALOG_S1_BUF
;			E_ANALOG_COEFF_TBL
;Ausgangsparameter:	ANALOG_RESULT_BUF
;			ANALOG_S1_BUF
;veränderte Register:	CCR, A, B, X, Y, R[0..1,3..7,10..27]
;------------------------------------------------------------------------------
					;
SCALE_ANALOG:
	MOVW	#ANALOG_BUF,R10		;Zeiger auf analoge Rohdaten
	MOVW	#ANALOG_RESULT_BUF,R12	;Zeiger auf Ergebnisbuffer

	MOVW	#E_ANALOG_COEFF_TBL,R16	;Zeiger auf Mittelungskonstanten
	MOVW	#ANALOG_S1_BUF,R6	;Zeiger auf Vorgeschichtswerte
	MOVB	#1,R3			;maximal 1 Analogeingang
					;
SCALE_ANALOG1:
	LDX	R10			;
	MOVW	2,X+,R18		;Rohdatenwert nach R[18..19]
	STX	R10			;
					;
	LDX	R16			;
	LDAA	1,X+			;
	STX	R16			;
	CMPA	#0			;wenn Mittelungskonstante > 0,
	BEQ	SCALE_ANALOG2		;dann
	STAA	R0			;  Mittelungskonstante
	MOVW	#R18,R4			;  Zeiger auf Eingangswert
					;  R[6..7] zeigt auf Vorgeschichtswert
	JSR	MEAN16			;  Aufruf der Mittelungsfunktion
SCALE_ANALOG2:
	LDX	R6			;Zeiger auf Vorgeschichtswerte
	LEAX	3,X			;zum nächsten 24-bit Wert verschieben
	STX	R6			;
					;
	LDY	R12			;
	LDD	R18			;
	STD	2,Y+			;16-bit Ergebnis im Ergebnisbuffer ablegen
	STY	R12			;
	DEC	R3			;
	BNE	SCALE_ANALOG1		;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
