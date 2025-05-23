	include	"s12ga_240.sfr"
	include	"s12ga_Switches.sfr"
	include	"s12ga_MPL115A1.sfr"
	title	"s12ga_MPL115A1  Copyright (C) 2011-2014, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_MPL115A1.asm
;
;Copyright:	(C) 2011-2014, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	30.11.2014
;
;Description:	Funktionen f�r den Zugriff auf das serielle Digital-Barometer
;		vom Typ Freescale MPL115A1
;		Das Barometer-Bauelement wird im 4-Wire Modus betrieben.
;		Das bedeutet, dass Daten vom Bauelement jeweils mit steigender
;		Flanke des SCLK-Taktes gelesen und mit dessen fallender Flanke
;		geschrieben werden.
;
;Folgende Bezeichner sind in s12ga_MPL115A1.sfr zu definieren:
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
;Revision History:	Original Version  01.11
;
;30.11.2014	Anpassung an MC9S12GA240
;		Herkunft: s12xep_MPL115A1_s.asm
;		SHIFT_LEFT,
;		SHIFT_RIGHT,
;		CALCULATE_PRESSURE: Anpassung an HCS12- statt HCS12X-Befehlssatz
;
;12.01.2011	Urfassung
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	MUL3216S		;Code
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	MPL_READ_VALUES		;Code
	xdef	MPL_RESET		;Code
					;
	xdef	MPL_NOVALUE		;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
CMD_READ_POUTH:		equ	80h	;
CMD_READ_POUTL:		equ	82h	;
CMD_READ_TOUTH:		equ	84h	;
CMD_READ_TOUTL:		equ	86h	;
CMD_READ_COEF1:		equ	88h	;
CMD_READ_COEF2:		equ	8Ah	;
CMD_READ_COEF3:		equ	8Ch	;
CMD_READ_COEF4:		equ	8Eh	;
CMD_READ_COEF5:		equ	90h	;
CMD_READ_COEF6:		equ	92h	;
CMD_READ_COEF7:		equ	94h	;
CMD_READ_COEF8:		equ	96h	;
CMD_READ_COEF9:		equ	98h	;
CMD_READ_COEF10:	equ	9Ah	;
CMD_READ_COEF11:	equ	9Ch	;
CMD_READ_COEF12:	equ	9Eh	;
					;
CMD_START_PRESS_CONV:	equ	20h	;
CMD_START_TEMP_CONV:	equ	22h	;
CMD_START_BOTH_CONVS:	equ	24h	;
					;
MPL_NOVALUE:		equ	8000h	;
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:
MPL_FLAGS:	ds.b	1		;Flags
_COEFF_LOADED:	equ	bit0		;1, wenn Sensorkoeffizienten eingelesen sind
;
;
;
;
;
;
_CONV_STARTED:	equ	bit7		;1, nachdem Wandlung gestartet wurde
					;
		align	2

wPADC:		ds.w	1
wTADC:		ds.w	1
wPCOMP:		ds.w	1
wTCOMP:		ds.w	1
					;
MPL_COEFF_BUF:
					;
dwA0:
wA0H:		ds.w	1
wA0L:		ds.w	1
					;
dwB1:
wB1H:		ds.w	1
wB1L:		ds.w	1
					;
dwB2:
wB2H:		ds.w	1
wB2L:		ds.w	1
					;
dwC12:
wC12H:		ds.w	1
wC12L:		ds.w	1
					;
dwC11:
wC11H:		ds.w	1
wC11L:		ds.w	1
					;
dwC22:
wC22H:		ds.w	1
wC22L:		ds.w	1
					;
MPL_COEFF_BUF_CNT:	equ	(* - MPL_COEFF_BUF)
					;
RESULTA:	ds.l	2
RESULTB:	ds.l	2
RESULTC:	ds.l	2
					;
		even
TOV:
					;
.text:		section
					;
