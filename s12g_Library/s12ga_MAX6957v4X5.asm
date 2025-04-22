	include	"s12ga_240.sfr"
	include "s12ga_MAX6957v4X5.sfr"
	title	"s12ga_MAX6957v4X5  Copyright (C) 2009-2017, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_MAX6957X4.asm
;
;Copyright:	(C) 2009-2017, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	03.01.2017
;
;Description:	Funktionen für den Zugriff auf bis zu vier serielle 28-Port
;		LED-Treiber vom Typ Maxim MAX6957 zur Ansteuerung von jeweils
;		fünf RGB LEDs.
;
;Folgende Bezeichner sind in s12ga_MAX6957v4X5.sfr zu definieren:
;
;Addresses:	CS_LEDS0
;		CS_LEDS1
;		CS_LEDS2
;		CS_LEDS3
;------------------------------------------------------------------------------
;Revision History:	Original Version  04.09
;
;03.01.2017	neue Funktion: RGB_GETCOLOR
;
;07.10.2016	ISEG_ADDR_TBL_CNT nun öffentlich deklariert
;03.10.2016	Bei allen Aufrufen von Funktionen des Modules s12ga_SoftSPIv2.asm
;		wird in Register R10 eine _CS-Maske übergeben, die jeweils 
;		unverändert zurück gegeben wird.
;		Dadurch sind alle Funktionen dieses Modules nicht mehr
;		parameterkompatibel zu denen im Herkunftsmodul!
;
;28.09.2016	Anpassung an MC9S12GA240
;		Herkunft: s12p_MAX6957X4.asm
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	SPI_RESET		;Code
	xref	SPI_WRITE16		;Code
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	RGB_FLASH		;Code
;
;begin 03.01.2017
	xdef	RGB_GETCOLOR		;Code
;end
;
	xdef	RGB_RESET		;Code
	xdef	RGB_SETBRIGHTNESS	;Code
	xdef	RGB_SETCOLOR		;Code
					;
	xdef.b	E_RGB_INDEX		;Number
	xdef.b	E_RGB_NOFLASH		;Number
					;
	xdef.b	ISEG_ADDR_TBL_CNT	;Number
					;
;------------------------------------------------------------------------------
;Variables and Constants
;------------------------------------------------------------------------------
					;
E_RGB_NOFLASH:	equ	-1		;
E_RGB_INDEX:	equ	-2		;
					;
;------------------------------------------------------------------------------
;Control Registers
;
NO_OP:			equ	00h	;No-Op Code
					;
CNFGR:			equ	04h	;MAX6957 Configuration Register
DITER:			equ	07h	;MAX6957 Display Test Register
PCNFGR0:		equ	09h	;MAX6957 Port Configuration Register 0
PCNFGR1:		equ	0Ah	;MAX6957 Port Configuration Register 1
PCNFGR2:		equ	0Bh	;MAX6957 Port Configuration Register 2
PCNFGR3:		equ	0Ch	;MAX6957 Port Configuration Register 3
PCNFGR4:		equ	0Dh	;MAX6957 Port Configuration Register 4
PCNFGR5:		equ	0Eh	;MAX6957 Port Configuration Register 5
PCNFGR6:		equ	0Fh	;MAX6957 Port Configuration Register 6
;					;
PORT4:			equ	24h	;MAX6957 Port 4
PORT5:			equ	25h	;MAX6957 Port 5
;					;
PORT30:			equ	3Eh	;MAX6957 Port 30
PORT31:			equ	3Fh	;MAX6957 Port 31
					;
;------------------------------------------------------------------------------
					;
SWITCH_REGS_CNT:	equ	3	; = SWITCH_ADDR_TBL_CNT
CURRENT_REGS_CNT:	equ	12	; = CURRENT_ADDR_TBL_CNT
					;
LED_REGS_CNT:		equ	SWITCH_REGS_CNT + CURRENT_REGS_CNT
VAR_CNT:		equ	1 + 2 * LED_REGS_CNT
					;
oFLAGS:			equ	0
oSHADOW_REGS:		equ	1
oSHADOW_SWITCH_REGS:	equ	oSHADOW_REGS
oSHADOW_CURRENT_REGS:	equ	oSHADOW_REGS + SWITCH_REGS_CNT
oTARGET_REGS:		equ	1 + LED_REGS_CNT
oTARGET_SWITCH_REGS:	equ	oTARGET_REGS
oTARGET_CURRENT_REGS:	equ	oTARGET_REGS + SWITCH_REGS_CNT
					;
_DIRTY:			equ	bit7	;1, wenn Shadowbuffer verändert wurde
					;
.locals:	section
					;
;------------------------------------------------------------------------------
					;
BOV:

;------------------------------------------------------------------------------
;CHIP0: Reihenfolge und Typen der Variablen dürfen nicht verändert werden!
;
CHIP0_VAR:
					;
CHIP0_FLAGS:
	ds.b	1			;Flags
					;
CHIP0_SHADOW_REGS:
					;Schattenregister
CHIP0_SHADOW_SWITCH_REGS:
	ds.b	SWITCH_REGS_CNT		;Ein-/Aus-Register
CHIP0_SHADOW_CURRENT_REGS:
	ds.b	CURRENT_REGS_CNT	;Stromwertregister
					;
CHIP0_TARGET_REGS:
					;Zielregister
CHIP0_TARGET_SWITCH_REGS:
	ds.b	SWITCH_REGS_CNT		;Ein-/Aus-Register
