#GNU make

name = booterdash

install_drive = /dev/sdi

$(name).img	:	$(name).asm
	@du -h --apparent-size $(name).img || true;
	jwasm -bin -Fo $@ -Fl=$*.lst $<;
	@du -h --apparent-size $(name).img

.PHONY	:	clean
clean	    :
	rm -f *.o *.lst *.err *.img *.bin

.PHONY	:	install
install	    :	$(name).img
	dd conv=notrunc if=$(name).img of=$(install_drive)
	
.PHONY	:	run
run	    :	$(name).img
	dosbox-debug $(name).img