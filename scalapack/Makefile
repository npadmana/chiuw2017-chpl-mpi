MKLROOT=/opt/intel/mkl
MKLLIBS=-lmkl_scalapack_lp64

all: scalapack.x

scalapack.x: scalapack.chpl
	chpl -o $@ $< \
		-I${MKLROOT}/include -L${MKLROOT}/lib \
		${MKLLIBS}
