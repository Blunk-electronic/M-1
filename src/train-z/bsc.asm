
ram_out		equ	80h
ram_out2	equ	0A3h 	;same as ram_out, but no increment of st_adr, ins V6.0
ram_in		equ	81h

st_adr0		equ	081h
st_adr1		equ	082h
st_adr2		equ	083h

path		equ	08Bh
cmd			equ	084h	;executor command/step_mode

dc_t1a		equ	060h	;drv_char_tap1a
dc_t1b		equ	062h	;drv_char_tap1b
dc_t2a		equ	064h	;drv_char_tap2a
dc_t2b		equ	066h	;drv_char_tap2b
tap1_rel	equ	040h
tap2_rel	equ	042h
i2c_mux		equ	020h
ref_cmp1	equ	058h
ref_cmp2	equ	05Ah
vcc_io1		equ	05Ch
vcc_io2		equ	05Eh

tap_in12	equ	088h	;TAP inputs 1/2 fail, tdi, exp, mask
ex_state	equ	089h	;exectuor state
t_state12	equ	08Ah	;state of tap 1 and 2

b_prc_1a	equ	08Ch	;LSB of bits processed 1
b_prc_1b	equ	08Dh
b_prc_1c	equ	08Eh
b_prc_1d	equ	08Fh	;MSB of bits processed 1

b_prc_2a	equ	097h	;LSB of bits processed 1
b_prc_2b	equ	098h
b_prc_2c	equ	099h
b_prc_2d	equ	09Ah	;MSB of bits processed 1

sxr_ln1a	equ	090h	;LSB of SXR chain length 1
sxr_ln1b	equ	091h
sxr_ln1c	equ	092h
sxr_ln1d	equ	093h	;MSB of SXR chain length 1

sxr_ln2a	equ	09Bh	;LSB of SXR chain length 2
sxr_ln2b	equ	09Ch
sxr_ln2c	equ	09Dh
sxr_ln2d	equ	09Eh	;MSB of SXR chain length 2

step_ida	equ	094h	;MSB of step_id
step_idb	equ	095h

ram_adr0	equ	085h	;LSB of current RAM address
ram_adr1	equ	086h
ram_adr2	equ	087h	;MSB of current RAM address

vec_st1		equ	096h	;vector state 1
vec_st2		equ	09Fh    ;vector state 2

strt_stop	equ	098h	;test start / stop   55/AA

fw_ex0		equ	0A0h	;executor firmware lowbyte
fw_ex1		equ	0A1h	;executor firmware highbyte

mach_sts	equ	0A2h	;machine status ; ins V6.0
				;	bit 0 cleared when a_ram is zero

;OFFSET	equ	2000h
OFFSET	equ	8000h
;OFFSET	equ	0000h




CH0	equ	0h
CH1	equ	1h
CH2	equ	2h
CH3	equ	3h

SIO_A_D	equ	4h
SIO_A_C	equ	6h
SIO_B_D	equ	5h
SIO_B_C	equ	7h

PIO_A_D	equ	8h
PIO_A_C	equ	0Ah
PIO_B_D	equ	9h
PIO_B_C	equ	0Bh

RAM_BOT		equ	1800h+OFFSET	;lowest user RAM address

RAM_DATA_STS	equ	1000h	;holds 1 after successful download in RAM area
				;beginning at 1800h+OFFSET

;RAM_HID		equ	1000h		;lowest system RAM address
SCRATCH		equ	1001h 	;used by various functions
CMD_STS		equ	1002h	;holds status of cmd. 0=incomplete, 1=complete
PIO_A_MODE	equ	1003h	;holds current PIO A mode
PIO_A_IO_CONF	equ	1004h	;holds current IO configuration of PIO A

PIO_B_MODE	equ	1005h	;holds current PIO B mode
PIO_B_IO_CONF	equ	1006h	;holds current IO configuration of PIO B

RAM_TOP		equ	1007h	;here and at RAM_TOP+1 highest user RAM address stored
			;1008h	;highbyte of highest user RAM address
;BLK_ERR		equ	1009h	;number of garbled blocks during download
OUT_LEN		equ	100Bh	;holds length of output buffer (lowbyte)
			;100Ch 	;holds length of output buffer (highbyte)
ECHO_STS	equ	100Dh	;holds FFh if echo enabled, 0h if echo disabled

TEMP3		equ	100Eh	;used by heartbeat

SOURCE_ADR	equ	100Fh	;for flash programming: source address lowbyte
			;1010h	;source address highbyte
DEST_ADR	equ	1011h	;for flash programming: destination address lowbyte
			;1012h	;destination address highbyte
NUMB_OF_BYTES	equ	1013h	;for flash programming: number of bytes lowbyte
			;1014h	;number of byte highbyte
temp0		equ	1015h	;used by various functions, holds number of 
				;unsuccessful block transfers/block during download
			;1016h	;highbyte of temp0
CMD_LEN 	equ	101Ch	;holds actual length of cmd in cmd buffer (lowbyte)
			;101Dh	;holds actual length of cmd in cmd buffer (highbyte)
IN_LEN		equ	101Eh	;holds length of of last cmd in input buffer (lowbyte)
			;101F	;holds length of of last cmd in input buffer (highbyte)
			
CMD_PTR		equ	01020h	;start pos where cmd buffer begins, RX char become appended
				;req_number converts cmd buffer to integer NUMBER (see below)
				;max 32d characters allowed
				;so value in NUMBER may be as large as 16x8bit=128bit
STD_OUT		equ	01040h	;start pos where TX chars are stored and appended, max 64d char 
				;allowed
NUMBER		equ	01080h	;start pos of long number storage
				;no protection agains stack corruption !
				;stack defaults to 1800h upon system start

;fuer zwischenspeicherung in funktion register dump:	;v93
bak_af		equ	01100h
bak_bc		equ	01102h
bak_de		equ	01104h
bak_hl		equ	01106h
bak_ix		equ	01108h
bak_iy		equ	0110Ah
bak_pc		equ	0110Ch
bak_sp		equ	0110Eh
;-------------------------------------------------------------------------------








;-------PROG START UPON SYSTEM RESET BEGIN: ------------------------------------
	org	0+OFFSET
WARM_START:
	jp	INI_PIO
	
	;int vectors for cmd line mode
	org	0Ch+OFFSET
	DEFW	RX_CHA_AVAILABLE
	org	0Eh+OFFSET
	DEFW	SPEC_RX_CONDITON

	;int vectors for CTC
	org	16h+OFFSET
	DEFW	CT3_ZERO

	;int vectors for download mode:
	org	1Ch+OFFSET
	DEFW	BYTE_AVAILABLE
	org	1Eh+OFFSET
	DEFW	SPEC_BYTE_COND

	org	66h+OFFSET
;	DEFW	NMI
NMI:	jp	WARM_START	;handle NMI as Master Reset



;-------PIO INIT begin-----------------------------
	org	0100h+OFFSET	
	
INI_PIO:
	;init PIO A
	ld	a,04Fh		; set PIO A input mode
	out	(PIO_A_C),A
	ld	a,0FFh		; set D7..0 of output register H
	out	(PIO_A_D),A	; 

	;init PIO B
	ld	A,0CFh		; set PIO B to bit mode
	ld	(PIO_B_MODE),A	; update global PIO B mode status variable
	out	(PIO_B_C),A

	ld	a,0FFh		; set D7..0 to input mode
	ld	(PIO_B_IO_CONF),A	;update global PIO B IO status variable
	out	(PIO_B_C),A	; write IO configuration into PIO B
	
	ld	A,0F0h		; SDA0, SCL0, SDA1, SCL1 = L
				; if direction of SDA or SCL changes to output
				; the pin will drive L
	out	(PIO_B_D),A	;loading PIO B output register
	
	in	A,(PIO_B_D)	;check status of PIO B D7
	bit	7,A		;when H proceed at INI_PIO_DONE
;	jp	nz,INI_PIO_DONE	;when L
	jp	INI_PIO_DONE	;bsc_v5-1-0
	;re-init PIO B
	ld	a,04Fh		; set PIO B input mode
	out	(PIO_B_C),A
	ld	a,0FFh		; set D7..0 of output register H
	out	(PIO_B_D),A	; 
	jp	8000h		; jump to user prom bottom address
INI_PIO_DONE:


;ROM_TEST:
;	ld	E,06Fh	;load E with expected rom check sum
;	ld	HL,0h
;	ld	B,0h
;	sub	A	;A,B,HL cleared
;l_RT:	ld	A,B	;restore A from B
;	add	A,(HL)	;add A and data where HL points to
;	inc	HL	;advance HL
;	ld	B,A	;backup A in B
;	ld	A,H	;look if
;	cp	10h	;H has reached last ROM address +1 
;	jp	nz,l_RT	;loop until H has reached last ROM address +1
;	ld	A,B	;restore A from B
;	cp	E	;compare A with expected rom check sum
;	jp	z,RT_END;if match proceed at RT_END
	
	;init PIO A
;	ld	a,0CFh		; set PIO A to bit mode
;	out	(PIO_A_C),A
;	ld	a,0FEh		; set D0 to output mode
;	out	(PIO_A_C),A	;
;	ld	a,0h		; set D0 L
;	out	(PIO_A_D),A
;	ld	B,0
;l_RT0:	djnz	l_RT0
;	jp	WARM_START
;RT_END:

;-------------------------------------------------------------
INI_SYS_VAR:
	ld	HL,1800h	; init stack pointer
	ld	SP,HL
	sub	A
;	ld	(BLK_ERR),A
	ld	(CMD_LEN),A	; reset CMD length counter
	ld	(CMD_LEN+1),A
	ld	(CMD_STS),A	; clear CMD status variable
	ld	(RAM_DATA_STS),A ; clear RAM DATA STS
	ld	(OUT_LEN),A	; clear STD_OUT length counter	
	ld	(OUT_LEN+1),A
	dec	A
	ld	(ECHO_STS),A	; set ECHO ON

;----------------------------------------------------------------------


	;RESET all I2C-Busses
	call	RST_I2C0
	call	RST_I2C1
	

;-------CTC INIT begin----------------------------------------------------------------------
INI_CTC:
	;init CH 1
	ld 	A,00000011b	; int off, timer on, prescaler=16, don't care ext. TRG edge,
				; start timer on loading constant, no time constant follows
				; sw-rst active, this is a ctrl cmd
	out 	(CH1),A		; CH1 is on hold now



	;init CH2
	;CH2 divides CPU CLK by (256*256) providing clock signal at TO2 at JP3:#11 
	ld 	A,00100111b	; int off, timer on, prescaler=256, no ext. start,
				; start upon loading time constant, time constant follows
				; sw reset, this is a ctrl cmd
	out 	(CH2),A
