	include	"s12ga_240.sfr"
	include	"s12ga_MC33879.sfr"
	title	"s12ga_MC33879  Copyright (C) 2006-2014, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12xep_MC33879.asm
;
;Copyright:	(C) 2006-2014, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	30.11.2014
;
;Description:	Funktionen f�r den Zugriff auf den seriellen Achtfach-Lasttreiber
;		vom Typ Freescale MC33879.
;
;Folgende Bezeichner sind in s12ga_MC33879.sfr zu definieren:
;
;Bits:		_MISO
;		_MOSI
;		_SCLK
;		_CS
;
;Ports:		MISO_DIR
;		MISO_PORT
;		MOSI_DIR
;		MOSI_PORT
;		SCLK_DIR
;		SCLK_PORT
;		CS_DIR
;		CS_PORT
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.06
;
;30.11.2014	Anpassung an MC9S12GA240
;		Herkunft: s12xep_MC33879_s.asm
;
;13.01.2011	Anpassung an MC9S12XEP100
;
;14.11.2006	Original:	s12c_MC33879_s.asm
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	PWS_RESET		;Code
	xdef	PWS_UPDATE		;Code
					;
.text:		section
					;
;//////////////////////////////////////////////////////////////////////////////
;SWRITE schreibt neue Zust�nde f�r die acht Schaltausg�nge und liest den
;Fehlerstatus des Bauelementes (MSB first).
;
;Die Taktfrequenz betr�gt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;Der Hersteller des Bauelementes empfiehlt 4 MHz bei 3,1..5,5 V.
;
;Eingangsparameter:	D		zu schreibende Daten
;Ausgangsparameter:	D		Fehlerstatus
;			SCLK_PORT._SCLK	0
;ver�nderte Register:	CCR, R3
;//////////////////////////////////////////////////////////////////////////////
					;
SWRITE:
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
	BCLR	CS_PORT,_CS		;Bauteil selektieren
	MOVB	#16,R3			;bit-Z�hler auf Startwert
SWRITE1:
	BSET	SCLK_PORT,_SCLK		;Takt auf '1' zur �bernahme des zu lesenden bits
	LSLD				;Daten um ein bit nach links schieben
	BCC	SWRITE2			;wenn CARRY
	BSET	MOSI_PORT,_MOSI		;dann Sendeleitung auf '1'
	BRA	SWRITE3			;
SWRITE2:
	BCLR	MOSI_PORT,_MOSI		;sonst Sendeleitung auf '0'
	NOP				;
SWRITE3:
	BRCLR	MISO_PORT,_MISO,SWRITE4	;wenn zu lesendes bit gesetzt
	ORAB	#00000001b		;dann '1' in gelesene Daten eintragen
	BRA	SWRITE5			;
SWRITE4:
	ANDB	#11111110b		;sonst '0' in gelesene Daten eintragen
SWRITE5:
	BCLR	SCLK_PORT,_SCLK 	;Takt auf '0' zur �bernahme des zu schreibenden bits
	DEC	R3			;weiter,
	BNE	SWRITE1			;  bis alle bits �bertragen
	BSET	CS_PORT,_CS		;danach Bauteil deaktivieren
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: PWS_RESET bringt Daten- und Taktleitungen in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;//////////////////////////////////////////////////////////////////////////////
					;
PWS_RESET:
	BSET	CS_DIR,_CS		;CS-Pin auf Ausgang schalten
	BSET	CS_PORT,_CS		;CS:		Out= 1
					;
	BSET	SCLK_DIR,_SCLK		;SCLK-Pin auf Ausgang schalten
	BCLR	SCLK_PORT,_SCLK		;SCLK:		Out= 0
	BSET	MOSI_DIR,_MOSI		;MOSI-Pin auf Ausgang schalten
	BCLR	MOSI_PORT,_MOSI		;MOSI:		Out= 0
	BCLR	MISO_DIR,_MISO		;MISO-Pin auf Eingang schalten
					;MISO:		In
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: PWS_UPDATE l�dt neue Schalt-Zust�nde in den Treiber-Baustein.
;
;Eingangsparameter:	R0/R1		Schalt- und �berwachungskommando
;Ausgangsparameter:	R0/R1		letzter Fehlerstatus
;ver�nderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
PWS_UPDATE:
	LDD	R0			;
	JSR	SWRITE			;Kommando ausf�hren
	STD	R0			;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
