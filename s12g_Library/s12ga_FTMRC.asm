	include	"s12ga_240.sfr"
	include	"s12ga_Switches.sfr"
	title	"s12ga_FTMRC  Copyright (C) 2009-2014, micro dynamics GmbH"
;------------------------------------------------------------------------------
;Module:	s12ga_FTMRC.asm
;
;Copyright:	(C) 2009-2014, micro dynamics GmbH
;Author(s):	Michael Frank
;Update:	27.11.2014
;
;Description:	Funktionen für den Schreibzugriff auf den prozessorinternen
;		Flash EEPROM-Speicher des Freescale MC9S12GA240
;		Hervorgegangen aus s12p_FTMRC.asm
;		Die Funktionen weisen weitgehend gleiche Parameterkonventionen
;		auf wie diejenigen der Module s12c_FTS.asm bzw. s12_EETS.asm.
;------------------------------------------------------------------------------
;Revision History:	Original Version  04.09
;
;27.11.2014	Anpassung an MC9S12GA240:
;		C_SECTOR_SIZE = 2	(s12p = 128)
;		GLOBAL_OFFSET = 0	(s12p = 4000h)
;
;24.04.2010	Korrektur in Funktion FTMRC_COPY
;------------------------------------------------------------------------------
					;
;------------------------------------------------------------------------------
;Externals
;------------------------------------------------------------------------------
					;
	xref	BUS_CLK			;Number
	xref.b	C_FDIV			;Number
					;
;------------------------------------------------------------------------------
;Publics
;------------------------------------------------------------------------------
					;
	xdef	FTMRC_COPY		;Code
	xdef	FTMRC_FLASH		;Code
	xdef	FTMRC_RESET		;Code
	xdef	FTMRC_WRITE8		;Code
	xdef	FTMRC_WRITE16		;Code
					;
	xdef	E_FTMRC_BUSY		;Number
	xdef	E_FTMRC_TIMEOUT		;Number
	xdef	E_FTMRC_INVALID_ACCESS	;Number
					;
;------------------------------------------------------------------------------
;Constants
;------------------------------------------------------------------------------
					;
E_FTMRC_BUSY:		equ	-1
E_FTMRC_TIMEOUT:	equ	-2
E_FTMRC_INVALID_ACCESS:	equ	-3
					;
CMD_PROGRAM:		equ	11h
CMD_SECTOR_ERASE:	equ	12h
					;
;------------------------------------------------------------------------------
;C_SECTOR_SIZE gibt die Größe eines zusammenhängend zu löschenden Speicher-
;sektors in Anzahl der Datenworte an.
;Zur Anpassung an andere Sektorgrößen ist dieser Wert entsprechend zu ändern.
;------------------------------------------------------------------------------
					;
C_SECTOR_SIZE:	equ	2		;4 Bytes (= 2 Words) Sektorgröße
					;
SECTOR_MASK:    equ	(2 * C_SECTOR_SIZE) - 1
I_BIT:		equ	bit4		;
					;
;------------------------------------------------------------------------------
;GLOBAL_OFFSET gibt den Versatz zwischen der Adresse im lokaler 64k-Adressenraum
;und der Adresse im globalen 256k-Adressenraum an.
;------------------------------------------------------------------------------
					;
GLOBAL_OFFSET:	equ	0000h		;
					;
;------------------------------------------------------------------------------
;Variables
;------------------------------------------------------------------------------
					;
.locals:	section
					;
BOV:
FTMRC_FLAGS:	ds.b	1		;Flags
_LOADED:	equ	bit0		;1, wenn EEPROM-Sektor in Sektorbuffer eingelesen ist
;
;
;
_LAST_I_BIT:	equ	bit4		;1, wenn I-bit = 1 war
;
;
_DIRTY:		equ	bit7		;1, wenn Sektorbuffer gegenüber EEPROM-Sektor verändert wurde
					;
FTMRC_SECTOR_ADDR:
		ds.w	1		;Zeiger auf aktuellen Sektor im D-Flash EEPROM-Speicher,
					;wenn _LOADED gesetzt
