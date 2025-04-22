	include	"s12c_128.sfr"
	include	"s12c_SoftSPI.sfr"
	title	"s12c_FM25256B  Copyright (C) 2009, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_FM25256B.asm
;
;Copyright:	(C) 2009, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	22.06.2009
;
;Description:	Funktionen für den Zugriff auf ein oder mehrere über SPI
;		angeschlossene 32Kx8 FRAM RAMTRON FM25256B.
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
;16.06.2009	Funktion TRANSMIT_BYTE korrigiert
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref.b	FRAM_DEVICE_CT		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	FRAM_BLOCKREAD		;Code
	xdef	FRAM_BLOCKWRITE		;Code
	xdef	FRAM_READ_STATUS	;Code
	xdef	FRAM_RESET		;Code
	xdef	FRAM_WRITE_ENABLE	;Code
	xdef	FRAM_WRITE_DISABLE	;Code
	xdef	FRAM_WRITE_STATUS	;Code
					;
	xdef	E_FRAM_RANGE		;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
E_FRAM_RANGE:		equ	-6
					;
CMD_WREN:		equ	06h	;
CMD_WRDI:		equ	04h	;
CMD_RDSR:		equ	05h	;
CMD_WRSR:		equ	01h	;
CMD_READ:		equ	03h	;
CMD_WRITE:		equ	02h	;

;------------------------------------------------------------------------------
;C_FRAM_SIZE gibt die Größe eines Speicherbausteines in Anzahl der Datenbytes an.
;Zur Anpassung an andere Speichergrößen ist dieser Wert entsprechend zu ändern.
;------------------------------------------------------------------------------
					;
C_FRAM_SIZE:	equ	32768		;32K-Bytes Speichergröße
					;
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
FRAM_RESET:
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
;//////////////////////////////////////////////////////////////////////////////
;TRANSMIT_BYTE überträgt ein Byte über die SPI-Schnittstelle.
;
;Die Taktfrequenz beträgt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;
;Eingangsparameter:	A		zu sendendes Datenbyte
;Ausgangsparameter:	A		empfangenes Datenbyte
;veränderte Register:	CCR, B
;//////////////////////////////////////////////////////////////////////////////
					;
TRANSMIT_BYTE:
	LDAB	#8			;8 bits übertragen
TRANSMIT_BYTE1:
	LSLA				;Datenbyte um ein bit nach links schieben
	BCC	TRANSMIT_BYTE2		;wenn zu schreibendes bit gesetzt,
	BSET	MOSI_PORT,_MOSI		;dann Sendeleitung auf '1'
	BRA	TRANSMIT_BYTE3		;
TRANSMIT_BYTE2:
	BCLR	MOSI_PORT,_MOSI		;sonst Sendeleitung auf '0'
	NOP				;
TRANSMIT_BYTE3:
	BSET	SCLK_PORT,_SCLK		;Takt auf '1' zur Übernahme des nächsten bits
	NOP				;wenn gelesenes bit gesetzt
	BRCLR	MISO_PORT,_MISO,TRANSMIT_BYTE4
	ORAA	#00000001b		;dann '1' rechts in Datenbyte eintragen
	BRA	TRANSMIT_BYTE5		;
TRANSMIT_BYTE4:
	ANDA	#11111110b		;sonst '0' rechts in Datenbyte eintragen
TRANSMIT_BYTE5:
	BCLR	SCLK_PORT,_SCLK 	;Takt auf '0'
	DBNE	B,TRANSMIT_BYTE1	;weiter, bis alle bits übertragen
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;SUBMIT_COMMAND bearbeitet ein FRAM-Kommando.
;
;Die Taktfrequenz beträgt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;
;Eingangsparameter:	A		Kommando
;			R10		Schreib-/Leseflag
;			R0/R1		Aufrufparameter
;			(R8:)X		Quelladresse
;			(R9:)Y		Zieladresse
;			R2/R3		Anzahl Bytes
;Ausgangsparameter:	R0/R1		Rückgabewerte
;			(R8:)X		neue Quelladresse
;			(R9:)Y		neue Zieladresse
;			R2/R3		verbleibende Anzahl Bytes
;veränderte Register:	CCR, A, B
;//////////////////////////////////////////////////////////////////////////////
					;
