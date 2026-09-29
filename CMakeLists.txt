cmake_minimum_required(VERSION 3.20)
project(x86Os C)

set(QEMU_EXE "C:/Program Files/qemu/qemu-system-x86_64.exe")

find_program(NASM_EXE nasm REQUIRED)
find_program(GCC_EXE gcc REQUIRED)
find_program(LD_EXE ld REQUIRED)
find_program(OBJCOPY_EXE objcopy REQUIRED)

set(KERNEL_PE  "${CMAKE_CURRENT_BINARY_DIR}/kernel.pe")
set(KERNEL_BIN "${CMAKE_CURRENT_BINARY_DIR}/kernel.bin")
set(KERNEL_MAP "${CMAKE_CURRENT_BINARY_DIR}/kernel.map")
set(OS_IMAGE   "${CMAKE_CURRENT_BINARY_DIR}/os-image.bin")

# 1. Find all sources and headers recursively, skipping build folders
file(GLOB_RECURSE KERNEL_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.c")
file(GLOB_RECURSE KERNEL_HEADERS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.h")
list(FILTER KERNEL_SOURCES EXCLUDE REGEX "/cmake-build-[^/]*/|/CMakeFiles/")
list(FILTER KERNEL_HEADERS EXCLUDE REGEX "/cmake-build-[^/]*/|/CMakeFiles/")

# Indexing only: gives CLion a target so code analysis works.
# EXCLUDE_FROM_ALL means it is never built.
add_library(kernel_index OBJECT EXCLUDE_FROM_ALL ${KERNEL_SOURCES} ${KERNEL_HEADERS})
target_include_directories(kernel_index PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_options(kernel_index PRIVATE -ffreestanding -m64 -nostdlib
        -mno-red-zone -mno-mmx -mno-sse -fno-pic -fno-pie -fno-stack-protector)

# Compile each .c file. Object name comes from the relative path,
# e.g. headers/vga/vga.c -> headers_vga_vga_c.o
set(KERNEL_OBJS "")
foreach(src ${KERNEL_SOURCES})
    file(RELATIVE_PATH rel ${CMAKE_CURRENT_SOURCE_DIR} ${src})
    string(REGEX REPLACE "[/\\\\.]" "_" objname ${rel})
    set(obj "${CMAKE_CURRENT_BINARY_DIR}/${objname}.o")
    add_custom_command(
            OUTPUT ${obj}
            COMMAND ${GCC_EXE} -O2 -ffreestanding -m64 -nostdlib -mno-red-zone -mno-mmx -mno-sse
            -fno-pic -fno-pie -fno-exceptions -fno-asynchronous-unwind-tables
            -fno-unwind-tables -fno-stack-protector
            -I${CMAKE_CURRENT_SOURCE_DIR}
            -MMD -MF ${obj}.d
            -c ${src} -o ${obj}
            DEPENDS ${src}
            DEPFILE ${obj}.d
            COMMENT "Compiling ${rel}..."
            VERBATIM
    )
    list(APPEND KERNEL_OBJS ${obj})
endforeach()

# 2. Link all objects
add_custom_command(
        OUTPUT ${KERNEL_PE}
        COMMAND ${LD_EXE} -nostdlib -T ${CMAKE_CURRENT_SOURCE_DIR}/linker.ld
        --image-base 0 --file-alignment 512 --section-alignment 512
        --disable-reloc-section -Map ${KERNEL_MAP}
        ${KERNEL_OBJS} -o ${KERNEL_PE}
        DEPENDS ${KERNEL_OBJS} ${CMAKE_CURRENT_SOURCE_DIR}/linker.ld
        COMMENT "Linking kernel..."
        VERBATIM
)

# 3. Flatten: section contents only, starting at 0x10000 (no PE headers)
add_custom_command(
        OUTPUT ${KERNEL_BIN}
        COMMAND ${OBJCOPY_EXE} -O binary ${KERNEL_PE} ${KERNEL_BIN}
        DEPENDS ${KERNEL_PE}
        COMMENT "Extracting flat kernel binary..."
        VERBATIM
)

# 4. Bootloader incbin's kernel.bin and works out the sector count itself
add_custom_command(
        OUTPUT ${OS_IMAGE}
        COMMAND ${NASM_EXE} -f bin -I${CMAKE_CURRENT_BINARY_DIR}/
        ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm -o ${OS_IMAGE}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm ${KERNEL_BIN}
        COMMENT "Assembling bootloader + kernel into os-image.bin..."
        VERBATIM
)

add_custom_target(BuildOS ALL DEPENDS ${OS_IMAGE})

# Normal run: no logging
add_custom_target(RunOS
        COMMAND "${QEMU_EXE}" -drive format=raw,file=${OS_IMAGE}
        DEPENDS BuildOS
        COMMENT "Launching QEMU..."
        USES_TERMINAL
        VERBATIM
)

# Debug run: stops on triple fault and logs interrupts/resets to qemu.log
add_custom_target(RunOSDebug
        COMMAND "${QEMU_EXE}" -drive format=raw,file=${OS_IMAGE}
        -no-reboot -d int,cpu_reset -D ${CMAKE_CURRENT_BINARY_DIR}/qemu.log
        DEPENDS BuildOS
        COMMENT "Launching QEMU (debug)..."
        USES_TERMINAL
        VERBATIM
)