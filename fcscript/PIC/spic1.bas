main:
high 0 'for T mode serial
serin 0,T2400,("C"),b1,b2
sertxd(b1,b2)
if b1 = "1" then
	high 1
	pause 10
	serout 0,T2400,("PICDATA",cr,lf)
	pause 100
	low 1
else
	high 1
	pause 10
	serout 0,T2400,("PICERR",cr,lf)
	pause 100
	low 1
endif
goto main
