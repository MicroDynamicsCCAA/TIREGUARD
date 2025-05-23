	include	"s12ga_240.sfr"
	title	"tg4Init  Copyright (C) 2005-2015, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TIREGUARD 4	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg4Init.asm
;
;Copyright:	(C) 2005-2015, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	07.01.2015
;
;Description:	Das Programmmodul INIT fixiert die Betriebsweise der Peripherie
;		bei jedem Programmdurchlauf, soweit dadurch die laufende Funktion
;		nicht gest�rt wird.
;		Hierdurch soll verhindert werden, dass ein Peripherieelement
;		durch eine externe St�rung in eine falsche Betriebsart
;		umgeschaltet wird und dann nur noch unbrauchbare oder gar keine
;		Resultate liefert.
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;07.01.2015	Version 4.00
;27.11.2014	Anpassung an MC9S12GA240
;		Herkunft: tg3Init.asm
;
;27.11.2007	Version 2.00
;27.11.2007	Erg�nzungen f�r LIN-Empfangsmultiplexer
;
;24.11.2006	Version 1.00
;08.11.2006	Anpassung an MC9S12C128
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	CAN_RESET		;Code
	xref	CAN_STATUS		;Code
	xref	DISABLE_INTERRUPTS	;Code
	xref	WATCHDOG_RESET		;Code
					;
	xref	E_CAN0_CONFIG_TBL	;bssData
					;
	xref	CAN0_TIMEOUT_CTR	;Data
	xref	LOOP_FLAGS		;Data
	xref.b	_LOOP_TIMEOUT		;bitMask
	xref	TICK_CTR		;Data
					;
	xref.b	_CAN_RXOK		;bitMask
	xref.b	_CAN_TXOK		;bitMask
	xref.b	_CAN_RXSTAT		;bitMask
	xref.b	_CAN_TXSTAT		;bitMask
					;
	xref.b	C_ATD_PRSC		;Number
	xref.b	C_PTPSR			;Number
	xref.b	TICK_CT			;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	INIT			;Code
					;
.text:		section
					;
;==============================================================================
;INIT Modul-Einsprung
;==============================================================================
					;
INIT:
	BCLR	PTT,bit5		;Begin der aktiven Zyklusphase
					;
	JSR	START_LOOP		;
	JSR	INIT_PORTS		;
	JSR	INIT_COMLINES		;
	JSR	INIT_CAN		;
	JSR	INIT_LIN		;
	JSR	INIT_ANALOG		;
	JSR	INIT_SENSORS		;
	JSR	INIT_INT		;
	JSR	MISC_INIT		;
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
;START_LOOP initialisiert die Zykluszeit.
;
;Eingangsparameter:	LOOP_CTR
;Ausgangsparameter:	LOOP_CTR
;			LOOP_FLAGS._LOOP_TIMEOUT
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
START_LOOP:
	MOVB	#C_PTPSR,PTPSR		;Precision-Timer Z�hltakt-Vorteiler
	MOVB	#10000000b,TIOS		;Timer-Kanal 7 im Output Compare Mode betreiben
	MOVB	#10000000b,TIE		;Compare Interrupt 7 Enable
	MOVB	#11111111b,OCPD		;alle Timer-Kan�le von Output-Pins trennen
					;
	MOVB	#10001000b,TSCR1	;Precision-Timer starten
					;
	LDAA	TICK_CTR		;
	CMPA	#TICK_CT		;wenn TICK_CTR > Startwert,
	BLS	START_LOOP1		;dann
	MOVB	#TICK_CT,TICK_CTR	;  TICK_CTR auf Startwert setzen
START_LOOP1:
	BCLR	LOOP_FLAGS,_LOOP_TIMEOUT;
	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_PORTS sichert die Einstellungen der MCU-Ports.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
