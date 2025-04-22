	include	"s12c_128.sfr"
	include	"s12c_SoftSPI.sfr"
	title	"s12c_SoftSPI  Copyright (C) 2009, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_SoftSPI.asm
;
;Copyright:	(C) 2009, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	24.05.2009
;
;Description:	Funktionen für die serielle SPI-Kommunikation
;
;Folgende Bezeichner sind in s12c_SoftSPI.sfr zu definieren:
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
;Revision History:	Original Version  04.09
;
;21.05.2009	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	SPI_RESET		;Code
	xdef	SPI_READ16		;Code
	xdef	SPI_WRITE16		;Code
					;
.text:		section
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: SPI_RESET bringt Daten- und Taktleitungen der SPI-Schnittstelle
;in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;//////////////////////////////////////////////////////////////////////////////
					;
SPI_RESET:
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
;SPI_READ16 liest ein Datenwort.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0/R1		gelesenes Datenwort, rechtsbündig
;veränderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
SPI_READ16:
	MOVB	#16,R3			;
					;
;//////////////////////////////////////////////////////////////////////////////
;SPI_READ liest Daten seriell über die SPI-Schnittstelle.
;
;Die Taktfrequenz beträgt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;
;Eingangsparameter:	R3		Anzahl zu übertragender bits
;Ausgangsparameter:	R0/R1		gelesene Daten, rechtsbündig
;veränderte Register:	CCR, A, B
;//////////////////////////////////////////////////////////////////////////////
					;
SPI_READ:
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
	BCLR	CS_PORT,_CS		;Bauteil selektieren
	LDD	#0			;Ergebnisregister fegen
					;
SPI_READ_1:
	BSET	SCLK_PORT,_SCLK		;Takt auf '1'
	LSLD				;Ergebnis um ein bit nach links schieben
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0' zur Übernahme des bits
	BRCLR	MISO_PORT,_MISO,SPI_READ_2
					;wenn bit gesetzt
	ORAB	#00000001b		;dann '1' in gelesene Daten eintragen
	BRA	SPI_READ_3		;
SPI_READ_2:
	ANDB	#11111110b		;sonst '0' in gelesene Daten eintragen
SPI_READ_3:
	DEC	R3			;weiter,
	BNE	SPI_READ_1		;  bis alle bits übertragen
					;
	BSET	CS_PORT,_CS		;danach Bauteil deaktivieren
	STD	R0			;
	RTS				;
					;
;------------------------------------------------------------------------------
;SPI_WRITE16 schreibt ein Datenwort und liest gleichzeitig ein Antwort-Datenwort.
;
;Eingangsparameter:	R0/R1		zu schreibendes Datenwort, linksbündig
;Ausgangsparameter:	R0/R1		gelesenes Datenwort, rechtsbündig
;veränderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
SPI_WRITE16:
	MOVB	#16,R3			;
					;
;//////////////////////////////////////////////////////////////////////////////
;SPI_WRITE schreibt Daten seriell über die SPI-Schnittstelle.
;
;Die Taktfrequenz beträgt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;
;Eingangsparameter:	R3              Anzahl der zu übertragenden bits
;			R0/R1		zu schreibende Daten, linksbündig
;Ausgangsparameter:	R0/R1		gelesene Daten, rechtsbündig
;veränderte Register:	CCR, A, B
;//////////////////////////////////////////////////////////////////////////////
					;
SPI_WRITE:
	LDD	R0			;
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
	BCLR	CS_PORT,_CS		;Bauteil selektieren
					;
SPI_WRITE1:
	LSLD				;Daten um ein bit nach links schieben
	BCC	SPI_WRITE2		;wenn CARRY
	BSET	MOSI_PORT,_MOSI		;dann Sendeleitung auf '1'
	BRA	SPI_WRITE3		;
SPI_WRITE2:
	BCLR	MOSI_PORT,_MOSI		;sonst Sendeleitung auf '0'
	NOP				;
SPI_WRITE3:
	BSET	SCLK_PORT,_SCLK		;Takt auf '1' zur Übernahme des zu schreibenden bits
	NOP				;
	BCLR	SCLK_PORT,_SCLK 	;Takt auf '0'
	BRCLR	MISO_PORT,_MISO,SPI_WRITE4
					;wenn gelesenes bit gesetzt
	ORAB	#00000001b		;dann '1' in gelesene Daten eintragen
	BRA	SPI_WRITE5		;
SPI_WRITE4:
	ANDB	#11111110b		;sonst '0' in gelesene Daten eintragen
SPI_WRITE5:
	DEC	R3			;weiter,
	BNE	SPI_WRITE1		;  bis alle bits übertragen
					;
	BSET	CS_PORT,_CS		;danach Bauteil deaktivieren
	STD	R0			;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
