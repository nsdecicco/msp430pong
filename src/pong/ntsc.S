
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

; +---------------------------------------------------------+
; |           Register Usage                                |
; +-----+---------------------------------------------------+
; |     | Use                                               |
; +-----+---------------------------------------------------+
; | r0  | program counter (PC)                              |
; | r1  | stack pointer (SP)                                |
; | r2  | SR                                                |
; | r3  | constant generator                                |
; +-----+---------------------------------------------------+
; | r4  | used by system???                                 |
; | r5  | paddle positions (low byte = left, high = right)  |
; | r6  | black level                                       |
; | r7  | white level                                       |
; | r8  | ball velocity (low byte = x, high byte = y)       |
; | r9  | temp usage                                        |
; | r10 | ball position                                     |
; | r11 | temp usage                                        |
; | r12 | temp usage                                        |
; | r13 | temp usage                                        |
; | r14 | line number                                       |
; | r15 | loop counter for small local loops (delay loops)  |
; +-----+---------------------------------------------------+

; Registers
#define BALLPOS   r10
#define PADDLEPOS r5
#define BALLVEL   r8
#define LINENUM   r14
#define LOOPCTR   r15
#define BLKLVL    r6
#define WHTLVL    r7

#define P2X 100 ; paddle 2 starting x position (FIXME just a guess)
#define BALLSTART 0x4040 ; Ball starting position (FIXME just a guess)
#define BALL_H 0x08
#define BALL_W 0x08
#define PADWIDTH  0x08

.section	.init9,"ax",@progbits
.p2align 1,0
.global	main
	.type	main,@function
main:
	;mov r1,r4
	;add #2,r4
	mov.w #WDTPW|WDTHOLD,&WDTCTL
	;bis.b #OUT_PINS,&P1DIR
	;bic.b #BIT0|BIT1|BIT2|BIT3,&P1DIR
	mov.b #0xf0,&P1DIR ; pins P1.0-P1.3 are switches; P1.4-P1.7 are outputs
	mov.b #0x0f,&P1REN ; enable pullup resistor on P1.0-P1.3
	mov.b #0x0f,&P1OUT ; set pullup resistor on P1.0-P1.3
	mov.b #RSEL0|RSEL1|RSEL2|RSEL3,&BCSCTL1
	mov.b #DCO0|DCO1|DCO2,&DCOCTL
	bic.b #SELM0|SELM1|DIVM0|DIVM1,&BCSCTL2
	mov.b #0x4f,BLKLVL ; black level (with pullup resistor info crammed in)
	mov.b #0xDf,WHTLVL ; white level (with pullup resistor info crammed in)

    mov.w #0x7540,BALLPOS
	mov.w #0xffff,BALLVEL
	mov.w #0x0000,PADDLEPOS

; start of a new field.
; this sub is hit for both even and odd fields.
newfield:
	mov.b #239,LINENUM ; line #. There are 241 active lines on an even 
	xor.w #0x100,LINENUM

line:

;; front porch (1.5 uS)
	mov.b BLKLVL,&P1OUT ; 4 cycles = 0.193 uS
	;mov.b #7,LOOPCTR    ; 2 cycles = ~0.1 uS
	mov.b #10,LOOPCTR    ; 2 cycles = ~0.1 uS
fp:
	sub.b #1,LOOPCTR    ; delay (2 cycles)
	jnz fp          ; 2 cycles = ~0.1 uS

	; delay loop cost:
	; (init LOOPCTR) + [ (sub) + (jnz) ]*count
	; (2 + count*(2+2))/20.7e6 = 1.5 uS - 0.193 uS
	;  ^-- cost of initializing LOOPCTR       ^^^^^^^^
	; cost of changing value for next portion of signal
	; count = ((1.5e-6 - 0.193e-6) * 20.7e6 - 2)/4 = 6.26
	; using 6 cylces gives cost of delay loop of
	;    (2 + 6*4)/20.7 ~= 1.25 uS
	; adding the 0.193 uS of transitioning states
	;    1.25 uS + 0.193 uS ~= 1.45 uS

	; add one bogus register move to add 1/20.7e6 ~= 0.05 uS
	mov BLKLVL,LOOPCTR

;; sync (4.7 uS)
	mov.b #0x0f,&P1OUT
	;mov.b #23,LOOPCTR     ; 2 cycles = ~0.1 uS
	mov.b #32,LOOPCTR     ; 2 cycles = ~0.1 uS <-- trial and error