CHIP0_TARGET_CURRENT_REGS:
	ds.b	CURRENT_REGS_CNT	;Stromwertregister
					;
;------------------------------------------------------------------------------
;CHIP1: Reihenfolge und Typen der Variablen dürfen nicht verändert werden!
;
CHIP1_VAR:
					;
CHIP1_FLAGS:	
	ds.b	1			;Flags
					;
CHIP1_SHADOW_REGS:
					;Schattenregister
CHIP1_SHADOW_SWITCH_REGS:
	ds.b	SWITCH_REGS_CNT		;Ein-/Aus-Register
CHIP1_SHADOW_CURRENT_REGS:
	ds.b	CURRENT_REGS_CNT	;Stromwertregister
					;
CHIP1_TARGET_REGS:
					;Zielregister
CHIP1_TARGET_SWITCH_REGS:
	ds.b	SWITCH_REGS_CNT		;Ein-/Aus-Register
CHIP1_TARGET_CURRENT_REGS:
	ds.b	CURRENT_REGS_CNT	;Stromwertregister
					;
;------------------------------------------------------------------------------
;CHIP2: Reihenfolge und Typen der Variablen dürfen nicht verändert werden!
;
CHIP2_VAR:
					;
CHIP2_FLAGS:	
	ds.b	1			;Flags
					;
CHIP2_SHADOW_REGS:
					;Schattenregister
CHIP2_SHADOW_SWITCH_REGS:
	ds.b	SWITCH_REGS_CNT		;Ein-/Aus-Register
CHIP2_SHADOW_CURRENT_REGS:
	ds.b	CURRENT_REGS_CNT	;Stromwertregister
					;
CHIP2_TARGET_REGS:
					;Zielregister
CHIP2_TARGET_SWITCH_REGS:
	ds.b	SWITCH_REGS_CNT		;Ein-/Aus-Register
CHIP2_TARGET_CURRENT_REGS:
	ds.b	CURRENT_REGS_CNT	;Stromwertregister
					;
;------------------------------------------------------------------------------
;CHIP3: Reihenfolge und Typen der Variablen dürfen nicht verändert werden!
;
CHIP3_VAR:
					;
CHIP3_FLAGS:
	ds.b	1			;Flags
					;
CHIP3_SHADOW_REGS:
					;Schattenregister
CHIP3_SHADOW_SWITCH_REGS:
	ds.b	SWITCH_REGS_CNT		;Ein-/Aus-Register
CHIP3_SHADOW_CURRENT_REGS:
	ds.b	CURRENT_REGS_CNT	;Stromwertregister
					;
CHIP3_TARGET_REGS:
					;Zielregister
CHIP3_TARGET_SWITCH_REGS:
	ds.b	SWITCH_REGS_CNT		;Ein-/Aus-Register
CHIP3_TARGET_CURRENT_REGS:
	ds.b	CURRENT_REGS_CNT	;Stromwertregister
					;
TOV:
					;
.text:		section
					;
;------------------------------------------------------------------------------
;Public: RGB_RESET bringt einen LED-Treiberchip in Grundstellung
;
;Eingangsparameter:	R9		Chip Index (0..3)
;Ausgangsparameter:     R9		bleibt unverändert (!)
;			CHIPx_FLAGS._DIRTY
;			A		0 	= ok
;					<> 0    = Fehler
;veränderte Register:	CCR, B, X, Y, R[0..8,10]
;------------------------------------------------------------------------------
					;
RGB_RESET:
	LDAA	R9			;
	CMPA	#LOW(CHIPx_ADDR_TBL_CNT);wenn Index nicht im zulässigen Bereich,
	BLO	RGB_RESET1		;dann
	LDAA	#E_RGB_INDEX		;  Fehler: ungültiger Index
	JMP	RGB_RESET9		;
					;
RGB_RESET1:
	LDAA	R9			;Index liefert Zeiger in Tabelle
	LDY	#CHIPx_ADDR_TBL		;
	LDAB	A,Y			;8-bit Portadresse lesen
	STAB	R10			;und als _CS-Maske nach R10
					;
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CHIPx_VAR_TBL		;
	LDY	A,Y			;Anfang der Chip-Systemvariablen
	LDX	#VAR_CNT		;Anzahl Bytes
	LDAA	#0			;Füllwert
RGB_RESET2:
	STAA	1,Y+			;
	DBNE	X,RGB_RESET2		;alle Variablen auf Füllwert setzen
					;
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CHIPx_VAR_TBL		;
	LDY	A,Y			;
	LEAY	oTARGET_REGS,Y		;Zeiger auf Target-Register

	LDX	#LED_REGS_CNT		;Anzahl Bytes
	LDAA	#0FFh			;Füllwert, muss(!) <> Füllwert der Systemvariablen sein.
RGB_RESET3:
	STAA	1,Y+			;
	DBNE	X,RGB_RESET3		;alle Registervariablen auf Füllwert setzen
					;
	JSR	SPI_RESET		;
					;
	LDX	#CONFIG_TBL		;Zeiger auf Konfiguration
RGB_RESET4:
	LDAA	1,X+			;Adresse lesen
	CMPA	#NO_OP			;wenn Adresse <> NO-OP
	BEQ	RGB_RESET5		;dann
	LDAB	1,X+			;  Adresse nach R0
	STD	R0			;  Daten nach R1
	JSR	SPI_WRITE16		;  Kommando ausführen
	BRA	RGB_RESET4		;  und weiter, bis "NO-OP"
					;