INIT_PORTS:
	MOVB	#11111111b,PUCR		;
	MOVB	#11000000b,ECLKCTL	;disable ECLK
	MOVB	#00000011b,PKGCR	;48 LQFP Package
	MOVB	#00000000b,PRR0		;
	MOVB	#00000000b,PRR1		;
					;Port A:
	MOVB	#00000000b,DDRA		;bit.[0..7]	In: - unavailable -
					;
					;Port B:
	MOVB	#00000000b,DDRB		;bit.[0..7]	In: - unavailable -
					;
					;Port E:
	MOVB	#00010000b,DDRE		;bit.[0..1]	In: EXTAL, XTAL
	;				;bit.[2..7]	In: - unavailable -
					;
					;Port T
	MOVB	#00100100b,DDRT		;bit.[0..1]	In: XIRQ#, IRQ#
	;				;bit.[2]	Out: MC33879._CE# = 1
	;				;bit.[3..4]	In: - not connected -
	;				;bit.[5]	Out: Working = 0
	;				;bit.[6..7]	In: - unavailable -
	MOVB	#11111111b,PERT		;
	MOVB	#00000000b,PPST		;
					;Port S:
	MOVB	#11001010b,DDRS		;bit.[0]	In: SCI0._RXD
	;				;bit.[1]	Out: SCI0._TXD
	;				;bit.[2]	In: SCI1._RXD
	;				;bit.[3]	Out: SCI1._TXD, WARNLAMP = 1
	;				;bit.[4]	In: SPI0._MISO
	;				;bit.[5]	In: - not connected -
	;				;bit.[6..7]	Out: SPI0._MOSI, _SCK
	MOVB	#11111111b,PERS		;
	MOVB	#00000000b,PPSS		;
	MOVB	#00000000b,WOMS		;
					;Port M:
	MOVB	#00000010b,DDRM		;bit.[0]	In: MSCAN0.RxD
	;				;bit.[1]	Out: MSCAN0.TxD
	;				;bit.[2..7]	In: - unavailable -
	MOVB	#11111111b,PERM		;
	MOVB	#00000000b,PPSM		;
	MOVB	#00000000b,WOMM		;
					;Port P:
	MOVB	#00111111b,DDRP		;bit.[0..1]	Out: LIN RX Multiplexer = 0 0
	;				;bit.[2]	Out: DS1722._SERMODE = 1 (SPI)
	;				;bit.[3]	Out: DS1722._CE = 0
	;				;bit.[4]	Out: MPL115A1._CE# = 1
	;				;bit.[5]	Out: MPL115A1._SHDN# = 1
	;				;bit.[6..7]	In: - unavailable -
	MOVB	#11111111b,PERP		;
	MOVB	#00000000b,PPSP		;
	MOVB	#00000000b,PIEP		;
	MOVB	#11111111b,PIFP		;
					;Port J:
	MOVB	#00000101b,DDRJ		;bit.[0]	Out: CAN_SW: 0 = open
	;				;bit.[1..2]	In: - not connected -
	;				;bit.[3]	Out: LIN_EN: 1 = enabled
	;				;bit.[4..7]	In: - unavailable -
	MOVB	#11111111b,PERJ		;
	MOVB	#00000000b,PPSJ		;
	MOVB	#00000000b,PIEJ		;
	MOVB	#11111111b,PIFJ		;
	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_COMLINES sichert die Einstellungen der seriellen Schnittstellen.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
INIT_COMLINES:

	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_CAN sichert die Einstellungen der CAN-Schnittstelle.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR, A, B, X, Y, R[0,4..5]
;------------------------------------------------------------------------------
					;
INIT_CAN:
	MOVB	#0,R0			;
	JSR	CAN_STATUS		;
	TAB				;
	ANDA	#_CAN_RXSTAT		;
	CMPA	#_CAN_RXSTAT		;wenn Receive-Error-Counter > 255
	BEQ	INIT_CAN1		;
	TBA				;
	ANDA	#_CAN_TXSTAT		;
	CMPA	#_CAN_TXSTAT		;oder Transmit-Error-Counter > 255
	BEQ	INIT_CAN1		;( = BusOff )
					;
	TBA				;
	ANDA	#_CAN_RXOK		;oder weder _CAN_RXOK noch _CAN_TXOK gesetzt
	BNE	INIT_CAN2		;
	TBA				;
	ANDA	#_CAN_TXOK		;
	BNE	INIT_CAN2		;
					;
	DEC	CAN0_TIMEOUT_CTR	;und Zeitgrenze erreicht,
	BNE	INIT_CAN3		;
					;
INIT_CAN1:
	MOVB	#0,R0			;
	MOVW	#E_CAN0_CONFIG_TBL,R4	;dann
	JSR	CAN_RESET		;  MSCAN0 neu initialisieren
					;
INIT_CAN2:
	MOVB	#0,CAN0_TIMEOUT_CTR	;Zeitgrenz-Z�hler auf Startwert
					;
INIT_CAN3:
	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_LIN sichert die Einstellungen des LIN-Masters.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
INIT_LIN:

	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_ANALOG bereitet die Spannungsmessung der Analogeing�nge vor.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
INIT_ANALOG:
	MOVB	#10000000b,ATD0CTL2	;Power on, int's and ext-triggger disable
	MOVB	#01000000b,ATD0CTL3	;8 Kan�le, non-FIFO mode, non-FREEZE mode
	MOVB	#C_ATD_PRSC,ATD0CTL4	;10-bit AD, 2 clock periods sample time
	MOVB	#0,ATD0DIEN		;disable digital inputs
	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_SENSORS sichert die Einstellungen der Sensor-Schnittstellen.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
INIT_SENSORS:

	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_INT sichert die Einstellungen der Interruptfunktionen.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
INIT_INT:
	SEI				;Interrupts global sperren
	JSR	DISABLE_INTERRUPTS	;nicht benutzte Interrupts sperren
					;
	LDX	#DEADLOCK		;
	PSHX				;Programmstartadresse,
	LDX	#0000h			;
	PSHX				;Y-Register,
	PSHX				;X-Register,
	LDD	#0000h			;
	PSHD				;B:A-Register
	PSHC				;und Status auf Stack ablegen
	RTI				;evtl. klemmenden Interrupt quittieren
					;
DEADLOCK:
	CLI				;globale Interruptfreigabe
	RTS				;
					;
;------------------------------------------------------------------------------
;MISC_INIT nimmt weitere Fixierungen vor.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;ver�nderte Register:	CCR
;------------------------------------------------------------------------------
					;
MISC_INIT:
	JSR	WATCHDOG_RESET		;Watchdog r�cksetzen
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end