sync:
	sub.b #1,LOOPCTR    ; delay (2 cycles)
	jnz sync        ; 2 cycles
	; count = ((4.7e-6 - 0.193e-6) * 20.7e6 - 2)/4 = 22.8


;; back porch (5 uS)
	mov.b BLKLVL,&P1OUT ; 4 cycles = 0.193 uS
;	mov.b #18,LOOPCTR     ; 2 cycles = ~0.1 uS
	mov.b #33,LOOPCTR     ; 2 cycles = ~0.1 uS <-- trial and error
bp:
	sub.b #1,LOOPCTR    ; delay (2 cycles)
	jnz bp          ; 2 cycles
	; count = ((5e-6 - 0.193e-6) * 20.7e6 - 2)/4 = 24.37

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; active line (52.5 uS) ;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;	mov #4,r13 ; want four vertical bars
;al_init:
;	mov.b r13,r12                        ; (1 cycle)
;	bic.b #0xFE,r12 ; select only 1s digit (2 cycles)
;	bic #1,SR ; clear carry flag
;	rrc.b r12 ; 0000 0001 -> 0000 0000, carry set   (1 cycle)
;	rrc.b r12 ; 0000 0000 -> 1000 0000, carry reset (1 cycle)
;	inv.b r12 ; negate r12
;	inc.b r12 ; negate r12 (coupled with the above inv. this
;	          ;             gives the negative two's compliment)
;	add.b WHTLVL,r12
;	mov.b r12,&P1OUT       ; 4 cycles = 0.193 uS
;	mov.w #85,LOOPCTR
;al:
;	sub.w #1,LOOPCTR
;	jnz al
;
;	dec.w r13
;	jnz al_init

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compute paddle drawing stuff ;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Will store colors in r9 and r11
; Paddle 1 pos is in low byte
	mov.b PADDLEPOS,r9
	mov r14,r12
	bic #0x100,r12
	cmp r9,r12
	jl p1_not_on_line
	add #0x40,r9
	cmp r9,r12
	jge p1_not_on_line
	mov WHTLVL,r9
	jmp p2test
p1_not_on_line:
	mov BLKLVL,r9

p2test:
	mov PADDLEPOS,r11
	bic.w #0x00FF,r11
	clrc
	rrc r11
	rrc r11
	rrc r11
	rrc r11
	rrc r11
	rrc r11
	rrc r11
	rrc r11
	cmp r11,r12
	jl p2_not_on_line
	add #0x40,r11
	cmp r11,r12
	jge p2_not_on_line
	mov WHTLVL,r11
	jmp balldraw
p2_not_on_line:
	mov BLKLVL,r11
    ; start bogus instr.
	;add #0x40,LOOPCTR        ; add #0x40,r11
	;cmp LOOPCTR,LOOPCTR      ; cmp r11,r12
	;cmp LOOPCTR,LOOPCTR      ; jge p2_not_on_line
	;cmp LOOPCTR,LOOPCTR      ; ^ also for above (4 cycles)
	;mov #0x40,LOOPCTR        ; mov WHTLVL,r11
	                         ; jmp balldraw
	;cmp LOOPCTR,LOOPCTR      ; ^ also for above (4 cycles)
	;cmp LOOPCTR,LOOPCTR      ; ^ also for above (4 cycles)
	                         ; ^ instructions that are missed when this
	; end bogus instr            jump is hit

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compute ping pong ball drawing info ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

balldraw:

	; Is (part of) the ball on this line?
	mov BALLPOS,r13
	bic #1,SR ; clear carry flag
	bic #0x00FF,r13 ; clr.b oddly clears the whole thing
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	rrc r13 ; r13 lower byte = by
#if 0
	cmp.b r13,r14
	jl not_ball_line
	add.b #0x08,r13
	cmp.b r13,r14
	jge not_ball_line
#else
	mov r14,r12
	bic #0x100,r12
	cmp.w r13,r12
	jl not_ball_line
	add #0x8,r13
	cmp.w r13,r12
	jge not_ball_line
#endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw left paddle ;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	mov #20,LOOPCTR              ; Delay before drawing left paddle
	mov.b BLKLVL,&P1OUT          ; to shift it to the right
left_paddle_before_loop:
	dec LOOPCTR
	jnz left_paddle_before_loop

	mov #10,LOOPCTR
	mov.b r9,&P1OUT
left_paddle_loop:
	dec LOOPCTR
	jnz left_paddle_loop

	mov.b BLKLVL,&P1OUT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw ping pong ball ;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Compute how many delay cycles are necessary before drawing the ball
	mov.b BALLPOS,r13
	add r13,r13 ; double ball x position
	mov r13,LOOPCTR
ball_line_before_loop:
	dec LOOPCTR
	jnz ball_line_before_loop

	mov.b WHTLVL,&P1OUT
	mov #20,LOOPCTR
ball_line_ball_loop:
	dec LOOPCTR
	jnz ball_line_ball_loop

	mov.b BLKLVL,&P1OUT
	
	bic.w #0xFF00,r13
	inv r13
	inc r13
	add #227, r13       ; If this number is too small (active line is too
	                    ; short), the ball will be skewed horizontally to
	                    ; the right; if it is too large (active line is
	                    ; too long), it will be skewed to the left
	mov.w r13,LOOPCTR
