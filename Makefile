SRC             = $(wildcard ./lib/src/*.lua)

fmtchk:
	stylua --check $(SRC)

fmtfix:
	stylua $(SRC)