;	ld	A,0FFh		; time constant defined
	ld	A,060h		; time constant defined	;v93
	out 	(CH2),A		; and loaded into channel 2
				; T02 outputs 77Hz (at 5Mhz CPU CLK)


	;init CH3
	;CH3 is supplied by clock signal from TO2 via jumper at JP3:#11/13
	;CH3 divides TO2 clock by AFh
	;CH3 interupts CPU appr. every 2sec to service int routine CT3_ZERO (flashed LED D0/1)
	ld 	A,11000111b	; int on, counter on, prescaler don't care, edge don't care,
				; time trigger don't care, time constant follows
				; sw reset, this is a ctrl cmd
	out 	(CH3),A
	ld	A,0AFh		; time constant defined
	out 	(CH3),A		; and loaded into channel 3
	
	ld	A,10h		; it vector defined in bit 7-3,bit 2-1 don't care, bit 0 = 0
	out 	(CH0),A		; and loaded into channel 0



	;init CH0
	;CH0 provides SIO A RX/TX clock
	ld 	A,00000111b	; int off, timer on, prescaler=16, don't care ext. TRG edge,
				; start timer on loading constant, time constant follows
				; sw-rst active, this is a ctrl cmd
	out 	(CH0),A
	ld	A,1h		; time constant defined
	out 	(CH0),A		; and loaded into channel 0

				; TO0 outputs app. 10Mhz/2/16/(time constant)/16
				; which results in 19200 bits per sec
;-------CTC INIT done-----------------------------------------------------------------------











;-------SIO INIT begin----------------------------------------------------------------------
INI_SIO:
	call	SIO_A_RESET	;cares for WR4,5,1 settings

;-------SIO INIT done-----------------------------------------------------------------------












;-------CPU Interrupt setup begin----------------------------------------------------------
INT_INI:
	ld	BC,OFFSET
	ld	A,B
	ld	I,A	;load I reg with highbyte of OFFSET
	im	2	;enable int mode 2
	;di		;no int allowed yet, will be enabled later
	ei		;V841
;-------CPU Interrupt setup end------------------------------------------------------------	
	








	call	bsc_init





;-------MENUE begin------------------------------------------------------------------------
menu:
	ld	HL,Welcome	;TX welcome note
	call	TX_STR
	;call	TX_STR_TERM

	ld	HL,prompt	;TX prompt
	call	TX_STR
;	call	TX_STR_TERM





;-------CMD pre processor begin-------------------------------------------
CMD_pre_proc:
;	call	SIO_A_EI	;enable SIO_A interrupts
	call	poll_CMD_cpl	;loop here until CMD_STS=complete
	
;-------CMD pre processor end----------------------------------------------





;-------CMD post processor begin-------------------------------------------
CMD_post_proc:
	;verify cmd in cmd buffer against list of available cmds:
	


	ld	HL,fill
	call	PAR_CMD
	jp	nc,l_10a

		call	fill_mem
		jp	EO_post_proc


l_10a:
	ld	HL,clrram
	call	PAR_CMD
	jp	nc,l_16a

		ld	A,0FFh		;reset cmd cannel -> stops executor
		out	(cmd),A

		ld	A,00001010b	;direct adr and data from init to ram
		out	(path),A

		ld	A,020h
		out	(cmd),A		;start RAM init
		ld	A,0FFh
		out	(cmd),A		;reset cmd channel 
	
l_clr: 		in	A,(mach_sts)	;read machine status register
		bit	0,A		;test if bit 0 cleared
		jr	nz,l_clr	;RAM init done if bit 0 cleared
		jp	EO_post_proc




l_16a:
	ld	HL,firmware
	call	PAR_CMD
	jp	nc,l_16b

		ld	HL,sys_fw
		call	TX_STR
		in	A,(fw_ex1)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(fw_ex0)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		jp	EO_post_proc



l_16b:
	ld	HL,copy	
	call	PAR_CMD
	jp	nc,l_15

		call	req_snd		;request source, number, destination address
		ldir
		jp	EO_post_proc



l_15:
	ld	HL,cmp	
	call	PAR_CMD
	jp	nc,l_13

		call	req_snd		;request source, number, destination address
		call	cmp_mem		;compare mem blocks
		jp	EO_post_proc


l_13:
	ld	HL,erf	
	call	PAR_CMD
	jp	nc,l_14

		call	id_check	;do id check of user flash prom
		;call	prot_off	;disable sw protection ;v94
		call	fl_erase	;erase flash	;v94
		;call	prot_on		;enable sw protection ;v94
		jp	EO_post_proc

	

l_14:	
	ld	HL,PRG_FL
	call	PAR_CMD
	jp	nc,l_102
	
		call	req_snd		;request source, number, destination address
		call	id_check	;do id check of user flash prom
		call	fl_erase	;erase flash
		call	fl_prog		;program flash
		jp	EO_post_proc


l_102:
	ld	HL,POUT
	call	PAR_CMD
	jp	nc,l_01

		ld	HL,io_adr
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get io address from host
		ld	C,A		;save io address in c
		push	BC
		ld	HL,io_dat
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get io data from host
		pop	BC		;restore io address in C
		out	(C),A		;output io data at io address
		jp	EO_post_proc


l_01:
	ld	HL,PIN
	call	PAR_CMD
	jp	nc,l_02A

		ld	HL,io_adr
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get io address from host
		ld	C,A		;save io address in c
		in	A,(C)
		push	AF		;backup value input from port on stack
		ld	HL,io_dat	;announce transmission of input value
		call	TX_STR
		pop	AF		;restore value input from port from stack
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		jp	EO_post_proc

		
l_02A:		
	ld	HL,pio_test
	call	PAR_CMD
	jp	nc,l_02

		call	p_test
		jp	EO_post_proc


l_02:
	ld	HL,RAM_S		;see comments at label l_0 and following
	call	PAR_CMD
	jp	nc,l_4p

		call	RAM_SIZE_CHK
;		call	TX_STR_TERM
		jp	EO_post_proc


l_4p:
	ld	HL,runtest
	call	PAR_CMD
	jp	nc,l_4q

		call	req_d	;ask host for bits [23:8] of destination address

		;load vector output ram address
		sub	A
		out	(st_adr0),A ; bits [7:0] always fixed to 00h
		ld	HL,(DEST_ADR)
		ld 	A,L
		out	(st_adr1),A
		ld	A,H
		out	(st_adr2),A

		;ld	A,00000001b	;direct adr from ram to rf , release d_ram : RAM debug mode
		ld	A,00000101b	;direct adr from ex to ram , ram drives data : EX mode
		out	(path),A

		;ld	A,010h		;set  executor step mode: production 
		;out	(cmd),A

		ld	A,055h
		out	(strt_stop),A		;55h in strt_stop starts test
		nop
		nop
		ld	A,0FFh
		out	(strt_stop),A
		jp	EO_post_proc


l_4q:
	ld	HL,stoptest
	call	PAR_CMD
	jp	nc,l_4r

		ld	A,0AAh
		out	(strt_stop),A		;AAh in strt_stop stops test
		nop
		nop
		ld	A,0FFh
		out	(strt_stop),A
		jp	EO_post_proc


l_4r:
	ld	HL,stwidth
	call	PAR_CMD
	jp	nc,l_4

		ld	HL,st_width
		call	TX_STR
		call	req_number	;get step width from host
		out	(cmd),A		;load step width in executor cmd register
		jp	EO_post_proc



l_4:	ld	HL,DLD		;see comments at label l_0 and following
	call	PAR_CMD
	jp	nc,l_4a

		ld	A,0FFh		;stop executor
		out	(cmd),A

		call	req_d	;ask host for bits [23:8] of destination address

		;load vector output ram address (-1)
		sub	A
		dec 	A
		out	(st_adr0),A ; bits [7:0] always fixed to FFh
		ld	HL,(DEST_ADR)
		dec HL
		ld 	A,L
		out	(st_adr1),A
		ld	A,H
		out	(st_adr2),A

		ld	A,00000000b	;direct adr and data from rf to ram
		out	(path),A

		ld	HL,AWT_TRM
		call	TX_STR	;request user to transmit file per xmodem
;		call	TX_STR_TERM
		call	DWNLD	;download file
;		call	TX_STR_TERM

		;clear vector output ram address (default start address)
		sub	A
		out	(st_adr0),A
		out	(st_adr1),A
		out	(st_adr2),A

		;ld	A,00000001b	;direct adr from ram to rf , release d_ram : RAM debug mode
		ld	A,00000101b	;direct adr from ex to ram , ram drives data : EX mode
		out	(path),A

		ld	A,010h		;set executor step width: production
		out	(cmd),A

		jp	EO_post_proc


l_4a:	ld	HL,dbg			;see comments at label l_0 and following
	call	PAR_CMD
	jp	nc,l_41

		ld	HL,exe_state
		call	TX_STR
		in	A,(ex_state)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		ld	HL,tap_state
		call	TX_STR
		in	A,(t_state12)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		ld	HL,tap_in
		call	TX_STR
		in	A,(tap_in12)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		ld	HL,step_id
		call	TX_STR
		in	A,(step_idb)
		call	APP_ACCU
		in	A,(step_ida)
		call	APP_ACCU
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		;tx total bit count chain 1
		ld	HL,bits_to1
		call	TX_STR
		in	A,(sxr_ln1d)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(sxr_ln1c)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(sxr_ln1b)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(sxr_ln1a)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

                ;tx bit position chain 1
		ld	HL,bits_pr1
		call	TX_STR
		in	A,(b_prc_1d)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(b_prc_1c)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(b_prc_1b)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(b_prc_1a)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		;tx vector state 1
		ld	HL,vst1
		call	TX_STR
		in	A,(vec_st1)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		;tx total bit count chain 2
		ld	HL,bits_to2
		call	TX_STR
		in	A,(sxr_ln2d)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(sxr_ln2c)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(sxr_ln2b)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(sxr_ln2a)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

                ;tx bit position chain 2
		ld	HL,bits_pr2
		call	TX_STR
		in	A,(b_prc_2d)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(b_prc_2c)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(b_prc_2b)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(b_prc_2a)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		;tx vector state 2
		ld	HL,vst2
		call	TX_STR
		in	A,(vec_st2)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

                ;tx current RAM address
		ld	HL,ram_adr
		call	TX_STR
		in	A,(ram_adr2)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(ram_adr1)
		call	APP_ACCU	;append value to STD_OUT
		in	A,(ram_adr0)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		;tx current RAM data
		ld	HL,rm_data
		call	TX_STR
		in	A,(ram_out2)	;chgd from ram_out to ram_out2 in V6.0
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		jp	EO_post_proc



l_41:	ld	HL,HELP		;see comments at label l_0 and following
	call	PAR_CMD
	jp	nc,l_42

		ld	HL,CMD_SET
		call	TX_STR
;		call	TX_STR_TERM
		jp	EO_post_proc




