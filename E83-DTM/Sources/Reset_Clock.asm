Reset:
;------------------------------------------------------------------------------
;RESET_CLOCK stellt die PLL für den gewünschten Bustakt ein und schaltet den
;Takt von direktem Oszillatortakt auf PLL-Takt um.
;Eingangsparameter:	keine
;Ausgangsparameter:	keine
;veränderte Register:	CCR
;------------------------------------------------------------------------------
					;
RESET_CLOCK:
	BCLR	CLKSEL,_PLLSEL		;sicherstellen, dass Oszillatortakt eingeschaltet ist
	MOVB	#11110001b,PLLCTL	;
					;
 ifne fUse_PLL
	MOVB	#C_SYNR,SYNR		;PLL_CLK = OSC_CLK * (SYNR+1) / (REFDV+1)
	MOVB	#C_REFDV,REFDV		;und warten, bis PLL eingeschwungen ist
RESET_CLOCK1:
	BRCLR	CRGFLG,_LOCK,RESET_CLOCK1
					;
	MOVB	#10000000b,CLKSEL	;Bustakt auf PLL-Takt umschalten
 else
	MOVB	#00000000b,CLKSEL	;Bustakt auf Oszillatortakt schalten
 endif
					;
	RTS				;
					;

Init:
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