;//////////////////////////////////////////////////////////////////////////////
;SPI_READ liest Daten seriell aus dem Digital-Barometer.
;
;Die Taktfrequenz betr�gt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;Das Bauelement erlaubt maximal 8 MHz bei 2,35..5,5 V.
;
;Eingangsparameter:	A		Kommando
;Ausgangsparameter:	B		gelesene Daten, rechtsb�ndig
;ver�nderte Register:	CCR, R3
;//////////////////////////////////////////////////////////////////////////////
					;
SPI_READ:
	LDAB	#0FFh			;
	MOVB	#16,R3			;
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
	BCLR	CS_PORT,_CS		;Bauteil selektieren
					;
SPI_READ_1:
	LSLD				;Ergebnis um ein bit nach links schieben
	BCC	SPI_READ_12		;wenn CARRY
	BSET	MOSI_PORT,_MOSI		;dann Sendeleitung auf '1'
	BRA	SPI_READ_13		;
SPI_READ_12:
	BCLR	MOSI_PORT,_MOSI		;sonst Sendeleitung auf '0'
	NOP				;
SPI_READ_13:
	BSET	SCLK_PORT,_SCLK		;Takt auf '1' zur �bernahme des bits
	BRCLR	MISO_PORT,_MISO,SPI_READ_2
					;wenn bit gesetzt
	ORAB	#00000001b		;dann '1' in gelesene Daten eintragen
	BRA	SPI_READ_3		;
SPI_READ_2:
	ANDB	#11111110b		;sonst '0' in gelesene Daten eintragen
SPI_READ_3:
	BCLR	SCLK_PORT,_SCLK		;Takt auf '0'
	DEC	R3			;weiter,
	BNE	SPI_READ_1		;  bis alle bits �bertragen
					;
	BSET	CS_PORT,_CS		;Bauteil deaktivieren
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;SPI_WRITE schreibt Daten seriell in das Digital-Barometer.
;
;Die Taktfrequenz betr�gt ca. 1,0 MHz bei 24,0 MHz Bustakt.
;Das Bauelement erlaubt maximal 8 MHz bei 2,35..5,5 V.
;
;Eingangsparameter:	A		Kommando
;			B		zu schreibende Daten, rechtsb�ndig
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR, R3
;//////////////////////////////////////////////////////////////////////////////
					;
SPI_WRITE:
	MOVB	#16,R3			;
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
	BSET	SCLK_PORT,_SCLK		;Takt auf '1' zur �bernahme des bits
	NOP				;
	BCLR	SCLK_PORT,_SCLK 	;Takt auf '0'
	DEC	R3			;weiter,
	BNE	SPI_WRITE1		;  bis alle bits �bertragen
					;
	BSET	CS_PORT,_CS		;Bauteil deaktivieren
	RTS				;
					;
;------------------------------------------------------------------------------
;SHIFT_LEFT32 schiebt einen 32-bit Wert nach links.
;
;Eingangsparameter:	Y		Zeiger auf 32-bit Wert
;			B		Anzahl der Schiebeschritte
;Ausgangsparameter:	Y		bleibt unver�ndert
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
SHIFT_LEFT32:
	ASL	3,Y			;
	ROL	2,Y			;
	ROL	1,Y			;
	ROL	0,Y			;
	DBNE	B,SHIFT_LEFT32		;
	RTS				;
					;
;------------------------------------------------------------------------------
;SHIFT_RIGHT32 schiebt einen 32-bit Wert nach rechts.
;
;Eingangsparameter:	Y		Zeiger auf 32-bit Wert
;			B		Anzahl der Schiebeschritte
;Ausgangsparameter:	Y		bleibt unver�ndert
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
SHIFT_RIGHT32:
	ASR	0,Y			;
	ROR	1,Y			;
	ROR	2,Y			;
	ROR	3,Y			;
	DBNE	B,SHIFT_RIGHT32		;
	RTS				;
					;
