	include	"s12c_128.sfr"
	title	"tg3Interrupts  Copyright (C) 2005-2006, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TireGuard 3	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg3Interrupts.asm
;
;Copyright:	(C) 2005-2006, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	24.11.2006
;
;Description:	Interrupt Routinen
;------------------------------------------------------------------------------
;Revision History:	Original Version	11.05
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	SYS_START		;Code
					;
	xref	LOOP_CTR		;Data
	xref	LOOP_FLAGS		;Data
	xref.b	_LOOP_OV		;bitMask
	xref.b	_LOOP_TIMEOUT		;bitMask
	xref	TOS			;Data
					;
	xref.b	LOOP_CT			;Number
	xref	TICK_REL		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	DISABLE_INTERRUPTS	;Code
					;
	xdef	NO_CODE_TRAP		;Code
	xdef	NO_INT			;Code
	xdef	RESET_INT		;Code
	xdef	TICKER_INT		;Code
					;
;------------------------------------------------------------------------------
;Definition der Konstanten
;------------------------------------------------------------------------------
					;
.text:		section
					;
;------------------------------------------------------------------------------
;NO_CODE_TRAP	Einsprung, wenn regulärer Programmablauf verlassen wurde und
;		der Prozessor auf einen der im gesamten Programm verteilt
;		eingebauten 'TRAP 0FFh'-Befehle trifft, die einen
;		'Unimplemented Instruction Trap'- Interrupt zu dieser Stelle
;		auslösen.
;------------------------------------------------------------------------------
					;
NO_CODE_TRAP:
	LDS	#TOS			;Stackpointer auf Anfangswert
	LDX	#SYS_START		;
	PSHX				;Programmstartadresse,
	LDX	#0000h			;
	PSHX				;Y-Register,
	PSHX				;X-Register,
	LDD	#0000h			;
	PSHD				;B:A-Register
	PSHB				;und Status auf Stack ablegen
					;evtl. anliegenden Interrupt quittieren
	RTI				;und Kaltstart
					;
;------------------------------------------------------------------------------
;RESET_INT	Einsprung nach POWERUP- oder WATCHDOG-RESET
;------------------------------------------------------------------------------
					;
RESET_INT:
	JMP	SYS_START		;
					;
;------------------------------------------------------------------------------
;NO_INT		Notbremse für ungültige Interrupts
;------------------------------------------------------------------------------
					;
NO_INT:
	RTI				;
					;
;------------------------------------------------------------------------------
;DISABLE_INTERRUPTS sperrt alle nicht benutzten Interrupts.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
DISABLE_INTERRUPTS:
	BCLR	CRGINT,#10010010b	;nicht benutzte Interrupts sperren
	BCLR	IRQCR,#01000000b	;
					;
	BCLR	TSCR2,_TOI		;
	BCLR	TIE,#00111111b		;
	BCLR	PACTL,#00000011b	;
					;
	BCLR	ATD0CTL2,#00000010b	;
					;
	BCLR	SCI0CR1,#11110011b	;
					;
	BCLR	SPI0CR1,#10100000b	;
					;
	BCLR	FCNFG,#11000000b	;
					;
	BCLR	PIEP,#11111111b		;
	BCLR	PIEJ,#11000011b		;
	RTS				;
					;
;------------------------------------------------------------------------------
;TICKER_INT		Modulus Up Counter Überlauf
;
;Priorität:		normal
;Interruptquelle:	TFLG1._C7F
;Auslöser:		Überlauf des Modulus Up Counters
;Initialisierung:	Module 'tg3Init'
;
;Eingangsparameter:	LOOP_CTR
;Ausgangsparameter:	LOOP_CTR
;			LOOP_FLAGS._LOOP_OV
;			LOOP_FLAGS._LOOP_TIMEOUT
;Laufzeit:		6..24 µs	@ 8 MHz
;------------------------------------------------------------------------------
					;
TICKER_INT:
	LDAA	LOOP_CTR		;wenn Programmzyklus beendet,
	DBNE	A,TICKER_INT2		;dann
	BRCLR	LOOP_FLAGS,_LOOP_TIMEOUT,TICKER_INT1
	BSET	LOOP_FLAGS,_LOOP_OV	;  wenn _LOOP_TIMEOUT gesetzt, dann _LOOP_OV setzen
TICKER_INT1:
	BSET	LOOP_FLAGS,_LOOP_TIMEOUT;  _LOOP_TIMEOUT setzen
	LDAA	#LOOP_CT		;  LOOP_CTR auf Startwert
TICKER_INT2:
	STAA	LOOP_CTR		;
					;
	LDD	TC7			;
	ADDD	#TICK_REL		;Compare Register 7 für nächsten Tick aktualisieren
	STD	TC7			;
	MOVB	#_C7F,TFLG1		;Compare Channel 7 Interrupt-Flag rücksetzen
	RTI				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