l_42:	ld	HL,EO
	call	PAR_CMD
	jp	nc,l_5
	
		sub	A
		ld	(ECHO_STS),A
		jp	EO_post_proc
	


	

l_5:	ld	HL,VIEW_MEM	;see comments at label l_0 and following
	call	PAR_CMD
	jp	nc,l_5b

		ld	HL,mem_adr16
    		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;ask host for 16 bit number
		call	READ_MEM
		jp	EO_post_proc



l_5b:	ld	HL,vw_out_ram		;see comments at label l_0 and following
	call	PAR_CMD
	jp	nc,l_8

		ld	HL,mem_adr16
    		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;ask host for 16 bit number
		call	rd_out_ram
		jp	EO_post_proc




l_8:	ld	HL,ca_usr_prg		;see comments at label l_0 and following

	call	PAR_CMD
	jp	nc,l_9

		ld	HL,mem_adr16
    		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;ask host for user program start address
		ld	(temp0),HL	;backup start address in temp0
		ld	HL,l_ret	;load user program return 
		push	HL		;address on stack
		ld	HL,(temp0)	;restore user program start address in HL
		jp	(HL)		;jump to user program
l_ret:		jp	EO_post_proc





		
l_9:	ld	HL,RSTI2C0
	call	PAR_CMD
	jp	nc,l_91

		;resetting i2c0 bus:
		call	RST_I2C0	;do 10 x LHL on SCL0 while SDA0 = H
		call	SCL0_IN		;SCL0 = H
		jp	EO_post_proc
	



	

l_91:	ld	HL,RSTI2C1
	call	PAR_CMD
	jp	nc,l_921

		;resetting i2c1 bus:
		call	RST_I2C1	;do 10 x LHL on SCL1 while SDA1 = H
		call	SCL1_IN		;SCL1 = H
		jp	EO_post_proc



l_921:	ld	HL,i2c1_test
	call	PAR_CMD
	jp	nc,l_10

		call	i1test

		jp	EO_post_proc





l_10:	ld	HL,I2C0P		;access to i2c pio devices
	call	PAR_CMD
	jp	nc,l_112

		call	I2C0_START

		ld 	HL,p0_sel	;request select code from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get select code from host
		push	AF

		;send 8bit device address to slave:
		call	I2C0_tx
		jp	nc,EO_post_proc

		pop	AF	; check for write or read access requested by host
		bit	0,A			
		jp	z,l_651

		ld 	HL,p0_in	;anounce transmission of read value to host
		call	TX_STR
		call	I2C0_RX		; returns with slave data byte in C
			
		;transmit data byte to host
		;ld	A,C
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host

		call	I2C0_STOP
		jp	EO_post_proc

	
		;write access follows:
				
l_651:		;write byte into slave
		ld 	HL,p0_out	;request output value from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get output value from host
		call	I2C0_tx
		jp	nc,EO_post_proc

		call	I2C0_STOP
		jp	EO_post_proc
		



l_112:
	ld	HL,I2C1P		;access to i2c pio devices
	call	PAR_CMD
	jp	nc,l_11

		call	I2C1_START

		ld 	HL,p1_sel	;request select code from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get select code from host
		push	AF

		;send 8bit device address to slave:
		call	I2C1_tx
		jp	nc,EO_post_proc

		pop	AF
		bit	0,A	; check for write or read access requested by host
		jp	z,l_652

		ld	HL,p1_in	;anounce transmission of read value to host
		call	TX_STR
		call	I2C1_RX	; returns with slave data byte in C
		
		;transmit data byte to host
		;ld	A,C
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		
		call	I2C1_STOP
		jp	EO_post_proc

	
		;write access follows:
				
l_652:		;write byte into slave
		ld 	HL,p1_out	;request output value from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get output value from host
		call	I2C1_tx
		jp	nc,EO_post_proc

		call	I2C1_STOP
		jp	EO_post_proc




	
	
l_11:	ld	HL,I2C0F		;access to i2c flash devices
	call	PAR_CMD
	jp	nc,l_110

		call	I2C0_START

		ld	HL,f0_sel	;request device select code from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get device select code from host
		push	AF

		res	0,A		; clear LSB to indicate write access to slave
		call	I2C0_tx
		jp	nc,EO_post_proc

		ld	HL,f0_adr	;request memory address from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get memory address from host
		call	I2C0_tx
		jp	nc,EO_post_proc
	
		pop	AF		; check for write or read access requested by host
		push	AF
		bit	0,A			
		jp	z,l_65
				
		;read access follows:

		;restart I2C bus 0
		call	SCL0_IN		;SCL0 = H
		call	I2C0_START

		;resend 8bit device select code
		pop	AF		
		call	I2C0_tx
		jp	nc,EO_post_proc

		ld	HL,f0_dar	; anounce transmission of read byte to host
		call	TX_STR	
		call	I2C0_RX	; returns with slave data byte in C

		;forward data byte to host
		;ld	A,C
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		call	I2C0_STOP
		jp	EO_post_proc
				
l_65:		;write byte into slave
		ld	HL,f0_daw	;request byte to be written from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get byte to be written from host
		
		call	I2C0_tx
		jp	nc,EO_post_proc

		call	I2C0_STOP
		jp	EO_post_proc




l_110:	ld	HL,I2C1F		;access to i2c flash devices
	call	PAR_CMD
	jp	nc,l_100

		call	I2C1_START

		ld	HL,f1_sel	;request device select code from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get device select code from host
		push	AF

		;send 8bit device select code to slave:
		res	0,A		; clear LSB to indicate write access to slave
		call	I2C1_tx
		jp	nc,EO_post_proc

		ld	HL,f1_adr	;request memory address from host
		call	TX_STR
;		call	TX_STR_TERM
		call 	req_number	;get memory address from host
		call	I2C1_tx
		jp	nc,EO_post_proc

		pop	AF		; check for write or read access requested by host
		push	AF
		bit	0,A			
		jp	z,l_653
				
		;read access follows:

		;restart I2C bus 1
		call	SCL1_IN		;SCL1 = H
		call	I2C1_START

		;resend 8bit device select code
		pop	AF
		call	I2C1_tx
		jp	nc,EO_post_proc

		ld	HL,f1_dar	;anounce transmission of data read to host
		call	TX_STR
		call	I2C1_RX	; returns with slave data byte in C

		;forward data byte to host
		;ld	A,C
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
		call	I2C1_STOP
		jp	EO_post_proc

				
l_653:		;write byte into slave
		ld	HL,f1_daw	;request byte to be written from host
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get byte to be written from host
		
		call	I2C1_tx
		jp	nc,EO_post_proc

		call	I2C1_STOP
		jp	EO_post_proc





	;--------------------------------------------------------------
l_100:	;process any other command this way:
;	call	wait_2
	ld	HL,error	;TX "unkown cmd" 
	call	TX_STR
;	call	TX_STR_TERM
	
EO_post_proc:
;	call	wait_2
	ld	HL,prompt		;TX "prompt"
	call	TX_STR
;	call	TX_STR_TERM
	jp	CMD_pre_proc	;go checking CMD_STS

	
	;-------CMD parsing begin--------------------------------------------------
	;requires HL pointing to CMD to be parsed
PAR_CMD:
	ld	DE,CMD_PTR
l_51:
	ld	A,(DE)
	CPI
	jp	nz,l_52 ;if mismatch of first char in cmd buffer, do next parsing
	inc	DE	;prepare next char in cmd buffer		
	cp	0Dh	;check for end of cmd (CR)	
	jp	nz,l_51		;if end of cmd reached
				;and start cmd execution:
				
				;sending of NEW_LINE here removed with V80
				
	scf		;if match return with carry set
	RET

l_52:	scf
	ccf		;if mismatch return with carry cleared
	RET
	;-------CMD parsing end--------------------------------------------------

;-------CMD post processor end-------------------------------------------------------------------------










;-------DOWNLOAD begin--------------------------------------------------------------------
DWNLD:	ld	C,01h		;defines timeout	

TICKER:	call   	WAIT_2
	dec	C
	ld	A,C
	cp	0
	jp	nz,TICKER

;-------------
	;set up TX and RX:
;	ld	a,00110000b	;write into WR0: error reset, select WR0
;	out	(SIO_A_C),A

	ld	a,018h		;write into WR0: channel reset
	out	(SIO_A_C),A

	ld	a,004h		;write into WR0: select WR4
	out	(SIO_A_C),A
	ld	a,44h		;44h write into WR4: clkx16,1 stop bit, no parity
	out	(SIO_A_C),A

	ld	a,005h		;write into WR0: select WR5
	out	(SIO_A_C),A
	ld	a,0E8h		;DTR active, TX 8bit, BREAK off, TX on, RTS inactive
	out	(SIO_A_C),A

	ld	a,01h		;write into WR0: select WR1
	out	(SIO_B_C),A
	ld	a,00000100b	;no interrupt in CH B, special RX condition affects vect	
	out	(SIO_B_C),A

	ld	a,02h		;write into WR0: select WR2
	out	(SIO_B_C),A
	ld	a,10h		;write into WR2: cmd line int vect (see int vec table)
	out	(SIO_B_C),A	;bits D3,D2,D1 are changed according to RX condition

	sub	A
	ld	(temp0),A	;reset bad blocks counter
	ld	(RAM_DATA_STS),A ;clear RAM DATA STS
	ld	C,1h		;C holds first block nr to expect
	ld	HL,(DEST_ADR)	;set lower destinatiion address of user program

	call	SIO_A_EI
	call	A_RTS_ON

	call	TX_NAK		;NAK indicates ready for transmission to host

;----------------------------
REC_BLOCK:
	;set block transfer mode
	ld	a,21h		;write into WR0 cmd4 and select WR1
	out	(SIO_A_C),A
	ld	a,10101000b	;wait active, interrupt on first RX character
	out	(SIO_A_C),A	;buffer overrun is a spec RX condition

	ei
	call	A_RTS_ON
	halt			;await first rx char
	call	A_RTS_OFF

	ld	a,01h		;write into WR0: select WR1
	out	(SIO_A_C),A
	ld	a,00101000b	;wait function inactive
	out	(SIO_A_C),A

	;check return code of block reception (e holds return code)
	ld	a,e		
	cp	0		;block finished, no error
	jp	z,l_210
	cp	2		;eot found
	jp	z,l_211
	cp	3		;chk sum error
	jp	z,l_613

;	call	TX_NAK		;other error ?
;	sub	a
	ld	a,10h
	ld	(RAM_DATA_STS),A; set RAM DATA STS to 10h
	jp	l_612

l_210:	call	TX_ACK		;when no error
	inc	c		;prepare next block to receive
	sub	A
	ld	(temp0),A	;clear bad block counter
	jp	REC_BLOCK	

l_211:	call	TX_ACK		;on eot
	ld	A,01h
	ld	(RAM_DATA_STS),A; set RAM DATA STS to 01h
	jp	l_612	

