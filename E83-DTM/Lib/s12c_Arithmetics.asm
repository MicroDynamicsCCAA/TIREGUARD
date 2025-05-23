	include	"s12c_128.sfr"
	title	"s12c_Arithmetics  Copyright (C) 2004-2006, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_Arithmetics.asm
;
;Copyright:	(C) 2004-2006, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	24.11.2006
;
;Description:	16-, 24- und 32-bit Arithmetik
;------------------------------------------------------------------------------
;Revision History:	Original Version  12.04
;
;24.11.2006
;08.11.2006	Anpassung an MC9S12C128
;
;23.08.2005	Function MUL3216U neu
;12.08.2005	Fehler in DIV3232U korrigiert
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	DIV3216U		;Code
	xdef	DIV3232U		;Code
	xdef	MUL3216U		;Code
					;
.text:		section
					;
;------------------------------------------------------------------------------
;MUL3216U multipliziert eine vorzeichenlose 32-bit Zahl mit einer vorzeichenlosen
;16-bit Zahl und liefert ein 64-bit Ergebnis.
;Eingangsparameter:	R[0..3]		Multiplikand MSB..LSB
;			R[6..7]		Multiplikator MSB..LSB
;Ausgangsparameter:	R[0..7]		Produkt MSB..LSB
;ver�nderte Register:	CCR, A, B, Y
;Laufzeit:	? �s @ 8 MHz Bustakt
;------------------------------------------------------------------------------
					;
MUL3216U:
	LDD	R2			;Multiplikand Low Word
	LDY	R6			;Multiplikator
	EMUL				;Multiplikation 16x16 bit
	STD	R4			;
	STY	R2			;Zwischenergebnis in R[2..5]
					;
	LDD	R0			;Multiplikand High Word
	LDY	R6			;Multiplikator
	EMUL				;Multiplikation 16x16 bit
					;
	MOVW	R4,R6			;Zwischenergebnis umspeichern
					;
	ADDD	R2			;
	STD	R4			;Teilergebnisse addieren
	EXG	D,Y			;
	ADCB	#0			;
	ADCA	#0			;
	STD	R2			;
	MOVW	#0,R0			;Ergebnis in R[0..7]
	RTS				;
					;
;------------------------------------------------------------------------------
;DIV3216U dividiert eine vorzeichenlose 32-bit Zahl durch eine vorzeichenlose
;16-bit Zahl und liefert ein 32-bit Ergebnis sowie einen 16-bit Rest.
;Eingangsparameter:	R[0..3]		Dividend MSB..LSB
;			R[6..7]		Divisor MSB..LSB
;Ausgangsparameter:	R[0..3]		Quotient MSB..LSB
;			R[6..7]		Rest MSB..LSB
;			CCR.C		set:	Divisor = 0
;					clr:	sonst
;ver�nderte Register:	CCR, A, B, X, Y
;Laufzeit:	7 �s @ 8 MHz Bustakt
;------------------------------------------------------------------------------
					;
DIV3216U:
	LDX	R6			;
	BNE	DIV3216U1		;wenn Divisor = 0,
	SEC				;dann
	JMP	DIV3216U9		;  CARRY setzen und zur�ck
					;
DIV3216U1:
	LDD	R0			;wenn Dividend High Word <> 0
	BEQ	DIV3216U2		;
					;
	LDY	#0			;dann
	EDIV				;  1. Division 32/16 bit
	STY	R0			;  Ergebnis High Word in R[0..1]
	TFR	D,Y			;
	LDD	R2			;
	EDIV				;  2. Division 32/16 bit
	STY	R2			;  Ergebnis Low Word in R[2..3]
	JMP	DIV3216U8		;
					;
DIV3216U2:
	LDD	R2			;sonst
	IDIV				;  Division 16/16 bit
	MOVW	#0,R0			;  Ergebnis High Word in R[0..1] = 0
	STX     R2			;  Ergebnis Low Word in R[2..3]
					;
DIV3216U8:
	STD	R6			;Rest in R[6..7]
	CLC				;CARRY r�cksetzen
					;
DIV3216U9:
	RTS				;
					;
;------------------------------------------------------------------------------
;DIV3232U dividiert eine vorzeichenlose 32-bit Zahl durch eine vorzeichenlose
;32-bit Zahl und liefert ein 32-bit Ergebnis sowie einen 32-bit Rest.
;Eingangsparameter:	R[0..3]		Dividend MSB..LSB
;			R[4..7]		Divisor MSB..LSB
;Ausgangsparameter:	R[0..3]		Quotient MSB..LSB
;			R[4..7]		Rest MSB..LSB
;			CCR.C		set:	Divisor = 0
;					clr:	sonst
;ver�nderte Register:	CCR, A, B, X, Y, R[20..23]
;Laufzeit:	max. 20 �s @ 8 MHz Bustakt
;------------------------------------------------------------------------------
					;
