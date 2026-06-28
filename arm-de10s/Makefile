CROSS_COMPILE ?= arm-none-eabi-

CC      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
OBJDUMP := $(CROSS_COMPILE)objdump
SIZE    := $(CROSS_COMPILE)size

BUILD_DIR := build
EXTRA_CFLAGS ?=

ARCH_CFLAGS := -mcpu=cortex-a9 -marm -mfloat-abi=soft
WARN_CFLAGS := -Wall -Wextra -Werror -Wno-unused-parameter
COMMON_CFLAGS := $(ARCH_CFLAGS) $(WARN_CFLAGS) -std=c11 -Os -g3 \
	-ffreestanding -fno-builtin -fdata-sections -ffunction-sections \
	-Icommon -Ipi_monte_carlo -Ipi_monte_carlo/common $(EXTRA_CFLAGS)
ASFLAGS := $(ARCH_CFLAGS) -g3 -x assembler-with-cpp
LDFLAGS := -nostdlib -Wl,--gc-sections -Wl,--build-id=none
LDLIBS := -lgcc

COMMON_SRCS := common/startup.S common/uart.c common/socfpga.c common/mem.c common/print.c
COMMON_OBJS := $(patsubst %,$(BUILD_DIR)/%.o,$(COMMON_SRCS))

HELLO_ELF := $(BUILD_DIR)/hello_uart/hello_uart.elf
HELLO_BIN := $(BUILD_DIR)/hello_uart/hello_uart.bin
HELLO_LST := $(BUILD_DIR)/hello_uart/hello_uart.lst
HELLO_OBJS := $(COMMON_OBJS) $(BUILD_DIR)/hello_uart/main.c.o

PI_CORE1_ELF := $(BUILD_DIR)/pi_monte_carlo/core1.elf
PI_CORE1_BIN := $(BUILD_DIR)/pi_monte_carlo/core1.bin
PI_CORE1_LST := $(BUILD_DIR)/pi_monte_carlo/core1.lst
PI_CORE1_OBJS := $(COMMON_OBJS) \
	$(BUILD_DIR)/pi_monte_carlo/common/monte_carlo.c.o \
	$(BUILD_DIR)/pi_monte_carlo/core1/main.c.o

PI_CORE0_ELF := $(BUILD_DIR)/pi_monte_carlo/core0.elf
PI_CORE0_BIN := $(BUILD_DIR)/pi_monte_carlo/core0.bin
PI_CORE0_LST := $(BUILD_DIR)/pi_monte_carlo/core0.lst
PI_CORE0_OBJS := $(COMMON_OBJS) \
	$(BUILD_DIR)/pi_monte_carlo/common/monte_carlo.c.o \
	$(BUILD_DIR)/pi_monte_carlo/core0/main.c.o \
	$(BUILD_DIR)/pi_monte_carlo/core0/core1_image.S.o

.PHONY: all hello pi clean sizes

all: hello pi

hello: $(HELLO_ELF) $(HELLO_BIN) $(HELLO_LST)

pi: $(PI_CORE0_ELF) $(PI_CORE0_BIN) $(PI_CORE0_LST) \
	$(PI_CORE1_ELF) $(PI_CORE1_BIN) $(PI_CORE1_LST)

sizes: $(HELLO_ELF) $(PI_CORE0_ELF) $(PI_CORE1_ELF)
	$(SIZE) $^

$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(@D)
	$(CC) $(COMMON_CFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/%.S.o: %.S
	@mkdir -p $(@D)
	$(CC) $(ASFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/pi_monte_carlo/core0/core1_image.S.o: pi_monte_carlo/core0/core1_image.S $(PI_CORE1_BIN)
	@mkdir -p $(@D)
	$(CC) $(ASFLAGS) -DCORE1_BIN_PATH=\"$(abspath $(PI_CORE1_BIN))\" -MMD -MP -c $< -o $@

$(HELLO_ELF): $(HELLO_OBJS) linker/hello.ld
	@mkdir -p $(@D)
	$(CC) $(COMMON_CFLAGS) $(LDFLAGS) -T linker/hello.ld \
		-Wl,-Map=$(basename $@).map $(HELLO_OBJS) $(LDLIBS) -o $@

$(PI_CORE1_ELF): $(PI_CORE1_OBJS) linker/core1.ld
	@mkdir -p $(@D)
	$(CC) $(COMMON_CFLAGS) $(LDFLAGS) -T linker/core1.ld \
		-Wl,-Map=$(basename $@).map $(PI_CORE1_OBJS) $(LDLIBS) -o $@

$(PI_CORE0_ELF): $(PI_CORE0_OBJS) linker/core0.ld
	@mkdir -p $(@D)
	$(CC) $(COMMON_CFLAGS) $(LDFLAGS) -T linker/core0.ld \
		-Wl,-Map=$(basename $@).map $(PI_CORE0_OBJS) $(LDLIBS) -o $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.lst: %.elf
	$(OBJDUMP) -d -S $< > $@

clean:
	$(RM) -r $(BUILD_DIR)

-include $(shell find $(BUILD_DIR) -name '*.d' 2>/dev/null)
