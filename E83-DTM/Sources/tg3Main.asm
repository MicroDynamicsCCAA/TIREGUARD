	include	"s12c_128.sfr"
	include	"s12c_Switches.sfr"
	title	"tg3Main  Copyright (C) 2005-2011, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TireGuard 3	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg3Main.asm
;
;Copyright: 	(C) 2005-2011, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	20.01.2011
;
;Description:	Start und Hauptprogrammschleife
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;20.01.2011	Version 2.50
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
	MOVB	#00000000b,INITRG	;MCU-Register beginnen bei 0x0000h
	MOVB	#00000001b,INITEE	;internes EEPROM beginnt bei 0x0400h
	MOVB	#00010001b,INITRM	;internes RAM beginnt bei 0x1000h
					;
	LDY	#BOR			;Anfang der General Purpose Registers
	LDX	#REGS_SIZE_CT		;Anzahl Bytes
	LDAA	#0			;F�llwert
SYS_START1:
	STAA	1,Y+			;s�mtliche General Purpose Register
	DBNE	X,SYS_START1		;auf Anfangswert setzen
					;
	LDY	#BOV			;Anfang der Systemvariablen
	LDX	#VAR_SIZE_CT		;Anzahl Bytes
	LDAA	#0			;F�llwert
SYS_START2:
	STAA	1,Y+			;s�mtliche Arbeitsvariablen
	DBNE	X,SYS_START2		;auf Anfangswert setzen
					;
	LDY	#BOS			;Anfang des Stackbereichs
	LDX	#STACK_SIZE_CT		;Anzahl Bytes
	LDAA	#0BBh			;F�llwert
SYS_START3:
	STAA	1,Y+			;gesamten Stackbereich
	DBNE	X,SYS_START3		;auf F�llwert setzen
					;
	LDS	#TOS			;Stackpointer auf Anfangswert
	JSR	RESET			;R�cksetzen des Tireguard 2 - Systems
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