FTMRC_SECTOR_BUF:
		ds.w	C_SECTOR_SIZE	;Sektorbuffer
					;
TOV:
					;
.text:		section
					;
;------------------------------------------------------------------------------
;PROGRAM_SECTOR aktualisiert einen Sektor im internen D-Flash EEPROM-Speicher.
;
;Eingangsparameter:	X		Zeiger auf Quelle, bleibt unverändert
;			Y		Zeiger auf Ziel, bleibt unverändert
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, R[8..13]
;------------------------------------------------------------------------------
					;
PROGRAM_SECTOR:
	STX	R8			;X- und Y-Register retten
	STY	R10			;
					;
	BRSET	FCLKDIV,_FDIVLD,PROGRAM_SECTOR1
	MOVB	#C_FDIV,FCLKDIV		;ggf. Taktvorteiler setzen
					;
PROGRAM_SECTOR1:
	BRSET	FSTAT,_CCIF,PROGRAM_SECTOR2
	LDAA	#E_FTMRC_BUSY		;Fehler: Nicht bereit
	LBRA	PROGRAM_SECTOR9		;
					;
PROGRAM_SECTOR2:
	BRCLR	FSTAT,_FPVIOL | _ACCERR,PROGRAM_SECTOR21
	BSET	FSTAT,_FPVIOL | _ACCERR	;Fehlerflags zurücksetzen
					;
PROGRAM_SECTOR21:
	LDD	#0FFFFh			;
	LDX	#C_SECTOR_SIZE		;
PROGRAM_SECTOR22:
	CPD	2,Y+			;
	BNE	PROGRAM_SECTOR3		;
	DBNE	X,PROGRAM_SECTOR22	;
	BRA	PROGRAM_SECTOR4		;wenn Sektor <> 0FFFFh.0FFFFh... ...0FFFFh.0FFFFh
					;
PROGRAM_SECTOR3:
	LDD	R10			;für die Programmierung jetzt
	ADDD	#GLOBAL_OFFSET		;Umrechnung der lokalen in die globale Adresse
	EXG	D,Y			;
	MOVB	#0,FCCOBIX		;dann
	LDAA	#CMD_SECTOR_ERASE	;  Kommando: Sektor löschen
	LDAB	#0			;
	STD	FCCOB			;
					;
	MOVB	#1,FCCOBIX		;
	STY	FCCOB			;  Startaddresse ablegen
					;
	BSR	SUBMIT_COMMAND		;  Kommando ausführen
	BNE	PROGRAM_SECTOR9		;
					;
PROGRAM_SECTOR4:
	LDX	R8			;
	LDD	R10			;für die Programmierung jetzt
	ADDD	#GLOBAL_OFFSET		;Umrechnung der lokalen in die globale Adresse
	EXG	D,Y			;
	LDD	#C_SECTOR_SIZE		;nun Sektor programmieren
	STD	R12			;
PROGRAM_SECTOR41:
	MOVB	#0,FCCOBIX		;
	LDAA	#CMD_PROGRAM		;Kommando: Programmieren
	LDAB	#0			;
	STD	FCCOB			;
					;
	LDD	2,X+			;wenn Datenwort = 0FFFFh,
	CPD	#0FFFFh			;dann
	BEQ	PROGRAM_SECTOR42	;  keine Programmierung erforderlich
					;
	MOVB	#1,FCCOBIX		;sonst
	STY	FCCOB			;  Addresse ablegen
					;
	MOVB	#2,FCCOBIX		;
	STD	FCCOB			;  Datenwort ablegen
					;
	BSR	SUBMIT_COMMAND		;  Kommando ausführen
	BNE	PROGRAM_SECTOR9		;
PROGRAM_SECTOR42:
	LEAY	2,Y			;
	LDD	R12			;
	SUBD	#1			;
	STD	R12			;
	BNE	PROGRAM_SECTOR41	;weiter, bis gesamter Sektor bearbeitet
					;