RGB_RESET5:
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CHIPx_VAR_TBL		;
	LDY	A,Y			;Zeiger auf Systemvariablen
	LDAA	oFLAGS,Y		;
	ORAA	#_DIRTY			;_DIRTY-Flag setzen
	STAA	oFLAGS,Y		;
					;
	JSR	RGB_FLASH		;MAX6957-Register aktualisieren
	CLRA				;
					;
RGB_RESET9:
	RTS				;
					;
;------------------------------------------------------------------------------
;FLASH
;
;Eingangsparameter:     R2		;Anzahl Bytes
;			R4/R5		;Zeiger auf Shadow Register
;			R6/R7		;Zeiger auf Target Register
;			Y		;Zeiger auf Adressentabelle
;			R10		;_CS-Maske
;Ausgangsparameter:	R10		;_CS-Maske bleibt unverändert
;veränderte Register:	CCR, A, B, X, R[0..8]
;------------------------------------------------------------------------------
					;
FLASH:
					;
;	SEI				;
					;
	MOVB	#0,R8			;
					;
FLASH1:
	LDX	R4			;Zeiger auf Shadow Register
	LDAA	0,X			;
	LDX	R6			;Zeiger auf Target Register
	STAA	0,X			;Target Register aktualisieren
	STAA	R1			;Datenbyte nach R1

	CLRA
	LDAB	R8			;
	LDAA	D,Y			;
	STAA	R0			;Adresse nach R0
	JSR	SPI_WRITE16		;Kommando ausführen
					;
FLASH2:
	LDX	R4			;Zeiger verschieben
	INX				;
	STX	R4			;
	LDX	R6			;
	INX				;
	STX	R6			;
	INC	R8			;Index incrementieren
	DEC	R2			;Bytezähler decrementieren
	BNE	FLASH1			;
					;
;	CLI				;
					;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: RGB_FLASH schreibt neue Daten in den LED-Treiber.
;
;Eingangsparameter:	R9		Chip Index (0..3)
;			CHIPx_FLAGS._DIRTY
;Ausgangsparameter:     R9		bleibt unverändert (!)
;			CHIPx_FLAGS._DIRTY
;			A		0 	= ok
;					<> 0    = Fehler
;veränderte Register:	CCR, B, X, Y, R[0..8,10]
;------------------------------------------------------------------------------
					;
RGB_FLASH:
	LDAA	R9			;
	CMPA	#LOW(CHIPx_ADDR_TBL_CNT);wenn Index nicht im zulässigen Bereich,
	BLO	RGB_FLASH1		;dann
	LDAA	#E_RGB_INDEX		;  Fehler: ungültiger Index
	JMP	RGB_FLASH9		;
					;
RGB_FLASH1:
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CHIPx_VAR_TBL		;
	LDY	A,Y			;Zeiger auf Systemvariablen
	LDAA	oFLAGS,Y		;
	ANDA	#_DIRTY			;
	BNE	RGB_FLASH2		;
	LDAA	#E_RGB_NOFLASH		;
	BRA	RGB_FLASH9		;
					;
RGB_FLASH2:
	LDAA	R9			;Index liefert Zeiger in Tabelle
	LDY	#CHIPx_ADDR_TBL		;
	LDAB	A,Y			;8-bit Portadresse lesen
	STAB	R10			;und als _CS-Maske nach R10
;
;begin 03.01.2017
	CLRA				;
	LDAB	R9			;Index * 2 liefert Zeiger in Tabelle
	LSLB				;
	ADDD	#CHIPx_VAR_TBL		;
	EXG	D,Y			;
	LDD	0,Y			;
	ADDD	#oSHADOW_SWITCH_REGS	;
	STD	R4			;
	LDD	0,Y			;
	ADDD	#oTARGET_SWITCH_REGS	;
	STD	R6			;
	LDY	#SWITCH_ADDR_TBL	;
	MOVB	#SWITCH_REGS_CNT,R2	;Anzahl Bytes
	JSR	FLASH			;
					;
	CLRA				;
	LDAB	R9			;Index * 2 liefert Zeiger in Tabelle
	LSLB				;
	ADDD	#CHIPx_VAR_TBL		;
	EXG	D,Y			;
	LDD	0,Y			;
	ADDD	#oSHADOW_CURRENT_REGS	;
	STD	R4			;
	LDD	0,Y			;
	ADDD	#oTARGET_CURRENT_REGS	;
	STD	R6			;
	LDY	#CURRENT_ADDR_TBL	;
	MOVB	#CURRENT_REGS_CNT,R2	;Anzahl Bytes
	JSR	FLASH			;
;end
;
					;
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CHIPx_VAR_TBL		;
	LDY	A,Y			;Zeiger auf Systemvariablen
	LDAA	oFLAGS,Y		;
	ANDA	#LOW(~_DIRTY)		;_DIRTY-Flag rücksetzen
	STAA	oFLAGS,Y		;
	CLRA				;
					;
RGB_FLASH9:
	RTS				;
					;
