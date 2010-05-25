#picaxe28x1
wait 1
symbol ADCcs = 2
symbol ADCclk = 0 ' clock (output pin)
symbol ADCDout = 1 ' data (output pin for shiftout)
symbol ADCDin = input5 ' data
symbol LED = 0	'portc 0
high ADCcs

symbol cutDown = 5
symbol noise = 4

symbol camServo = 3
symbol camCtrl = 7
symbol camServoEn = 6


high portc 6 'for T mode serial
hsersetup B2400_4, %01

hi2csetup i2cmaster, %11010000, i2cslow, i2cbyte

' VERSION CHANGES
' 
' USES BINTOASCII WORKAROUND FOR DROPPING MIDDLE ZEROES IN HSEROUT
'
' USES 2 MINUTE INACTIVITY TIMEOUT AND RESET
'

'w0 (b0,b1) = ADC output
'can use with care, used by specific functions ie shiftIn:  (b15-b20)
'use to pass numbers to specific functions		   	(b17-b20)
'
'can use but only use as temp as will get changed: (b21+)
'use for command functions ie setClock
'

'w0 AND w1 - used in getString for ADC reads

'w2 and w3 - used in getString for 12bit temp readings

'########need to do error checking


settimer 49110				' 1 second major tick
timer = 65415 				' preload to 120 tick
toflag = 0
setintflags %10000000,%10000000	' interrupt on toflag




waitforInput:
pause 1