SUBMIT_COMMAND:
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
	BCLR	CS_PORT,_CS		;Bauteil selektieren
					;
	JSR	TRANSMIT_BYTE		;Kommando senden
	LDD	R2			;
	SUBD	#1			;
	STD	R2			;
	BNE	SUBMIT_COMMAND1		;
	CLRA				;
	JMP	SUBMIT_COMMAND9		;
					;
SUBMIT_COMMAND1:
	LDAA	R0			;
	JSR	TRANSMIT_BYTE		;Adresse High Byte senden oder
	STAA	R0			;aktuellen Status empfangen oder
	LDD	R2			;neuen Status senden
	SUBD	#1			;
	STD	R2			;
	BNE	SUBMIT_COMMAND2		;
	CLRA				;
	JMP	SUBMIT_COMMAND9		;
					;
SUBMIT_COMMAND2:
	LDAA	R1			;
	JSR	TRANSMIT_BYTE		;Adresse Low Byte senden
	LDD	R2			;
	SUBD	#1			;
	STD	R2			;
	BNE	SUBMIT_COMMAND3		;
	CLRA				;
	JMP	SUBMIT_COMMAND9		;
					;
SUBMIT_COMMAND3:
	TST	R10			;wenn Schreibkommando,
	BEQ	SUBMIT_COMMAND31	;dann
	LDAA	1,X+			;  Byte von Quelladresse lesen
	INY				;  Zieladresse verschieben
SUBMIT_COMMAND31:
	JSR	TRANSMIT_BYTE		;Byte übertragen
	TST	R10			;wenn Lesekommando,
	BNE	SUBMIT_COMMAND32	;dann
	INX				;  Quelladresse verschieben
	STAA	1,Y+			;  Byte an Zieladresse schreiben

SUBMIT_COMMAND32:
	LDD	R2			;
	SUBD	#1			;Bytezähler decrementieren
	STD	R2			;
					;
	TST	R10			;wenn Schreibkommando
	BEQ	SUBMIT_COMMAND5		;dann
	CPY	#C_FRAM_SIZE		;
	BLO	SUBMIT_COMMAND6		;  wenn Offset der Zieladresse > Speicherchipgröße,
	LDY	#0			;  dann
	LDAA	R9			;    Offset auf Null setzen
	INCA				;    Page incrementieren
	CMPA	#FRAM_DEVICE_CT		;    wenn Page > Speicherchipanzahl,
	BLO	SUBMIT_COMMAND41	;    dann
	CLRA				;      Page auf Null setzen
SUBMIT_COMMAND41:
	STAA	R9			;
	JMP	SUBMIT_COMMAND9		;    Schreibvorgang abbrechen
					;
SUBMIT_COMMAND5:
	CPX	#C_FRAM_SIZE		;sonst
	BLO	SUBMIT_COMMAND6		;  wenn Offset der Leseadresse > Speicherchipgröße,
	LDX	#0			;  dann
	LDAA	R8			;    Offset auf Null setzen
	INCA				;    Page incrementieren
	CMPA	#FRAM_DEVICE_CT		;    wenn Page > Speicherchipanzahl,
	BLO	SUBMIT_COMMAND51	;    dann
	CLRA				;      Page auf Null setzen
SUBMIT_COMMAND51:
	STAA	R8			;
	JMP	SUBMIT_COMMAND9		;    Lesevorgang abbrechen
					;
SUBMIT_COMMAND6:
	LDD	R2			;weiter, bis alles übertragen
	BNE	SUBMIT_COMMAND3		;
	CLRA				;
					;
SUBMIT_COMMAND9:
	BSET	CS_PORT,_CS		;danach Bauteil deaktivieren
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FRAM_WRITE_ENABLE
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, R[2..3]
;------------------------------------------------------------------------------
					;
