	include	"s12c_128.sfr"
	title	"s12c_RX4045  Copyright (C) 2009, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12c_RX4045.asm
;
;Copyright:	(C) 2009, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	25.06.2009
;
;Description:	Funktionen für den Zugriff auf die über SPI angeschlossene
;		Hardwareuhr EPSON TOYO RX-4045.
;------------------------------------------------------------------------------
;Revision History:	Original Version  05.09
;
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	SPI_WRITE16		;Code
					;
	xref.b	RTC_LOOP_CT		;Number
	xref.b	RTC_LOOP_STEP		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	PACK_TIME_AND_DATE	;Code
	xdef	RTC_GET_ADJUST		;Code
	xdef	RTC_GET_TIME		;Code
	xdef	RTC_RESET		;Code
	xdef	RTC_RUN			;Code
	xdef	RTC_SET_ADJUST		;Code
	xdef	RTC_SET_TIME		;Code
	xdef	UNPACK_TIME_AND_DATE	;Code
					;
	xdef	RTC_BUF			;Data
	xdef	RTC_FLAGS		;Data
	xdef.b	_TIME_SET		;bitMask
	xdef.b	_S10_TRIG		;bitMask
	xdef.b	_M10_TRIG		;bitMask
	xdef.b	_H1_TRIG		;bitMask
	xdef.b	_CLK_ERROR		;bitMask
					;
	xdef.b	E_RTC_RANGE		;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
E_RTC_RANGE:		equ	-6
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:
					;
RTC_BUF:
	ds.b	7			;7 x BCD, gepackt
RTC_LOOP_CTR:
	ds.b	1			;DATA8:
RTC_FLAGS:
	ds.b	1			;
_TIME_SET:	equ	bit0		;1, wenn Uhr korrekt gestellt
;
;
_S10_TRIG:	equ	bit3		;1, wenn 10-Sekunden Sprung
_M10_TRIG:	equ	bit4		;1, wenn 10-Minuten Sprung
_H1_TRIG:	equ	bit5		;1, wenn 1-Stunden Sprung
;
_CLK_ERROR:	equ	bit7		;1, bei fehlerhafter Uhrenfunktion
					;
TOV:
					;
					;
.text:		section
					;
;------------------------------------------------------------------------------
;Public: RTC_RESET fegt die RTC-bezogenen Variablen.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veraenderte Register:	CCR, A, X, Y
;------------------------------------------------------------------------------
					;
RTC_RESET:
	LDX	#BOV			;Anfang der Systemvariablen
	LDY	#(TOV - BOV)		;Anzahl Bytes
	LDAA	#0			;Füllwert
RTC_RESET1:
	STAA	1,X+			;
	DBNE	Y,RTC_RESET1		;alle Variablen auf Null setzen
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;RTC_GET_ADJUST liest den Uhrentakt-Korrekturwert DIGITAL OFFSET.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	A		aktueller Uhrentakt-Korrekturwert
;veränderte Register:	CCR, A, B, R[0..1,3]
;//////////////////////////////////////////////////////////////////////////////
					;
RTC_GET_ADJUST:
	MOVW	#7C00h,R0		;
	JSR	SPI_WRITE16		;
	LDAA	R1			;
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;RTC_SET_ADJUST schreibt einen neuen Uhrentakt-Korrekturwert DIGITAL OFFSET.
;
;Eingangsparameter:	A		neuer Uhrentakt-Korrekturwert
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, R[0..1,3]
;//////////////////////////////////////////////////////////////////////////////
					;
RTC_SET_ADJUST:
	MOVB	#78h,R0			;
	STAA	R1			;
	JSR	SPI_WRITE16		;
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;RTC_RUN sichert die Einstellung der Uhrenfunktion.
;
;Eingangsparameter:	R0		Uhrentakt-Korrekturwert
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, A, B, R[0..1,3]
;//////////////////////////////////////////////////////////////////////////////
					;
RTC_RUN:
	LDAA	R0			;
	STAA	R1			;
	ANDA	#10000000b		;
	BEQ	RTC_RUN1		;wenn Uhrentakt-Korrekturwert unzulässig,
	LDAA	#E_RTC_RANGE		;dann
	BRA	RTC_RUN9		;  abbrechen und mit Fehler zurück
					;
