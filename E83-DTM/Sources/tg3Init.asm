	include	"s12c_128.sfr"
	title	"tg3Init  Copyright (C) 2005-2007, micro dynamics GmbH"
;------------------------------------------------------------------------------
;TireGuard 3a	Betriebsprogramm
;------------------------------------------------------------------------------
;Module:	tg3Init.asm
;
;Copyright:	(C) 2005-2007, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	27.11.2007
;
;Description:	Das Programmmodul INIT fixiert die Betriebsweise der Peripherie
;		bei jedem Programmdurchlauf, soweit dadurch die laufende Funktion
;		nicht gestört wird.
;		Hierdurch soll verhindert werden, dass ein Peripherieelement
;		durch eine externe Störung in eine falsche Betriebsart
;		umgeschaltet wird und dann nur noch unbrauchbare oder gar keine
;		Resultate liefert.
;------------------------------------------------------------------------------
;Revision History:	Original Version  11.05
;
;27.11.2007	Version 2.00
;27.11.2007	Ergänzungen für LIN-Empfangsmultiplexer
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
	xref	CAN0_CONFIG_TBL		;roData
					;
	xref	CAN0_TIMEOUT_CTR	;Data
	xref	LOOP_CTR		;Data
	xref	LOOP_FLAGS		;Data
	xref.b	_LOOP_TIMEOUT		;bitMask
					;
	xref.b	_CAN_RXOK		;bitMask
	xref.b	_CAN_TXOK		;bitMask
	xref.b	_CAN_RXSTAT		;bitMask
	xref.b	_CAN_TXSTAT		;bitMask
					;
	xref.b	C_ATD_PRSC		;Number
	xref.b	C_TSCR2			;Number
	xref.b	LOOP_CT			;Number
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
	BCLR	PTT,bit7		;Begin der aktiven Zyklusphase
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
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
START_LOOP:
	MOVB	#C_TSCR2,TSCR2		;Zähltakt-Vorteiler
	MOVB	#11000000b,TIOS		;Timer-Kanäle 6..7 im Output Compare Mode betreiben
	MOVB	#11000000b,TIE		;Compare Interrupts 6..7 Enable
	MOVB	#10000000b,TSCR1	;Timer starten
					;
	LDAA	LOOP_CTR		;
	CMPA	#LOOP_CT		;wenn LOOP_CTR > Startwert,
	BLS	START_LOOP1		;dann
	MOVB	#LOOP_CT,LOOP_CTR	;  LOOP_CTR auf Startwert setzen
START_LOOP1:
	BCLR	LOOP_FLAGS,_LOOP_TIMEOUT;
	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_PORTS sichert die Einstellungen der MCU-Ports.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
INIT_PORTS:
	MOVB	#11111111b,PUCR		;
	MOVB	#00000000b,RDRIV	;
	MOVB	#00000000b,MODRR	;
					;Port A:
	MOVB	#00000000b,DDRA		;bit.[0]	In: - not connected -
	;				;bit.[1..7]	In: - unavailable -
					;
					;Port B:
	MOVB	#00000000b,DDRB		;bit.[0..3]	In: - unavailable -
	;				;bit.[4]	In: - not connected -
	;				;bit.[5..7]	In: - unavailable -
					;
					;Port E:
	BSET	PEAR,#00010000b		;
	MOVB	#00000000b,DDRE		;bit.[0..7]	In: - not connected -
					;
					;Port K:
	MOVB	#00000000b,DDRK		;bit.[0..7]	In: - not connected -
					;
					;Port T
;
;begin 27.11.2007
	MOVB	#11110010b,DDRT		;bit.[0..1]	In: Soft-SCI1
	;				;bit.[1]	Out: Warnlamp
	;				;bit.[2..3]	In: - not connected -
	;				;bit.[4]	Out: MC33879._CS
	;				;bit.[5..6]	Out: LIN-RX-Multiplexer
	;				;bit.[7]	Out: Working
;end
;
	MOVB	#00000000b,RDRT		;
	MOVB	#11111111b,PERT		;
	MOVB	#00000000b,PPST		;
					;Port S:
	MOVB	#00000010b,DDRS		;bit.[0]	In: SCI0
	;				;bit.[2..3]	In: - not connected -
	;				;bit.[4..7]	In: - unavailable -
	MOVB	#00000000b,RDRS		;
	MOVB	#11111111b,PERS		;
	MOVB	#00000000b,PPSS		;
	MOVB	#00000000b,WOMS		;
					;Port M:
	MOVB	#00111000b,DDRM		;bit.[0..1]	I/O: MSCAN0
	;				;bit.[2]	In: SPI0._MISO
	;				;bit.[3]	Out: DS1722._CE
	;				;bit.[4..5]	Out: SPI0._MOSI,_SCLK
	;				;bit.[6..7]	In: - unavailable
	MOVB	#00000000b,RDRM		;
	MOVB	#11111111b,PERM		;
	MOVB	#00000000b,PPSM		;
	MOVB	#00000000b,WOMM		;
					;Port P:
	MOVB	#00000000b,DDRP		;bit.[0..4]	In: - unavailable -
	;				;bit.[5]	In: - not connected -
	;				;bit.[6..7]	In: - unavailable -
	MOVB	#00000000b,RDRP		;
	MOVB	#11111111b,PERP		;
	MOVB	#00000000b,PPSP		;
	MOVB	#00000000b,PIEP		;
	MOVB	#11111111b,PIFP		;
					;Port J:
	MOVB	#00000000b,DDRJ		;bit.[0..5]	In: - unavailable -
	;				;bit.[6..7]	In: - not connected -
	MOVB	#00000000b,RDRJ		;
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
;veränderte Register:	CCR
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
;veränderte Register:	CCR, A, B, X, Y, R[0,4..5]
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
	MOVW	#CAN0_CONFIG_TBL,R4	;dann
	JSR	CAN_RESET		;  MSCAN0 neu initialisieren
					;
INIT_CAN2:
	MOVB	#0,CAN0_TIMEOUT_CTR	;Zeitgrenz-Zähler auf Startwert
					;
INIT_CAN3:
	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_LIN sichert die Einstellungen des LIN-Masters.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
INIT_LIN:

	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_ANALOG bereitet die Spannungsmessung der Analogeingänge vor.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
INIT_ANALOG:
	MOVB	#10000000b,ATD0CTL2	;Power on, int's and ext-triggger disable
	MOVB	#01000000b,ATD0CTL3	;8 Kanäle, non-FIFO mode, non-FREEZE mode
	MOVB	#C_ATD_PRSC,ATD0CTL4	;10-bit AD, 2 clock periods sample time
	MOVB	#0,ATD0DIEN		;disable digital inputs
	RTS				;
					;
;------------------------------------------------------------------------------
;INIT_SENSORS sichert die Einstellungen der Sensor-Schnittstellen.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
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
;veränderte Register:	CCR, A, B, X, Y
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
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
MISC_INIT:
	BCLR	CLKSEL,#00111111b	;Stromsparmodi ausschalten
					;
	JSR	WATCHDOG_RESET		;Watchdog rücksetzen
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end