FRAM_WRITE_ENABLE:
	MOVW	#1,R2			;
	LDAA	#CMD_WREN		;Kommando
	JSR	SUBMIT_COMMAND		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FRAM_WRITE_DISABLE
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, R[2..3]
;------------------------------------------------------------------------------
					;
FRAM_WRITE_DISABLE:
	MOVW	#1,R2			;
	LDAA	#CMD_WRDI		;Kommando
	JSR	SUBMIT_COMMAND		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FRAM_READ_STATUS
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0		Status
;			A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, R[0..3]
;------------------------------------------------------------------------------
					;
FRAM_READ_STATUS:
	MOVW	#2,R2			;
	MOVB	#0FFh,R0		;
	LDAA	#CMD_RDSR		;Kommando
	JSR	SUBMIT_COMMAND		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FRAM_WRITE_STATUS
;
;Eingangsparameter:	R0		Status
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, R[0..3]
;------------------------------------------------------------------------------
					;
FRAM_WRITE_STATUS:
	JSR	FRAM_WRITE_ENABLE	;Schreibfreigabe
					;
	MOVW	#2,R2			;
	LDAA	#CMD_WRSR		;Kommando
	JSR	SUBMIT_COMMAND		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FRAM_BLOCKREAD liest Daten aus dem FRAM-Speicher in einen Puffer.
;
;Eingangsparameter:	R8:X		Quelladresse
;			Y		Zieladresse
;			R2/R3		Anzahl Bytes
;Ausgangsparameter:	R8:X		neue Quelladresse
;			Y		neue Zieladresse
;			R2/R3		verbleibende Anzahl Bytes
;			A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, A, B, R[0..1,10]
;------------------------------------------------------------------------------
					;
FRAM_BLOCKREAD:
	LDD	R2			;wenn Byteanzahl = 0,
	BEQ	FRAM_BLOCKREAD9		;dann ok und schon fertig
					;
FRAM_BLOCKREAD1:
	ADDD	#3			;drei Bytes für
	STD	R2			;Kommando und Quelladresse berücksichtigen
	STX	R0			;Offset der Quelladresse
	LDAA	#CMD_READ		;Kommando
	MOVB	#0,R10			;Lesemerker
	JSR	SUBMIT_COMMAND		;
	LDD	R2			;wenn Bytezähler > 0,
	BEQ	FRAM_BLOCKREAD9		;dann
	LDAA	#E_FRAM_RANGE		;  mit E_FRAM_RANGE zurück
					;
FRAM_BLOCKREAD9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FRAM_BLOCKWRITE schreibt Daten aus einem Puffer in den FRAM-Speicher.
;
;Eingangsparameter:	X		Quelladresse
;			R9:Y		Zieladresse
;			R2/R3		Anzahl Bytes
;Ausgangsparameter:	X		neue Quelladresse
;			R9:Y		neue Zieladresse
;			R2/R3		verbleibende Anzahl Bytes
;			A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, A, B, R[0..1,10..11]
;------------------------------------------------------------------------------
					;
FRAM_BLOCKWRITE:
	LDD	R2			;wenn Byteanzahl = 0,
	BEQ	FRAM_BLOCKWRITE9	;dann ok und schon fertig
					;
FRAM_BLOCKWRITE1:
	ADDD	#3			;drei Bytes für
	STD	R2			;Kommando und Zieladresse berücksichtigen
					;
	MOVW	R2,R10			;
	JSR	FRAM_WRITE_ENABLE	;Schreibfreigabe
	MOVW	R10,R2			;
					;
	STY	R0			;Offset der Zieladresse
	LDAA	#CMD_WRITE		;Kommando
	MOVB	#0FFh,R10		;Schreibmerker
	JSR	SUBMIT_COMMAND		;
	LDD	R2			;wenn Bytezähler > 0,
	BEQ	FRAM_BLOCKWRITE9	;dann
	LDAA	#E_FRAM_RANGE		;  mit E_FRAM_RANGE zurück
					;
FRAM_BLOCKWRITE9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
