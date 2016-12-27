
# Copyright (c) 2015 Nicholas DeCicco. <nsd.cicco@gmail.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

ifeq ($(OS),Windows_NT)
ASM = msp430-elf-gcc
OBJCOPY = msp430-elf-objcopy
ASMFLAGS = -O0 -Wall -g -mmcu=msp430g2231 -D_GNU_ASSEMBLER_ \
           -LC:\TI\gcc\include -IC:\TI\gcc\include
MSP430FLASHER = MSP430Flasher
else
ASM = msp430-gcc
ASMFLAGS = -O0 -Wall -g -mmcu=msp430g2231 -D_GNU_ASSEMBLER_
MSPDEBUG = mspdebug
endif

TARGET_BASENAME = ntsc

TARGET_ELF = $(TARGET_BASENAME).elf
TARGET_HEX = $(TARGET_BASENAME).hex

all: $(TARGET_ELF)

$(TARGET_ELF): %.elf : %.S
	$(ASM) $(ASMFLAGS) $< -o $@

$(TARGET_HEX): %.hex : %.elf
	$(OBJCOPY) -O ihex $< $@

ifeq ($(OS),Windows_NT)
upload: $(TARGET_HEX)
	$(MSP430FLASHER) -w $<
else
upload: $(TARGET_ELF)
	$(MSPDEBUG) rf2500 "prog $<"

debug: $(TARGET_ELF)
	$(MSPDEBUG) rf2500 "prog $<" gdb
endif

clean:
	-rm $(TARGET_ELF) $(TARGET_HEX)