PROGRAM_SECTOR8:
	CLRA				;ok, mit A = 0 zurück
					;
PROGRAM_SECTOR9:
	LDX	R8			;X- und Y-Register restaurieren
	LDY	R10			;
	RTS				;
					;
;------------------------------------------------------------------------------
;SUBMIT_COMMAND führt ein vorbereitetes Lösch- bzw. Schreibkommando aus.
;
;Eingangsparameter:	A		Kommando
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B
;------------------------------------------------------------------------------
					;
SUBMIT_COMMAND:

 ifeq fDebug
	MOVB	#55h,ARMCOP		;Watchdog-Timer neu starten
	MOVB	#0AAh,ARMCOP		;muss hier, anders als bei s12c, nicht zwingend zu Fuß gemacht werden
 endif


	BSET	FSTAT,_CCIF		;Kommandoausführung starten
	LDD	#BUS_CLK		;Timeout auf Startwert : max 40 ms
SUBMIT_COMMAND1:
	BRSET	FSTAT,_CCIF,SUBMIT_COMMAND2		;5
	NOP				;		 1
	NOP				;		 1
	DBNE	D,SUBMIT_COMMAND1	;		 3
					;	Summe	10 Zyklen : max 10 ms
	LDD	#BUS_CLK		;
SUBMIT_COMMAND11:
	BRSET	FSTAT,_CCIF,SUBMIT_COMMAND2		;5
	NOP				;		 1
	NOP				;		 1
	DBNE	D,SUBMIT_COMMAND11	;		 3
					;	Summe	10 Zyklen : max 10 ms
	LDD	#BUS_CLK		;
SUBMIT_COMMAND12:
	BRSET	FSTAT,_CCIF,SUBMIT_COMMAND2		;5
	NOP				;		 1
	NOP				;		 1
	DBNE	D,SUBMIT_COMMAND12	;		 3
					;	Summe	10 Zyklen : max 10 ms
	LDD	#BUS_CLK		;
SUBMIT_COMMAND13:
	BRSET	FSTAT,_CCIF,SUBMIT_COMMAND2		;5
	NOP				;		 1
	NOP				;		 1
	DBNE	D,SUBMIT_COMMAND13	;		 3
					;	Summe	10 Zyklen : max 10 ms
	LDAA	#E_FTMRC_TIMEOUT	;Fehler: Timeout
	BRA	SUBMIT_COMMAND9		;
					;
SUBMIT_COMMAND2:
	BRCLR	FSTAT,_FPVIOL | _ACCERR,SUBMIT_COMMAND8
	LDAA	#E_FTMRC_INVALID_ACCESS	;Fehler: Unzulässiger Schreibzugriff
	BRA	SUBMIT_COMMAND9		;
					;
SUBMIT_COMMAND8:
	CLRA				;ok, mit A = 0 zurück
					;
SUBMIT_COMMAND9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FTMRC_RESET fegt den EEPROM-Sektorbuffer und setzt die
;Statusflags zurück.
;
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR, A, B, X, Y
;------------------------------------------------------------------------------
					;
FTMRC_RESET:
	LDY	#FTMRC_SECTOR_BUF
	LDX	#C_SECTOR_SIZE		;
	LDD	#0FFFFh			;
FTMRC_RESET1:
	STD	2,Y+			;Sektorbuffer fegen
	DBNE	X,FTMRC_RESET1		;
					;
	MOVB	#0,FTMRC_FLAGS		;Flags rücksetzen
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FTMRC_WRITE8 schreibt ein Byte in den internen EEPROM-Sektorbuffer.
;
;Eingangsparameter:	R6/R7		Zieladresse
;			R0		Datenbyte
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, X, Y, R[3..13]
;------------------------------------------------------------------------------
					;
FTMRC_WRITE8:
	MOVW	#R0,R4			;Zeiger auf Quelle in R4/R5
	MOVB	#1,R3			;1 Byte
	JSR	FTMRC_COPY		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FTMRC_WRITE16 schreibt ein Wort in den internen EEPROM-Sektorbuffer.
