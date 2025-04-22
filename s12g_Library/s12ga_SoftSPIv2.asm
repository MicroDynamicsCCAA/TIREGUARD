	include	"s12ga_240.sfr"
	include	"s12ga_SoftSPIv2.sfr"
	title	"s12ga_SoftSPIv2  Copyright (C) 2009-2016, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_SoftSPIv2.asm
;
;Copyright:	(C) 2009-2016, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	05.10.2016
;
;Description:	Funktionen für die serielle SPI-Kommunikation
;
;Folgende Bezeichner sind in s12ga_SoftSPIv2.sfr zu definieren:
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
;02.10.2016	In Register R10 wird in allen Funktionen eine _CS-Maske 
;		übergeben, die jeweils unverändert zurück gegeben wird.
;		Dadurch sind alle Funktionen nicht mehr parameterkompatibel zu
;		denen im Herkunftsmodul!
;
;28.09.2016	Anpassung an MC9S12GA240
;		Herkunft: s12p_SoftSPI.asm
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
;
;begin 02.10.2016
;Eingangsparameter:	R10		_CS-Maske
;Ausgangsparameter:	R10		_CS-Maske bleibt unverändert
;end
;
;veränderte Register:	CCR
;//////////////////////////////////////////////////////////////////////////////
					;
SPI_RESET:
;
;begin 02.10.2016
	LDAA	CS_DIR			;
	ORAA	R10			;CS-Pin auf Ausgang schalten
	STAA	CS_DIR			;
	LDAA	CS_PORT			;
	ORAA	R10			;CS:		Out= 1
	STAA	CS_PORT			;
;end
;					;
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
;
;begin 02.10.2016
;Eingangsparameter:	R10		_CS-Maske bleibt unverändert
;end
;
;Ausgangsparameter:	R0/R1		gelesenes Datenwort, rechtsbündig
;
;begin 02.10.2016
;			R10		_CS-Maske bleibt unverändert
;end
;
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
;
;begin 02.10.2016
;			R10		_CS-Maske
;end
;
;Ausgangsparameter:	R0/R1		gelesene Daten, rechtsbündig
;
;begin 02.10.2016
;			R10		_CS-Maske bleibt unverändert
;end
;
;veränderte Register:	CCR, A, B
;//////////////////////////////////////////////////////////////////////////////
					;
SPI_READ:
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
;
;begin 05.10.2016
	LDAA	R10			;
	EORA	#0FFh			;
	ANDA	CS_PORT			;
	STAA	CS_PORT			;Bauteil selektieren
;end
;
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
;
;begin 05.10.2016
	STD	R0			;
					;
	LDAA	R10			;
	ORAA	CS_PORT			;
	STAA	CS_PORT			;danach Bauteil deaktivieren
;end
;
	RTS				;
					;
;------------------------------------------------------------------------------
;SPI_WRITE16 schreibt ein Datenwort und liest gleichzeitig ein Antwort-Datenwort.
;
;Eingangsparameter:	R0/R1		zu schreibendes Datenwort, linksbündig
;
;begin 02.10.2016
;			R10		_CS-Maske
;end
;
;Ausgangsparameter:	R0/R1		gelesenes Datenwort, rechtsbündig
;
;begin 02.10.2016
;			R10		_CS-Maske bleibt unverändert
;end
;
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
;Eingangsparameter:	R0/R1		zu schreibende Daten, linksbündig
;			R3              Anzahl der zu übertragenden bits
;
;begin 02.10.2016
;			R10		_CS-Maske
;end
;
;Ausgangsparameter:	R0/R1		gelesene Daten, rechtsbündig
;
;begin 02.10.2016
;			R10		_CS-Maske bleibt unverändert
;end
;
;veränderte Register:	CCR, A, B
;//////////////////////////////////////////////////////////////////////////////
					;
SPI_WRITE:
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
;
;begin 05.10.2016
	LDAA	R10			;
	EORA	#0FFh			;
	ANDA	CS_PORT			;
	STAA	CS_PORT			;Bauteil selektieren
					;
	LDD	R0			;
;end
;
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
	LBNE	SPI_WRITE1		;  bis alle bits übertragen
					;
;
;begin 05.10.2016
	STD	R0			;
					;
	LDAA	R10			;
	ORAA	CS_PORT			;
	STAA	CS_PORT			;danach Bauteil deaktivieren
;end
;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