ball_line_after_loop:
	dec LOOPCTR
	jnz ball_line_after_loop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw right paddle on ball line ;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	mov #10,LOOPCTR
	mov.b r11,&P1OUT ; TODO change back to r11
right_paddle_loop:
	dec LOOPCTR
	jnz right_paddle_loop

	mov #33,LOOPCTR
	mov.b BLKLVL,&P1OUT
right_paddle_after_loop:
	dec LOOPCTR
	jnz right_paddle_after_loop

	jmp ret_top

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lines that don't contain the ball ;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

not_ball_line:

	mov #20,LOOPCTR
	mov.b BLKLVL,&P1OUT
left_paddle_before_loop2:
	dec LOOPCTR
	jnz left_paddle_before_loop2

	mov #10,LOOPCTR
	mov.b r9,&P1OUT
left_paddle_loop2:
	dec LOOPCTR
	jnz left_paddle_loop2

	mov.b BLKLVL,&P1OUT
	mov #253,LOOPCTR

not_ball_line_loop:
	sub.w #1,LOOPCTR
	jnz not_ball_line_loop

	mov BLKLVL,LOOPCTR ; Add one bogus register move to add ~ 0.05 uS
	mov BLKLVL,LOOPCTR ; Add one bogus register move to add ~ 0.05 uS

	mov #10,LOOPCTR
	mov.b r11,&P1OUT
right_paddle_loop2:
	dec LOOPCTR
	jnz right_paddle_loop2

	mov #35,LOOPCTR
	mov.b BLKLVL,&P1OUT
right_paddle_after_loop2:
	dec LOOPCTR
	jnz right_paddle_after_loop2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; back to top ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ret_top:
	dec.b LINENUM
	jnz line
	bit #0x100,LINENUM
	jnz odd_extra_al
	jmp pre_pre_eq

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; odd field half active line ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

odd_extra_al:

; After an odd field, we need to display an extra half line.
	bit.w #100,LINENUM
	jz pre_pre_eq

;; front porch (1.5 uS)
	mov.b BLKLVL,&P1OUT       ; 4 cycles
	mov.b #10,LOOPCTR         ; 2 cycles
fp_extra:
	sub.b #1,LOOPCTR          ; 2 cycles
	jnz fp_extra          ; 2 cycles
	mov BLKLVL,LOOPCTR            ; bogus mov op for time
;; sync (4.7 uS)
	mov.b #0x0f,&P1OUT
	mov.b #32,LOOPCTR         ; 2 cycles
sync_extra:
	sub.b #1,LOOPCTR          ; 2 cycles
	jnz sync_extra        ; 2 cycles
;; back porch (5 uS)
	mov.b BLKLVL,&P1OUT
	mov.b #33,LOOPCTR
bp_extra:
	sub.b #1,LOOPCTR
	jnz bp_extra
;; active line (52.5 uS)
	mov.w #160,LOOPCTR
al_extra:
	sub.b #0x1, LOOPCTR
	jnz al_extra

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Equalization pulses before the vertical sync ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

pre_pre_eq:

	mov.b #6,LINENUM             ; There are three equalization pulse "lines",
	                         ; but two actual pulses per line.

preveq_init:
	mov.w #16, LOOPCTR
	mov.b #0x0f,&P1OUT
preverteq:
	dec.w LOOPCTR
	; 2.54 uS
	jnz preverteq

	mov.w #198, LOOPCTR          ; double up eq pulses
	mov.b BLKLVL, &P1OUT