;------------------------------------------------------------------------------
;READ_COEFFICIENTS liest die f�r die Kompensationsberechnung erforderlichen
;Koeffizienten aus dem Sensorspeicher und legt sie umformatiert im RAM ab.
;
;Eingangsparameter:	keine
;Ausgangsparameter:     MPL_FLAGS._LOADED
;			MPL_COEFF_BUF
;ver�nderte Register:	CCR, A, B, Y, R3
;------------------------------------------------------------------------------
					;
READ_COEFFICIENTS:
	LDY	#MPL_COEFF_BUF		;
	LDAB	#MPL_COEFF_BUF_CNT	;
	LDAA	#0FFh			;
READ_COEFFICIENTS1:
	STAA	1,Y+			;Koeffizientenbuffer fegen
	DBNE	B,READ_COEFFICIENTS1	;
					;
	MOVB	#3,R3			;
READ_COEFFICIENTS2:
	LDAA	#CMD_READ_COEF2		;
	JSR	SPI_READ		;
	STAB	dwA0+1			;pr�fen, ob Sensor aktiv ist
	LDAA	#CMD_READ_COEF1		;
	JSR	SPI_READ		;
	STAB	dwA0+0			;
	CPD	#0			;ein g�ltiger dwA0-Wert ist stets ungleich Null (!)
	BNE	READ_COEFFICIENTS3	;
	DEC	R3			;
	BNE	READ_COEFFICIENTS2	;
	LBRA	READ_COEFFICIENTS9	;
					;
READ_COEFFICIENTS3:
					;
;------------------------------------------------------------------------------
; a0
;
	LDAA	#CMD_READ_COEF2		;
	JSR	SPI_READ		;
	STAB	dwA0+1			;
	LDAA	#CMD_READ_COEF1		;
	JSR	SPI_READ		;
	STAB	dwA0+0			;
	LDD	#0			;
	STD	dwA0+2			;
	LDY	#dwA0			;
	LDAB	#3			;3 mal rechts schieben
	JSR	SHIFT_RIGHT32		;dwA0 : 16,16
					;
;------------------------------------------------------------------------------
; b1
;
	LDAA	#CMD_READ_COEF4		;
	JSR	SPI_READ		;
	STAB	dwB1+3			;
	LDAA	#CMD_READ_COEF3		;
	JSR	SPI_READ		;
	STAB	dwB1+2			;
	ANDB	#10000000b		;
	BNE	B1_NEG			;
	LDD	#0000h			;
	BRA	B1_POS			;
B1_NEG:
	LDD	#0FFFFh			;
B1_POS:
	STD	dwB1+0			;
	LDY	#dwB1			;
	LDAB	#3			;3 mal links schieben
	JSR	SHIFT_LEFT32		;dwB1 : 16,16
					;
;------------------------------------------------------------------------------
; b2
;
	LDAA	#CMD_READ_COEF6		;
	JSR	SPI_READ		;
	STAB	dwB2+3			;
	LDAA	#CMD_READ_COEF5		;
	JSR	SPI_READ		;
	STAB	dwB2+2			;
	ANDB	#10000000b		;
	BNE	B2_NEG			;
	LDD	#0000h			;
	BRA	B2_POS			;
B2_NEG:
	LDD	#0FFFFh			;
B2_POS:
	STD	dwB2+0			;
	LDY	#dwB2			;
	LDAB	#2			;2 mal links schieben
	JSR	SHIFT_LEFT32		;dwB2 : 16,16
					;
;------------------------------------------------------------------------------
; c12
;
	LDAA	#CMD_READ_COEF8		;
	JSR	SPI_READ		;
	STAB	dwC12+3			;
	LDAA	#CMD_READ_COEF7		;
	JSR	SPI_READ		;
	STAB	dwC12+2			;
	ANDB	#10000000b		;
	BNE	C12_NEG			;
	LDD	#0000h			;
	BRA	C12_POS			;
C12_NEG:
	LDAB	dwC12+2			;
	ANDB	#01111111b		;
	STAB	dwC12+2			;
	LDD	#0FF00h			;
C12_POS:
	STD	dwC12+0			;dwC12 : 8,24
					;