l_613:	call	TX_NAK		;on chk sum error
	scf
	ccf			;clear carry flag
	ld	DE,0080h	;subtract 80h
	sbc	HL,DE		;from HL, so HL is reset to block start address

	ld	A,(temp0)	;count bad blocks in temp0
	inc	A
	ld	(temp0),A	
	cp	09h
	jp	z,l_612		;abort download after 9 attempts to transfer a block
	jp	REC_BLOCK	;repeat block reception

l_612:
DLD_END:
	call	SIO_A_RESET
	ret

	

;-------Int routine upon byte available begin---------------------

BYTE_AVAILABLE:

EXP_SOH_EOT:
	in	A,(SIO_A_D)	;read RX byte into A
l_205:	cp	01h		;check for SOH
	jp	z,EXP_BLK_NR
	cp	04h		;check for EOT
	jp	nz,l_2020
	ld	e,2h
	reti

	;await block number
EXP_BLK_NR:
	in	A,(SIO_A_D)	;read RX byte into A
	cp	C		;check for match of block nr
	jp	nz,l_2020

	;await complement of block number
	ld	A,C		;copy block nr to expect into A
	CPL			;and cpl A
	ld	E,A		;E holds cpl of block nr to expect
EXP_CPL_BLK_NR:
	in	A,(SIO_A_D)	;read RX byte into A
	cp	E		;check for cpl of block nr
	jp	nz,l_2020

	;await data block
	ld	D,0h		;start value of checksum
	ld	B,80h		;defines block size 128byte		
EXP_DATA:
	in	A,(SIO_A_D)	;read RX byte into A
;----------------------------	
;	ld	(HL),A		;bsc_v5-1-0
	call	sorter		;write into BSC vector RAM ;bsc_v5-1-0
;----------------------------
;	ld	(HL),A		;bsc_v5-1-0
	add	A,D		;update
	ld	D,A		;checksum in D
	inc	HL		;dest address +1
	djnz	EXP_DATA	;loop until block finished
		    
EXP_CHK_SUM:
	in	A,(SIO_A_D)	;read RX byte into A
;	ld	a,045h		;for debug only
	cp	D		;check for checksum match
	jp	z,l_2021
	ld	e,3h
	reti

l_2020:	ld	E,1h
	RETI
l_2021:	ld	E,0h
	RETI		;return when block received completely


;---------------------------
TX_NAK:	
	ld	a,15h	;send NAK 15h to host
	out	(SIO_A_D),A
	call	TX_EMP
	RET

TX_ACK:
	ld	a,6h	;send AK to host
	out	(SIO_A_D),A
	call	TX_EMP
	RET



;-------Int routine upon RX overflow begin---------------------
SPEC_BYTE_COND:			;in case of RX overflow
	ld	HL,DLD_END
	push	HL
	reti


;-------DOWNLOAD end----------------------------------------------------------








;-------I2C SUBROUTINES BEGIN---------------------------------------------
;transmits byte to I2C device on bus 0
;returns with carry cleared if ackn bit not found
;modifies A,B,C,D,HL
I2C0_tx:	call	send0_byte
		bit	1,D		; test D register for acknowledge bit
		scf
		ret	z		;return if akn bit = L with carry set
		;when ACK error on bus - transmit error message to host and stop bus
		call	TX_error
		call	I2C0_STOP
		scf
		ccf
		ret			;return if akn bit = H with carry cleared

I2C1_tx:	call	send1_byte
		bit	3,D		; test D register for acknowledge bit
		scf
		ret	z		;return if akn bit = L with carry set
		;when ACK error on bus - transmit error message to host and stop bus
		call	TX_error
		call	I2C1_STOP
		scf
		ccf
		ret			;return if akn bit = H with carry cleared


	
RST_I2C0:	;modifies A, B, D
		;SDA0 must be H for proper reset
		;leaves SDA0 = H and SCL0 = H
		ld	B,0Ah	    ; do 10 SCL0 cycles while SDA0 is H
l_77:		call	SCL0_CYCLE
		djnz	l_77
		call	SCL0_IN
		ret

RST_I2C1:	;modifies A, B, D
		;SDA1 must be H for proper reset
		;leaves SDA1 = H and SCL1 = H
		ld	B,0Ah	    ; do 10 SCL1 cycles while SDA0 is H
l_771:		call	SCL1_CYCLE
		djnz	l_771
		call	SCL1_IN
		ret

SCL0_CYCLE:	;modifies A
		;returns D wherin bit 1 represents status of SDA0 while
		;SCL0 was H
		;leaves SCL0 = L
		call	SCL0_OUT
		call	SCL0_IN
		
		;look for ackn bit
		in	A,(PIO_B_D)
		ld	D,A
		call	SCL0_OUT
		ret

SCL1_CYCLE:	;modifies A
		;returns D wherin bit 3 represents status of SDA1 while
		;SCL1 was H
		;leaves SCL1 = L
		call	SCL1_OUT
		call	SCL1_IN
		
		;look for ackn bit
		in	A,(PIO_B_D)
		ld	D,A
		call	SCL1_OUT
		ret

SDA0_IN:	;modifies A	    
		;reload PIO B mode
		ld	A,(PIO_B_MODE)
		out	(PIO_B_C),A
		;change direction of SDA0 to input
		ld	A,(PIO_B_IO_CONF)
		set	1,A
		out	(PIO_B_C),A
		ld	(PIO_B_IO_CONF),A
		ret

SDA1_IN:	;modifies A	    
		;reload PIO B mode
		ld	A,(PIO_B_MODE)
		out	(PIO_B_C),A
		;change direction of SDA1 to input
		ld	A,(PIO_B_IO_CONF)
		set	3,A
		out	(PIO_B_C),A
		ld	(PIO_B_IO_CONF),A
		ret
	
SDA0_OUT:	;modifies A
		;reload PIO B mode
		ld	A,(PIO_B_MODE)
		out	(PIO_B_C),A
		;change direction of SDA0 to output
		ld	A,(PIO_B_IO_CONF)
		res	1,A
		out	(PIO_B_C),A
		ld	(PIO_B_IO_CONF),A
		ret

SDA1_OUT:	;modifies A
		;reload PIO B mode
		ld	A,(PIO_B_MODE)
		out	(PIO_B_C),A
		;change direction of SDA1 to output
		ld	A,(PIO_B_IO_CONF)
		res	3,A
		out	(PIO_B_C),A
		ld	(PIO_B_IO_CONF),A
		ret

SCL0_IN:	;modifies A
		;reload PIO B mode
		ld	A,(PIO_B_MODE)
		out	(PIO_B_C),A
		;change direction of SCL0 to input
		ld	A,(PIO_B_IO_CONF)
		set	0,A
		out	(PIO_B_C),A
		ld	(PIO_B_IO_CONF),A
		ret

SCL1_IN:	;modifies A
		;reload PIO B mode
		ld	A,(PIO_B_MODE)
		out	(PIO_B_C),A
		;change direction of SCL1 to input
		ld	A,(PIO_B_IO_CONF)
		set	2,A
		out	(PIO_B_C),A
		ld	(PIO_B_IO_CONF),A
		ret

SCL0_OUT:	;modifies A
		;reload PIO B mode
		ld	A,(PIO_B_MODE)
		out	(PIO_B_C),A
		;change direction of SCL0 to output
		ld	A,(PIO_B_IO_CONF)
		res	0,A
		out	(PIO_B_C),A
		ld	(PIO_B_IO_CONF),A
		ret

SCL1_OUT:	;modifies A
		;reload PIO B mode
		ld	A,(PIO_B_MODE)
		out	(PIO_B_C),A
		;change direction of SCL1 to output
		ld	A,(PIO_B_IO_CONF)
		res	2,A
		out	(PIO_B_C),A
		ld	(PIO_B_IO_CONF),A
		ret

send0_byte:	;requires value to be sent in A
		;returns with bit 1 of D holding status of ACKN bit
		;and SCL0 = L and SDA0 = H
		;modifies A, B, C, D
		ld	B,8h		; 8 bits are to be clocked out
		ld	C,A		; copy to C reg
l_74:		sla	C		; shift MSB of C into carry
		jp	c,SDA0_H	; when L
SDA0_L:		call	SDA0_OUT	; pull SDA0 low
		jp	l_75
SDA0_H:		call	SDA0_IN		; release SDA0 to let it go high
l_75:		call	SCL0_CYCLE	; do SCL0 cycle (LHL)
		djnz	l_74		; process next bit of C reg
		call	SDA0_IN		; release SDA0 to let it go high
		call	SCL0_CYCLE	; do SCL0 cycle (LHL), bit 1 of D holds ackn bit
		ret

send1_byte:	;requires value to be sent in A
		;returns with bit 3 of D holding status of ACKN bit
		;and SCL1 = L and SDA1 = H
		;modifies A, B, C, D
		ld	B,8h		; 8 bits are to be clocked out
		ld	C,A		; copy to C reg
l_741:		sla	C		; shift MSB of C into carry
		jp	c,SDA1_H	; when L
SDA1_L:		call	SDA1_OUT	; pull SDA1 low
		jp	l_751
SDA1_H:		call	SDA1_IN		; release SDA1 to let it go high
l_751:		call	SCL1_CYCLE	; do SCL1 cycle (LHL)
		djnz	l_741		; process next bit of C reg
		call	SDA1_IN		; release SDA1 to let it go high
		call	SCL1_CYCLE	; do SCL1 cycle (LHL), bit 3 of D holds ackn bit
		ret

I2C0_RX:	;modifies A, B, D
		;returns with slave data byte in C
		;leaves SCL0 = L and SDA0 = H
		ld	B,8h
l_66:		in	A,(PIO_B_D)
		scf
		bit	1,A
		jp	nz,H0_found	
L0_found:	ccf
H0_found:	rl	C
		call	SCL0_CYCLE
		djnz	l_66
		call	SCL0_CYCLE	;send NAK to slave
		;byte ready in C
		ld	A,C
		ret


I2C1_RX:	;modifies A, B, D
		;returns with slave data byte in C
		;leaves SCL1 = L and SDA1 = H
		ld	B,8h
l_661:		in	A,(PIO_B_D)
		scf
		bit	3,A
		jp	nz,H1_found	
L1_found:	ccf
H1_found:	rl	C
		call	SCL1_CYCLE
		djnz	l_661
		call	SCL1_CYCLE	;send NAK to slave
		;byte ready in C
		ld	A,C
		ret


I2C0_START:	;start I2C bus 0
		call	SDA0_OUT	;SDA = L
		call	SCL0_OUT	;SCL = L
		ret

I2C1_START:	;start I2C bus 1
		call	SDA1_OUT	;SDA = L
		call	SCL1_OUT	;SCL = L
		ret


