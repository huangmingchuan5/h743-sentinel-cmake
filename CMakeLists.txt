cmake_minimum_required(VERSION 3.22)

#
# This file is generated only once,
# and is not re-generated if converter is called multiple times.
#
# User is free to modify the file as much as necessary
#

# Setup compiler settings
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)


# Define the build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()

# Set the project name
# ---------------------------------------------------------------------------
# 工程名自动取「当前目录名」，复制模板到新目录后无需修改任何文件：
#   Cmake_3_BASE_TIMER/  ->  CMAKE_PROJECT_NAME = Cmake_3_BASE_TIMER
#   产物同步为 build/Cmake_3_BASE_TIMER.elf，run.sh / flash 会自动跟随
# 如需固定名字，把下面两行换成 set(CMAKE_PROJECT_NAME 你的名字)
# ---------------------------------------------------------------------------
get_filename_component(_AUTO_PROJECT_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
set(CMAKE_PROJECT_NAME "${_AUTO_PROJECT_NAME}")

# Enable compile command to ease indexing with e.g. clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

# Core project settings
project(${CMAKE_PROJECT_NAME})
message("Build type: " ${CMAKE_BUILD_TYPE})

# Enable CMake support for ASM and C languages
enable_language(C ASM)

# FreeRTOS 内核配置头是整个工程的必需项；缺失时在这里直接给出明确提示，
# 否则编译到 FreeRTOS.h 第 98 行才报 "FreeRTOSConfig.h: No such file or directory"。
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/User/FreeRTOSConfig.h")
    message(FATAL_ERROR
        "缺少 User/FreeRTOSConfig.h（FreeRTOS 内核配置头）。\n"
        "可从 ../demo2_1/User/FreeRTOSConfig.h 复制回来，注意原文件是 GBK 编码。")
endif()

# Create an executable object type
add_executable(${CMAKE_PROJECT_NAME})

# Add STM32CubeMX generated sources
add_subdirectory(cmake/stm32cubemx)

# ============================================================
# 用户 BSP 代码：User/Inc 放头文件，User/Src 放 .c
#
# 用 GLOB_RECURSE + CONFIGURE_DEPENDS 自动收集源文件：
#   - User/Src 下新增 .c 后无需改本文件，cmake 会自动重新配置
#   - 会递归包含子目录（如 User/Src/led/led.c）
#
# 若不希望用 GLOB（CMake 官方更推荐显式列出），可改为：
#   target_sources(${CMAKE_PROJECT_NAME} PRIVATE
#       ${CMAKE_CURRENT_SOURCE_DIR}/User/Src/bsp_led.c
#   )
# ============================================================
file(GLOB_RECURSE USER_SOURCES CONFIGURE_DEPENDS
     ${CMAKE_CURRENT_SOURCE_DIR}/User/Src/*.c
)

# ============================================================
# demo2_1 应用层 / BSP / FreeRTOS 内核（从 MDK 工程移植）
#
# 目录分工：
#   App/        应用任务（日志、控制台、告警、健康检查、示例任务）
#   BSP/        板级驱动（LED、EEPROM、QSPI Flash、I2C、传感器、RTC、串口、PWM）
#   FreeRTOS/   V9.0.0 内核 + GCC/ARM_CM4F 端口 + heap_4
#   User/       FreeRTOSConfig.h
#
# 同样用 GLOB_RECURSE：新增 .c 不用改本文件。
# ============================================================
file(GLOB_RECURSE APP_SOURCES CONFIGURE_DEPENDS
     ${CMAKE_CURRENT_SOURCE_DIR}/App/*.c
)
file(GLOB_RECURSE BSP_SOURCES CONFIGURE_DEPENDS
     ${CMAKE_CURRENT_SOURCE_DIR}/BSP/*.c
)
file(GLOB_RECURSE FREERTOS_SOURCES CONFIGURE_DEPENDS
     ${CMAKE_CURRENT_SOURCE_DIR}/FreeRTOS/src/*.c
     ${CMAKE_CURRENT_SOURCE_DIR}/FreeRTOS/port/*.c
)

# ============================================================
# demo2_1 比模板多生成的 CubeMX 外设文件（gpio/i2c/quadspi/tim/usart/timebase）
#
# 不写进 cmake/stm32cubemx/CMakeLists.txt —— 那个文件每次 CubeMX GENERATE CODE
# 都会整体重写。这里从 Core/Src 全量收集，再排除已经加入 target 的文件
# （main/it/msp/syscalls/sysmem/startup），以及由 STM32_Drivers 单独编译的
# system_stm32h7xx.c，避免重复编译。
# ============================================================
file(GLOB _CORE_ALL CONFIGURE_DEPENDS
     ${CMAKE_CURRENT_SOURCE_DIR}/Core/Src/*.c
)
get_target_property(_CORE_TARGET_SOURCES ${CMAKE_PROJECT_NAME} SOURCES)
set(_CORE_TARGET_NORM "")
foreach(_f ${_CORE_TARGET_SOURCES})
  get_filename_component(_f_abs "${_f}" ABSOLUTE)
  list(APPEND _CORE_TARGET_NORM "${_f_abs}")
endforeach()

set(CORE_EXTRA_SOURCES "")
foreach(_f ${_CORE_ALL})
  get_filename_component(_f_abs "${_f}" ABSOLUTE)
  list(FIND _CORE_TARGET_NORM "${_f_abs}" _hit)
  if((_hit EQUAL -1) AND NOT (_f_abs MATCHES "/system_stm32h7xx\\.c$"))
    list(APPEND CORE_EXTRA_SOURCES "${_f_abs}")
  endif()
endforeach()

# Link directories setup
target_link_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined library search paths
)

# Add sources to executable
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user sources here
    ${USER_SOURCES}
    ${APP_SOURCES}
    ${BSP_SOURCES}
    ${FREERTOS_SOURCES}
    ${CORE_EXTRA_SOURCES}
)

# ============================================================
# HAL 驱动源文件
#
# 默认策略（推荐）：自动收录 Drivers/STM32H7xx_HAL_Driver/Src 下所有
#   stm32h7xx_hal_*.c，再和 CubeMX 生成的清单做差集，永远不会漏。
#   未在 stm32h7xx_hal_conf.h 中打开的模块，其 .c 编译出来是空文件，
#   既不占 Flash 也不增加运行时开销；未被调用的函数还会被 --gc-sections 丢掉。
#
# 想改回"手动只加需要的"：cmake -DHAL_AUTO_ALL_SOURCES=OFF ..
#   注意手动模式下每启用一个新外设，都要在这里补一行对应驱动，
#   否则链接会报 undefined reference to HAL_xxx_xxx。
# ============================================================
option(HAL_AUTO_ALL_SOURCES "自动编译 Drivers 下全部 HAL 驱动，避免漏加 .c" ON)

if(HAL_AUTO_ALL_SOURCES)

  file(GLOB _HAL_ALL_SOURCES CONFIGURE_DEPENDS
       ${CMAKE_CURRENT_SOURCE_DIR}/Drivers/STM32H7xx_HAL_Driver/Src/stm32h7xx_hal_*.c)

  # CubeMX 已经编译过的文件，必须排除，否则 OBJECT 库 + 主程序各编译一份 → multiple definition
  get_target_property(_HAL_CUBE_SOURCES STM32_Drivers SOURCES)
  if(NOT _HAL_CUBE_SOURCES)
    set(_HAL_CUBE_SOURCES "")
  endif()

  set(_HAL_CUBE_NORM "")
  foreach(_f ${_HAL_CUBE_SOURCES})
    get_filename_component(_f_abs "${_f}" ABSOLUTE)
    list(APPEND _HAL_CUBE_NORM "${_f_abs}")
  endforeach()

  set(_HAL_EXTRA_SOURCES "")
  foreach(_f ${_HAL_ALL_SOURCES})
    get_filename_component(_f_abs "${_f}" ABSOLUTE)

    # *_template.c 一律不要：msp_template 会和 Core/Src/stm32h7xx_hal_msp.c 冲突，
    # timebase_*_template 会和 core_delay.c 里的 HAL_InitTick 冲突
    if(_f_abs MATCHES "_template\\.c$")
      continue()
    endif()

    list(FIND _HAL_CUBE_NORM "${_f_abs}" _hit)
    if(_hit EQUAL -1)
      list(APPEND _HAL_EXTRA_SOURCES "${_f_abs}")
    endif()
  endforeach()

  if(_HAL_EXTRA_SOURCES)
    target_sources(${CMAKE_PROJECT_NAME} PRIVATE ${_HAL_EXTRA_SOURCES})
    list(LENGTH _HAL_EXTRA_SOURCES _n)
    message(STATUS "HAL: CubeMX 之外自动补充 ${_n} 个驱动源文件")
  endif()

else()

  target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    # CubeMX 未启用 UART / ADC 时，手动补对应 HAL 驱动（User 下的 BSP 用到了这些外设）
    # 若以后在 CubeMX 中启用对应外设，这些文件会被自动加入 cmake/stm32cubemx/CMakeLists.txt，本段可删除
    ${CMAKE_CURRENT_SOURCE_DIR}/Drivers/STM32H7xx_HAL_Driver/Src/stm32h7xx_hal_uart.c
    ${CMAKE_CURRENT_SOURCE_DIR}/Drivers/STM32H7xx_HAL_Driver/Src/stm32h7xx_hal_adc.c
    ${CMAKE_CURRENT_SOURCE_DIR}/Drivers/STM32H7xx_HAL_Driver/Src/stm32h7xx_hal_adc_ex.c
  )

endif()

# Add include paths
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined include paths
    ${CMAKE_CURRENT_SOURCE_DIR}/User/Inc
    ${CMAKE_CURRENT_SOURCE_DIR}/User

    # FreeRTOS：内核头文件 + 端口头文件（portmacro.h）
    ${CMAKE_CURRENT_SOURCE_DIR}/FreeRTOS/include
    ${CMAKE_CURRENT_SOURCE_DIR}/FreeRTOS/port

    # 应用层
    ${CMAKE_CURRENT_SOURCE_DIR}/App/Config
    ${CMAKE_CURRENT_SOURCE_DIR}/App/console
    ${CMAKE_CURRENT_SOURCE_DIR}/App/log
    ${CMAKE_CURRENT_SOURCE_DIR}/App/sample
    ${CMAKE_CURRENT_SOURCE_DIR}/App/system

    # 板级驱动
    ${CMAKE_CURRENT_SOURCE_DIR}/BSP/LED
    ${CMAKE_CURRENT_SOURCE_DIR}/BSP/ee
    ${CMAKE_CURRENT_SOURCE_DIR}/BSP/flash
    ${CMAKE_CURRENT_SOURCE_DIR}/BSP/i2c
    ${CMAKE_CURRENT_SOURCE_DIR}/BSP/pwm
    ${CMAKE_CURRENT_SOURCE_DIR}/BSP/rtc
    ${CMAKE_CURRENT_SOURCE_DIR}/BSP/sensor
    ${CMAKE_CURRENT_SOURCE_DIR}/BSP/uart
)

# Add project symbols (macros)
target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined symbols
)

# Remove wrong libob.a library dependency when using cpp files
list(REMOVE_ITEM CMAKE_C_IMPLICIT_LINK_LIBRARIES ob)

# Add linked libraries
target_link_libraries(${CMAKE_PROJECT_NAME}
    stm32cubemx

    # Add user defined libraries
)