;------------------------------------------------------------------------------
; c11
;
	LDAA	#CMD_READ_COEF10	;
	JSR	SPI_READ		;
	STAB	dwC11+3			;
	LDAA	#CMD_READ_COEF9		;
	JSR	SPI_READ		;
	STAB	dwC11+2			;
	ANDB	#10000000b		;
	BNE	C11_NEG			;
	LDD	#0000h			;
	BRA	C11_POS			;
C11_NEG:
	LDAB	dwC11+2			;
	ANDB	#01111111b		;
	STAB	dwC11+2			;
	LDD	#0FF00h			;
C11_POS:
	STD	dwC11+0			;
	LDD	dwC11+2			;
	LSRD				;
	LSRD				;
	STD	dwC11+2			;dwC11 : 8,24
					;
;------------------------------------------------------------------------------
; c22
;
	LDAA	#CMD_READ_COEF12	;
	JSR	SPI_READ		;
	STAB	dwC22+3			;
	LDAA	#CMD_READ_COEF11	;
	JSR	SPI_READ		;
	STAB	dwC22+2			;
	ANDB	#10000000b		;
	BNE	C22_NEG			;
	LDD	#0000h			;
	BRA	C22_POS			;
C22_NEG:
	LDAB	dwC22+2			;
	ANDB	#01111111b		;
	STAB	dwC22+2			;
	LDD	#0FF00h			;
C22_POS:
	STD	dwC22+0			;
	LDD	dwC22+2			;
	LSRD				;
	LSRD				;
	LSRD				;
	LSRD				;
	LSRD				;
	LSRD				;
	STD	dwC22+2			;dwC22 : 8,24
					;
	BSET	MPL_FLAGS,_COEFF_LOADED	;
					;
READ_COEFFICIENTS9:
	RTS				;
					;
;------------------------------------------------------------------------------
;CALCULATE_PRESSURE berechnet aus Druck- und Temperaturmesswert den 
;kompensierten Umgebungsluftdruckwert.
;Berechnungsvorschrift (siehe Datenblatt):
;wPCOMP:= a0 + (b1 + c11 * wPADC + c12 * wTADC) * wPADC + (b2 + c22 * wTADC) * wTADC
;
;Eingangsparameter:	wPADC
;			wTADC
;Ausgangsparameter:	wPCOMP		kompensierter Umgebungsluftdruckwert
;ver�nderte Register:	CCR, A, B, X, Y, R[0..7]
;------------------------------------------------------------------------------
					;
CALCULATE_PRESSURE:

;------------------------------------------------------------------------------
; 1. Teil: RESULTA:= b1 + c11 * wPADC + c12 * wTADC
;
	MOVB	#0,RESULTA+7		;RESULTA:= b1
	MOVW	wB1L,RESULTA+5		;
	MOVW	wB1H,RESULTA+3		;
	TST	RESULTA+3		;
	BPL	EXPAND_B1_1		;
	MOVW	#0FFFFh,RESULTA+1	;
	MOVB	#0FFh,RESULTA+0		;
	BRA	EXPAND_B1_2		;
EXPAND_B1_1:
	MOVW	#0,RESULTA+1		;
	MOVB	#0,RESULTA+0		;
EXPAND_B1_2:
					;
	MOVW	wC11H,R0		;
	MOVW	wC11L,R2		;
	MOVW	wPADC,R6		;
	JSR	MUL3216S		;
	LDD	R6			;
	ADDD	RESULTA+6		;RESULTA:= RESULTA + c11 * PADC
	STD	RESULTA+6		;
	LDD	R4			;
	ADCB	RESULTA+5		;
	ADCA	RESULTA+4		;
	STD	RESULTA+4		;
	LDD	R2			;
	ADCB	RESULTA+3		;
	ADCA	RESULTA+2		;
	STD	RESULTA+2		;
	LDD	R0			;
	ADCB	RESULTA+1		;
	ADCA	RESULTA+0		;
	STD	RESULTA+0		;
					;
	MOVW	wC12H,R0		;
	MOVW	wC12L,R2		;
	MOVW	wTADC,R6		;
	JSR	MUL3216S		;
	LDD	R6			;
	ADDD	RESULTA+6		;RESULTA:= RESULTA + c12 * TADC
	STD	RESULTA+6		;
	LDD	R4			;
	ADCB	RESULTA+5		;
	ADCA	RESULTA+4		;
	STD	RESULTA+4		;
	LDD	R2			;
	ADCB	RESULTA+3		;
	ADCA	RESULTA+2		;
	STD	RESULTA+2		;
	LDD	R0			;
	ADCB	RESULTA+1		;
	ADCA	RESULTA+0		;
	STD	RESULTA+0		;
					;