;
;begin 03.01.2017
;------------------------------------------------------------------------------
;GETCOLOR liefert den aktuell in den Targetregistern gespeicherten Intensitäts-
;wert einer LED.
;
;Eingangsparameter:	R9		;Chip-Index
;			R4/R5		;Index und Maske SWITCH
;			R6/R7		;Index und Maske CURRENT
;			Y		;Zeiger auf Adressentabelle
;Ausgangsparameter:	R9		;bleibt unverändert (!)
;			R0		;aktueller Intensitätswert
;			Y		;bleibt unverändert (!)
;veränderte Register:	CCR, A, B, X
;------------------------------------------------------------------------------
					;
GETCOLOR:
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDX	#CHIPx_VAR_TBL		;
	LDD	A,X			;
	ADDD	#oTARGET_SWITCH_REGS	;
	ADDB	R4			;
	ADCA	#0			;
	EXG	D,X			;
					;
	LDAA	0,X			;
	ANDA	R5			;
	BEQ	GETCOLOR8		;wenn Switch-bit gesetzt,
					;
	LDAA	R9			;dann
	LSLA				;  Index * 2 liefert Zeiger in Tabelle
	LDX	#CHIPx_VAR_TBL		;
	LDD	A,X			;
	ADDD	#oTARGET_CURRENT_REGS	;
	ADDB	R6			;
	ADCA	#0			;
	EXG	D,X			;
					;
	LDAA	0,X			;  Current-Wert lesen
					;
	LDAB	R7			;
	CMPB	#0			;
	BEQ	GETCOLOR1		;
					;  ggf. 4x rechts schieben
	LSRA				;
	LSRA				;
	LSRA				;
	LSRA				;
					;
GETCOLOR1:
	ANDA	#00001111b		;  Current-Wert Low Nibble maskieren
	INCA				;
	STAA	R0			;  und in R0 ablegen
	BRA	GETCOLOR9		;
					;
GETCOLOR8:
	MOVB	#0,R0			;sonst
					;  Current-Wert = 0 in R0 ablegen
GETCOLOR9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: RGB_GETSTATUS gibt die Farbwerte einer LED aus den Targetregistern zurück.
;
;Eingangsparameter:	R9		Chip-Index (0..3)
;			R0		LED-Index (0..4)
;Ausgangsparameter:	R9		bleibt unverändert (!)
;			R1		Rot-Wert
;			R2		Grün-Wert
;			R3		Blau-Wert
;			A		0	= ok
;					<> 0	= Fehler
;veränderte Register:	CCR, A, B, X, Y, R[4..7]
;------------------------------------------------------------------------------
					;
RGB_GETCOLOR:
	LDAA	R9			;
	CMPA	#LOW(CHIPx_ADDR_TBL_CNT);wenn Chip-Index nicht im zulässigen Bereich,
	BLO	RGB_GETCOLOR1		;dann
	LDAA	#E_RGB_INDEX		;  Fehler: ungültiger Index
	JMP	RGB_GETCOLOR9		;
					;
RGB_GETCOLOR1:
	LDAA	R0			;
	CMPA	#LOW(LEDx_BASE_TBL_CNT)	;wenn LED-Index nicht im zulässigen Bereich,
	BLO	RGB_GETCOLOR2		;dann
	LDAA	#E_RGB_INDEX		;  Fehler: ungültiger Index
	JMP	RGB_GETCOLOR9		;
					;
RGB_GETCOLOR2:
	LDAA	R0			;
	LSLA				;LED-Index * 2
	STAA	R0			;
	LDY	#LEDx_BASE_TBL		;Zeiger auf Adressentabelle der
	LDAB	R0			;LEDx bezogenen Port-Adressen
	LDY	B,Y			;
					;
	LDX	2,Y+			;Zeiger auf die Tabelle für den Rotwert
	LDD	0,X			;
	STD	R4			;
	LDD	2,X			;
	STD	R6			;
	JSR	GETCOLOR		;
	MOVB	R0,R1			;
					;
	LDX	2,Y+			;Zeiger auf die Tabelle für den Grünwert
	LDD	0,X			;
	STD	R4			;
	LDD	2,X			;
	STD	R6			;
	JSR	GETCOLOR		;
	MOVB	R0,R2			;
					;
	LDX	2,Y+			;Zeiger auf die Tabelle für den Blauwert
	LDD	0,X			;
	STD	R4			;
	LDD	2,X			;
	STD	R6			;
	JSR	GETCOLOR		;
	MOVB	R0,R3			;
	CLRA				;
					;
RGB_GETCOLOR9:
	RTS				;
					;
;end
;
;------------------------------------------------------------------------------
;SETCOLOR
;
;Eingangsparameter:	R9		;Chip-Index
;			R0		;neuer Intensitätswert
;			R4/R5		;Index und Maske SWITCH
;			R6/R7		;Index und Maske CURRENT
;			Y		;Zeiger auf Adressentabelle
;Ausgangsparameter:	R9		;bleibt unverändert (!)
;			Y		;bleibt unverändert (!)
;veränderte Register:	CCR, A, B, X, R[0..7]
;------------------------------------------------------------------------------
					;
SETCOLOR:
					;