I2C0_STOP:	;stop I2C bus 0
		call	SDA0_OUT
		call	SCL0_IN
		call	SDA0_IN	
		;jp	EO_post_proc
		ret

I2C1_STOP:	;stop I2C bus 1
		call	SDA1_OUT
		call	SCL1_IN
		call	SDA1_IN	
		;jp	EO_post_proc
		ret


;-------I2C SUBROUTINES END------------------------------------------





TX_error:
		ld	HL,error	; TX error message to host
		call	TX_STR
;		call	TX_STR_TERM
		ret




;-------Int. Routine for CT3 zero count begin------------------------------
CT3_ZERO:
	;flashes D0 and D1 as 2 bit binary counter
	push	AF

	ld	A,0CFh
	out	(PIO_A_C),A	;set PIO A to bit mode
	ld	A,0FCh
	out	(PIO_A_C),A	;set io configuration: A0 and A1 are outputs
	ld	A,(TEMP3)
	inc	A		;inc temp3 content
	out	(PIO_A_D),A	;load temp3 onto pio port A
	ld	(TEMP3),A	;save temp3

	pop	AF
	EI		;came with V784
	reti
;-------Int. Routine for CT3 zero count begin------------------------------








;-------SIO INTERRUPT ROUTINES for cmd line mode BEGIN-----------------------------------------


;-------Int Routine upon RX charcter begin-------------------------------------------------
RX_CHA_AVAILABLE:
;	ei			;in V841
	push	AF		;backup AF
	call	A_RTS_OFF
;	ld	a,005h		;write into WR0: select WR5
;	out	(SIO_A_C),A
;	ld	a,0E8h		;DTR active, TX 8bit, BREAK off, TX on, RTS inactive
;	out	(SIO_A_C),A


	in	A,(SIO_A_D)	;read RX character into A
	;push	AF		;backup RX character
	; A holds received character

	;add RX character to string in cmd buffer:
	ld	BC,(CMD_LEN)	;BC holds current length of command
	ld	HL,CMD_PTR	;set HL at begin of cmd buffer
	add	HL,BC		;HL now holds pos to store RX char in
	;pop	AF		;restore RX char in A
	ld	(HL),A		;write RX char where HL points to

	ld	IY,ECHO_STS	; IY points to ECHO_STS

	;examine RX character:
	cp	0Dh		;was last RX char a CR ?
	jp	z,RX_CR
	cp	08h		;was last RX char a BS ?
	jp	z,RX_BSP
        cp	7Fh		;was last RX char a DEL ?
	jp	z,RX_BSP
	
	;for any other character:

	;if ECHO_STS=FFh TX received char back to host
;	ld	IY,ECHO_STS
	rrc	(IY+0)		;each rotating of FFh sets carry
	jp	nc,l_212	;if ECHO_STS<>FFh don't echo an proceed at l_212
				;echo character (HL still points at char received last)
	out	(SIO_A_D),A	;to host
	call	TX_EMP
	call	RX_EMP

l_212:
	inc	BC
	ld	(CMD_LEN),BC	;CMD_LEN holds current lenght of command
	;sub	A		;comm. in V841
	;ld	(CMD_STS),A	;comm. in V841 ;set or leave CMD status  "incomplete"
;	call	A_RTS_ON	;V877
	jp	eo_rx_cha_ava
;	pop	AF
;	reti



	;-------process cr character begin----------
RX_CR:
;	call	SIO_A_DI

	rrc	(IY+0)		;each rotating of FFh sets carry
	jp	nc,l_220	;if ECHO_STS<>FFh don't TX line feed an proceed at l_220
				;(ECHO is ON if ECHO_STS=FFh)

	ld	HL,NEW_LINE	;transmit new line
	call	TX_STR
	ld	BC,(CMD_LEN)	;TX_STR modifies BC, so restore BC from CMD_LEN

l_220:  ld	(IN_LEN),BC	;copy CMD_LEN into IN_LEN

	ld	A,1
	ld	(CMD_STS),A	;set CMD status to "complete"
;	call	SIO_A_DI	;disable SIO_A interrupts ;in V841

	sub	A
	ld	(CMD_LEN),A	;clear CMD_LEN
	ld	(CMD_LEN+1),A

;	call	A_RTS_OFF
	jp	eo_rx_cha_ava

;	pop	AF		;restore AF
;	reti			;leave procedure but do not enable interupts
	;-------process cr character end---------------



	;-------process backspace charcter begin-----------
RX_BSP:	ld	HL,0FFFFh
	add	HL,BC			;carry is set if CMD_LEN>0
	jp	nc,END_OF_RX_BSP	;do not BACKSPACE if CMD_LEN=0

	dec	BC		;if CMD_LEN>0 then CMD_LEN-1
	ld	(CMD_LEN),BC	;update CMD_LEN

	ld	HL,BS_SP_BS
	call	TX_STR
;	call	A_RTS_ON	;V877

END_OF_RX_BSP:
	;sub 	A		;comm. in V841
	;ld	(CMD_STS),A	;comm. in V841 ;set or leave CMD status  "incomplete"
;	pop	AF
;	reti
	;-------process backspace character end-----------	

eo_rx_cha_ava:
;	call	A_RTS_ON
	pop	AF
;	ei
	reti
	
;-------Int Routine upon RX charcter end---------------------------------------------------	



;-------poll CMD_STS loop------------------------------
	;waits until "cmd complete"
	;modifies all registers
poll_CMD_cpl:
;	call	SIO_A_RESET
	call	A_RTS_ON
l_690:
	ei
	call	A_RTS_ON	;V877
	halt
	ld	A,(CMD_STS)
	cp	1h		;poll for "cmd complete"
	jp	nz,l_690

;	di
	sub	A
	ld	(CMD_STS),A
;	call	A_RTS_OFF
;	call	SIO_A_DI
	RET






;-------Int routine upon special RX condition begin---------------------
SPEC_RX_CONDITON:
	jp	WARM_START
;-------Int Routine upon special RX condition end--------------------------





SIO_A_RESET:
	;set up TX and RX:
	ld	a,00110000b	;write into WR0: error reset, select WR0
	out	(SIO_A_C),A

	ld	a,018h		;write into WR0: channel reset
	out	(SIO_A_C),A

	ld	a,004h		;write into WR0: select WR4
	out	(SIO_A_C),A
	ld	a,44h		;44h write into WR4: clkx16,1 stop bit, no parity
	out	(SIO_A_C),A

	ld	a,005h		;write into WR0: select WR5
	out	(SIO_A_C),A
	ld	a,0E8h		;DTR active, TX 8bit, BREAK off, TX on, RTS inactive
	out	(SIO_A_C),A

	ld	a,01h		;write into WR0: select WR1
	out	(SIO_B_C),A
	ld	a,00000100b	;no interrupt in CH B, special RX condition affects vect	
	out	(SIO_B_C),A

	ld	a,02h		;write into WR0: select WR2
	out	(SIO_B_C),A
	ld	a,0h		;write into WR2: cmd line int vect (see int vec table)
				;bits D3,D2,D1 are changed according to RX condition
	out	(SIO_B_C),A

	ld	a,01h		;write into WR0: select WR1
	out	(SIO_A_C),A
	ld	a,00011000b	;interrupt on all RX characters, parity is not a spec RX condition
				;buffer overrun is a spec RX condition
	out	(SIO_A_C),A

SIO_A_EI:
	;enable SIO channel A RX
	ld	a,003h		;write into WR0: select WR3
	out	(SIO_A_C),A
;	ld	a,0C1h		;RX 8bit, auto enable off, RX on
	ld	a,0E1h		;RX 8bit, auto enable on, RX on	;v93
	out	(SIO_A_C),A	
	;Channel A RX active
	RET


SIO_A_DI:
	;disable SIO channel A RX
	ld	a,003h		;write into WR0: select WR3
	out	(SIO_A_C),A
;	ld	a,0C0h		;RX 8bit, auto enable off, RX off
	ld	a,0E0h		;RX 8bit, auto enable on, RX off	;v93
	out	(SIO_A_C),A	
	;Channel A RX inactive
	ret

A_RTS_OFF:
	ld	a,005h		;write into WR0: select WR5
	out	(SIO_A_C),A
	ld	a,0E8h		;DTR active, TX 8bit, BREAK off, TX on, RTS inactive
	out	(SIO_A_C),A
	ret
	
A_RTS_ON:
	ld	a,005h		;write into WR0: select WR5
	out	(SIO_A_C),A
	ld	a,0EAh		;DTR active, TX 8bit, BREAK off, TX on, RTS active
	out	(SIO_A_C),A
	ret



;-------SUBROUTINES BEGIN-------------------------------------------
;-asks host for a number
;-smallest unit is BYTE (so host must send at least 2 characters)
;-half bytes are not accepted (e.g. it is invalid if host sends "123")
;-in case of invalid input a return to EO_post_proc is performed (by manipulation of stack) !
;-does not check content of characters (e.g. result of sending "nice" is unknown)
;-the result of the last 2 characters in this number is returned in A
;-the result of the last 4 characters in this number is returned in HL, wherein H holds high
; byte and L holds low byte:
; (e.g. sending "123456" returns A holding 56h, and HL holding 3456h)
; all other characters get lost
;-modifies all registers except the background registers
;-loads every converted byte into long number storage (lowbyte at lowest address)

req_number:	;call 	set_CMD_incpl	;clear CMD status	;comm. V841
		;call	SIO_A_EI
		;ei			;comm. V841
		call	poll_CMD_cpl
		ld	A,(IN_LEN)	;get lowbyte of IN_LEN
		srl	A		;divide by 2 / A holds number of words in input buffer
		ld	B,A		;copy into B
		jp	nc,l_133	;if IN_LEN was odd	
		ld	HL,error	;TX ..?	
		call	TX_STR
		ld	HL,EO_post_proc	;replace return address on stack by address of EO_post_proc
		inc	SP		
		inc	SP
		push	HL		
		ret			;and return
		
l_133:		ld	DE,CMD_PTR
		ld	IX,NUMBER	;IX points to beginning of long number storage
l_132:		push	BC		;backup number of words on stack
		call	conv_RX_2ASC2BIN;convert word in input buffer to byte , DE points to word
					;A holds result
		ld	(IX+0),A	;load A into long number storage
		inc	IX		;advance pointer of long number storage by 1
		inc	DE		;advance DE by two
		inc	DE		;so that it point to next word in input buffer
		pop	BC		;restore number of words from stack
		bit	0,B		;check for last cycle: bit 0 of counter is set in last cycle
		jp	nz,l_135
		ld	H,A
l_135:		djnz	l_132		;loop to l_132 until all words are read from buffer
		ld	L,A
		ret			;return
				








;-----------------------------------------------------


;TX_STR_TERM:
	;modifies HL, A