;------------------------------------------------------------------------------
; 2. Teil: RESULTB:= b2 + c22 * wTADC
;
	MOVB	#0,RESULTB+7		;RESULTB:= b2
	MOVW	wB2L,RESULTB+5		;
	MOVW	wB2H,RESULTB+3		;
	TST	RESULTB+3		;
	BPL	EXPAND_B2_1		;
	MOVW	#0FFFFh,RESULTB+1	;
	MOVB	#0FFh,RESULTB+0		;
	BRA	EXPAND_B2_2		;
EXPAND_B2_1:
	MOVW	#0,RESULTB+1		;
	MOVB	#0,RESULTB+0		;
EXPAND_B2_2:
					;
	MOVW	wC22H,R0		;
	MOVW	wC22L,R2		;
	MOVW	wTADC,R6		;
	JSR	MUL3216S		;
	LDD	R6			;
	ADDD	RESULTB+6		;RESULTB:= RESULTB + c22 * TADC
	STD	RESULTB+6		;
	LDD	R4			;
	ADCB	RESULTB+5		;
	ADCA	RESULTB+4		;
	STD	RESULTB+4		;
	LDD	R2			;
	ADCB	RESULTB+3		;
	ADCA	RESULTB+2		;
	STD	RESULTB+2		;
	LDD	R0			;
	ADCB	RESULTB+1		;
	ADCA	RESULTB+0		;
	STD	RESULTB+0		;
					;
;------------------------------------------------------------------------------
; 3. Teil: RESULTC:= a0 + RESULTA * wPADC + RESULTB * wTADC
;
	MOVB	#0,RESULTC+7		;RESULTC:= a0
	MOVW	wA0L,RESULTC+5		;
	MOVW	wA0H,RESULTC+3		;
	TST	RESULTC+3		;
	BPL	EXPAND_A0_1		;
	MOVW	#0FFFFh,RESULTC+1	;
	MOVB	#0FFh,RESULTC+0		;
	BRA	EXPAND_A0_2		;
EXPAND_A0_1:
	MOVW	#0,RESULTC+1		;
	MOVW	#0,RESULTC+0		;
EXPAND_A0_2:
					;
	MOVW	RESULTA+4,R0		;
	MOVW	RESULTA+6,R2		;
	MOVW	wPADC,R6		;
	JSR	MUL3216S		;
	LDD	R6			;
	ADDD	RESULTC+6		;RESULTC:= RESULTC + RESULTA * PADC
	STD	RESULTC+6		;
	LDD	R4			;
	ADCB	RESULTC+5		;
	ADCA	RESULTC+4		;
	STD	RESULTC+4		;
	LDD	R2			;
	ADCB	RESULTC+3		;
	ADCA	RESULTC+2		;
	STD	RESULTC+2		;
	LDD	R0			;
	ADCB	RESULTC+1		;
	ADCA	RESULTC+0		;
	STD	RESULTC+0		;
					;
	MOVW	RESULTB+4,R0		;
	MOVW	RESULTB+6,R2		;
	MOVW	wTADC,R6		;
	JSR	MUL3216S		;
	LDD	R6			;
	ADDD	RESULTC+6		;RESULTC:= RESULTC + RESULTB * TADC
	STD	RESULTC+6		;
	LDD	R4			;
	ADCB	RESULTC+5		;
	ADCA	RESULTC+4		;
	STD	RESULTC+4		;
	LDD	R2			;
	ADCB	RESULTC+3		;
	ADCA	RESULTC+2		;
	STD	RESULTC+2		;
	LDD	R0			;
	ADCB	RESULTC+1		;
	ADCA	RESULTC+0		;
	STD	RESULTC+0		;
					;
