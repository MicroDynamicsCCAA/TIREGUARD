	include	"s12ga_240.sfr"
	title	"tg4Interrupts  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg4Interrupts.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	07.01.2015
;
;Description:	Interrupt Routinen
;------------------------------------------------------------------------------
;Revision History:	Original Version	11.05
;
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3Interrupts.asm
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
	xref	LOOP_FLAGS		;Data
	xref.b	_LOOP_OV		;bitMask
	xref.b	_LOOP_TIMEOUT		;bitMask
	xref	TICK_CTR		;Data
	xref	TOS			;Data
					;
	xref.b	TICK_CT			;Number
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
;NO_CODE_TRAP	Einsprung, wenn regul�rer Programmablauf verlassen wurde und
;		der Prozessor auf einen der im gesamten Programm verteilt
;		eingebauten 'TRAP 0FFh'-Befehle trifft, die einen
;		'Unimplemented Instruction Trap'- Interrupt zu dieser Stelle
;		ausl�sen.
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
;RESET_INT	Einsprung nach POWERUP-, CLOCK-MONITOR oder WATCHDOG-RESET
;------------------------------------------------------------------------------
					;
RESET_INT:
	JMP	SYS_START		;
					;
;------------------------------------------------------------------------------
;NO_INT		Notbremse f�r ung�ltige Interrupts
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
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
DISABLE_INTERRUPTS:
	BCLR	IRQCR,#01000000b	;nicht benutzte Interrupts sperren
					;
	BCLR	CPMUINT,#10010010b	;
					;
	BCLR	TIE,#01111111b		;
					;
	BCLR	TSCR2,#10001000b	;
					;
	BCLR	PACTL,#00000011b	;
					;
	BCLR	SPI0CR1,#10100000b	;
					;
	BCLR	SCI1CR2,#11110000b	;
					;
	BCLR	ATD0CTL2,#00000011b	;
					;
	BCLR	PIEJ,#00001111b		;
					;
	BCLR	ACMPC,#10000000b	;
					;
	BCLR	SCI2CR2,#11110000b	;
					;
	BCLR	SPI1CR1,#10100000b	;
					;
	BCLR	SPI2CR1,#10100000b	;
					;
	BCLR	FERCNFG,#00000011b	;
					;
	BCLR	FCNFG,#10000000b	;
					;
	BCLR	CAN0RIER,#11000010b	;
					;
	BCLR	PIEP,#00111111b		;
					;
	BCLR	CPMULVCTL,#00000010b	;
					;
	BCLR	CPMUAPICTL,#00000010b	;
					;
	BCLR	PIE1AD,#11111111b	;
					;
	BCLR	PIE0AD,#00001111b	;
	RTS				;
					;
;------------------------------------------------------------------------------
;TICKER_INT		Output Compare Event Channel 7
;
;Priorit�t:		normal
;Interruptquelle:	TFLG1._C7F
;Ausl�ser:		Output Compare Event Channel 7
;Initialisierung:	Module 'tg4Init'
;
;Eingangsparameter:	TICK_CTR
;Ausgangsparameter:	TICK_CTR
;			LOOP_FLAGS._LOOP_OV
;			LOOP_FLAGS._LOOP_TIMEOUT
;Laufzeit:		6..24 �s	@ 8 MHz
;------------------------------------------------------------------------------
					;
TICKER_INT:
	LDAA	TICK_CTR		;wenn Programmzyklus beendet,
	DBNE	A,TICKER_INT2		;dann
	BRCLR	LOOP_FLAGS,_LOOP_TIMEOUT,TICKER_INT1
	BSET	LOOP_FLAGS,_LOOP_OV	;  wenn _LOOP_TIMEOUT gesetzt, dann _LOOP_OV setzen
TICKER_INT1:
	BSET	LOOP_FLAGS,_LOOP_TIMEOUT;  _LOOP_TIMEOUT setzen
	LDAA	#TICK_CT		;  TICK_CTR auf Startwert
TICKER_INT2:
	STAA	TICK_CTR		;
					;
	LDD	TC7			;
	ADDD	#TICK_REL		;Compare Register 7 f�r n�chsten Tick aktualisieren
	STD	TC7			;
	MOVB	#_C7F,TFLG1		;Compare Channel 7 Interrupt-Flag r�cksetzen
	RTI				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
