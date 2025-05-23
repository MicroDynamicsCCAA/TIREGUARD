	include	"s12ga_240.sfr"
	title	"s12ga_Mean16  Copyright (C) 2004-2014, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_Mean16.asm
;
;Copyright:	(C) 2004-2014, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	27.11.2014
;
;Description:	Berechnung des fortlaufenden Mittelwertes eines
;		16-bit Datenstromes.
;------------------------------------------------------------------------------
;Revision History:	Original Version  12.04
;
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: s12p_Mean16.asm
;
;28.04.2009	Anpassung an MC9S12P128
;
;24.11.2006	Anpassung an MC9S12C128
;
;27.02.2005	ge�nderte Nutzung der Register: R[20..27] statt R[8..17]
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	MEAN16			;Code
					;
.text:		section
					;
;------------------------------------------------------------------------------
;Public: MEAN16 bildet den fortlaufenden Mittelwert eines 16-bit Datenstromes.
;
;Der Berechnung liegen folgende Beziehungen zugrunde:
;s1 = ue + s1
;ua = s1 / c
;s1 = s1 - ua
;
;Eingangsparameter:	R4/R5	Zeiger auf 16-bit Eingangswert mit Vorzeichen
;			R0	Mittelungsl�nge, also Anzahl der Werte, �ber
;				die zu mitteln ist
;			R6/R7	Zeiger auf 24-bit Vorgeschichtswert
;
;Ausgangsparameter:	R4/R5	Zeiger auf 16-bit Ausgangswert mit Vorzeichen ( unver�ndert )
;				Eingangswert wird vom Ausgangswert �berschrieben
;			R6/R7	Zeiger auf 24-bit Vorgeschichtswert ( unver�ndert )
;ver�nderte Register:	CCR, A, B, X, Y, R[20..27]
;Laufzeit:		29 �s	@ 8 MHz Bustakt
;------------------------------------------------------------------------------

MEAN16:
	LDAA	R0			;wenn Mittelungsl�nge > 0
	BNE	MEAN16_1		;dann
	JMP	MEAN16_9		;
					;
MEAN16_1:
	LDX	R4			;  Zeiger auf Eingangswert
	LDY	R6			;  Zeiger auf Vorgeschichtswert
					;
	LDD	0,X			;
	STD	R22			;
	SEX	A,D                     ;
	STAA	R21			;  ue auf 32 bit erweitert
	SEX	A,D			;
	STAA	R20			;  in R[20..23]
					;
	MOVW	1,Y,R26			;
	LDAA	0,Y			;
	STAA	R25			;  s1 auf 32 bit erweitert
	SEX	A,D			;
	STAA	R24			;  in R[24..27]
					;
	LDX	#R20			;  Zeiger auf ue
	LDY	#R24			;  Zeiger auf s1
					;
	LDD	2,X			;  s1:= ue + s1
	ADDD	2,Y			;
	STD	2,Y			;
	LDAA	1,X			;
	ADCA	1,Y			;
	STAA	1,Y			;
	LDAA	0,X			;
	ADCA	0,Y			;
	STAA	0,Y			;
					;
	LDAB	R0			;
	LDAA	#0			;  16-bit Divisor c in X
	TFR	D,X			;
					;
	LDY	R24			;
	LDD	R26			;  32-bit Dividend s1 in Y:D
					;
	EDIVS				;  32/16 bit Division
					;
	STY	R22			;  Ergebnis ist ua
					;
	LDX	#R20			;  Zeiger auf ua
	LDY	#R24			;  Zeiger auf s1
					;
	LDD	2,X			;
	SEX	A,D			;
	STAA	R21			;  ua auf 32 bit erweitert
	SEX	A,D			;
	STAA	R20			;  in R[20..23]
					;
	LDD	2,Y			;
	SUBD	2,X			;
	STD	2,Y			;
	LDAA	1,Y			;
	SBCA	1,X			;  s1:= s1 - ua
	STAA	1,Y			;
	LDAA	0,Y			;
	SBCA	0,X			;
	STAA	0,Y			;
					;
	LDX	R4			;  Zeiger auf Ausgangswert
	LDY	R6			;  Zeiger auf Vorgeschichtswert
					;
	MOVW	R22,0,X			;  ua speichern
					;
	MOVB	R25,0,Y			;  s1 speichern
	MOVW	R26,1,Y			;
					;
MEAN16_9:
	RTS				;und fertig
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