eqline:
	dec.w LOOPCTR
	jnz eqline

	dec.b LINENUM
	jnz preveq_init

	mov.b #6,LINENUM             ; double up vert pulses
vsync_init:
	mov.b #0x0f,&P1OUT          ; Take output low
	mov.w #182, LOOPCTR          ; double up vert pulses
vsync:
	dec.w LOOPCTR
	jnz vsync

	mov.b BLKLVL,&P1OUT          ; Take output to black level for vsync pulse
	mov.w #32, LOOPCTR

vsync_pulse:
	dec.w LOOPCTR
	jnz vsync_pulse

	dec.b LINENUM
	jnz vsync_init

;; Post vertical sync equalization pulses

	;mov.b #3,LINENUM
	mov.b #6,LINENUM ; double up eq pulses

preveq_init2:
	mov.w #16, LOOPCTR
	mov.b #0x0f,&P1OUT
preverteq2:
	dec.w LOOPCTR
	; 2.54 uS
	jnz preverteq2

	;mov.w #412, LOOPCTR
	mov.w #198, LOOPCTR
	mov.b BLKLVL, &P1OUT
eqline2:
	dec.w LOOPCTR
	jnz eqline2

	dec.b LINENUM
	jnz preveq_init2

; After an odd field, we need to delay by an extra 1/2 H.
	bit.w #100,LINENUM
	jz hl_start

	mov.w #214,LOOPCTR
oddfieldextra:
	sub.b #1, LOOPCTR
	jnz oddfieldextra

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; Blank (hidden) lines ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

hl_start:
	mov.b #14,LINENUM

hiddenlines:
#ifdef TRIGGER_EQ_PULSES
	cmp #0x02,r14
	jnz donttrig
    bis.b #0x01, &P1OUT ; Trigger on P1.0
donttrig:
#endif

;; front porch (1.5 uS)
	mov.b BLKLVL,&P1OUT
	mov.b #10,LOOPCTR
fp2:
	sub.b #1,LOOPCTR
	jnz fp2
	mov BLKLVL,LOOPCTR               ; add one bogus register move to add

;; sync (4.7 uS)
	mov.b #0x0f,&P1OUT
	mov.b #32,LOOPCTR
sync2:
	sub.b #1,LOOPCTR
	jnz sync2

;; back porch (5 uS)
	mov.b BLKLVL,&P1OUT
	mov.b #33,LOOPCTR
bp2:
	sub.b #1,LOOPCTR
	jnz bp2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; active line (52.5 uS) ;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	mov.b BLKLVL,&P1OUT

	cmp #0x01,LINENUM
	jz al2_short
	;mov.w #355,LOOPCTR      ; this was the loop length w/o the
	                         ; above cmp/jz and al2_short
	mov.w #353,LOOPCTR
	jmp al2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; update game state ;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

al2_short:                   ; This is where we compute new ball position

	mov.w #280,LOOPCTR        ; TODO might need to adj shorter
	                          ; if too long, on RCA display, ball gets
	                          ; skewed to right at top of screen

	mov.b &P1IN,r12 ; p2 up
	bic.b #0xFE,r12
	xor.b #0x1,r12    ; inputs are active low; toggle bit
	mov.b &P1IN,r13
	clrc
	rrc.b r13
	bic.b #0xFE,r13
	xor.b #0x1,r13    ; inputs are active low; toggle bit
	inv.b r13
	inc.b r13
	add.b r13,r12   ; r12 = down - up
	mov.b PADDLEPOS,r13
	clrc                ; not sure if necessary
	add.b r12,r13
	cmp #0xff,r13
	jeq paddle_pos_x_neg
	bic.w #0x00FF,PADDLEPOS
	clrc
	add.w r13,PADDLEPOS
	mov.b PADDLEPOS,r13
	cmp #160,r13     ; TODO: adj this num
	jge paddle_pos_top
	jmp paddle2
paddle_pos_x_neg:
	bic.w #0x00FF,PADDLEPOS
	jmp paddle2
paddle_pos_top:
	dec PADDLEPOS

paddle2:
#if 1
	mov.b &P1IN,r12 ; p2 up
	rrc r12
	rrc r12
	bic #0xFFFE,r12
	xor #0x1,r12    ; inputs are active low; toggle bit
	mov.b &P1IN,r13
	clrc
	rrc r13
	rrc r13
	rrc r13
	bic #0xFFFE,r13
	xor #0x1,r13    ; inputs are active low; toggle bit
	inv r13
	inc r13
	add r13,r12       ; r12 = down - up
