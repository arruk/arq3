CC ?= gcc
SYSROOT ?= build/sysroot

TARGET := pi_monte_carlo
SRCS := main.c
OBJS := $(SRCS:.c=.o)

CFLAGS ?= -O2 -Wall -Wextra -std=c11
CPPFLAGS ?=
LDFLAGS ?=
LDLIBS ?=

ifneq ($(wildcard $(SYSROOT)/usr/include),)
CPPFLAGS += -I$(SYSROOT)/usr/include
endif

ifneq ($(wildcard $(SYSROOT)/usr/lib),)
LDFLAGS += -L$(SYSROOT)/usr/lib
endif

LDLIBS += -pthread

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -pthread -c -o $@ $<

run: $(TARGET)
	./$(TARGET) $(SAMPLES) $(THREADS)

clean:
	rm -f $(TARGET) $(OBJS)