DIV3232U:
	LDX	R4			;
	BNE	DIV3232U2		;wenn Divisor High Word = 0,
	LDX	R6			;dann
	BNE	DIV3232U1		;  wenn Division durch Null,
	SEC				;  dann
	JMP	DIV3232U9		;    CARRY setzen und zur�ck
					;
DIV3232U1:
	JSR	DIV3216U		;  sonst
	JMP	DIV3232U9		;    Division 32/16 bit ausf�hren
					;
DIV3232U2:
	TST	R4			;
	BEQ	DIV3232U4		;
					;
;------------------------------------------------------------------------------
; 32-bit Divisor
;
	MOVW	R2,R22			;Dividend Low Word retten
					;
	LDD	R0			;
	LDX	R4			;
	IDIV				;Dividend High Word / Divisor High Word
	STX	R2			;Ergebnis
	STD	R20			;Rest
					;
	LDAA	R3			;Ergebnis * Divisor Low Byte
	LDAB	R7			;
	MUL				;
	STD	R1			;
	LDAA	R3			;
	LDAB	R6			;
	MUL				;
	ADDB	R1			;
	ADCA	#0			;
	STD	R0			;
					;
	LDD	R22			;vom Divisionsrest subtrahieren
	SUBD	R1			;
	STD	R22			;
	LDD	R20			;
	SBCB	R0			;
	SBCA	#0			;
	STD	R20			;
	LDAA	#0			;
	STAA	R2			;wenn Ergebnis >= 0,
 	BCS	DIV3232U3		;
	JMP	DIV3232U8		;dann fertig
DIV3232U3:
	JMP	DIV3232U7		;sonst korrigieren
					;
;------------------------------------------------------------------------------
; 24-bit Divisor
;
DIV3232U4:
	MOVW	R2,R22			;Dividend retten
	CLR	R2			;
					;
	LDD	R0			;
	CPD	R5			;
	BCC	DIV3232U5		;wenn Dividend > Divisor
	STD	R20			;
	BRA	DIV3232U6		;
					;
DIV3232U5:
	LDX	R5			;dann
	IDIV				;  Dividend[0..1] / Divisor[1..2]
	STD	R20			;  Rest nach R[10..11]
	STX	R1			;  Ergebnis nach R[1..2]
					;
	LDAA	R2			;  Ergebnis * Divisor Low Byte
	LDAB	R7			;
	MUL				;
	STD	R0			;
					;
	LDD	R21			;  vom Rest subtrahieren
	SUBD	R0			;
	STD	R21			;
	LDAB	R20			;
	SBCB	#0			;
	STAB	R20			;
					;
	BCC	DIV3232U6		;  wenn Rest danach < 0
	DEC	R2			;  dann
	LDD	R21			;     Ergebnis korrigieren
	ADDD	R6			;
	STD	R21			;     Rest + Divisor
	LDAB	R20			;
	ADCB	R5			;
	STAB	R20			;
					;
DIV3232U6:
	LDAB	R20			;
	CLRA				;
	TFR	D,Y			;
	LDD	R21			;
	LDX	R5			;
	EDIV				;Rest / Divisor[1..2]
	CLR	R20			;
	STD	R21			;neuen Rest nach R[10..12]
	TFR	Y,D			;
	STAB	R3			;Ergebnis nach R3
					;
	LDAB	R7			;
	CLRA				;
	EMUL				;Ergebnis * Divisor Low Byte
	STD	R0			;
					;
	LDD	R22			;vom Rest subtrahieren
	SUBD	R0			;
	STD	R22			;
	LDAB	R21			;
	SBCB	#0			;
	STAB	R21			;wenn Rest danach < 0,

	BCC	DIV3232U8		;dann
	DEC	R20			;
					;
;------------------------------------------------------------------------------
; Ergebnis ggf. korrigieren und Rest umspeichern
;
DIV3232U7:
	DEC	R3			;  Ergebnis korrigieren
	LDD	R22			;
	ADDD	R6			;  Rest + Divisor
	STD	R22			;
	LDD	R20			;
	ADCB	R5			;
	ADCA	R4			;
	STD	R20			;
					;
DIV3232U8:
	MOVW	#0,R0			;Quotient High Word = 0
	MOVW	R20,R4			;Rest umspeichern
	MOVW	R22,R6			;
	CLC				;CARRY r�cksetzen
					;
DIV3232U9:
	RTS				;
					;
;------------------------------------------------------------------------------
	end

