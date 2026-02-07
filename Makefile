SHELL := /bin/bash

TARGET ?= qemu

ifeq ($(TARGET), qemu)
	CPU_FLAG = -mcpu=arm926ej-s 
	FLOAT_FLAG = -mfloat-abi=soft
endif
ifeq ($(TARGET), beagle)
	CPU_FLAG = -mcpu=cortex-a8 -Wall -Werror -O2 -ffreestanding
	FLOAT_FLAG = -mfpu=neon -mfloat-abi=hard
endif
FLAGS = -I ./lib -I ./os $(CPU_FLAG) $(FLOAT_FLAG)

LDFLAGS = -nostdlib

BIN = ./bin
LIB_SRCS = $(wildcard ./lib/*.c)
OS_SRCS = $(wildcard ./os/*.c)
MAIN_SRC = $(wildcard ./source/*.c)
SRCS = $(LIB_SRCS) $(OS_SRCS) $(MAIN_SRC)
LINK_SRC = $(wildcard ./*.ld)
STARTUP_SRC = $(wildcard ./os/*.s)

START = $(patsubst %.s, $(BIN)/%.o, $(notdir $(STARTUP_SRC)))
OBJS = $(patsubst %.c, $(BIN)/%.o, $(notdir $(SRCS)))

.PHONY: init clean run debug help

default: $(BIN)/main.elf

$(BIN)/main.elf: $(BIN) $(START) $(OBJS)
	@echo "Linking object files..."
	arm-none-eabi-gcc $(FLAGS) $(LDFLAGS) -T $(LINK_SRC) $(START) $(OBJS) -lgcc -o $(BIN)/main.elf
	@echo "Converting ELF to binary..."
	arm-none-eabi-objcopy -O binary $(BIN)/main.elf $(BIN)/main.bin

$(BIN):
	mkdir -p $(BIN)

$(BIN)/%.o: ./lib/%.c
	arm-none-eabi-gcc $(FLAGS) -c -g $< -o $@

$(BIN)/%.o: ./os/%.c
	arm-none-eabi-gcc $(FLAGS) -c -g $< -o $@

$(BIN)/%.o: ./os/%.s
	@echo "Assembling startup file..."
	arm-none-eabi-gcc $(FLOAT_FLAG) -c -g $< -o $@

$(BIN)/%.o: ./source/%.c
	@echo "Compiling main file..."
	arm-none-eabi-gcc $(FLAGS) -c -g $< -o $@

init: ./os ./lib ./source ./.vscode
	cp ~/Documents/debug_files/*.json ./.vscode

./os:
	mkdir -p ./os
./lib:
	mkdir -p ./lib
./source:
	mkdir -p ./source
./.vscode:
	mkdir -p ./.vscode

clean:
	@echo "Cleaning up..."
	@rm -rf $(BIN)

run: $(BIN)/main.elf
ifeq ($(TARGET), qemu)
	qemu-system-arm -M versatilepb -nographic -kernel $(BIN)/main.elf
endif

debug: $(BIN)/main.elf
ifeq ($(TARGET), qemu)
	gdb-multiarch $(BIN)/main.elf -q -ex 'target remote :1234'
	gnome-terminal -- bash -c "qemu-system-arm -M versatilepb -nographic -s -S -kernel $(BIN)/main.elf; exec bash"
endif

help:
	@echo "Compiling and running of C program for the OS course."
	@echo "Available commands:"
	@echo " - default: compile the project to generate the .elf and .bin file for execution"
	@echo " - init: sets up the directory for starting up a project"
	@echo " - clean: cleans the compiled files"
	@echo " - run: runs the program on QEMU"
	@echo " - debug: enters debug mode on GDB"
	@echo "NOTE: the default target is QEMU, to change it use 'TARGET=beagle'"