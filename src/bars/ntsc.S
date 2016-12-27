
; Copyright (c) 2015 Nicholas DeCicco. <nsd.cicco@gmail.com>
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

.file "ntsc.S"
.arch msp430g2231
.cpu 430

#include <msp430.h>

#define PC r0
#define SP r1
#define SR r2

#define OUT_PINS BIT4|BIT5|BIT6|BIT7
#define ODD_FIELD_EXTRA
;#define OUT_SYNC 0x0
;#define OUT_BLACK BIT2
;#define OUT_WHITE BIT4|BIT6|BIT7

.section	.init9,"ax",@progbits
.p2align 1,0
.global	main
	.type	main,@function
main:
	mov r1,r4
	add #2,r4
	mov.w #WDTPW|WDTHOLD,&WDTCTL
	bis.b #OUT_PINS,&P1DIR
	bis.b #BIT0,&P1DIR
	mov.b #RSEL0|RSEL1|RSEL2|RSEL3,&BCSCTL1
	mov.b #DCO0|DCO1|DCO2,&DCOCTL
	bic.b #SELM0|SELM1|DIVM0|DIVM1,&BCSCTL2
;	mov.b #OUT_SYNC,r5
;	mov.b #OUT_BLACK,r6
;	mov.b #OUT_WHITE,r7
	mov.b #0x0,r5  ; sync level
	mov.b #0x40,r6 ; black level
	mov.b #0xD0,r7 ; white level

	mov.w #0x01,r11 ; will use r11 to keep track of even/odd fields
	                ; 0 = even field
	                ; 1 = odd field
	                ; We'll set this to 1 now because the 1 bit will be
	                ; immediately flipped.
	mov.b #0x01,r10 ; use pin 1 as trigger

; start of a new field.
; this sub is hit for both even and odd fields.
newfield:
	mov.b #239,r14 ; line #. There are 241 active lines on an even 
	xor.w #0x01,r11

line:

;; front porch (1.5 uS)
	mov.b r6,&P1OUT ; 4 cycles = 0.193 uS
	;mov.b #7,r15    ; 2 cycles = ~0.1 uS
	mov.b #10,r15    ; 2 cycles = ~0.1 uS
fp:
	sub.b #1,r15    ; delay (2 cycles)
	jnz fp          ; 2 cycles = ~0.1 uS

	; delay loop cost:
	; (init r15) + [ (sub) + (jnz) ]*count
	; (2 + count*(2+2))/20.7e6 = 1.5 uS - 0.193 uS
	;  ^-- cost of initializing r15       ^^^^^^^^
	; cost of changing value for next portion of signal
	; count = ((1.5e-6 - 0.193e-6) * 20.7e6 - 2)/4 = 6.26
	; using 6 cylces gives cost of delay loop of
	;    (2 + 6*4)/20.7 ~= 1.25 uS
	; adding the 0.193 uS of transitioning states
	;    1.25 uS + 0.193 uS ~= 1.45 uS

	; add one bogus register move to add 1/20.7e6 ~= 0.05 uS
	mov r6,r15

;; sync (4.7 uS)
	mov.b r5,&P1OUT
	;mov.b #23,r15     ; 2 cycles = ~0.1 uS
	mov.b #32,r15     ; 2 cycles = ~0.1 uS <-- trial and error
sync:
	sub.b #1,r15    ; delay (2 cycles)
	jnz sync        ; 2 cycles
	; count = ((4.7e-6 - 0.193e-6) * 20.7e6 - 2)/4 = 22.8


;; back porch (5 uS)
	mov.b r6,&P1OUT ; 4 cycles = 0.193 uS
;	mov.b #18,r15     ; 2 cycles = ~0.1 uS
	mov.b #33,r15     ; 2 cycles = ~0.1 uS <-- trial and error
bp:
	sub.b #1,r15    ; delay (2 cycles)
	jnz bp          ; 2 cycles
	; count = ((5e-6 - 0.193e-6) * 20.7e6 - 2)/4 = 24.37

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; active line (52.5 uS) ;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	mov #4,r13
al_init:
	mov.b r13,r12                        ; (1 cycle)
	bic.b #0xFE,r12 ; select only 1s digit (2 cycles)
	;ral r12 ; 1<<1 = 2
	;ral r12 ; 2<<1 = 4
	;ral r12 ; 2<<1 = 8
	;ral r12 ; 2<<1 = 16 (1 in the upper nib)
	;ral r12 ; 2<<1 = 32 (2 in the upper nib)
	;ral r12 ; 2<<1 = 64 (4 in the upper nib)  ;
	; ^ral is emulated, prefer to use rrc (rotate r carry)
	; only two ops anyway this way: (plus clear carry)
	bic #1,SR ; clear carry flag
	rrc.b r12 ; 0000 0001 -> 1000 0000 (1 cycle)
	rrc.b r12 ; 1000 0000 -> 0100 0000 (1 cycle)
	mov.b r7,r8  ; 1 cycle
	sub.b r12,r8 ; 1 cycle

	mov.b r8,&P1OUT ; 4 cycles = 0.193 uS
	;mov.w #269,r15
;	mov.w #353,r15 ; <-- trial and error (w/ no line counting)
;	mov.w #351,r15 ; <-- trial and error
	mov.w #85,r15 ; <-- trial and error
