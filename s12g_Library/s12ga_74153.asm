	include	"s12ga_240.sfr"
	include	"s12ga_74153.sfr"
	title	"s12ga_74153  Copyright (C) 2007-2014, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_74153.asm
;
;Copyright:	(C) 2007-2014, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	30.11.2014
;
;Description:	Funktionen für den Zugriff auf den LIN-Empfangsmultiplexer
;		vom Typ 74HC153.
;
;Folgende Bezeichner sind in s12ga_74153.sfr zu definieren:
;
;Bits:		_A
;		_B
;
;Ports:		MUX_DIR
;		MUX_PORT
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.07
;
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: s12xep_74153.asm
;
;06.02.2011	Anpassung an MC9S12XEP100
;
;26.11.2007	Original:	s12c_75153.asm
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	MUX_RESET		;Code
	xdef	MUX_UPDATE		;Code
					;
	xdef.b	E_MUX_INDEX		;Number
					;
;------------------------------------------------------------------------------
;Variables and Constants
;------------------------------------------------------------------------------
					;
E_MUX_INDEX:	equ	-2		;
					;
.text:		section
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: MUX_RESET bringt Multiplexer-Steuerleitungen in Grundstellung.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, Y
;//////////////////////////////////////////////////////////////////////////////
					;
MUX_RESET:
	LDY	#MUX_DIR		;
	LDAA	0,Y			;
	ORAA    #_A | _B		;CPU-Steuerleitungen sind Outputs
	STAA	0,Y			;
	LDY	#MUX_PORT		;
	LDAA	0,Y			;
	ANDA    #LOW(~(_A | _B))	;Multiplexer in Zustand 0 schalten
	STAA	0,Y			;
	RTS				;
					;
;//////////////////////////////////////////////////////////////////////////////
;Public: MUX_UPDATE lädt neue Position in den Multiplexer-Baustein.
;
;Eingangsparameter:	A		neue Multiplexer-Position
;Ausgangsparameter:	A 		0	= ok
;			A 		<> 0	= Fehler
;veränderte Register:	CCR, B, Y
;//////////////////////////////////////////////////////////////////////////////
					;
MUX_UPDATE:
	CMPA	#LOW(MUX_JMP_TBL_CNT)	;wenn Index nicht im zulässigen Bereich,
	BLO	MUX_UPDATE1		;dann
	LDAA	#E_MUX_INDEX		;  Fehler: ungültiger Index
	BRA	MUX_UPDATE9		;

MUX_UPDATE1:
	TAB				;
	CLRA				;
	LSLD				;Index * 2
	LDY	#MUX_JMP_TBL		;Basisadresse
	JMP	[D,Y]			;Absprung in Unterprogramm
					;
	even
MUX_JMP_TBL:
	dc.w	MUX_STATE0		;
	dc.w	MUX_STATE1		;
	dc.w	MUX_STATE2		;
	dc.w	MUX_STATE3		;
MUX_JMP_TBL_CNT:	equ	(* - MUX_JMP_TBL) / 2
					;
MUX_STATE0:
	LDY     #MUX_PORT		;
	LDAA	0,Y			;
	TAB				;
	ANDA	#LOW(~(_A | _B))	;A = 0, B = 0
	BRA	MUX_UPDATE7		;
					;
MUX_STATE1:
	LDY     #MUX_PORT		;
	LDAA	0,Y			;
	TAB				;
	ANDA	#LOW(~_B)		;
	ORAA	#_A			;A = 1, B = 0
	BRA	MUX_UPDATE7		;
					;
MUX_STATE2:
	LDY     #MUX_PORT		;
	LDAA	0,Y			;
	TAB				;
	ANDA	#LOW(~_A)		;
	ORAA	#_B			;A = 0, B = 1
	BRA	MUX_UPDATE7		;
					;
MUX_STATE3:
	LDY     #MUX_PORT		;
	LDAA	0,Y			;
	TAB				;
	ORAA	#_A | _B		;A = 1, B = 1
					;
MUX_UPDATE7:
	CBA				;wenn neue <> alter Position
	BEQ	MUX_UPDATE8		;dann
	STAA	0,Y			;  neue Position einstellen
MUX_UPDATE8:
	CLRA				;ok, mit A = 0 zurück
					;
MUX_UPDATE9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