;------------------------------------------------------------------------------
; 4. Teil: Ergebnis runden und umskalieren
;
	LDD	RESULTC+3		;
	TST	RESULTC+5		;Nachkommastellen runden und abschneiden
	BPL	CALCULATE_PRESSURE8	;
	ADDD	#1			;
CALCULATE_PRESSURE8:
	LDY	#650			;Messbereich 50..115 kPa entsprechend 500..1150 mbar
	EMUL				;
	LDX	#1023			;10-bit Aufl�sung
	EDIV				;in Einheiten von 1,0 mbar umrechnen
	LSLD				;
	SUBD	#1023			;wenn Divisor > dem Zweifachen des Divisionsrestes
	BLO	CALCULATE_PRESSURE9	;dann
	INY				;  Quotient incrementieren (runden)
CALCULATE_PRESSURE9:
	TFR	Y,D			;
	ADDD	#500			;500 mbar Offset addieren
	STD	wPCOMP			;Ergebnis in wPCOMP ablegen
	RTS				;
					;
;------------------------------------------------------------------------------
;CALCULATE_TEMPERATURE berechnet den Temperaturwert.
;Berechnungsvorschrift (siehe Datenblatt):
;wTCOMP:= (472 - wTADC) * 8 / 5,35 + 200
;
;Eingangsparameter:	wTADC
;Ausgangsparameter:	wTCOMP		auf 0,125�C pro Increment umskalierter Temperaturwert
;ver�nderte Register:	CCR, A, B, X, Y, R[0..7]
;------------------------------------------------------------------------------
					;
CALCULATE_TEMPERATURE:
	LDD	#472			;Zahlenwert bei 25�C
	SUBD	wTADC			;minus Rohdatenwert
	STD	R6			;
	MOVW	#0001h,R0		;mal 97998 (= 8 * 65536 / 5,35)
	MOVW	#07ECEh,R2		;
	JSR	MUL3216S		;
	LDD	R4			;dividiert durch 65536
	TST	R6			;
	BPL	CALCULATE_TEMPERATURE1	;Nachkommastellen runden und abschneiden
	ADDD	#1			;
CALCULATE_TEMPERATURE1:
	ADDD	#200			;Offset addieren
	STD	wTCOMP			;Ergebnis in wTCOMP ablegen
	RTS				;
					;
;------------------------------------------------------------------------------
;READ_RAW_PRESSURE liest den Luftdruck-Rohdatenwert.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0/R1		Luftdruckwert
;ver�nderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
READ_RAW_PRESSURE:
	LDAA	#CMD_READ_POUTH		;
	JSR	SPI_READ		;
	STAB	R0			;
	LDAA	#CMD_READ_POUTL		;
	JSR	SPI_READ		;
	STAB	R1			;
					;
	LDD	R0			;
	LSRD				;
	LSRD				;
	LSRD				;Druckmesswert 6 mal nach rechts schieben
	LSRD				;
	LSRD				;
	LSRD				;
	STD	R0			;rechtsb�ndiges Ergebnis ablegen
	RTS				;
					;
;------------------------------------------------------------------------------
;READ_RAW_TEMPERATURE liest den Temperatur-Rohdatenwert.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0/R1		Temperaturwert
;ver�nderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
READ_RAW_TEMPERATURE:
	LDAA	#CMD_READ_TOUTH		;
	JSR	SPI_READ		;
	STAB	R0			;
	LDAA	#CMD_READ_TOUTL		;
	JSR	SPI_READ		;
	STAB	R1			;
					;
	LDD	R0			;
	LSRD				;
	LSRD				;
	LSRD				;Temperaturmesswert 6 mal nach rechts schieben
	LSRD				;
	LSRD				;
	LSRD				;
	STD	R0			;rechtsb�ndiges Ergebnis ablegen
	RTS				;
					;
