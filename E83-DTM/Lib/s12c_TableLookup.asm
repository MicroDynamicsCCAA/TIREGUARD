	include	"s12c_128.sfr"
	title	"s12c_TableLookup  Copyright (C) 2006-2009, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_TableLookup.asm
;
;Copyright:	(C) 2006-2009, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	20.05.2009
;
;Description:	Tabellensuche mit linearer Interpolation
;------------------------------------------------------------------------------
;Revision History:	Original Version  10.06
;
;20.05.2009	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	TBL16U			;Code
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	MUL3216U		;Code	s12_Arithmetics.asm
	xref	DIV3216U		;Code	s12_Arithmetics.asm
					;
.text:		section
					;
;------------------------------------------------------------------------------
;TBL16U setzt einen 16-bit Eingangswert in einen linear interpolierten aus
;einer Datentabelle entnommenen 32-bit Wert um.
;
;Eine Tabelle hat folgenden Aufbau:
;
;DATA16:	Stützstellenabstand
;DATA16:	Multiplikator = Skalierfaktor * 65536 zur Umrechnung des Eingangswertes
;		Ist Multiplikator = 0, wird der Eingangswert nicht umgerechnet.
;DATA16:	Offset, der vom skalierten Eingangswert subtrahiert wird
;DATA8:		Flags
;		bit7 		1 = 32-bit Daten
;				0 = 16 bit Daten
;		bit[0..6]	nicht definiert
;DATA8:		Anzahl der Tabellenwerte
;DATA...	Datentabelle
;
;Eingangsparameter:	R[6..7]		Ordinate (X-Wert) MSB..LSB
;			X		Zeiger auf Datentabelle
;Ausgangsparameter:	R[0..3]		Koordinate (Y-Wert) MSB..LSB
;			CCR.C		set:	Bereichsüberschreitung
;					clr:	sonst
;veränderte Register:	CCR, A, B, Y, R[8,10..13,20..23]
;Laufzeit:	ca. 44 µs @ 8 MHz Bustakt
;------------------------------------------------------------------------------
					;
TBL16U:
	LDD	R6			;Eingangs-Rohdatenwert
	LDY	2,X			;Multiplikator
	CPY	#0			;wenn Multiplikator <> 0,
	BEQ	TBL16U1			;dann
	EMUL				;  Eingangswert * Multiplikator / 65536
	EXG	Y,D			;
TBL16U1:
	SUBD	4,X			;Offset subtrahieren
	LBMI	TBL16U8			;wenn Ergebnis < 0,
					;dann
					;  Fehler passiert
	LDY	0,X			;
	EXG	X,Y			;X-Register retten
	IDIV				;aufbereiteter Eingangswert / Stützstellenabstand
	STX	R2			;Ergebnis nach R[2..3]
	STD	R6			;Rest (= Interpolationsfaktor) nach R[6..7]
	EXG	X,Y			;X-Register restaurieren
					;
	LDD	R2			;Zeigerindex in Tabelle
	CMPA	#0			;
	LBNE	TBL16U8			;wenn Indexgrenzen verletzt,
	CMPB	7,X			;dann
	LBHS	TBL16U8			;  Fehler passiert
					;
	LDAB	R3			;Zeigerindex nach B
	LDAA	6,X			;
	ANDA	#10000000b		;prüfen, ob 16-bit oder 32-bit Datentabelle
	BNE	TBL16U2			;
					;
	ASLB				;16-bit Werte
	ADDB	#8			;
	LDY	#0			;
	STY	R10			;
	LDY	B,X			;
	STY	R12			;erster Tabellenwert in R[10..13]
	ADDB	#2			;
	LDY	#0			;
	STY	R20			;
	LDY	B,X			;
	STY	R22			;zweiter Tabellenwert in R[20..23]
	BRA	TBL16U3			;
					;
TBL16U2:
	ASLB				;32-bit Werte
	ASLB				;
	ADDB	#8			;
	LDY	B,X			;
	STY	R10			;
	ADDB	#2			;
	LDY	B,X			;
	STY	R12			;erster Tabellenwert in R[10..13]
	ADDB	#2			;
	LDY	B,X			;
	STY	R20			;
	ADDB	#2			;
	LDY	B,X			;
	STY	R22			;zweiter Tabellenwert in R[20..23]
					;
TBL16U3:
	CLRA				;Merker, welcher Tabellenwert kleiner
	STAA	R8			;
	LDD	R22			;
	SUBD	R12			;
	STD	R2			;
	LDD	R20			;
	SBCB	R11			;
	SBCA	R10			;
	STD	R0			;
	BCC	TBL16U4			;wenn erster > zweitem Tabellenwert
	LDAA	#0FFh			;dann
	STAA	R8			;  Merker setzen
	LDD	R2			;
	COMA				;
	COMB				;  complement
	STD	R2			;
	LDD	R0			;
	COMA				;
	COMB				;
	STD	R0			;
	LDD	R2			;
	ADDD	#1			;  increment
	STD	R2			;
	LDD	R0			;
	ADCB	#0			;
	ADCA	#0			;  2-er Komplement der Differenz bilden
	STD	R0			;
					;
TBL16U4:
	JSR	MUL3216U		;Differenzbetrag * Interpolationsfaktor
	LDD	R0			;
	LBNE	TBL16U8			;wenn Zwischenergebnis > 32-bit,
	LDD	R2			;dann
	LBNE	TBL16U8			;  Fehler passiert
	LDD	R6			;
	STD	R2			;
	LDD	R4			;
	STD	R0			;
	LDD	0,X			;
	STD	R6			;
	JSR	DIV3216U		;Zwischenergebnis / Stützstellenabstand
	LDAA	R6			;
	ANDA	#10000000b		;Berechnungsergebnis runden
	BEQ	TBL16U5			;
	LDD	R2			;
	ADDD	#1			;
	STD	R2			;
	LDD	R0			;
	ADCB	#0			;
	ADCA	#0			;
	STD	R0			;liefert Interpolationswert
					;
TBL16U5:
	LDAA	R8			;
	BEQ	TBL16U6			;
	LDD	R12			;wenn erster Wert > zweitem Wert
	SUBD	R2			;dann
	STD	R2			;  Interpolationswert
	LDD	R10			;  vom ersten Tabellenwert subtrahieren
	SBCB	R1			;
	SBCA	R0			;
	STD	R0			;
	CLC				;
	BRA	TBL16U9			;
					;
TBL16U6:
	LDD	R12			;
	ADDD	R2			;sonst
	STD	R2			;  Interpolationswert
	LDD	R10			;  zum ersten Tabellenwert addieren
	ADCB	R1			;
	ADCA	R0			;
	STD	R0			;
	BRA	TBL16U9			;
					;
TBL16U8:
	LDY	#R0			;Fehler passiert!
	LDD	#0FFFFh			;
	STD	2,Y+			;Ergebnis auf -1
	STD	2,Y+			;
	SEC				;CARRY setzen
					;
TBL16U9:
	RTS				;
					;
;------------------------------------------------------------------------------
	end