;
;Eingangsparameter:	R6/R7		Zieladresse
;			R0/R1		Datenwort
;Ausgangsparameter:	A		0	= ok
;					<> 0	= Fehlercode
;veränderte Register:	CCR, B, X, Y, R[3..13]
;------------------------------------------------------------------------------
					;
FTMRC_WRITE16:
	MOVW	#R0,R4			;Zeiger auf Quelle in R4/R5
	MOVB	#2,R3			;2 Bytes
	JSR	FTMRC_COPY		;
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FTMRC_COPY schreibt n Bytes in den internen EEPROM-Sektorbuffer.
;
;Eingangsparameter:     R4/R5		Quelladresse
;			R6/R7		Zieladresse
;			R3		Anzahl Bytes (0 == 256)
;			FTMRC_SECTOR_ADDR
;			FTMRC_SECTOR_BUF
;			FTMRC_FLAGS._LOADED
;			FTMRC_FLAGS._DIRTY
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;	wenn A = 0:	R4/R5		nächste Quelladresse
;			R6/R7		nächste Zieladresse
;			FTMRC_SECTOR_ADDR
;			FTMRC_SECTOR_BUF
;			FTMRC_FLAGS._LOADED
;			FTMRC_FLAGS._DIRTY
;veränderte Register:	CCR, B, X, Y, R[3..17]
;------------------------------------------------------------------------------
					;
FTMRC_COPY:
	LDD	R6			;Zieladresse aufbereiten
	ANDB	#LOW (~SECTOR_MASK)	;
	ANDA	#HIGH (~SECTOR_MASK)	;
	STD	R14			;Sektor-Basisadresse in R14/R15
	LDD	R6			;
	ANDB	#LOW (SECTOR_MASK)	;
	ANDA	#HIGH (SECTOR_MASK)	;
	STD	R16			;Sektor-Offset in R16/R17
					;
FTMRC_COPY1:
	BRSET	FTMRC_FLAGS,_LOADED,FTMRC_COPY3
	LDX	R14			;wenn kein Sektor geladen
	LDY	#FTMRC_SECTOR_BUF	;
	LDD	#C_SECTOR_SIZE		;
	STD	R12			;
FTMRC_COPY2:
	LDD	2,X+			;dann
	STD	2,Y+			;  Sektor in Sektorbuffer laden
	LDD	R12			;
	SUBD	#1			;
	STD	R12			;
	BNE	FTMRC_COPY2		;
	MOVW	R14,FTMRC_SECTOR_ADDR	;  Sektor-Basisadresse merken
	BCLR	FTMRC_FLAGS,_DIRTY	;  _DIRTY-Flag rücksetzen
	BSET	FTMRC_FLAGS,_LOADED	;  _LOADED-Flag setzen
					;
FTMRC_COPY3:
	LDD	FTMRC_SECTOR_ADDR	;
	CPD	R14			;wenn neuer Sektor <> alter Sektor
	BEQ	FTMRC_COPY4		;und alter Sektor verändert,
	BRCLR	FTMRC_FLAGS,_DIRTY,FTMRC_COPY4
					;dann
	JSR	FTMRC_FLASH		;  alten Sektor aktualisieren
	BRA	FTMRC_COPY1		;
					;
FTMRC_COPY4:
	LDX	R4			;Zeiger auf Quelle laden
	LDY	R16			;Sektor-Offset
	LEAY	FTMRC_SECTOR_BUF,Y	;Zeiger in Sektorbuffer
	LDAA	1,X+			;Byte aus Quelle lesen
	CMPA	0,Y			;wenn Quellbyte von Byte im Sektorbuffer verschieden
	BEQ	FTMRC_COPY5		;dann
	STAA	0,Y			;  Quellbyte in den Sektorbuffer schreiben
	BSET	FTMRC_FLAGS,_DIRTY	;  _DIRTY-Flag setzen