;	SEI				;
 					;
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDX	#CHIPx_VAR_TBL		;
	LDD	A,X			;
	ADDD	#oSHADOW_SWITCH_REGS	;
	ADDB	R4			;
	ADCA	#0			;
	EXG	D,X			;
					;
	LDAA	R0			;
	CMPA	#0			;
	BEQ	SETCOLOR8		;wenn Intensitätswert <> 0
					;
	LDAA	0,X			;dann
	ORAA	R5			;  Switch-bit setzen
	STAA	0,X			;
					;
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDX	#CHIPx_VAR_TBL		;
	LDD	A,X			;
	ADDD	#oSHADOW_CURRENT_REGS	;
	ADDB	R6			;
	ADCA	#0			;
	EXG	D,X			;
					;
	LDAA	R0			;
	DECA				;
	ANDA	#00001111b		;  Current-Wert Low Nibble
					;
	LDAB	R7			;
	CMPB	#0			;
	BEQ	SETCOLOR1		;
					;
	LDAB	0,X			;
	ANDB	#00001111b		;
	LSLA				;
	LSLA				;
	LSLA				;
	LSLA				;  Current-Wert High Nibble
	BRA	SETCOLOR2		;
					;
SETCOLOR1:
	LDAB	0,X			;
	ANDB	#11110000b		;
					;
SETCOLOR2:
	ABA				;  Current-Wert setzen
	STAA	0,X			;
	BRA	SETCOLOR9		;
					;
SETCOLOR8:
	LDAA	0,X			;sonst
	COM	R5			;
	ANDA	R5			;  Switch-bit rücksetzen
	STAA	0,X			;
					;
SETCOLOR9:
					;
;	CLI				;
					;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: RGB_SETCOLOR setzt neue Farbwerte für eine LED in die Schattenregister.
;
;Eingangsparameter:	R9		Chip-Index (0..3)
;			R0		LED-Index (0..4)
;			R1		Rot-Wert
;			R2		Grün-Wert
;			R3		Blau-Wert
;Ausgangsparameter:	R9		bleibt unverändert (!)
;			CHIPx_FLAGS._DIRTY
;			A		0	= ok
;					<> 0	= Fehler
;veränderte Register:	CCR, A, B, X, Y, R[4..7]
;------------------------------------------------------------------------------
					;
RGB_SETCOLOR:
	LDAA	R9			;
	CMPA	#LOW(CHIPx_ADDR_TBL_CNT);wenn Chip-Index nicht im zulässigen Bereich,
	BLO	RGB_SETCOLOR1		;dann
	LDAA	#E_RGB_INDEX		;  Fehler: ungültiger Index
	JMP	RGB_SETCOLOR9		;
					;
RGB_SETCOLOR1:
	LDAA	R0			;
	CMPA	#LOW(LEDx_BASE_TBL_CNT)	;wenn LED-Index nicht im zulässigen Bereich,
	BLO	RGB_SETCOLOR2		;dann
	LDAA	#E_RGB_INDEX		;  Fehler: ungültiger Index
	JMP	RGB_SETCOLOR9		;
					;
RGB_SETCOLOR2:
	LDAA	R0			;
	LSLA				;LED-Index * 2
	STAA	R0			;
	LDY	#LEDx_BASE_TBL		;Zeiger auf Adressentabelle der
	LDAB	R0			;LEDx bezogenen Port-Adressen
	LDY	B,Y			;
					;
	LDX	2,Y+			;Zeiger auf die Tabelle für den Rotwert
	LDD	0,X			;
	STD	R4			;
	LDD	2,X			;
	STD	R6			;
	MOVB	R1,R0			;
	JSR	SETCOLOR		;
					;
	LDX	2,Y+			;Zeiger auf die Tabelle für den Grünwert
	LDD	0,X			;
	STD	R4			;
	LDD	2,X			;
	STD	R6			;
	MOVB	R2,R0			;
	JSR	SETCOLOR		;
					;
	LDX	2,Y+			;Zeiger auf die Tabelle für den Blauwert
	LDD	0,X			;
	STD	R4			;
	LDD	2,X			;
	STD	R6			;
	MOVB	R3,R0			;
	JSR	SETCOLOR		;
					;
	LDAA	R9			;
	LSLA				;Index * 2 liefert Zeiger in Tabelle
	LDY	#CHIPx_VAR_TBL		;
	LDY	A,Y			;Zeiger auf Systemvariablen
	LDAA	oFLAGS,Y		;
	ORAA	#_DIRTY			;_DIRTY-Flag setzen
	STAA	oFLAGS,Y		;
	CLRA				;
					;
RGB_SETCOLOR9:
	RTS				;

;------------------------------------------------------------------------------
;Public: RGB_SETBRIGHTNESS setzt neuen Helligkeitswert für einen Chip.
;
;Eingangsparameter:	R9		Chip-Index (0..3)
;			R1		neuer Segmentstromwert (0..15)
;Ausgangsparameter:	R9		bleibt unverändert
;			A		0	= ok
;					<> 0	= Fehler
;veränderte Register:	CCR, R10
;------------------------------------------------------------------------------
					;
RGB_SETBRIGHTNESS:
	LDAA	R9			;
	CMPA	#LOW(CHIPx_ADDR_TBL_CNT);wenn Chip-Index nicht im zulässigen Bereich,
	BLO	RGB_SETBRIGHTNESS1	;dann
	LDAA	#E_RGB_INDEX		;  Fehler: ungültiger Index
	JMP	RGB_SETBRIGHTNESS9	;
					;
RGB_SETBRIGHTNESS1:
	LDAA	R1			;
	CMPA	#LOW(ISEG_ADDR_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	RGB_SETBRIGHTNESS2	;dann
	LDAA	#E_RGB_INDEX		;  Fehler: ungültiger Index
	JMP	RGB_SETBRIGHTNESS9	;
					;
