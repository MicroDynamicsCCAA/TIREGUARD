	include	"s12c_128.sfr"
	include	"s12c_Switches.sfr"
	title	"tg3Globals  Copyright (C) 2005-2011, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TireGuard 3	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg3Globals.asm
;
;Copyright:	(C) 2005-2011, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	20.01.2011
;
;Description:	allgemeine Funktionen
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;20.01.2011	Version 2.50
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	CLEAR_BUFFER		;Code
	xdef	CALC_CHECKSUM		;Code
	xdef	VERIFY_CHECKSUM		;Code
	xdef	WATCHDOG_INIT		;Code
	xdef	WATCHDOG_RESET		;Code
					;
.text:		section
					;
;------------------------------------------------------------------------------
;Public: CLEAR_BUFFER f�llt einen Speicherbereich mit einem festen Wert.
;
;Eingangsparameter:	LDY		Zeiger auf Speicherbereich
;			R3		Anzahl Bytes
;			A		F�llwert
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
CLEAR_BUFFER:
	STAA	1,Y+			;
	DEC	R3			;
	BNE	CLEAR_BUFFER		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: CALC_CHECKSUM bildet die Pr�fsumme �ber einen Speicherbereich durch
;byteweise Addition der Werte mit jeweils nachfolgender Inkrementierung ohne
;Ber�cksichtigung der �berl�ufe.
;Als Ergebnis wird ein Zahlenwert so geliefert, dass die Summe einschlie�lich
;dieser Pr�fsumme den Wert 0 ergibt.
;
;Eingangsparameter:	X 		Anfangsadresse des Datenbereiches
;			R3		Anzahl Bytes des Datenbereiches
;Ausgangsparameter:	A		Pr�fsumme
;veraenderte Register:	CCR, B
;------------------------------------------------------------------------------
					;
CALC_CHECKSUM:
	CLRB				;Pr�fsumme auf Null setzen
	LDAA	R3			;
	BEQ	CALC_CHECKSUM2		;wenn Anzahl Bytes > 0,
					;dann
CALC_CHECKSUM1:
	ADDB	1,X+			;  Byte lesen und zur Pr�fsumme addieren
	ADCB	R3			;  Pr�fsumme aktualisieren
	DEC	R3			;
	BNE	CALC_CHECKSUM1		;  weiter, bis Bereich bearbeitet
					;
	CLRA				;
	SBA				;  0 - Pr�fsumme
	EXG	A,B			;  nach B
					;
CALC_CHECKSUM2:
	EXG	A,B			;Pr�fsumme nach A
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: VERIFY_CHECKSUM bildet die Pr�fsumme �ber einen Speicherbereich durch
;byteweise Addition der Werte mit jeweils nachfolgender Inkrementierung ohne
;Ber�cksichtigung der �berl�ufe.
;Zuletzt wird die originale Pr�fsumme addiert. Bei Konsistenz von Daten und
;originaler Pr�fsumme muss das Ergebnis der Pr�fung den Wert 0 ergeben.
;
;Eingangsparameter:	X		Anfangsadresse des Datenbereiches
;			Y		Zeiger auf originale Pr�fsumme
;			R3		Anzahl Bytes des Datenbereiches
;Ausgangsparameter:	A		0	= ok
;					<> 0	= Daten nicht konsistent
;veraenderte Register:	CCR, B
;------------------------------------------------------------------------------
					;
VERIFY_CHECKSUM:
	CLRB				;Pr�fsumme auf Null setzen
	LDAA	R3			;
	BEQ	VERIFY_CHECKSUM2	;wenn Anzahl Bytes > 0,
					;dann
VERIFY_CHECKSUM1:
	ADDB	1,X+			;  Byte lesen und zur Pr�fsumme addieren
	ADCB	R3			;  Pr�fsumme aktualisieren
	DEC	R3
	BNE	VERIFY_CHECKSUM1	;  weiter, bis Bereich bearbeitet
					;
	ADDB	0,Y			;  originale Pr�fsumme addieren

VERIFY_CHECKSUM2:
	EXG	A,B			;Pr�fungsergebnis nach A
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: WATCHDOG_INIT stellt die Zeitgrenze auf 2exp22 Oszillator-Takte und
;startet den Watchdog-Timer.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veraenderte Register:	CCR
;------------------------------------------------------------------------------
					;
WATCHDOG_INIT:
					;
 ifeq fDebug
	MOVB	#01000111b,COPCTL	;stops COP if in BDM mode / 2exp24 cycles
					;=> Timeout = 1056 ms @ 16 MHz OSC_CLK
 endif
					;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: WATCHDOG_RESET startet den Watchdog-Timer neu.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veraenderte Register:	CCR
;------------------------------------------------------------------------------
					;
WATCHDOG_RESET:
					;
 ifeq fDebug
	MOVB	#55h,ARMCOP		;
	MOVB	#0AAh,ARMCOP		;
 endif
					;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end

