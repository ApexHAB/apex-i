main:
high portc 6 'for T mode serial
hsersetup B2400_4, %00
serin 7,T2400,("C"),b1,b2
sertxd(b1,b2)
if b1 = "1" then
	high portc 0
	pause 10
	hserout 0,("PICDATA",cr,lf)
	pause 100
	low  portc 0
else
	high  portc 0
	pause 10
	hserout 0,("PICERR",cr,lf)
	pause 100
	low  portc 0
endif
goto main