#if 0
	clrc
	rla r12           ; these rrcs move r12 lowbyte to highbyte
	adc r12
	rlc r12
	rlc r12
	rlc r12
	rlc r12
	rlc r12
	rlc r12
	rlc r12               ; now we have either 0xFFFF or 0x0100
	mov PADDLEPOS,r13
	bic #0x00FF,r13       ; r13 = xx00
	add r12,r13           ; if paddlepos upper byte was 0 and r12 = -1,
	inv.b r13             ; adding r12 to paddle pos gives 0xFFFF
	inc.b r13
	clrc                 ; 
	rla r13            ; 
	rla r13
	rla r13
	rla r13
	rla r13
	rla r13
	rla r13
	rla r13
	add.w r13,r12 ; add 1 to r12 if adding r12 to paddlepos causes it
	              ; to roll backwards
	add.w r12,PADDLEPOS
#else
	mov PADDLEPOS,r13
	clrc                ; not sure if necessary
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	rrc r13
	add.b r12,r13
	cmp.b #0xff,r13
	jeq paddle2_pos_neg
	bic.w #0xFF00,PADDLEPOS
	clrc
	rla r13
	rla r13
	rla r13
	rla r13
	rla r13
	rla r13
	rla r13
	rla r13
	add.w r13,PADDLEPOS
	mov.w PADDLEPOS,r13
	bic #0x00FF,r13
	clrc
	rrc r13
	cmp #0x5000,r13     ; TODO: adj this num (0x5000 = 160 << 7)
	jge paddle2_pos_top
	jmp update_ball_pos
paddle2_pos_neg:
	bic.w #0xFF00,PADDLEPOS
	jmp update_ball_pos
paddle2_pos_top:
	sub.w #0x100,PADDLEPOS
#endif
#endif

update_ball_pos:

#if 0
	add.w BALLVEL,BALLPOS   ; This doesn't always properly add each
	                         ;number separately like we want