RTC_RUN1:
	MOVB	78h,R0			;Digital Offset Register:
	JSR	SPI_WRITE16		;
	MOVB	#0E8h,R0		;Control Register 1:
	MOVB	#00110000b,R1		;/12,24 <-- 1, /CLEN2 <-- 1
	JSR	SPI_WRITE16		;
	MOVB	#0F8h,R0		;Control Register 2:
	MOVB	#00101000b,R1		;/XST <-- 1, /CLEN1 <-- 1
	JSR	SPI_WRITE16		;
	CLRA				;mit A = 0 zurück
					;
RTC_RUN9:
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: RTC_SET_TIME schreibt Datum und Uhrzeit in die Hardwareuhr
;EPSON TOYO RX-4045, initialisiert und startet sie.
;
;Eingangsparameter:	R[12..18]	Datum und Uhrzeit in gepackter BCD-Darstellung
;					Uhrzeit     / Datum
;					CC SS MM HH   TT MM YY
;Ausgangsparameter:	RTC_FLAGS._CLK_ERROR
;			RTC_FLAGS._TIME_SET
;veränderte Register:	CCR, A, X, Y, R[0..4,12..18]
;//////////////////////////////////////////////////////////////////////////////
					;
RTC_SET_TIME:
	MOVB	R12,RTC_BUF+0		;1/100 Register setzen
					;
	LDX	#R13			;Zeiger auf Quelle: R[13..18]
	MOVB	#08h,R4			;Zieladresse und Kommando
	MOVB	#6,R2			;6 Bytes
RTC_SET_TIME1:
	LDAA	R4			;
	STAA	R0			;
	LDAA	1,X+			;ein Byte lesen, Quellzeiger verschieben
	STAA	R1			;
	JSR	SPI_WRITE16		;Byte schreiben
	LDAA	R4			;
	ADDA	#10h			;Zieladresse verschieben
	CMPA	#38h			;
	BNE	RTC_SET_TIME2		;
	ADDA	#10h			;Wochentagsregister überspringen
RTC_SET_TIME2:
	STAA	R4			;
	DEC	R2			;
	BNE	RTC_SET_TIME1		;weiter, bis alle Bytes übertragen
					;
	MOVB	#0E8h,R0		;Control Register 1:
	MOVB	#00110000b,R1		;/12,24 <-- 1, /CLEN2 <-- 1
	JSR	SPI_WRITE16		;
	MOVB	#0F8h,R0		;Control Register 2:
	MOVB	#00101000b,R1		;/XST <-- 1, /CLEN1 <-- 1
	JSR	SPI_WRITE16		;
					;
	BCLR	RTC_FLAGS,_CLK_ERROR	;Fehlerflag rücksetzen
	BSET	RTC_FLAGS,_TIME_SET	;
					;
	MOVB	#RTC_LOOP_CT,RTC_LOOP_CTR
	BRA	RTC_SET_TIME9		;
					;
RTC_SET_TIME8:
	BSET	RTC_FLAGS,_CLK_ERROR	;sonst Fehler passiert
					;
RTC_SET_TIME9:
	RTS				;
					;
;------------------------------------------------------------------------------
;CHK_TIME prüft die Uhrzeit auf Sekundensprung. In dem Fall wird das
;1/100 Sekunden-Register auf Null gesetzt. Sonst wird es incrementiert.
;
;Eingangsparameter:	R[13..18]
;			RTC_BUF[0..6]
;Ausgangsparameter:	RTC_BUF[0]
;veränderte Register:	CCR, A, B, X, Y, R3
;------------------------------------------------------------------------------
					;
CHK_TIME:
	LDX     #R13			;
	LDY	#RTC_BUF+1		;
	MOVB	#6,R3			;
CHK_TIME1:
	LDAA	1,X+			;
	CMPA	1,Y+			;
	BNE	CHK_TIME2		;
	DEC	R3			;
	BNE	CHK_TIME1		;
	LDY	#RTC_BUF+0		;
	LDAA	0,Y			;1/100 Sekunden Register lesen
	BRA	CHK_TIME3		;
					;
CHK_TIME2:
	LDAA	#00h			;nach Sekundensprung
	MOVB	#RTC_LOOP_CT,RTC_LOOP_CTR
	BRA	CHK_TIME8		;wieder auf Startwert setzen
					;
CHK_TIME3:
	DEC	RTC_LOOP_CTR		;
	BNE	CHK_TIME9		;
	MOVB	#RTC_LOOP_CT,RTC_LOOP_CTR
	ADDA	#RTC_LOOP_STEP		;1/100 Sekunden-Register aktualisieren
	DAA				;
					;
CHK_TIME8:
	LDY	#RTC_BUF+0		;
	STAA	0,Y			;Wert wegschreiben
					;
