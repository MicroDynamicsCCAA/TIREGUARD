	include	"s12c_128.sfr"
	include	"s12c_DS1722_a.sfr"
	title	"s12c_DS1722_a  Copyright (C) 2005-2012, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_DS1722_a.asm
;
;Copyright:	(C) 2005-2012, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	06.01.2012
;
;Description:	Funktionen für den Zugriff auf das serielle Digital-Thermometer
;		vom Typ DALLAS Semiconductor DS1722
;		Das Thermometer-Bauelement wird im SPI-Modus betrieben.
;
;		SingleChip-Version ohne MSB-Businterface
;
;Folgende Bezeichner sind in s12c_DS1722_a.sfr zu definieren:
;
;Switches:	fEnabled
;
;Bits:		_MISO
;		_MOSI
;		_SCLK
;		_CE
;		_SERMODE
;
;Ports:		MISO_DIR
;		MISO_PORT
;		MOSI_DIR
;		MOSI_PORT
;		SCLK_DIR
;		SCLK_PORT
;		CE_DIR
;		CE_PORT
;		SERMODE_DIR
;		SERMODE_PORT
;------------------------------------------------------------------------------
;Revision History:	Original Version  07.05
;
;06.01.2012	Rückanpassung an MC9S12C128
;18.06.2011	Überarbeitung und Umstellung auf SPI-Modus
;
;27.04.2009	Anpassung an MC9S12P128
;08.11.2006	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	SDT_RESET		;Code
	xdef	SDT_READ_CONFIG		;Code
	xdef	SDT_READ_VALUE		;Code
	xdef	SDT_WRITE_CONFIG	;Code
					;
;------------------------------------------------------------------------------
;Variables and Constants
;------------------------------------------------------------------------------
					;
CMD_READ_CONFIG:	equ	00h	;
CMD_READ_VALUE_LOW:	equ	01h	;
CMD_READ_VALUE_HIGH:	equ	02h	;
CMD_WRITE_CONFIG:	equ	80h	;
					;
					;
.text:		section
					;
;//////////////////////////////////////////////////////////////////////////////
;SUBMIT_COMMAND führt einen Schreib-/Lesezugriff auf das Digital-Thermometer aus.
;
;Die Taktfrequenz beträgt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;Das Bauelement erlaubt maximal 5 MHz bei 2,65..5,5 V.
;
;Eingangsparameter:	A		Kommando
;			B		ggf. zu schreibende Daten, rechtsbündig
;Ausgangsparameter:	B		ggf. gelesene Daten, rechtsbündig
;veränderte Register:	CCR, R3
;//////////////////////////////////////////////////////////////////////////////
					;
SUBMIT_COMMAND:
	MOVB	#16,R3			;
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
					;
 if fEnabled == _high
	BSET	CE_PORT,_CE		;Bauteil selektieren
 else
	BCLR	CE_PORT,_CE		;Bauteil selektieren
 endif
					;
SUBMIT_COMMAND1:
	LSLD				;Kommando-/Datenregister um ein bit nach links schieben
	BCC	SUBMIT_COMMAND2		;wenn CARRY,
	BSET	MOSI_PORT,_MOSI		;dann Sendeleitung auf '1'
	BRA	SUBMIT_COMMAND3		;
SUBMIT_COMMAND2:
	BCLR	MOSI_PORT,_MOSI		;sonst Sendeleitung auf '0'
	NOP				;
SUBMIT_COMMAND3:
	BSET	SCLK_PORT,_SCLK		;Takt auf '1' zur Übernahme des bits
	NOP				;
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
	NOP				;
	BRCLR	MISO_PORT,_MISO,SUBMIT_COMMAND4
					;wenn bit gesetzt,
	ORAB	#00000001b		;dann '1' in gelesene Daten eintragen
	BRA	SUBMIT_COMMAND5		;
SUBMIT_COMMAND4:
	ANDB	#11111110b		;sonst '0' in gelesene Daten eintragen
SUBMIT_COMMAND5:
	DEC	R3			;weiter,
	BNE	SUBMIT_COMMAND1		;  bis alle bits übertragen
					;
 if fEnabled == _high
	BCLR	CE_PORT,_CE		;Bauteil deaktivieren
 else
	BSET	CE_PORT,_CE		;Bauteil deaktivieren
 endif
					;
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: SDT_RESET bringt Daten- und Taktleitungen in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;//////////////////////////////////////////////////////////////////////////////
					;
SDT_RESET:
	BSET	SERMODE_DIR,_SERMODE	;SERMODE-Pin auf Ausgang schalten
	BSET	SERMODE_PORT,_SERMODE	;_SERMODE:	Out = 1 : SPI
					;
	BSET	CE_DIR,_CE		;CE-Pin auf Ausgang schalten
					;
 if fEnabled == _high
	BCLR	CE_PORT,_CE		;_CE:		Out = 0 : Bauteil deaktivieren
 else
	BSET	CE_PORT,_CE		;_CE:		Out = 1 : Bauteil deaktivieren
 endif
					;
	BSET	SCLK_DIR,_SCLK		;SCLK-Pin auf Ausgang schalten
	BCLR	SCLK_PORT,_SCLK		;_SCLK:		Out = 0
	BSET	MOSI_DIR,_MOSI		;MOSI-Pin auf Ausgang schalten
	BCLR	MOSI_PORT,_MOSI		;_MOSI:		Out = 0
	BCLR	MISO_DIR,_MISO		;MISO-Pin auf Eingang schalten
					;_MISO:		In
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SDT_READ_CONFIG liest die Konfigurationdaten aus dem Thermometer.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0		Byte mit aktuellen Konfigurationsdaten
;veränderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
SDT_READ_CONFIG:
	LDAA	#CMD_READ_CONFIG	;
	LDAB	#0FFh			;Ergebnis fegen
	JSR	SUBMIT_COMMAND		;
	STAB	R0			;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SDT_READ_VALUE liest den aktuellen Messwert aus dem Thermometer.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0/R1		Datenwort
;veränderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
SDT_READ_VALUE:
	LDAA	#CMD_READ_VALUE_HIGH	;
	LDAB	#0FFh			;Ergebnis fegen
	JSR	SUBMIT_COMMAND		;
	STAB	R0			;
					;
	LDAA	#CMD_READ_VALUE_LOW	;
	LDAB	#0FFh			;Ergebnis fegen
	JSR	SUBMIT_COMMAND		;
	STAB	R1			;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: SDT_WRITE_CONFIG schreibt neue Konfigurationsdaten in das Thermometer.
;
;Eingangsparameter:	R0		Byte mit neuen Konfigurationsdaten
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
SDT_WRITE_CONFIG:
	LDAA	#CMD_WRITE_CONFIG	;
	LDAB	R0			;neue Konfigurationsdaten
	JSR	SUBMIT_COMMAND		;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
