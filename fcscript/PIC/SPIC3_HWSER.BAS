high portc 6 'for T mode serial
hsersetup B2400_4, %00

hi2csetup i2cmaster, %11010000, i2cslow, i2cbyte

main:
serin 7,T2400,("C"),b0,b1,b2,b3,b4,b5,b6,b7
sertxd(b0,b1)
if b0 = "1" then
	if b1 = 1 then 'C11 - read time
		hi2cin 0, (b0,b1,b2,b3,b4,b5,b6,b7)
		gosub BCD_DECIMAL
		hserout 0,(#b2,#b1,#b0,cr,lf) ' send the time string to FC
		pause 50
	else if b1 = 2 then 'C12 - data string
		high portc 0
		pause 10
		hserout 0,("PICDATA",cr,lf)
		pause 100
		low  portc 0
	end if
else if b0 = "2" then   
	if b1 = "2" then  ' FC wants to set the time
		'hi2cout 0, (sec, mmn, hur)
		'hi2cout $0E, (%00000000)
		pause 50
	endif
else
	high  portc 0
	pause 10
	hserout 0,("PICERR",cr,lf)
	pause 100
	low  portc 0
endif
goto main

bcd_decimal:


	let b12 = b0 & %11110000 / 16 * 10
	let b0 = b0 & %00001111 + b12
	let b12 = b1 & %11110000 / 16 * 10
	let b1 = b1 & %00001111 + b12
	
	let b12 = b2 & %11110000 / 16 * 10
	let b2 = b2 & %00001111 + b12
	let b12 = b3 & %11110000 / 16 * 10
	let b3 = b3 & %00001111 + b12

	let b12 = b4 & %11110000 / 16 * 10
	let b4 = b4 & %00001111 + b12
	let b12 = b5 & %11110000 / 16 * 10
	let b5 = b5 & %00001111 + b12
	
	let b12 = b6 & %11110000 / 16 * 10
	let b6 = b6 & %00001111 + b12
	let b12 = b7 & %11110000 / 16 * 10
	let b7 = b7 & %00001111 + b1

return
