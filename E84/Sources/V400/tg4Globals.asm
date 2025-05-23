	include	"s12ga_240.sfr"
	include	"s12ga_Switches.sfr"
	title	"tg4Globals  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg4Globals.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	07.01.2015
;
;Description:	allgemeine Funktionen
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3Globals.asm
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
	xdef	CLEAR_BUFFER8		;Code
	xdef	CLEAR_BUFFER16		;Code
	xdef	WATCHDOG_INIT		;Code
	xdef	WATCHDOG_RESET		;Code
					;
.text:		section
					;
;------------------------------------------------------------------------------
;Public: CLEAR_BUFFER8 f�llt einen Speicherbereich mit einem festen Wert.
;
;Eingangsparameter:	LDY		Zeiger auf Speicherbereich
;			R3		Anzahl Bytes
;			A		8-bit F�llwert
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
CLEAR_BUFFER8:
	STAA	1,Y+			;
	DEC	R3			;
	BNE	CLEAR_BUFFER8		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: CLEAR_BUFFER16 f�llt einen Speicherbereich mit einem festen Wert.
;
;Eingangsparameter:	LDY		Zeiger auf Speicherbereich
;			R3		Anzahl Worte
;			D		16-bit F�llwert
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
CLEAR_BUFFER16:
	STD	2,Y+			;
	DEC	R3			;
	BNE	CLEAR_BUFFER16		;
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
 if (fDebug = 0)
	MOVB	#01000111b,CPMUCOP	;stops COP if in BDM mode / 2exp24 cycles
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
 if (fDebug = 0)
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