;	ld	HL,STR_TERM
;	call	TX_STR
;	ret

	
TX_STD_OUT:
	ld	HL,STD_OUT
	call	TX_STR
;	call	TX_STR_TERM
	ret

TX_STR: ;TX string, HL points to first byte address
	;modifies A, HL , BC
TX_CHA:	ld	a,(HL)
	out	(SIO_A_D),A
	call	TX_EMP
;	call	host_rdy
	sub	a
	cpi		;look for string termination character 0h
	jp	nz,TX_CHA
	ld	(OUT_LEN),A	;set output string length lowbyte to 0
	ld	(OUT_LEN+1),A	;set output string length highbyte to 0
	ret


TX_EMP:	; check for TX buffer empty
	;modifies A
	sub	a		;clear a, write into WR0: select RR0
	inc	a		;select RR1
	out	(SIO_A_C),A
	in	A,(SIO_A_C)		;read RRx
	bit	0,A
	jp	z,TX_EMP
	ret
	
RX_EMP:	; check for RX buffer empty
	;modifies A
	sub	a		;clear a, write into WR0: select RR0
	out	(SIO_A_C),A
	in	A,(SIO_A_C)	;read RRx
	bit	0,A
	ret	z          	;if any rx char left in rx buffer
	in	A,(SIO_A_D)     ;read that char
	jp	RX_EMP


;v93
;host_rdy:
;	ld	a,10h		; write cmd 2 into WR0: select RR0
;	out	(SIO_A_C),A
;l_551:	in	A,(SIO_A_C)		;read RR0
;	bit	5,A	;when host ready bit 5 (CTS) is H
;	jp	z,l_551
;	ret
	
;---------------------------------------------------









;-------delay----------------

WAIT_2:	; delay
	push	AF
	push	BC
	push	DE
	ld	de,0500h
l_W20:	djnz	l_W20
	dec 	de
        ld     	a,d
        or     	a      ;update zero flag
	jp	nz,l_W20
	pop	DE
	pop	BC
	pop	AF
        ret










;-------convert 2 received ASCII char to byte begin-----------------------------
;	DE points to input in CMD_PTR and CMD_PTR+1
;	output in A
;	modifies A, B  
conv_RX_2ASC2BIN:
		;ld	DE,CMD_PTR	;read first char in cmd buffer
		push	DE		;came with V783
		ld	A,(DE)
		bit	6,A
		jp	z,hi_ni_09	;if bit 6 not set,it's below Ah
		add	A,9h
		jp	sh_4xl
hi_ni_09:	sub	30h		;convert to 4 bit number
sh_4xl:		sla	A
		sla	A
		sla	A
		sla	A
		ld	B,A		;B[7..4] hold high nibble 

		inc	DE		;read 2nd char in cmd buffer
		ld	A,(DE)
		bit	6,A
		jp	z,lo_ni_09	;if bit 6 not set,it's below Ah
		add	A,9h
		and	0Fh
		jp	EO_conv_RX_2ASC2BIN
lo_ni_09:	sub	30h		;convert to 4 bit number

EO_conv_RX_2ASC2BIN:
		or	B		;A holds result
		pop	DE		;came with V783
		RET
;-------convert 2 received ASCII char to byte end----------------------------





;-------convert byte to 2 ASCII char begin---------------------------
;	input value in A
;	output high nibble in D, low nibble in C
; modifies A,BC,D

conv_BYTE2ASC:
		ld	C,A		;backup given byte in C

proc_hi_ni:	;process high nibble
		and	0F0h		;clear low nibble
		srl	A		;move high nibble into low nibble
		srl	A
		srl	A
		srl	A

		ld	B,A		;backup A in B
		ld	A,9		
		sub	B
		jp	c,ni_AF		;nibble > 9 ?
		ld	A,B		;restore nibble
		add	A,30h		;add 30h to make ASCII char
		jp	hi_ni_rdy
ni_AF:		ld	A,B		;restore nibble
		add	A,37h		;add 40h-9h to make ASCII char
hi_ni_rdy:	ld	D,A		;high nibble ready in D


		;process low nibble
		ld	A,C		;restore given byte from C
		and	0Fh		;clear high nibble
		ld	B,A		;backup A in B
		ld	A,9		
		sub	B
		jp	c,ni_AF2	;nibble > 9 ?
		ld	A,B		;restore nibble
		add	A,30h		;add 30h to make ASCII char
		jp	lo_ni_rdy
ni_AF2:		ld	A,B		;restore nibble
		add	A,37h		;add 40h-9h to make ASCII char
lo_ni_rdy:	ld	C,A		;low nibble ready in C
					;high nibble ready in D
		RET		
;-------convert byte to 2 ASCII char end---------------------------











;-------RAM size check begin---------------------------------
RAM_SIZE_CHK:

	ld	HL,RAM_BOT	;get RAM bottom as start value
    	scf			;set carry flag
	ccf			;comlpement carry flag
l_ER0:	
	ld	B,1h		;walking one starts at LSB
WALK_1:	
	ld	A,B		;copy to A
	ld	(HL),A		;write shift value into RAM
	ld	A,(HL)		;read shift value back from RAM
	cp	B
	jp	nz,RAM_RANGE	;if mismatch, top of RAM+1 reached
	sla	B
	jp	nc,WALK_1

	sub	A		;clean up RAM location
	ld	(HL),A

	inc	HL		;inc RAM address
	jp	l_ER0
		
RAM_RANGE:
	dec	HL		;last checked address - 1
	ld	(RAM_TOP),HL
	ld	A,H
	call	APP_ACCU
	ld	HL,(RAM_TOP)
	ld	A,L
	call	APP_ACCU
	call	TX_STD_OUT
	ret	
;--------RAM size check end -----------------------------------------------







;--------------------------------------------------------------------------
APP_ACCU:
	;converts A content into 2 ASCII characters in C and D
	;C holds low nibble, D holds high nibble
	;appends characters in C and D to STD_OUT
	;appends 0h as string termination
	;increments OUT_LEN by two
	;modifies A,BC,DE,IX,IY

	call	conv_BYTE2ASC	;converts A to 2xASCII chars in D and C
	ld	B,C
	ld	C,D		;high nibble in C, low nibble in B
	scf			;set carry flag
APP_CHAR:
	;requires char to append in C
	;returns at label l_933 if carry not set
	push	AF		;backup carry status
	ld	IX,STD_OUT	;IX points to STD_OUT begin
	;ld	A,(OUT_LEN)	;get current output string length
	ld	DE,(OUT_LEN)	;get current output string length
	ld	IY,OUT_LEN	;IY points to OUT_LEN
	;ld	D,0h
	;ld	E,A
	add	IX,DE		;IX points to last pos in string

	ld	(IX+0),C	;append C to string
	inc	(IY+0)		;OUT_LEN+1
	ld	(IX+1),0h	;append termination string
	pop	AF		;restore carry status
l_933:	ret	nc		;return if carry not set

	ld	(IX+1),B	;else append B to string (overwrite former termination)
	inc	(IY+0)		;OUT_LEN+1
	ld	(IX+2),0h	;append termination to string
	RET

;---------------------------------------------------------------------



READ_MEM:	;reads memory content starting where HL points to
		;transmits row by row, so STD_OUT holds max.  52d characters
		;modifies all registers !
		ld	B,10h		;read 16 lines
RD_HL_ROW:	push	BC

		;load first address of first row in STD_OUT
		ld	A,H		;append high byte of mem address
		EXX			;backup HL in background register
		call	APP_ACCU
		EXX			;restore HL from background register
		ld	A,L		;append low byte of mem address
		EXX			;backup HL in background register
		call	APP_ACCU
		scf			;add space character
		ccf
		ld	C,020h
		call	APP_CHAR
		EXX			;restore HL from background register
		;first address of first row ready in STD_OUT

		ld	B,10h		;read 16 columns
RD_HL_COL:	ld	A,(HL)		;read memory content into A
		EXX			;backup HL in background register
		call	APP_ACCU
		scf			;append space character
		ccf
		ld	C,020h
		call	APP_CHAR
		EXX			;restore HL from background register
		inc	HL		;HL points to next mem position	
		djnz	RD_HL_COL	;loop until 16 columns are read
		EXX			;backup HL in background register
		call	TX_STD_OUT	;TX row to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR
		EXX			;restore HL from background register
		pop	BC		;restore BC from stack
		djnz	RD_HL_ROW	;loop until 16 rows are read
		ret

;----------------------------------------------------------------------------
div_by_2:	
;divides content of BC by 2
;writes the result back into BC !
;modifies BC
		srl	B
		jp	c,l_713
		srl	C
		ret
l_713:		srl	C
		set	7,C
		ret


	

;----------------------------------------------------------------------------
TX_NUMBER:
;transfers long number to host
;HL points to low byte of number
;BC holds number of bytes
;modifies A, HL, BC
		add	HL,BC		
l_844:		dec	HL		;HL points to high byte of number
		ld	A,(HL)
		push	BC
		call	APP_ACCU	;append byte to STD_OUT
		pop	BC
		dec	BC		;number of bytes - 1
		ld	A,B
		cp	0		;test high byte of BC for 0
		jp	nz,l_844	;if yes,
		ld	A,C		
		cp	0		;test low byte of BC for 0
		jp	nz,l_844	;if yes,
		call	TX_STD_OUT	;TX input value to host
		ret
;-----------------------------------------------------------------------------




req_snd:	;requests source, number, destination address
		ld	HL,source16
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get source address from host
		ld	(SOURCE_ADR),HL
req_nd:
		ld	HL,count16
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get number of bytes to burn from host
		ld	(NUMB_OF_BYTES),HL
req_d:
		ld	HL,destin16
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get destination address from host
		ld	(DEST_ADR),HL

		;prepare block transfer and search commands like ldi, cpi, cpir, ldir
		ld	HL,(SOURCE_ADR)
		ld	DE,(DEST_ADR)
		ld	BC,(NUMB_OF_BYTES)
		ret




fill_mem:	ld	HL,new_dat
		call	TX_STR
;		call	TX_STR_TERM
		call	req_number	;get fill value from host
		ld	(SCRATCH),A	;save fill value in scratch

		call	req_nd		;request number, destination address
		
		ld	DE,(DEST_ADR)
		ld	BC,(NUMB_OF_BYTES)
l_fi0:
		ld	HL,SCRATCH	;set source pointer to scratch
		ldi			;copy fill value (from scratch) to destination address
		jp	pe,l_fi0	;loop until block filled
		ret


cmp_mem:
		;ld	HL,(SOURCE_ADR)
		;ld	DE,(DEST_ADR)
		;ld	BC,(NUMB_OF_BYTES)
l_cmp0:		ld	A,(DE)		;load data at dest. address into A
		ld	(SCRATCH),A	;place copy of data in scratch
		cpi			;cmp data at source address with data at dest. addr.
		jp	nz,l_cmp_err
		inc	DE		;advance dest. pointer
		jp	pe,l_cmp0	;loop until byte counter bc is 0
		ret