RGB_SETBRIGHTNESS2:
	LDAA	R9			;Index liefert Zeiger in Tabelle
	LDY	#CHIPx_ADDR_TBL		;
	LDAB	A,Y			;8-bit Portadresse lesen
	STAB	R10			;und als _CS-Maske nach R10
					;
	LDAA	R1			;
	LSLA				;Segmentstromwert * 2
	STAA	R1			;
	LDX	#ISEG_ADDR_TBL		;Zeiger auf Adressentabelle der
	LDAB	R1			;Segmentstrom-Datentabellen
	LDX	B,X			;Zeiger auf Stromwert-Daten
					;
	MOVB	#2,R2			;
RGB_SETBRIGHTNESS3:
	LDD	2,X+			;
	STD	R0			;R0 = Adresse, R1 = Daten, R10 = _CS-Maske
	JSR	SPI_WRITE16		;
	DEC	R2			;
	BNE	RGB_SETBRIGHTNESS3	;
	CLRA				;
					;
RGB_SETBRIGHTNESS9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
;Tabellen
;
	even
CHIPx_ADDR_TBL:
	dc.b	CS_LEDS0		;
	dc.b	CS_LEDS1		;
	dc.b	CS_LEDS2		;
	dc.b	CS_LEDS3		;
CHIPx_ADDR_TBL_CNT:	equ	(* - CHIPx_ADDR_TBL)
					;
	even
CHIPx_VAR_TBL:
	dc.w	CHIP0_VAR		;
	dc.w	CHIP1_VAR		;
	dc.w	CHIP2_VAR		;
	dc.w	CHIP3_VAR		;
CHIPx_VAR_TBL_CNT:	equ	(* - CHIPx_VAR_TBL) / 2
					;
;------------------------------------------------------------------------------
;
	even
CONFIG_TBL:
	dc.b	CNFGR, 01000001b	;Normal Operation, Individual Segment Current, Disable Transition Detection
	dc.b	PCNFGR0, 05h		;P[4..5]: GPIO Output
					;P[6..7]: LED Segment Driver
	dc.b	PCNFGR1, 0		;P[8..11]: LED Segment Driver
	dc.b	PCNFGR2, 0		;P[12..15]: LED Segment Driver
	dc.b	PCNFGR3, 0		;P[16..19]: LED Segment Driver
	dc.b	PCNFGR4, 0		;P[20..23]: LED Segment Driver
	dc.b	PCNFGR5, 0		;P[24..27]: LED Segment Driver
	dc.b	PCNFGR6, 50h		;P[28..29]: LED Segment Driver
					;P[30..31]: GPIO Output
	dc.b	DITER, 0		;Disable Display Test

	dc.b	PORT4, 0		;
	dc.b	PORT5, 0		;
	dc.b	PORT30, 0		;
	dc.b	PORT31, 0		;
					;
	dc.b	NO_OP, 0		;Ende der Tabelle
					;
;------------------------------------------------------------------------------
;
	even
LEDx_BASE_TBL:
	dc.w	LED0_ADDR_TBL
	dc.w	LED1_ADDR_TBL
	dc.w	LED2_ADDR_TBL
	dc.w	LED3_ADDR_TBL
	dc.w	LED4_ADDR_TBL

LEDx_BASE_TBL_CNT:	equ	(* - LEDx_BASE_TBL) / 2
					;
;------------------------------------------------------------------------------
;
	even
LED0_ADDR_TBL:
	dc.w	P12_TBL			;rot
	dc.w	P9_TBL			;grün
	dc.w	P13_TBL			;blau

LED0_ADDR_TBL_CNT:	equ	(* - LED0_ADDR_TBL) / 2
					;
;------------------------------------------------------------------------------
;
	even
LED1_ADDR_TBL:
	dc.w	P14_TBL			;rot
	dc.w	P11_TBL			;grün
	dc.w	P15_TBL			;blau

LED1_ADDR_TBL_CNT:	equ	(* - LED1_ADDR_TBL) / 2
					;
;------------------------------------------------------------------------------
;
	even
LED2_ADDR_TBL:
	dc.w	P17_TBL			;rot
	dc.w	P18_TBL			;grün
	dc.w	P19_TBL			;blau

LED2_ADDR_TBL_CNT:	equ	(* - LED2_ADDR_TBL) / 2
					;
;------------------------------------------------------------------------------
;
	even
LED3_ADDR_TBL:
	dc.w	P21_TBL			;rot
	dc.w	P22_TBL			;grün
	dc.w	P23_TBL			;blau

LED3_ADDR_TBL_CNT:	equ	(* - LED3_ADDR_TBL) / 2
					;
;------------------------------------------------------------------------------
;
	even
LED4_ADDR_TBL:
	dc.w	P25_TBL			;rot
	dc.w	P26_TBL			;grün
	dc.w	P27_TBL			;blau

LED4_ADDR_TBL_CNT:	equ	(* - LED4_ADDR_TBL) / 2
					;
;------------------------------------------------------------------------------
;
SWITCH_ADDR_TBL:
	dc.b	46h			;Ports 6..13
	dc.b	4Eh			;Ports 14..21
	dc.b	56h			;Ports 22..29
SWITCH_ADDR_TBL_CNT:	equ	(* - SWITCH_ADDR_TBL)
					;
