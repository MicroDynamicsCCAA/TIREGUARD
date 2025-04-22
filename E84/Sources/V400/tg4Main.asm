	include	"s12ga_240.sfr"
	include	"s12ga_Switches.sfr"
	title	"tg4Main  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg4Main.asm
;
;Copyright: 	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	07.01.2015
;
;Description:	Start und Hauptprogrammschleife
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3Main.asm
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	COMMUNICATE		;Code
	xref	INIT			;Code
	xref	INPUT			;Code
	xref	LIN_RUN			;Code
	xref	OUTPUT			;Code
	xref	RESET			;Code
	xref	SCALE			;Code
					;
	xref	BOR			;Data
	xref	BOV			;Data
	xref	BOS			;Data
	xref	TOS			;Data
					;
	xref	REGS_SIZE_CT		;Number
	xref	VAR_SIZE_CT		;Number
	xref	STACK_SIZE_CT		;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	SYS_START		;Code
					;
.init:		section
					;
;==============================================================================
;Hauptprogramm Modul-Einsprung
;==============================================================================
					;
SYS_START:
	SEI				;Interrupts sperren
					;
	LDY	#BOR			;Anfang der General Purpose Registers
	LDX	#REGS_SIZE_CT		;Anzahl Bytes
	LDAA	#0			;Füllwert
SYS_START1:
	STAA	1,Y+			;sämtliche General Purpose Register
	DBNE	X,SYS_START1		;auf Anfangswert setzen
					;
	LDY	#BOV			;Anfang der Systemvariablen
	LDX	#VAR_SIZE_CT		;Anzahl Bytes
	LDAA	#0			;Füllwert
SYS_START2:
	STAA	1,Y+			;sämtliche Arbeitsvariablen
	DBNE	X,SYS_START2		;auf Anfangswert setzen
					;
	LDY	#BOS			;Anfang des Stackbereichs
	LDX	#STACK_SIZE_CT		;Anzahl Bytes
	LDAA	#0BBh			;Füllwert
SYS_START3:
	STAA	1,Y+			;gesamten Stackbereich
	DBNE	X,SYS_START3		;auf Füllwert setzen
					;
	LDS	#TOS			;Stackpointer auf Anfangswert
	JSR	RESET			;Rücksetzen des Systems
					;
;------------------------------------------------------------------------------
;Hauptprogrammschleife
;Diese wird in einem festen Zeitraster entsprechend der Vorgabe der Konstanten
;LOOPTIME durchlaufen.
;------------------------------------------------------------------------------
					;
LOOP:
	JSR	INIT			;Initialisieren der Peripherie
	JSR	INPUT			;Abfragen der Eingangswerte
	JSR	LIN_RUN			;LIN-Kommunikation
	JSR	SCALE			;Berechnungen
	JSR	OUTPUT			;Ansteuern der Warnlampe
	JSR	COMMUNICATE		;CAN- und RS232-Kommunikation
	BRA	LOOP			;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