l_cmp_err:	dec	HL		;set source pointer back at address where error occured
		push 	HL		;save current source address
		push	DE		;save current dest. address

		ld	HL,error	;tx "..?"
		call	TX_STR
		ld	HL,at		;tx "at"
		call	TX_STR

		pop	DE		;restore current dest. address
		ld	A,D
		push	DE
		call	APP_ACCU
		pop	DE
		ld	A,E
		call	APP_ACCU
		call	TX_STD_OUT	;tx current dest. address to host
		
		ld	HL,expect	;tx "exp:" to host
		call	TX_STR
		pop	HL		;restore current source address
		ld	A,(HL)
		call	APP_ACCU
		call	TX_STD_OUT	;tx current source address to host
		
		ld	HL,read		;tx "read:"
		call	TX_STR	

		ld	A,(SCRATCH)	;restore from scratch data read at dest. address
		call	APP_ACCU
		call	TX_STD_OUT	;tx corrupted data to host

		ret

;----------flash programming----------------------------------------
		
fl_prog:	;programs data into flash page wise
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR
		ld	HL,(SOURCE_ADR)
		ld	DE,(DEST_ADR)
		ld	BC,(NUMB_OF_BYTES)

		call	rd_reset	;device reset

l_prg0:		call	l_AA55
		ld	A,0A0h
		ld	(0D555h),A	;5555h

		push	HL
		pop	IX		;IX holds PA
		ld	A,(HL)		;A holds PD
		ld	(scratch),A	;backup PD
		ldi			;copy source_adr to dest_adr, dec bc
		ex	af,af'		;backup psw in background

po_dq7:		;poll DQ7
		ld	A,(scratch)	;restore PD
		xor	(IX+0)		;compare PD with data read from flash
		bit	7,A
		jp	z,l_pas0	;pass when DQ7 read = PD DQ7

		;poll DQ5
		bit	5,(IX+0)
		jp	z,po_dq7	;if DQ5=0 go to po_dq7

		;if DQ5=1 poll DQ7
		ld	A,(scratch)	;restore PD
		xor	(IX+0)		;compare PD with data read from flash
		bit	7,A
		jp	z,l_pas0	;pass when DQ7 read = PD DQ7

fail:		ex	af,af'
		ld	HL,flashfail
		call	tx_str
		jp	rd_reset	;reset device

l_pas0:		ex	af,af'
		jp	po,rd_reset	;reset device if no more bytes are left to load
		jp	l_prg0

;-----------------------------


fl_erase:	;erases complete flash
		call	rd_reset	;device reset

		call	l_AA55
		ld	A,080h
		ld	(0D555h),A	;5555h
		call	l_AA55
		ld	A,010h
		ld	(0D555h),A	;5555h
		
fl_er0:		;poll DQ7
		ld	A,(0D555h)	;read from any flash address (e.g. 5555h)
		bit	7,A		;as long as DQ7=0
		jp	z,fl_er0
		jp	rd_reset

;-----------------------------

id_check:	;reads flash id code. must be 01A4h for AM29F040 type
		;modifies all registers
		call	rd_reset	;device reset		

		ld	HL,fl_id
		call	TX_STR
				
		call	l_AA55
		ld	A,090h		;v94
		ld	(0D555h),A	;5555h
		
		ld	A,(08000h)	;0h
		call	APP_ACCU
		ld	A,(08001h)	;1h
		call	APP_ACCU

		call	TX_STD_OUT	;TX id code to host

		
rd_reset:	;device reset
		call	l_AA55
		ld	A,0F0h
		ld	(0D555h),A	;5555h
		ret			;normal mode reached

;------------------


l_AA55:		;modifies A
		ld	A,0AAh
		ld	(0D555h),A	;5555h
		ld	A,055h
		ld	(0AAAAh),A	;2AAAh
		ret





;-----------I2C Bus 1 test ----------------------------------------------------------
i1test:
		;init error code
		ld	IX,temp0
		ld	(IX+0),0	;preload error code
		ld	(IX+1),05h	;preload test data counter (5 x write/read)
		
		ld	IY,scratch
		ld	(IY+0),0F0h	;set duration of i2c expander test

;--------------write test data into flash--------------------------
		ld 	HL,i2cflash
		call	TX_STR
	    	ld	HL,NEW_LINE	;transmit new line
		call	TX_STR


l_150:		call	I2C1_START

		ld	A,0A0h		;load i2c flash dev code
		call	I2C1_tx
		jp	c,l_151		;if no ackn error go l_151
		ld	(IX+0),10h	;set err code to 10h (ackn error on flash dev select)
		jp	EO_i1test
		
l_151:		sub	A		;address 0 is to be written
		call	I2C1_tx
		jp	c,l_152		;if no ackn error go l_152
		ld	(IX+0),11h	;set err code to 11h (ackn error on flash mem addr select)
		jp	EO_i1test

l_152:		ld	A,(IX+1)	;write test data to mem address
		call	I2C1_tx
		jp	c,l_153		;if no ackn error go l_153
		ld	(IX+0),12h	;set err code to 12h (ackn error on data write)
		jp	EO_i1test

l_153:		call	I2C1_STOP

;--------------read test data from flash----------------------------
lesen:		call	wait_2
		call	I2C1_START

		ld	A,0A0h		;load i2c flash dev code
		call	I2C1_tx
		jp	c,l_154		;if no ackn error go l_154
		ld	(IX+0),13h	;set err code to 13h (ackn error on flash dev select)
		jp	EO_i1test

l_154:		sub	A		;address 0 is to be read		
		call	I2C1_tx
;		scf			;for
;		ccf			;debug only !
		jp	c,l_1541	;if no ackn error go l_1541
		ld	(IX+0),14h	;set err code to 14h (ackn error on flash mem addr select)
		jp	EO_i1test
		
l_1541:		;restart I2C bus 0
		call	SCL1_IN		;SCL0 = H
		call	I2C1_START

		;resend 8bit device select code
		ld	a,0A1h		;load i2c flash dev code with r/w bit set
		call	I2C1_tx
;		scf			;for
;		ccf			;debug only !
		jp	c,l_1542	;if no ackn error go l_1542
		ld	(IX+0),15h	;set err code to 15h (ackn error on flash mem addr select)
		jp	EO_i1test

l_1542:		call	I2C1_RX		;returns with slave data byte in C
		ld	A,(IX+1)
;		inc	A		;for debug only
		cp	C
		jp	z,l_1543	;if no ackn error go l_1542
		ld	(IX+0),16h	;set err code to 16h (error on flash data read)
		jp	EO_i1test
	
l_1543:		call	I2C1_STOP
		dec	(IX+1)		;test data counter - 1
					;when 0 reached i2c flash test done, leaving data 01h at 
					;address 00h of flash
		jp	nz,l_150

;-------------write to i2c expander------------------------------		

		ld 	HL,i2cpio	
		call	TX_STR
	    	ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		call	I2C1_START

l_156:		ld	A,040h		;load i2c expander dev code
		call	I2C1_tx
		jp	c,l_155		;if no ackn error go l_155
		ld	(IX+0),17h	;set err code to 17h (ackn error on expander dev select)
		jp	EO_i1test
		
l_155:		ld	A,(IX+1)	;load test data into device
		call	I2C1_tx
		jp	c,l_157		;if no ackn error go l_157
		ld	(IX+0),18h	;set err code to 18h (ackn error on expander data write)
		jp	EO_i1test
l_157:		inc 	(IX+1)		;inc test data counter
		jp	nz,l_155	;end loop on overflow of test data counter
		
		dec	(IY+0)		;IY points to duration value of this test
		jp	nz,l_155	
		;FFh is left on data port of expander
		    		
EO_i1test:	call	I2C1_STOP
		
		;transmit error code to host
		ld	a,(temp0)
		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host

		ret

;---------PIO test---------------------------
p_test:
		ld 	HL,pio_ab
		call	TX_STR
	    	ld	HL,NEW_LINE	;transmit new line
		call	TX_STR

		ld	a,0fh		;port A and B in output mode
		out	(PIO_A_C),A
;		ld	a,0fh
		out	(PIO_B_C),A


		ld	B,0A0h		;set duration of test
l_pt1:		ld	HL,0000h	;set start value
		ld	DE,0001h	;set step widht
l_pt0:		ld	A,L
		out	(PIO_A_D),A	;load lowbyte into port A
		ld	A,H
		or	0Ch		;set B2 and B3 high
		out	(PIO_B_D),A	;load highbyte into port B
		ADD	HL,DE		;advance test data counter by one
		jp	nc,l_pt0
		djnz	l_pt1
		;FFh is left in output data register of port A and B

		ld	a,4fh		;port A and B in input mode
		out	(PIO_A_C),A
		out	(PIO_B_C),A
		ret


reg_dump:
;		call	show_reg
;		ex	AF,AF'
;		exx
;		call	show_reg
;		ex	AF,AF'
;		exx
;		ret

;show_reg:

		;backup registers in bak_xx
		push	HL
		ld	(bak_hl),HL

		push	AF
		pop	HL
		ld	(bak_af),HL

;		push	BC
;		pop	HL
		ld	(bak_bc),BC

;		push	DE
;		pop	HL
		ld	(bak_de),DE

;		push	IX
;		pop	HL
		ld	(bak_ix),IX

;		push	IY
;		pop	HL
		ld	(bak_iy),IY

		push	IY
		push	IX
		push	DE
		push	BC
		push	AF

		call	l_rd3		;make newline

		ld	HL,reg_af	;announce transmission of AF
		call	TX_STR
		pop	AF		;restore value input from port from stack
		push	AF
		call	APP_ACCU	;append value to STD_OUT
		pop	BC
		call	l_rd1

		ld	HL,reg_bc	;announce transmission of BC
		call	TX_STR
		pop	AF		;restore value input from port from stack
		push	AF
		call	APP_ACCU	;append value to STD_OUT
		pop	BC
		call	l_rd1

		ld	HL,reg_de	;announce transmission of DE
		call	TX_STR
		pop	AF		;restore value input from port from stack
		push	AF
		call	APP_ACCU	;append value to STD_OUT
		pop	BC
		call	l_rd1

		ld	HL,reg_ix	;announce transmission of IX
		call	TX_STR
		pop	AF		;restore value input from port from stack
		push	AF
		call	APP_ACCU	;append value to STD_OUT
		pop	BC
		call	l_rd1

		ld	HL,reg_iy	;announce transmission of IY
		call	TX_STR
		pop	AF		;restore value input from port from stack
		push	AF
		call	APP_ACCU	;append value to STD_OUT
		pop	BC
		call	l_rd1

		ld	HL,reg_hl	;announce transmission of HL
		call	TX_STR
		pop	AF		;restore value input from port from stack
		push	AF
		call	APP_ACCU	;append value to STD_OUT
		pop	BC
		call	l_rd1

		;get return address