CHK_TIME9:
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: RTC_GET_TIME liest die Hardwareuhr EPSON TOYO RX-4045 und legt Datum
;und Uhrzeit im Prozessor-internen Speicher ab.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	RTC_BUF[0..7]	Datum und Uhrzeit in gepackter BCD-Darstellung
;					Uhrzeit	    / Datum
;					CC SS MM HH   TT MM YY
;			RTC_FLAGS._RTC_ERROR
;veränderte Register:	CCR, A, X, Y, R[0..5,12..18]
;//////////////////////////////////////////////////////////////////////////////
					;
RTC_GET_TIME:
	LDAA	RTC_BUF+1		;
	ANDA	#11110000b		;
	STAA	R5			;alten 10-Sekunden-Wert retten
	LDAA	RTC_BUF+2		;
	ANDA	#11110000b		;
	STAA	R6			;alten 10-Minuten-Wert retten
	LDAA	RTC_BUF+3		;
	ANDA	#00001111b		;
	STAA	R7			;alten 1-Stunden-Wert retten
					;
;------------------------------------------------------------------------------
;erstes Lesen
;
	MOVB	#0Ch,R4			;Quelladresse und Kommando
	LDY	#R13			;Zeiger auf Ziel: R[13..18]
	MOVB	#6,R2			;6 Bytes
RTC_GET_TIME11:
	LDAA	R4			;
	STAA	R0			;
	MOVB	#0,R1			;
	JSR	SPI_WRITE16		; - erstes Lesen -
	LDAA	R1			;
	STAA	1,Y+			;ein Byte lesen, Zielzeiger verschieben
	LDAA	R4			;
	ADDA	#10h			;Quelladresse verschieben
	CMPA	#3Ch			;
	BNE	RTC_GET_TIME12		;
	ADDA	#10h			;Wochentagsregister überspringen
RTC_GET_TIME12:
	STAA	R4			;
	DEC	R2			;
	BNE	RTC_GET_TIME11		;weiter, bis alle Bytes übertragen
	JSR	CHK_TIME		;1/100 Sekunden nachführen
					;
;------------------------------------------------------------------------------
;zweites Lesen
;
	MOVB	#0Ch,R4			;Quelladresse und Kommando
	LDY	#RTC_BUF+1		;Zeiger auf Ziel: RTC_BUF[1..6]
	MOVB	#6,R2			;6 Bytes
RTC_GET_TIME21:
	LDAA	R4			;
	STAA	R0			;
	MOVB	#0,R1			;
	JSR	SPI_WRITE16		; - zweites Lesen -
	LDAA	R1			;
	STAA	1,Y+			;ein Byte lesen, Zielzeiger verschieben
	LDAA	R4			;
	ADDA	#10h			;Quelladresse verschieben
	CMPA	#3Ch			;
	BNE	RTC_GET_TIME22		;
	ADDA	#10h			;Wochentagsregister überspringen
RTC_GET_TIME22:
	STAA	R4			;
	DEC	R2			;
	BNE	RTC_GET_TIME21		;weiter, bis alle Bytes übertragen
					;
;------------------------------------------------------------------------------
;Leseergebnisse vergleichen
;
	LDX	#RTC_BUF+1		;
	LDY	#R13			;
	MOVB	#6,R2			;
RTC_GET_TIME3:
	LDAA	1,X+			;Daten des ersten Lesens mit denen
	CMPA	1,Y+			;des zweiten Lesens vergleichen
	BNE	RTC_GET_TIME4		;wenn verschieden,
	DEC	R2			;dann
	BNE	RTC_GET_TIME3		;  drittes Lesen erforderlich
	BRA	RTC_GET_TIME6		;
					;
;------------------------------------------------------------------------------
;drittes Lesen
;
RTC_GET_TIME4:
	JSR	CHK_TIME		;  dann jetzt 1/100 Sekunden nachführen
					;
	MOVB	#0Ch,R4			;  Quelladresse und Kommando
	LDY	#RTC_BUF+1		;  Zeiger auf Ziel: RTC_BUF[1..6]
	MOVB	#6,R2			;  6 Bytes
RTC_GET_TIME41:
	LDAA	R4			;
	STAA	R0			;
	MOVB	#0,R1			;
	JSR	SPI_WRITE16		;  - drittes Lesen -
	LDAA	R1			;
	STAA	1,Y+			;  ein Byte lesen, Zielzeiger verschieben
	LDAA	R4			;
	ADDA	#10h			;  Quelladresse verschieben
	CMPA	#3Ch			;
	BNE	RTC_GET_TIME42		;
	ADDA	#10h			;  Wochentagsregister überspringen