b21 = hserptr - ptr
if b21 >= 4 then		
	if @ptrinc = "C" then		
		b21 = @ptrinc
		b22 = @ptrinc
		b23 = @ptrinc
		b23 = b23 - 48
		b24 = hserptr - ptr
		if b24 >= b23 then
			if b21 = "1" then
				if b22 = "1" then gosub getString	
				if b22 = "2" then gosub getClock
				if b22 = "3" then gosub getADC
				if b22 = "4" then gosub PingPong
			elseif b21 = "2" then
				if b22 = "1" then gosub flashALL			
				if b22 = "2" then gosub	setclock
				if b22 = "9" then gosub cD
			elseif b21 = "3" then
				if b22 = "1" then gosub takeNOW			
			'	if b22 = "2" then gosub			
			endif
		else
			ptr = ptr - 4	
		endif
	else
		ptr = ptr - 1
		b21 = @ptr
		sertxd("stray byte   ",@ptr,"  ",#b21,"   ptr:",#ptr,"  serptr:",#hserptr,cr,lf)
		ptr = ptr + 1
	endif
elseif b21 >= 1 then
	if @ptr <> "C" then	
		sertxd("Stray Byte -- ",@ptr,cr,lf)
		ptr = ptr + 1
	endif
endif




if hserptr > 100 then
	ptr = 0
	hserptr = 0
	sertxd("pointers reset due to too much crap in the buffer",cr,lf)
endif


if ptr > hserptr then
	ptr = 0
	hserptr = 0
	sertxd("pointers reset due to overtake",cr,lf)
endif

if ptr = hserptr then
	if ptr <> 0 then
		hserptr = 0
		ptr = 0
		sertxd("pointers reset",cr,lf)
	endif
endif

goto waitforInput



'#####################################
'#############GET STRING##############
'#####################################

sertxd("entering getstring",cr,lf)

getstring:
high portc 0

'readtemp12 1,w3   ' ot
'pause 50
'readtemp12 2,w2   ' it
'pause 50

b19 = 2
gosub ADCshift
b19 = 2
gosub ADCshift

w1 = w0


b19 = 1
gosub ADCshift
b19 = 1
gosub ADCshift

hserout 0,("AVDATA-IT")
' it kludge
readit12:
readtemp12 2,w2   ' it
pause 10
if w2 = 0 or w2 = 65535 then goto readit12
sertxd("it w2: ",#w2,cr,lf)
bintoascii w2, b22,b23,b24,b25,b26
If w2 >= 10000 Then : HserOut 0,(b22) : End If
If w2 >= 1000  Then : HserOut 0,(b23) : End If
If w2 >= 100   Then : HserOut 0,(b24) : End If
If w2 >= 10    Then : HserOut 0,(b25) : End If
HserOut 0,(b26)


hserout 0,("OT")
' ot kludge
readot12:
readtemp12 1,w2   ' it
pause 10
if w2 = 0 or w2 = 65535 then goto readot12
sertxd("ot w2: ",#w2,cr,lf)
bintoascii w2, b22,b23,b24,b25,b26
If w2 >= 10000 Then : HserOut 0,(b22) : End If
If w2 >= 1000  Then : HserOut 0,(b23) : End If
If w2 >= 100   Then : HserOut 0,(b24) : End If
If w2 >= 10    Then : HserOut 0,(b25) : End If
HserOut 0,(b26)


hserout 0,("PP",#w1,"BV",#w0,cr,lf)

sertxd("PIcDATA",cr,lf)
pause 100

low portc 0

b19 = @ptrinc
if b19 <> 10 then sertxd("Stop byte error",cr,lf) endif

settimer 49110				' 1 second major tick
timer = 65415 				' preload to 120 tick
toflag = 0
setintflags %10000000,%10000000	' interrupt on toflag

sertxd("leaving getstring",cr,lf)

return

'#####################################
'#####################################
'#####################################



'#####################################
'#############GET CLOCK###############
'#####################################

getclock:

sertxd("entering getclock",cr,lf)

high portc 0
hi2cin 0, (b17,b18,b19)
gosub BCD_DECIMAL

' send the time string to FC
'hserout 0,("time: ")
if b19 < 10 then hserout 0,("0") endif
'hserout 0,(#b19,":")
hserout 0,(#b19)
if b18 < 10 then hserout 0,("0") endif
hserout 0,(#b18)
if b17 < 10 then hserout 0,("0") endif
hserout 0,(#b17,cr,lf) 

b19 = @ptrinc
if b19 <> 10 then sertxd("Stop byte error",cr,lf) endif

pause 100



low portc 0

settimer 49110				' 1 second major tick
timer = 65415 				' preload to 120 tick
toflag = 0
setintflags %10000000,%10000000	' interrupt on toflag

sertxd("leaving getclock",cr,lf)

return

'#####################################
'#####################################
'#####################################




'#####################################
'##############GET ADC################
'#####################################
getADC:

sertxd("entering getadc",cr,lf)

high portc 0

b19 = @ptrinc
b19 = b19 - 48
b21 = b19

'hserout 0,("adc ",#b21,":  ")
sertxd("adc ",#b21,":  ")

gosub ADCshift
pause 1
b19 = b21
gosub ADCshift

hserout 0,(#w0,cr,lf)
sertxd(#w0,cr,lf)

low portc 0

b19 = @ptrinc
if b19 <> 10 then sertxd("Stop byte error",cr,lf) endif

settimer 49110				' 1 second major tick
timer = 65415 				' preload to 120 tick
toflag = 0
setintflags %10000000,%10000000	' interrupt on toflag

sertxd("leaving getadc",cr,lf)

return
'#####################################
'#####################################
'#####################################


'#####################################
'############PING PONG################
'#####################################
pingpong:

sertxd("entering pingpong",cr,lf)

hserout 0,("PONG",cr,lf)


high portc 0
pause 100
low portc 0

b19 = @ptrinc
if b19 <> 10 then sertxd("Stop byte error",cr,lf) endif

settimer 49110				' 1 second major tick
timer = 65415 				' preload to 120 tick
toflag = 0
setintflags %10000000,%10000000	' interrupt on toflag

sertxd("leaving pingpong",cr,lf)

return
'#####################################
'#####################################
'#####################################


'#####################################
'##############FLASH ALL##############
'#####################################
flashALL:

sertxd("entering flashall",cr,lf)

hserout 0,("FA",cr,lf)

b19 = @ptrinc
if b19 <> 10 then sertxd("Stop byte error",cr,lf) endif


high portc 0
high noise

wait 5

low noise
low portc 0

settimer 49110				' 1 second major tick
timer = 65415 				' preload to 120 tick
toflag = 0
setintflags %10000000,%10000000	' interrupt on toflag

sertxd("leaving flashall",cr,lf)

return
'#####################################
'#####################################
'#####################################



'#####################################
'###############set clock#############
'#####################################

setclock:

high portc 0

b21 = @ptrinc
b22 = @ptrinc
b23 = @ptrinc
b24 = @ptrinc
b25 = @ptrinc
b26 = @ptrinc

b21 = b21 - 48
b22 = b22 - 48
b23 = b23 - 48
b24 = b24 - 48
b25 = b25 - 48
b26 = b26 - 48

b21 = b21 * 16
b21 = b21 + b22

b23 = b23 * 16
b23 = b23 + b24

b25 = b25 * 16
b25 = b25 + b26

hi2cout 0, (b25, b23, b21)
hi2cout $0E, (0)

pause 200		'pause for a nice break :-)
low portc 0

b19 = @ptrinc
if b19 <> 10 then sertxd("Stop byte error",cr,lf) endif

hserout 0,("L",cr,lf)

return


'#####################################
'#####################################
'#####################################


'#####################################
'#############CUT DOWN################
'#####################################
cD:

hserout 0,("UTRX",cr,lf)
'sertxd("UTDOWN",cr,lf)
pause 100

b19 = @ptrinc
if b19 <> 10 then sertxd("Stop byte error",cr,lf) endif

high portc 0
high cutDown
wait 10
low cutDown
low portc 0

pause 10


return

'#####################################
'#####################################
'#####################################



'#####################################
'##############take NOW###############
'#####################################
takeNOW:

sertxd("entering takenow",cr,lf)

'symbol camServo 6
'symbol camCtrl = 7

b19 = @ptrinc
b21 = b19 - 48     ' ascii to dec
w11 = b21 * 3000

sertxd("b19: ",#b19," b21: ",#b21," w11: ",#w11,cr,lf)

high camServoEn
pause 10

servo camServo, 75
pause 1000
pulsout camCtrl, w11 
'high camCtrl
'pause 30
'low camCtrl
pause 100

servo camServo, 140
pause 1000
pulsout camCtrl, w11
'high camCtrl
'pause 30
'low camCtrl
pause 100

low camServoEn


' servo command overrides internal timer, so restart it
settimer 49110				' 1 second major tick
timer = 65415 				' preload to 120 tick
toflag = 0
setintflags %10000000,%10000000	' interrupt on toflag


b19 = @ptrinc
if b19 <> 10 then sertxd("Stop byte error",cr,lf) endif

high portc 0
pause 100
low portc 0

hserout 0,("PI",cr,lf)
pause 10

sertxd("leaving takenow",cr,lf)

return
'#####################################
'#####################################
'#####################################











'##################################################################################
'##################################################################################
'##################################################################################

'#####################################
'##everyones favourite BCD function###
'#####################################

'input/output on b17,b18,b19,b20

bcd_decimal:

	let b15 = b17 & %11110000 / 16 * 10
	let b17 = b17 & %00001111 + b15
	let b15 = b18 & %11110000 / 16 * 10
	let b18 = b18 & %00001111 + b15	
	let b15 = b19 & %11110000 / 16 * 10
	let b19 = b19 & %00001111 + b15
	let b15 = b20 & %11110000 / 16 * 10
	let b20 = b20 & %00001111 + b15

return

'#####################################
'#####################################
'#####################################


'#####################################
'##########ADC SHIFT!!!###############
'#####################################

'b19 selects channel
'w0 is output word


ADCshift:
low ADCclk
low ADCDout
low ADCcs

high ADCDout
pulsout ADCclk, 10
high ADCDout
pulsout ADCclk, 10

for b17 = 1 to 3
	b18 = b19 & %100
	if b18 > 0 then
		high ADCDout
	else
		low ADCDout
	endif
	pulsout ADCclk, 10
	b19 = b19 * 2
next b17
pause 1
pulsout ADCclk, 10
pause 1
pulsout ADCclk, 10

w0 = 0

for b17 = 1 to 12

	w0 = w0 * 2
	if ADCDin is on then
		w0 = w0 + 1
	endif
	pulsout ADCclk,10
next b17

high ADCcs
low ADCDout

return

'#####################################
'#####################################
'#####################################

'##################################################################################
'##################################################################################
'##################################################################################









interrupt:
	timer = 65415
	toflag = 0
	sertxd("2 MINS INTERRUPT",cr,lf)
	sertxd("hserptr: ",#hserptr," ptr: ",#ptr," b21: ",#b21,cr,lf)
	setintflags %10000000,%10000000
	pause 100
	reset
return