#else
	mov.b BALLPOS,r13
	mov.b BALLVEL,r12
	add.b r12,r13
	bic.w #0x00FF,BALLPOS    ; Throw away x component of position
	                         ; (it's ok; we have the new x pos in r13)
	mov.w BALLVEL,r12
	bis.w #0x00FF,r12
	add.w r12,BALLPOS
	bic.w #0x00FF,BALLPOS
	add.w r13,BALLPOS        ; ball pos is now updated
#endif

	                         ; ball will be 8x8
	;cmp.b #PADWIDTH,BALLPOS  ; ball can't go past paddle
	;cmp.b #0x30,BALLPOS  ; ball can't go past paddle
	mov.b BALLPOS,r12
	cmp #0x2,r12
	jl ball_left             ; if it does, see if it hit the paddle
; ^^^^^^^ this one works

#if 0
	mov.b BALLPOS,r12
	add.b #0x8,r12           ; r12 = bx + bw

; FIXME: This test is not working at all TODO
; (try changing 200 to, say, 100)
	cmp.b #100,r12
	jl ball_right            ; see if ball went past right paddle
	                         ; (if 200 < r12)
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#else
	mov BALLPOS,r12
	bic #0xff00,r12
;	mov #122,r13
	mov #112,r13
	cmp r12,r13
	jl ball_right
	
#endif

	mov.w BALLPOS, r12
	bic.w #0x00FF, r12       ; r12 = by (in the high byte)
	add.w #0x800,r12         ; r12 = by + bh (in the high byte)
	bic #1,SR ; clear carry flag
; it seems like overspill is an issue here
	rrc r12
	rrc r12
	rrc r12
	rrc r12
	rrc r12
	rrc r12
	rrc r12
	rrc r12
; doesn't make a difference which:
#if 0
	cmp #0xE6,r12
#else
	mov #0xE6,r13
	cmp r12,r13
#endif
	jl ball_bot
;	cmp.w #0xE600,r12        ; 0xF1 = 241
;	jl ball_bot

#if 1
	sub.w #0x8, r12
	cmp #0x1, r12
	jl ball_top
#else
	mov.w BALLPOS, r12
	bic.w #0x00FF, r12       ; r12 = by (in the high byte)
	cmp.w #0x100,r12         ; to avoid signed representation of ball
	jge ball_top              ; vertical position, we won't let the ball go
	                         ; higher than 1 pixel from the top
#endif

	jmp al2

ball_bot:
	sub.w #0x100,BALLPOS
	jmp inv_y_vel

ball_top:
	add.w #0x100,BALLPOS
	jmp inv_y_vel

inv_y_vel:                   ; Invert y velocity
	mov.b BALLVEL,r13        ; Save x velocity to r13
	bis.w #0x00FF,BALLVEL    ; Throw away x velocity in BALLVEL
	inv.w BALLVEL            ; invert BALLVEL (0xFFFF -> 0x0000,
	                         ;                 0x01FF -> 0xFE00)
	add.w #0x100,BALLVEL     ; Make BALLVEL neg. whatever it was before
	                         ;                (0xFE00 -> 0xFF00)
	                         ;                (0x0000 -> 0x0100)
	add.w r13,BALLVEL
	jmp al2

inv_x_vel:                   ; Invert x velocity
	mov.b BALLVEL, r13
	inv.b r13
	inc.b r13
	bic.w #0x00FF,BALLVEL    ; Throw away x velocity in BALLVEL
	add.w r13, BALLVEL
	jmp al2

ball_right:                  ; Ball hit right edge
                             ; Need to check if ball hit paddle
#if 1
	mov.w BALLPOS,r12
	add.w #0x800,r12
	bic.w #0x00FF,r12        ; r12 = by + bh (in the high byte)
	mov.w PADDLEPOS,r13
	bic.w #0x00FF,r13        ; r13 = p1      (in the high byte)
	clrc ;hack to avoid weird overflow bug
	rrc r13 ;hack to avoid weird overflow bug
	clrc ;hack to avoid weird overflow bug
	rrc r12 ;hack to avoid weird overflow bug
	cmp.w r12,r13
	jge p1lose                ; is by + bh < p1?

	;rla r12 ;hack to avoid weird overflow bug
	;rla r13 ;hack to avoid weird overflow bug

	;sub.w #0x800,r12         ; r12 = by
	;add.w #0x4000,r13        ; r13 = p1 + ph

	sub.w #0x400,r12         ; r12 = by
	add.w #0x2000,r13        ; r13 = p1 + ph
	; ^ numbers adjusted to accomidate hack

	cmp.w r12,r13
	jl p1lose               ; is by > p1 + ph?
	; ^ TODO: change to p2lose
#endif

	; Only remaining case is that the ball hit the paddle. Reverse
	; direction.
	mov.b BALLPOS,r13        ; Bump ball back towards the left
	bic.w #0x00ff,BALLPOS
	dec.b r13
	add.w r13,BALLPOS
	jmp inv_x_vel


ball_left:                   ; Ball hit left edge
                             ; Need to check if ball hit paddle
#if 1
	mov.w BALLPOS,r12
	add.w #0x800,r12
	bic.w #0x00FF,r12        ; r12 = by + bh (in the high byte)
	mov.w PADDLEPOS,r13
	clrc
	rrc.w r13
	rrc.w r13
	rrc.w r13
	rrc.w r13
	rrc.w r13
	rrc.w r13
	rrc.w r13
	rrc.w r13
	rrc.w r13                ; r13 = p1      (in the high byte)
	bic.w #0x00FF,r13        ; r13 = p1      (in the high byte)
	cmp.w r12,r13
	jge p1lose                ; is by + bh < p1?

	sub.w #0x800,r12         ; r12 = by
	add.w #0x4000,r13        ; r13 = p1 + ph
	cmp.w r12,r13
	jl p1lose               ; is by > p1 + ph?
#endif

	; Only remaining case is that the ball hit the paddle. Reverse
	; y direction.
	mov.b BALLPOS,r13        ; Bump ball back towards the right
	inc.b r13
	bic.w #0x00ff,r13
	add.w r13,BALLPOS
	jmp inv_x_vel

p1lose:                      ; Player 1 loses (p2 gains a point)
	;mov.w #BALLSTART,BALLPOS  ; Reset ball position
	mov.w #0x7540,BALLPOS  ; Reset ball position

al2:
	sub.w #1,LOOPCTR
	jnz al2

	dec.b LINENUM
	jnz hiddenlines          ; 2 cycles

#ifdef TRIGGER_EQ_PULSES
    bic.b #0x01, &P1OUT ; Trigger on P1.0
#endif

	jmp newfield
.end
