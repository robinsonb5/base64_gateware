SUBDIRS = ../m68k_cross_baremetal libsoc helloworld

all: 
	for DIR in $(SUBDIRS); do \
		make -C $$DIR; \
	done;
	
clean:
	for DIR in $(SUBDIRS); do \
		make -C $$DIR clean; \
	done;