;------------------------------------------------------------------------------
;
CURRENT_ADDR_TBL:
	dc.b	13h			;Ports 6..7
	dc.b	14h			;Ports 8..9
	dc.b	15h			;Ports 10..11
	dc.b	16h			;Ports 12..13
	dc.b	17h			;Ports 14..15
	dc.b	18h			;Ports 16..17
	dc.b	19h			;Ports 18..19
	dc.b	1Ah			;Ports 20..21
	dc.b	1Bh			;Ports 22..23
	dc.b	1Ch			;Ports 24..25
	dc.b	1Dh			;Ports 26..27
	dc.b	1Eh			;Ports 28..29
CURRENT_ADDR_TBL_CNT:	equ	(* - CURRENT_ADDR_TBL)
					;
;------------------------------------------------------------------------------
;
P6_TBL:
	dc.b	0			;Index:	Schalter Ports 6..13
	dc.b	00000001b		;Mask:	bit0
	dc.b    0			;Index:	Strom Ports 6..7
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P7_TBL:
	dc.b	0			;Index:	Schalter Ports 6..13
	dc.b	00000010b		;Mask:	bit1
	dc.b    0			;Index:	Strom Ports 6..7
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P8_TBL:
	dc.b	0			;Index:	Schalter Ports 6..13
	dc.b	00000100b		;Mask:	bit2
	dc.b    1			;Index:	Strom Ports 8..9
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P9_TBL:
	dc.b	0			;Index:	Schalter Ports 6..13
	dc.b	00001000b		;Mask:	bit3
	dc.b    1			;Index:	Strom Ports 8..9
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P10_TBL:
	dc.b	0			;Index:	Schalter Ports 6..13
	dc.b	00010000b		;Mask:	bit4
	dc.b    2			;Index:	Strom Ports 10..11
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P11_TBL:
	dc.b	0			;Index:	Schalter Ports 6..13
	dc.b	00100000b		;Mask:	bit5
	dc.b    2			;Index:	Strom Ports 10..11
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P12_TBL:
	dc.b	0			;Index:	Schalter Ports 6..13
	dc.b	01000000b		;Mask:	bit6
	dc.b    3			;Index:	Strom Ports 12..13
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P13_TBL:
	dc.b	0			;Index:	Schalter Ports 6..13
	dc.b	10000000b		;Mask:	bit7
	dc.b    3			;Index:	Strom Ports 12..13
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P14_TBL:
	dc.b	1			;Index:	Schalter Ports 14..21
	dc.b	00000001b		;Mask:	bit0
	dc.b    4			;Index:	Strom Ports 14..15
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P15_TBL:
	dc.b	1			;Index:	Schalter Ports 14..21
	dc.b	00000010b		;Mask:	bit1
	dc.b    4			;Index:	Strom Ports 14..15
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P16_TBL:
	dc.b	1			;Index:	Schalter Ports 14..21
	dc.b	00000100b		;Mask:	bit2
	dc.b    5			;Index:	Strom Ports 16..17
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P17_TBL:
	dc.b	1			;Index:	Schalter Ports 14..21
	dc.b	00001000b		;Mask:	bit3
	dc.b    5			;Index:	Strom Ports 16..17
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P18_TBL:
	dc.b	1			;Index:	Schalter Ports 14..21
	dc.b	00010000b		;Mask:	bit4
	dc.b    6			;Index:	Strom Ports 18..19
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P19_TBL:
	dc.b	1			;Index:	Schalter Ports 14..21
	dc.b	00100000b		;Mask:	bit5
	dc.b    6			;Index:	Strom Ports 18..19
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P20_TBL:
	dc.b	1			;Index:	Schalter Ports 14..21
	dc.b	01000000b		;Mask:	bit6
	dc.b    7			;Index:	Strom Ports 20..21
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P21_TBL:
	dc.b	1			;Index:	Schalter Ports 14..21
	dc.b	10000000b		;Mask:	bit7
	dc.b    7			;Index:	Strom Ports 20..21
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P22_TBL:
	dc.b	2			;Index:	Schalter Ports 22..29
	dc.b	00000001b		;Mask:	bit0
	dc.b    8			;Index:	Strom Ports 22..23
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P23_TBL:
	dc.b	2			;Index:	Schalter Ports 22..29
	dc.b	00000010b		;Mask:	bit1
	dc.b    8			;Index:	Strom Ports 22..23
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P24_TBL:
	dc.b	2			;Index:	Schalter Ports 22..29
	dc.b	00000100b		;Mask:	bit2
	dc.b    9			;Index:	Strom Ports 24..25
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P25_TBL:
	dc.b	2			;Index:	Schalter Ports 22..29
	dc.b	00001000b		;Mask:	bit3
	dc.b    9			;Index:	Strom Ports 24..25
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P26_TBL:
	dc.b	2			;Index:	Schalter Ports 22..29
	dc.b	00010000b		;Mask:	bit4
	dc.b    10			;Index:	Strom Ports 26..27
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P27_TBL:
	dc.b	2			;Index:	Schalter Ports 22..29
	dc.b	00100000b		;Mask:	bit5
	dc.b    10			;Index:	Strom Ports 26..27
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
;
P28_TBL:
	dc.b	2			;Index:	Schalter Ports 22..29
	dc.b	01000000b		;Mask:	bit6
	dc.b    11			;Index:	Strom Ports 28..29
	dc.b	0			;Shift:	0
					;
;------------------------------------------------------------------------------
;
P29_TBL:
	dc.b	2			;Index:	Schalter Ports 22..29
	dc.b	10000000b		;Mask:	bit7
	dc.b    11			;Index:	Strom Ports 28..29
	dc.b	4			;Shift:	4
					;