RTC_GET_TIME42:
	STAA	R4			;
	DEC	R2			;
	BNE	RTC_GET_TIME41		;  weiter, bis alle Bytes übertragen
					;
RTC_GET_TIME6:
	MOVB	#0ECh,R0		;
	MOVB	#0,R1			;
	JSR	SPI_WRITE16		;
	LDAA	R1			;
	ANDA	#00110000b		;wenn CR1._/12-24 oder CR1._/CLEN2 rückgesetzt,
	CMPA	#00110000b		;dann
	BNE	RTC_GET_TIME8		;  Fehler passiert
					;
	MOVB	#0FCh,R0		;
	MOVB	#0,R1			;
	JSR	SPI_WRITE16		;
	LDAA	R1			;sonst wenn CR2._PON gesetzt oder CR2._/XST rückgesetzt
	ANDA	#01110000b		;dann
	CMPA	#00100000b		;  Fehler passiert
	BNE	RTC_GET_TIME8		;
					;sonst
	BCLR	RTC_FLAGS,_CLK_ERROR	;  Fehlerflag rücksetzen
					;
	LDAA	RTC_BUF+1		;
	ANDA	#11110000b		;  10-Sekunden-Wert
	CMPA	R5			;  auf Sprung prüfen
	BEQ     RTC_GET_TIME61		;
	BSET	RTC_FLAGS,_S10_TRIG	;
RTC_GET_TIME61:
	LDAA	RTC_BUF+2		;
	ANDA	#11110000b		;  10-Minuten-Wert
	CMPA	R6			;  auf Sprung prüfen
	BEQ     RTC_GET_TIME62		;
	BSET	RTC_FLAGS,_M10_TRIG	;
RTC_GET_TIME62:
	LDAA	RTC_BUF+3		;
	ANDA	#00001111b		;  1-Stunden-Wert
	CMPA	R7			;  auf Sprung prüfen
	BEQ     RTC_GET_TIME63		;
	BSET	RTC_FLAGS,_H1_TRIG	;
RTC_GET_TIME63:
	BRA	RTC_GET_TIME9		;
					;
RTC_GET_TIME8:
	BSET	RTC_FLAGS,_CLK_ERROR 	;Fehler passiert
	BCLR	RTC_FLAGS,_TIME_SET	;
					;
RTC_GET_TIME9:
	RTS				;
 					;
;//////////////////////////////////////////////////////////////////////////////
;Public: UNPACK_TIME_AND_DATE formt Datum und Uhrzeit von gepackter BCD-Darstellung
;zum Stellen der Uhrzeit im Uhrenbaustein in RTC-Darstellung um.
;
;Eingangsparameter:	R[12..18]	gepackte BCD-Darstellung

;Ausgangsparameter:	R[12..18]	RTC-Darstellung
;veränderte Register:	CCR, R[2..4]
;//////////////////////////////////////////////////////////////////////////////
					;
UNPACK_TIME_AND_DATE:
	MOVB	R12,R2			;Register zwischenspeichern
	MOVB	R13,R3			;
	MOVB	R14,R4			;
					;
	MOVB	R15,R15			;Stunde
	MOVB	R16,R14			;Minute
	MOVB	R17,R13			;Sekunde
	MOVB	R18,R12			;Hundertstel
					;
	MOVB	R2,R16			;Tag
	MOVB	R3,R17			;Monat
	MOVB	R4,R18			;Jahr
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: PACK_TIME_AND_DATE formt aus dem Uhrenbaustein gelesenes Datum und
;gelesene Uhrzeit in gepackte BCD-Darstellung um.
;
;Eingangsparameter:	RTC_BUF[0..6]	RTC-Darstellung
;Ausgangsparameter:	R[12..18]	gepackte BCD-Darstellung
;veränderte Register:	CCR
;//////////////////////////////////////////////////////////////////////////////
					;
PACK_TIME_AND_DATE:
	MOVB	RTC_BUF+4,R12		;Tag
	MOVB	RTC_BUF+5,R13		;Monat
	MOVB	RTC_BUF+6,R14		;Jahr
					;
	MOVB	RTC_BUF+3,R15		;Stunde
	MOVB	RTC_BUF+2,R16		;Minute
	MOVB	RTC_BUF+1,R17		;Sekunde
	MOVB	RTC_BUF+0,R18		;Hundertstel
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
