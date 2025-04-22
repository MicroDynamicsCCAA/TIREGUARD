	include	"s12c_128.sfr"
	include	"s12c_DS1722_s.sfr"
	title	"s12c_DS1722_s  Copyright (C) 2005-2012, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_DS1722_s.asm
;
;Copyright:	(C) 2005-2012, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	06.01.2012
;
;Description:	Funktionen für den Zugriff auf das serielle Digital-Thermometer
;		vom Typ DALLAS Semiconductor DS1722.
;		Das Thermometer-Bauelement wird im 3-Wire Modus betrieben.
;		Das bedeutet, dass Daten vom Bauelement jeweils mit steigender
;		Flanke des SCLK-Taktes gelesen und mit dessen fallender Flanke
;		geschrieben werden.
;
;		SingleChip-Version ohne MSB-Businterface
;
;Folgende Bezeichner sind in s12c_DS1722_s.sfr zu definieren:
;
;Switches:	fEnabled
;
;Bits:		_MISO
;		_MOSI
;		_SCLK
;		_CE
;
;Ports:		MISO_DIR
;		MISO_PORT
;		MOSI_DIR
;		MOSI_PORT
;		SCLK_DIR
;		SCLK_PORT
;		CE_DIR
;		CE_PORT
;------------------------------------------------------------------------------
;Revision History:	Original Version  07.05
;
;06.01.2012	über fEnabled selektierbarer aktiver CE-Pegel	
;
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
;SREAD liest Daten seriell aus dem Digital-Thermometer.
;
;Die Taktfrequenz beträgt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;Das Bauelement erlaubt maximal 5 MHz bei 2,65..5,5 V.
;
;Eingangsparameter:	R3		Anzahl zu übertragender bits
;Ausgangsparameter:	A		gelesene Daten, linksbündig
;veränderte Register:	CCR
;//////////////////////////////////////////////////////////////////////////////
					;
SREAD:
	LDAA	#0FFh			;Ergebnis fegen
					;
SREAD1:
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0' zur Übernahme des bits
	NOP				;
	NOP				;
	NOP				;warten, bis bit gültig ist
	NOP				;
	NOP				;
	NOP				;
	LSRA				;Daten um ein bit nach rechts schieben
	BRCLR	MISO_PORT,_MISO,SREAD2	;wenn bit gesetzt
	ORAA	#10000000b		;dann '1' in gelesene Daten eintragen
	BRA	SREAD3			;
SREAD2:
	ANDA	#01111111b		;sonst '0' in gelesene Daten eintragen
SREAD3:
	BSET	SCLK_PORT,_SCLK		;Takt auf '1'
	DEC	R3			;
	BNE	SREAD1			;
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;SWRITE schreibt Daten seriell in das Digital-Thermometer.
;
;Die Taktfrequenz beträgt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;Das Bauelement erlaubt maximal 5 MHz bei 2,65..5,5 V.
;
;Eingangsparameter:	R3		Anzahl zu übertragender bits
;			A		zu schreibende Daten, rechtsbündig
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;//////////////////////////////////////////////////////////////////////////////
					;
SWRITE:
	LSRA				;Datenbit ins CARRY-Flag schieben
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
	BCC	SWRITE1			;wenn CARRY
	BSET	MOSI_PORT,_MOSI		;dann Sendeleitung auf '1'
	BRA	SWRITE2			;
SWRITE1:
	BCLR	MOSI_PORT,_MOSI		;sonst Sendeleitung auf '0'
	NOP				;
SWRITE2:
	BSET	SCLK_PORT,_SCLK		;Takt auf '1' zur Übernahme des bits
	DEC	R3			;
	BNE	SWRITE			;
	RTS				;
					;
;------------------------------------------------------------------------------
;SUBMIT_COMMAND übergibt ein Kommando an das Digital-Thermometer.
;
;Eingangsparameter:	A		Kommando rechtsbündig
;Ausgangsparameter:	keine
;veränderte Register:	CCR, R3
;------------------------------------------------------------------------------
					;
SUBMIT_COMMAND:
	MOVB	#8,R3			;
	JSR	SWRITE			;
	RTS				;
					;
;------------------------------------------------------------------------------
;SEND_DATA übergibt ein Datenbyte an das Digital-Thermometer.
;
;Eingangsparameter:	A		Datenwort
;Ausgangsparameter:	keine
;veränderte Register:	CCR, R3
;------------------------------------------------------------------------------
					;
