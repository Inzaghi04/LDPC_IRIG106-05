# Compiler
CC = gcc
CFLAGS = -Wall -Iinclude

# Thư mục
SRC = src
LIB = lib
OBJ = obj
BIN = bin

# File
SRC_FILES = $(wildcard $(SRC)/*.c)
LIB_FILES = $(wildcard $(LIB)/*.c)

SOURCES = $(SRC_FILES) $(LIB_FILES)
OBJECTS = $(patsubst %.c, $(OBJ)/%.o, $(notdir $(SOURCES)))

TARGET = $(BIN)/program

.PHONY: all clean run

# Build
all: $(TARGET)

# Link
$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(TARGET)

# Compile src
$(OBJ)/%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Compile lib
$(OBJ)/%.o: $(LIB)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Run
run: all
	./$(TARGET)

# Clean
clean:
	rm -rf $(OBJ)/*.o $(TARGET)