FTMRC_COPY5:
	STX	R4			;
	LDY	R6			;Zeiger verschieben
	INY				;
	STY	R6			;
	LDY	R16			;
	INY				;
	STY	R16			;
	DEC	R3			;
	CPY	#SECTOR_MASK		;wenn Sektor-Offset eine Sektor-Grenze erreicht hat,
	BLS	FTMRC_COPY6		;dann
	JSR	FTMRC_FLASH		;  letzten Sektor zurückschreiben
	BNE	FTMRC_COPY9		;  nach Fehler abbrechen und mit Fehlercode zurück
	LDAA	R3			;  wenn noch nicht alle Bytes geschrieben,
	BEQ	FTMRC_COPY7		;  dann
	LDD	R14			;    Sektor-Basisadresse zeigt auf nächsten Sektor
	ADDD	#(2*C_SECTOR_SIZE)	;
	STD	R14			;
	LDD	#0			;    Sektor-Offset auf 0 setzen
	STD	R16			;    nächsten Sektor in Sektorbuffer laden
	LBRA	FTMRC_COPY1		;    und Schreiben dann fortsetzen
					;
FTMRC_COPY6:
	LDAA	R3			;sonst weiter,
	BNE	FTMRC_COPY4		;  bis alle Bytes in Sektorbuffer geschrieben
					;
FTMRC_COPY7:
	CLRA				;danach mit A = 0 zurück
					;
FTMRC_COPY9:
	RTS				;
					;
;------------------------------------------------------------------------------
;Public: FTMRC_FLASH löscht einen D-Flash EEPROM-Speichersektor und programmiert ihn
;mit dem Inhalt des EEPROM-Sektorbuffers.
;
;Eingangsparameter:	FTMRC_SECTOR_ADDR
;			FTMRC_SECTOR_BUF
;			FTMRC_FLAGS._LOADED
;			FTMRC_FLAGS._DIRTY
;Ausgangsparameter:	A		0 	= ok
;					<> 0	= Fehlercode
;			FTMRC_SECTOR_ADDR
;			FTMRC_SECTOR_BUF
;			FTMRC_FLAGS._LOADED
;			FTMRC_FLAGS._DIRTY
;veränderte Register:	CCR, B, X, Y, R[8..13]
;------------------------------------------------------------------------------
					;
FTMRC_FLASH:
	BRCLR	FTMRC_FLAGS,_LOADED,FTMRC_FLASH8
	BRCLR	FTMRC_FLAGS,_DIRTY,FTMRC_FLASH8
					;wenn Sektorbuffer geladen und verändert
	LDX	#FTMRC_SECTOR_BUF	;dann
	LDY	FTMRC_SECTOR_ADDR	;
	TFR	CCR,A			;
	ANDA	#I_BIT			;  wenn I-bit gesetzt,
	BEQ	FTMRC_FLASH1		;  dann
	BSET	FTMRC_FLAGS,_LAST_I_BIT	;    _LAST_I_BIT setzen
	BRA	FTMRC_FLASH2		;  sonst
FTMRC_FLASH1:
	BCLR	FTMRC_FLAGS,_LAST_I_BIT	;    _LAST_I_BIT rücksetzen
FTMRC_FLASH2:
	SEI				;  Interrupts sperren
	JSR	PROGRAM_SECTOR		;  Programmierung ausführen
	BRSET	FTMRC_FLAGS,_LAST_I_BIT,FTMRC_FLASH3
					;  wenn _LAST_I_BIT nicht gesetzt,
					;  dann
	CLI				;    Interrupts freigeben
FTMRC_FLASH3:
	CMPA	#0			;  wenn Fehler passiert
	BNE	FTMRC_FLASH9		;  dann
					;    mit Fehlercode zurück
FTMRC_FLASH8:
	JSR	FTMRC_RESET		;Sektorbuffer fegen und Flags rücksetzen
	CLRA				;ok, mit A = 0 zurück
					;
FTMRC_FLASH9:
	RTS				;
					;
	dcb.b	6, 0FFh			;
	SWI				;
					;
;------------------------------------------------------------------------------
	end