;------------------------------------------------------------------------------
; Globale Einstellung des Segmentstromes ISEG
; ISEGx.bit[3..0] : P5 / P31 / P4 / P30
;
	even
ISEG_ADDR_TBL:
	dc.w	ISEG0_TBL		;1,5 mA
	dc.w	ISEG1_TBL		;3 mA
	dc.w	ISEG2_TBL		;4,5 mA
	dc.w	ISEG3_TBL		;6 mA
	dc.w	ISEG4_TBL		;7,5 mA
	dc.w	ISEG5_TBL		;9 mA
	dc.w	ISEG6_TBL		;10,5 mA
	dc.w	ISEG7_TBL		;12 mA
	dc.w	ISEG8_TBL		;13,5 mA
	dc.w	ISEG9_TBL		;15 mA
	dc.w	ISEG10_TBL		;16,5 mA
	dc.w	ISEG11_TBL		;18 mA
	dc.w	ISEG12_TBL		;19,5 mA
	dc.w	ISEG13_TBL		;21 mA
	dc.w	ISEG14_TBL		;22,5 mA
	dc.w	ISEG15_TBL		;24 mA
ISEG_ADDR_TBL_CNT:	equ	(* - ISEG_ADDR_TBL) / 2
					;
;------------------------------------------------------------------------------
;
ISEG0_TBL:
	dc.b	PCNFGR0, 00001010b	;P4  : 1
					;P5  : 1
	dc.b	PCNFGR6, 10100000b	;P31 : 1
					;P30 : 1
;------------------------------------------------------------------------------
;
ISEG1_TBL:
	dc.b	PCNFGR0, 00001010b	;P4  : 1
					;P5  : 1
	dc.b	PCNFGR6, 10010000b	;P31 : 1
					;P30 : 0
;------------------------------------------------------------------------------
;
ISEG2_TBL:
	dc.b	PCNFGR0, 00000110b	;P4  : 0
					;P5  : 1
	dc.b	PCNFGR6, 10100000b	;P31 : 1
					;P30 : 1
;------------------------------------------------------------------------------
;
ISEG3_TBL:
	dc.b	PCNFGR0, 00000110b	;P4  : 0
					;P5  : 1
	dc.b	PCNFGR6, 10010000b	;P31 : 1
					;P30 : 0
;------------------------------------------------------------------------------
;
ISEG4_TBL:
	dc.b	PCNFGR0, 00001010b	;P4  : 1
					;P5  : 1
	dc.b	PCNFGR6, 01100000b	;P31 : 0
					;P30 : 1
;------------------------------------------------------------------------------
;
ISEG5_TBL:
	dc.b	PCNFGR0, 00001010b	;P4  : 1
					;P5  : 1
	dc.b	PCNFGR6, 01010000b	;P31 : 0
					;P30 : 0
;------------------------------------------------------------------------------
;
ISEG6_TBL:
	dc.b	PCNFGR0, 00000110b	;P4  : 0
					;P5  : 1
	dc.b	PCNFGR6, 01100000b	;P31 : 0
					;P30 : 1
;------------------------------------------------------------------------------
;
ISEG7_TBL:
	dc.b	PCNFGR0, 00000110b	;P4  : 0
					;P5  : 1
	dc.b	PCNFGR6, 01010000b	;P31 : 0
					;P30 : 0
;------------------------------------------------------------------------------
;
ISEG8_TBL:
	dc.b	PCNFGR0, 00001001b	;P4  : 1
					;P5  : 0
	dc.b	PCNFGR6, 10100000b	;P31 : 1
					;P30 : 1
;------------------------------------------------------------------------------
;
ISEG9_TBL:
	dc.b	PCNFGR0, 00001001b	;P4  : 1
					;P5  : 0
	dc.b	PCNFGR6, 10010000b	;P31 : 1
					;P30 : 0
;------------------------------------------------------------------------------
;
ISEG10_TBL:
	dc.b	PCNFGR0, 00000101b	;P4  : 0
					;P5  : 0
	dc.b	PCNFGR6, 10100000b	;P31 : 1
					;P30 : 1
;------------------------------------------------------------------------------
;
ISEG11_TBL:
	dc.b	PCNFGR0, 00000101b	;P4  : 0
					;P5  : 0
	dc.b	PCNFGR6, 10010000b	;P31 : 1
					;P30 : 0
;------------------------------------------------------------------------------
;
ISEG12_TBL:
	dc.b	PCNFGR0, 00001001b	;P4  : 1
					;P5  : 0
	dc.b	PCNFGR6, 01100000b	;P31 : 0
					;P30 : 1
;------------------------------------------------------------------------------
;
ISEG13_TBL:
	dc.b	PCNFGR0, 00001001b	;P4  : 1
					;P5  : 0
	dc.b	PCNFGR6, 01010000b	;P31 : 0
					;P30 : 0
;------------------------------------------------------------------------------
;
ISEG14_TBL:
	dc.b	PCNFGR0, 00000101b	;P4  : 0
					;P5  : 0
	dc.b	PCNFGR6, 01100000b	;P31 : 0
					;P30 : 1
;------------------------------------------------------------------------------
;
ISEG15_TBL:
	dc.b	PCNFGR0, 00000101b	;P4  : 0
					;P5  : 0
	dc.b	PCNFGR6, 01010000b	;P31 : 0
					;P30 : 0
;------------------------------------------------------------------------------
	end