al:
	sub.w #1,r15
	jnz al
	; count = ((52.5e-6 - 0.193e-6) * 20.7e6 - 4)/4 = 269.7

	dec.w r13
	jnz al_init

	dec.w r14
	jnz line ; 2 cycles

; After an odd field, we need to display an extra half line.
	cmp #0,r11
	jz pre_pre_eq

#ifdef ODD_FIELD_EXTRA
;; front porch (1.5 uS)
	mov.b r6,&P1OUT ; 4 cycles = 0.193 uS
	mov.b #10,r15    ; 2 cycles = ~0.1 uS
fp_extra:
	sub.b #1,r15    ; delay (2 cycles)
	jnz fp_extra          ; 2 cycles = ~0.1 uS
	mov r6,r15 ; bogus mov op for time
;; sync (4.7 uS)
	mov.b r5,&P1OUT
	mov.b #32,r15     ; 2 cycles = ~0.1 uS <-- trial and error
sync_extra:
	sub.b #1,r15    ; delay (2 cycles)
	jnz sync_extra        ; 2 cycles
;; back porch (5 uS)
	mov.b r6,&P1OUT ; 4 cycles = 0.193 uS
	mov.b #33,r15
bp_extra:
	sub.b #1,r15
	jnz bp_extra
;; active line (52.5 uS)
	mov.w #160,r15 ; <-- trial and error
al_extra:
	sub.b #0x1, r15
	jnz al_extra
#endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Equalization pulses before the vertical sync ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

pre_pre_eq:

	mov #6,r14               ; There are three equalization pulse "lines",
	                         ; but two actual pulses per line.

preveq_init:
	mov.w #16, r15
	mov.b r5,&P1OUT
preverteq:
	dec.w r15
	; 2.54 uS
	jnz preverteq

	mov.w #198, r15          ; double up eq pulses
	mov.b r6, &P1OUT
eqline:
	dec.w r15
	jnz eqline

	dec.w r14
	jnz preveq_init

	mov #6,r14               ; double up vert pulses
vsync_init:
	mov.b r5,&P1OUT          ; Take output low
	mov.w #182, r15          ; double up vert pulses
vsync:
	dec.w r15
	jnz vsync

	mov.b r6,&P1OUT          ; Take output to black level for vsync pulse
	mov.w #32, r15

vsync_pulse:
	dec.w r15
	jnz vsync_pulse

	dec.w r14
	jnz vsync_init

;; Post vertical sync equalization pulses

	;mov.w #3,r14
	mov.w #6,r14 ; double up eq pulses

preveq_init2:
	mov.w #16, r15
	mov.b r5,&P1OUT
preverteq2:
	dec.w r15
	; 2.54 uS
	jnz preverteq2

	;mov.w #412, r15
	mov.w #198, r15
	mov.b r6, &P1OUT
eqline2:
	dec.w r15
	jnz eqline2

	dec.w r14
	jnz preveq_init2

; After an odd field, we need to delay by an extra 1/2 H.
	cmp #0,r11
	jz hl_start

#ifdef ODD_FIELD_EXTRA
	mov.w #214,r15
oddfieldextra:
	sub.b #1, r15
	jnz oddfieldextra
#endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; Blank (hidden) lines ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

hl_start:

#if 1
	mov.w #14,r14

hiddenlines:

;; front porch (1.5 uS)
	mov.b r6,&P1OUT          ; 4 cycles = 0.193 uS
	;mov.b #7,r15            ; 2 cycles = ~0.1 uS
	mov.b #10,r15            ; 2 cycles = ~0.1 uS
fp2:
	sub.b #1,r15             ; delay (2 cycles)
	jnz fp2                  ; 2 cycles = ~0.1 uS
	mov r6,r15               ; add one bogus register move to add
	                         ; 1/20.7e6 ~= 0.05 uS
;; sync (4.7 uS)
	mov.b r5,&P1OUT
	;mov.b #23,r15           ; 2 cycles = ~0.1 uS
	mov.b #32,r15            ; 2 cycles = ~0.1 uS <-- trial and error
sync2:
	sub.b #1,r15             ; delay (2 cycles)
	jnz sync2                ; 2 cycles
	; count = ((4.7e-6 - 0.193e-6) * 20.7e6 - 2)/4 = 22.8

;; back porch (5 uS)
	mov.b r6,&P1OUT          ; 4 cycles = 0.193 uS
;	mov.b #18,r15            ; 2 cycles = ~0.1 uS
	mov.b #33,r15            ; 2 cycles = ~0.1 uS <-- trial and error
bp2:
	sub.b #1,r15             ; delay (2 cycles)
	jnz bp2                  ; 2 cycles
	; count = ((5e-6 - 0.193e-6) * 20.7e6 - 2)/4 = 24.37

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; active line (52.5 uS) ;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	mov.b r6,&P1OUT          ; 4 cycles = 0.193 uS
	;mov.w #269,r15
;	mov.w #353,r15           ; <-- trial and error (w/ no line counting)
	mov.w #355,r15           ; <-- trial and error
;	mov.w #85,r15            ; <-- trial and error
al2:
	sub.w #1,r15
	jnz al2
	; count = ((52.5e-6 - 0.193e-6) * 20.7e6 - 4)/4 = 269.7

	dec.w r14
	jnz hiddenlines          ; 2 cycles

#endif

#ifdef ENABLE_SCOPE_TRIG
	bic.b r10,&P1OUT         ; trigger signal for scope
#endif

	jmp newfield
.end