;------------------------------------------------------------------------------
;START_CONVERSION aktiviert den Sensorbaustein und startet die n�chsten
;AD-Wandlungen.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR, A, B, R3
;------------------------------------------------------------------------------
					;
START_CONVERSION:
	LDAA    #CMD_START_BOTH_CONVS	;
	LDAB	#0FFh			;
	JSR	SPI_WRITE		;
	BSET	MPL_FLAGS,_CONV_STARTED	;
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: MPL_RESET bringt Daten- und Taktleitungen in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR, A, B, Y, R3
;//////////////////////////////////////////////////////////////////////////////
					;
MPL_RESET:
	BSET	CS_DIR,_CS		;CS-Pin auf Ausgang schalten
	BSET	CS_PORT,_CS		;_CS:		Out = 1 : Bauteil deaktivieren
					;
	BSET	SCLK_DIR,_SCLK		;SCLK-Pin auf Ausgang schalten
	BCLR	SCLK_PORT,_SCLK		;_SCLK:		Out= 0
	BSET	MOSI_DIR,_MOSI		;MOSI-Pin auf Ausgang schalten
	BCLR	MOSI_PORT,_MOSI		;_MOSI:		Out= 0
	BCLR	MISO_DIR,_MISO		;MISO-Pin auf Eingang schalten
					;_MISO:		In
					;
	LDY	#BOV			;Anfang der lokalen Variablen
	LDAB	#(TOV-BOV)		;Anzahl Bytes
	LDAA	#0			;F�llwert
MPL_RESET1:
	STAA	1,Y+			;
	DBNE	B,MPL_RESET1		;alle Variablen auf F�llwert setzen
					;
	MOVB	#0,MPL_FLAGS		;Flags r�cksetzen
					;
	JSR	READ_COEFFICIENTS	;Koeffizienten lesen und umformatiert ablegen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: MPL_READ_VALUES liest Druck- und Temperaturwert und liefert den
;kompensierten und Offset-korrigierten Umgebungsluftdruckwert in Einheiten
;von 1,0 mbar entsprechend 0,1 kPa sowie den skalierten Temperaturwert in 
;Einheiten von 0,125 �C.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	R0/R1		kompensierter Umgebungsluftdruckwert
;			R2/R3		skalierter Temperaturwert
;ver�nderte Register:	CCR, A, B, X, Y, R[0..7]
;Laufzeit:	ca. 150 �s @ 24 MHz Bustakt, wenn Koeffizienten geladen sind
;------------------------------------------------------------------------------
					;
MPL_READ_VALUES:
	BRSET	MPL_FLAGS,_COEFF_LOADED,MPL_READ_VALUES1
	JSR	READ_COEFFICIENTS	;
	BRA	MPL_READ_VALUES8	;
					;
MPL_READ_VALUES1:
	BRSET	MPL_FLAGS,_CONV_STARTED,MPL_READ_VALUES2
	BRA	MPL_READ_VALUES8	;
					;
MPL_READ_VALUES2:
	BCLR	MPL_FLAGS,_CONV_STARTED	;
	JSR     READ_RAW_PRESSURE	;
	MOVW	R0,wPADC		;
	JSR	READ_RAW_TEMPERATURE	;
	MOVW	R0,wTADC		;
	JSR	CALCULATE_PRESSURE	;
	JSR	CALCULATE_TEMPERATURE	;
	BRA	MPL_READ_VALUES9	;
					;
MPL_READ_VALUES8:
	MOVW	#MPL_NOVALUE,wPCOMP	;
	MOVW	#MPL_NOVALUE,wTCOMP	;
					;
MPL_READ_VALUES9:
	JSR	START_CONVERSION	;
	MOVW	wPCOMP,R0		;
	MOVW	wTCOMP,R2		;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
