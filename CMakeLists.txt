cmake_minimum_required(VERSION 3.10)
project(x86Os NONE)

set(QEMU_EXE "C:/Program Files/qemu/qemu-system-x86_64.exe")

find_program(NASM_EXE nasm REQUIRED)

# 1. Assemble boot.asm into boot.bin
add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/boot.bin
        COMMAND ${NASM_EXE} -f bin ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm -o ${CMAKE_CURRENT_BINARY_DIR}/boot.bin
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm
        COMMENT "Assembling bootloader..."
        VERBATIM
)

# 2. Build target
add_custom_target(BuildBootloader ALL
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/boot.bin
)

# 3. Run in QEMU
add_custom_target(RunOS
        COMMAND "${QEMU_EXE}" -drive format=raw,file=${CMAKE_CURRENT_BINARY_DIR}/boot.bin
        DEPENDS BuildBootloader
        COMMENT "Launching QEMU..."
        USES_TERMINAL
        VERBATIM
)