SEND_DATA:
	MOVB	#8,R3			;
	JSR	SWRITE			;
	RTS				;
					;
;------------------------------------------------------------------------------
;RECEIVE_DATA liest ein Datenbyte aus dem Digital-Thermometer.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		Datenwort
;veränderte Register:	CCR, R3
;------------------------------------------------------------------------------
					;
RECEIVE_DATA:
	MOVB	#8,R3			;
	JSR	SREAD			;
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
	BSET	CE_DIR,_CE		;CE-Pin auf Ausgang schalten

 if fEnabled == _high
	BCLR	CE_PORT,_CE		;_CE:		Out = 0 : Bauteil deaktivieren
 else
	BSET	CE_PORT,_CE		;_CE:		Out = 1 : Bauteil deaktivieren
 endif
					;
	BSET	SCLK_DIR,_SCLK		;SCLK-Pin auf Ausgang schalten
	BCLR	SCLK_PORT,_SCLK		;SCLK:		Out= 0
	BSET	MOSI_DIR,_MOSI		;MOSI-Pin auf Ausgang schalten
	BCLR	MOSI_PORT,_MOSI		;MOSI:		Out= 0
	BCLR	MISO_DIR,_MISO		;MISO-Pin auf Eingang schalten
					;MISO:		In
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: SDT_READ_CONFIG liest die Konfigurationdaten aus dem Thermometer.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0		Byte mit aktuellen Konfigurationsdaten
;veränderte Register:	CCR, A, R3
;//////////////////////////////////////////////////////////////////////////////
					;
SDT_READ_CONFIG:
	LDAA	#CMD_READ_CONFIG	;
					;
 if fEnabled == _high
	BSET	CE_PORT,_CE		;Bauteil selektieren
 else
	BCLR	CE_PORT,_CE		;Bauteil selektieren
 endif
					;
	JSR	SUBMIT_COMMAND		;
	JSR	RECEIVE_DATA		;Datenbyte lesen
	STAA	R0			;
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
;Public: SDT_READ_VALUE liest den aktuellen Messwert aus dem Thermometer.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0/R1		Datenwort
;veränderte Register:	CCR, A, R3
;//////////////////////////////////////////////////////////////////////////////
					;
SDT_READ_VALUE:
	LDAA	#CMD_READ_VALUE_LOW	;
					;
 if fEnabled == _high
	BSET	CE_PORT,_CE		;Bauteil selektieren
 else
	BCLR	CE_PORT,_CE		;Bauteil selektieren
 endif
					;
	JSR	SUBMIT_COMMAND		;
	JSR	RECEIVE_DATA		;Datenbyte lesen
	STAA	R1			;
					;
 if fEnabled == _high
	BCLR	CE_PORT,_CE		;Bauteil deaktivieren
 else
	BSET	CE_PORT,_CE		;Bauteil deaktivieren
 endif
					;
	LDAA	#CMD_READ_VALUE_HIGH	;
					;
 if fEnabled == _high
	BSET	CE_PORT,_CE		;Bauteil selektieren
 else
	BCLR	CE_PORT,_CE		;Bauteil selektieren
 endif
					;
	JSR	SUBMIT_COMMAND		;
	JSR	RECEIVE_DATA		;Datenbyte lesen
	STAA	R0			;
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
;Public: SDT_WRITE_CONFIG schreibt neue Konfigurationsdaten in das Thermometer.
;
;Eingangsparameter:	R0		Byte mit neuen Konfigurationsdaten
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, R3
;//////////////////////////////////////////////////////////////////////////////
					;
SDT_WRITE_CONFIG:
	LDAA	#CMD_WRITE_CONFIG	;
					;
 if fEnabled == _high
	BSET	CE_PORT,_CE		;Bauteil selektieren
 else
	BCLR	CE_PORT,_CE		;Bauteil selektieren
 endif
					;
	JSR	SUBMIT_COMMAND		;
	LDAA	R0			;
	JSR	SEND_DATA		;Konfigurationsdaten übertragen
					;
 if fEnabled == _high
	BCLR	CE_PORT,_CE		;Bauteil deaktivieren
 else
	BSET	CE_PORT,_CE		;Bauteil deaktivieren
 endif
					;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
