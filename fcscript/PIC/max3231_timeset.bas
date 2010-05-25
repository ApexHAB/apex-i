'First program the date

symbol sec = $00
symbol mmn = $15
symbol hur = $10
symbol DOW = $05
symbol day = $20
symbol mth = $06


	
hi2csetup i2cmaster, %11010000, i2cslow, i2cbyte
'	hi2cout 0, (sec, mmn, hur, DOW, day, mth, $08)
'	hi2cout $0E, (%10000000)
	pause 50



'loop read

main:
hi2cin 0, (b0,b1,b2,b3,b4,b5,b6,b7)
gosub BCD_DECIMAL

sertxd(#b0," ",#b1," ",#b2," ",#b3," ",#b4," ",#b5," ",#b6," ",#b7,CR,LF)
wait 1 
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