;		pop	DE
		pop	HL
		ld	(bak_pc),HL
		push	HL
;		push	DE

		ld	HL,reg_pc	;announce transmission of PC
		call	TX_STR
		ld	HL,(bak_pc)
		ld	A,H
		call	APP_ACCU	;append value to STD_OUT
		ld	HL,(bak_pc)
		ld	A,L
		call	l_rd2

		ld	HL,reg_sp	;announce transmission of SP
		call	TX_STR
		ld	(bak_sp),SP
		ld	HL,(bak_sp)
;		inc	HL
;		inc	HL
		inc	HL
		inc	HL
		ld	(bak_sp),HL	;correct bak_sp to value previous to register_dump call
		ld	A,H
		call	APP_ACCU	;append value to STD_OUT
		ld	HL,(bak_sp)
		ld	A,L
		call	l_rd2

		ld	HL,reg_ir	;announce transmission of IR
		call	TX_STR
		ld	A,I
		call	APP_ACCU	;append value to STD_OUT
		ld	A,R
		call	l_rd2


		;restore registers
		ld	BC,(bak_bc)
		ld	DE,(bak_de)
		ld	IY,(bak_ix)
		ld	IX,(bak_iy)
		ld	HL,(bak_af)
		push	HL
		pop	AF
		ld	HL,(bak_hl)
	


		ret

l_rd1:
		ld	a,c
l_rd2:		call	APP_ACCU	;append value to STD_OUT
		call	TX_STD_OUT	;TX input value to host
l_rd3:		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR
		ret



;------BSC------------------------------------------------------------



bsc_init:	

	;clear vector output ram address
	sub	A
	out	(st_adr0),A
	out	(st_adr1),A
	out	(st_adr2),A

	ret


;--------------------------------------------------------------
sorter:
	out	(ram_out),A

	push	AF
	ld	A,0CFh
	out	(PIO_A_C),A	;set PIO A to bit mode
	ld	A,0FCh
	out	(PIO_A_C),A	;set io configuration: A0 and A1 are outputs
	ld	A,(TEMP3)
	inc	A		;inc temp3 content
	out	(PIO_A_D),A	;load temp3 onto pio port A
	ld	(TEMP3),A	;save temp3
	pop	AF


	ret
;---------------------------------------------------------------------



rd_out_ram:	;reads output RAM memory content starting where HL points to
		;transmits row by row, so STD_OUT holds max.  52d characters
		;modifies all registers !

		;backup st_adr
		in	A,(st_adr0)
		push	AF
		in	A,(st_adr1)
		push	AF
		in	A,(st_adr2)
		push	AF

		;set adr path from rf to ram
		;set data path from ram to rf
		ld	A,01h
		out	(path),A

		;preset start address (offset -1)
		sub	A
		dec	A		;adr [7:0] always fixed to FFh
		out	(st_adr0),A
		dec	HL		;adr [23:8] -1
		ld	A,L
		out	(st_adr1),A
		ld	A,H
		out	(st_adr2),A
		

l_fd:
		;fetch ram data 
		in	A,(ram_out)
		ld	(temp3),A

		;check if A[3:0]=0 -> new line header
		in	A,(ram_adr0)
		and	0Fh
		jr	nz,l_ab
		in	A,(ram_adr2)
		call	APP_ACCU
		in	A,(ram_adr1)
		call	APP_ACCU
		in	A,(ram_adr0)
		call	APP_ACCU
		scf
		ccf
		ld	C,020h
		call	APP_CHAR
l_ab:
		ld	A,(temp3)
		call	APP_ACCU
		scf
		ccf
		ld	C,020h
		call	APP_CHAR

		;check if A[3:0]=F -> end of line
		in	A,(ram_adr0)
		and	0Fh
		cp	0Fh
		jr	nz,l_el
		call	TX_STD_OUT	;TX row to host
		ld	HL,NEW_LINE	;transmit new line
		call	TX_STR
l_el:

		;check if A[7:0] = FFh -> end of page
		in	A,(ram_adr0)
		cp	0FFh
		jr	nz,l_fd
		;else exit
		
		;restore st_adr
		pop	AF
		out	(st_adr2),A
		pop	AF
		out	(st_adr1),A
		pop	AF
		out	(st_adr0),A

		ld	A,00000101b	;direct adr from ex to ram , ram drives data : EX mode
		out	(path),A

		ret




;-------TEXT BEGIN---------------------------------------------------
Welcome:
	DEFB	0Ch	;CLS
	DEFM	'BSC V6.0 ready' ;sys version
	DEFB	0
	
prompt:	DEFB	0Ah	;next line
	DEFB	0Dh	;cursor home
	DEFM	'cmd> '
	DEFB	0

sys_fw:
	DEFM	'cpu_firmware_version: 6.0'
	DEFB	0Ah
	DEFB	0Dh
	DEFM	'executor_firmware_version: '
	DEFB	0


reg_af:
	DEFM	'AF: '
	DEFB	0

reg_bc:
	DEFM	'BC: '
	DEFB	0

reg_de:
	DEFM	'DE: '
	DEFB	0

reg_hl:
	DEFM	'HL: '
	DEFB	0

reg_ix:
	DEFM	'IX: '
	DEFB	0

reg_iy:
	DEFM	'IY: '
	DEFB	0

reg_pc:
	DEFM	'PC: '
	DEFB	0

reg_sp:
	DEFM	'SP: '
	DEFB	0

reg_ir:
	DEFM	'IR: '
	DEFB	0

error:
	DEFM	'...?'
	DEFB	0

mem_adr16:
	DEFM	'mem_adr: '
	DEFB	0	

source16:
	DEFM	'source_adr: '
	DEFB	0	

destin16:
	DEFM	'destination_adr: '
	DEFB	0	
	
count16:
	DEFM	'number_of_bytes: '
	DEFB	0	

new_dat:
	DEFM	'new_dat: '
	DEFB	0h

st_width:
	DEFM	'step_width: '
	DEFB	0h


AWT_TRM:
	DEFM	'please send file via xmodem !'
	DEFB	0h

io_adr:
	DEFM	'io_addr: '
	DEFB	0h

io_dat:
	DEFM	'io_data: '
	DEFB	0h


;I2C PIOs:
p0_sel:
	DEFM	'p0_sel: '
	DEFB	0h

p1_sel:
	DEFM	'p1_sel: '
	DEFB	0h

p0_out:
	DEFM	'p0_out: '
	DEFB	0h

p1_out:
	DEFM	'p1_out: '
	DEFB	0h

p0_in:
	DEFM	'p0_in:  '
	DEFB	0h

p1_in:
	DEFM	'p1_in:  '
	DEFB	0h

;I2C FLASHs
f0_sel:
	DEFM	'f0_sel: '
	DEFB	0h

f1_sel:
	DEFM	'f1_sel: '
	DEFB	0h

f0_adr:
	DEFM	'f0_adr: '
	DEFB	0h

f1_adr:
	DEFM	'f1_adr: '
	DEFB	0h

f0_daw:
	DEFM	'f0_daw: '
	DEFB	0h

f1_daw:
	DEFM	'f1_daw: '
	DEFB	0h

f0_dar:
	DEFM	'f0_dar: '
	DEFB	0h

f1_dar:
	DEFM	'f1_dar: '
	DEFB	0h

fl_id:	DEFM	'flash-id: '
	DEFB	0h

flashfail:
	DEFM	'fail !'
	DEFB	0h

at:	DEFM	' at: '
	DEFB	0h

expect:	DEFM	' expected: '
	DEFB	0h

read:	DEFM	' read: '
	DEFB	0h

i2cflash:
	DEFM	'I2C SEEPROM...'
	DEFB	0h

i2cpio:
	DEFM	'I2C Expander...'
	DEFB	0h

pio_ab:
	DEFM	'PIO A/B...'
	DEFB	0h

exe_state:
	DEFM	'EXE: '
	DEFB	0h

tap_state:
	DEFM	'TST: '
	DEFB	0h

bits_to1:
	DEFM	'TO1: '
	DEFB	0h

bits_pr1:
	DEFM	'BP1: '
	DEFB	0h

bits_to2:
	DEFM	'TO2: '
	DEFB	0h

bits_pr2:
	DEFM	'BP2: '
	DEFB	0h

tap_in:
	DEFM	'TIN: '
	DEFB	0h

step_id:
	DEFM	'SID: '
	DEFB	0h

ram_adr:
	DEFM	'ADR: '
	DEFB	0h

rm_data:
	DEFM	'DAT: '
	DEFB	0h

vst1:
	DEFM	'VS1: '
	DEFB	0h

vst2:
	DEFM	'VS2: '
	DEFB	0h


NEW_LINE:
	DEFB	0Dh	;next line
	DEFB	0Ah	;cursor home
	DEFB	0
			
BS_SP_BS:
 	DEFB  	08h		;BSP
	DEFB	20h		;SPACE
	DEFB	08h		;BSP
	DEFB	0

2xBS:
 	DEFB  	08h		;BSP
	DEFB	08h		;BSP
	DEFB	0

	
;-------COMMAND SET begin----------------------------------------		

HELP:	
	DEFM	'help'
	DEFB	0Dh

CMD_SET:

POUT:
	DEFM	'portout'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

PIN:
	DEFM	'portin'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

RSTI2C0:
	DEFM	'rsti0'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

RSTI2C1:
	DEFM	'rsti1'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

I2C0F:
	DEFM	'i0f'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

I2C0P:
	DEFM	'i0p'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

I2C1F:
	DEFM	'i1f'	
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

I2C1P:
	DEFM	'i1p'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

VIEW_MEM:
	DEFM	'viewmem'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line
	
cmp:	
	DEFM	'comp'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

copy:
	DEFM	'copy'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

fill:
	DEFM	'fill'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

PRG_FL:
	DEFM	'prgflash'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

erf:
	DEFM	'eraseflash'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

RAM_S:
	DEFM	'testmem'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

DLD:	
	DEFM	'load'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

ca_usr_prg:
	DEFM	'call'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

EO:	
	DEFM	'echooff'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

i2c1_test:
	DEFM	'testi1'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

pio_test:
	DEFM	'testpio'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

dbg:	
	DEFM	'db'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

runtest:
	DEFM	'runtest'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

stoptest:
	DEFM	'stoptest'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

stwidth:
	DEFM	'step'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

firmware:
	DEFM	'fw'
	DEFB	0Dh	;cursor home
	DEFB	0Ah	;next line

clrram:
	DEFM	'clrram'
	DEFB	0Dh;
	DEFB	0Ah;

vw_out_ram:
	DEFM	'viewoutram'
	DEFB	0Dh;
	DEFB	0Ah;

CMDs_END:
	DEFB	0h



