# 第三方组件声明 / Third-Party Notices

根目录 `LICENSE`（MIT）**仅覆盖本仓库的原创部分**：`App/`、`BSP/`、`User/FreeRTOSConfig.h`、项目级 CMake 逻辑、脚本、OpenOCD 配置与文档。

下列组件版权归各自作者所有，**不适用**根目录 MIT，按各自许可证分发。

| 组件 | 仓库内位置 | 版权方 | 许可证 | 依据文件 |
|---|---|---|---|---|
| FreeRTOS Kernel V9.0.0 | `FreeRTOS/` | Real Time Engineers Ltd. | **GPL-2.0 WITH FreeRTOS-exception** | `LICENSES/GPL-2.0.txt`、`LICENSES/FreeRTOS-exception.txt` |
| STM32H7 HAL 驱动 | `Drivers/STM32H7xx_HAL_Driver/` | STMicroelectronics | **BSD-3-Clause** | `Drivers/STM32H7xx_HAL_Driver/LICENSE.txt` |
| CMSIS Core / Device | `Drivers/CMSIS/` | Arm Limited | **Apache-2.0** | `Drivers/CMSIS/LICENSE.txt` |
| CubeMX 生成代码 | `Core/Inc/`、`Core/Src/`（USER CODE 区除外） | STMicroelectronics | **BSD-3-Clause** | 文件头版权声明 |
| 启动文件 / 链接脚本 | `startup_stm32h743xx.s`、`STM32H743XX_FLASH.ld` | STMicroelectronics | **BSD-3-Clause** | 文件头版权声明 |

---

## 1. FreeRTOS Kernel V9.0.0

| 项 | 内容 |
|---|---|
| 位置 | `FreeRTOS/src/`、`FreeRTOS/include/`、`FreeRTOS/port/` |
| 版权 | Copyright (C) 2016 Real Time Engineers Ltd. / FreeRTOS.org |
| 许可 | **GNU GPL v2.0 + FreeRTOS exception**（`GPL-2.0 WITH FreeRTOS-exception`） |
| 全文 | `LICENSES/GPL-2.0.txt`、`LICENSES/FreeRTOS-exception.txt` |
| 来源 | <https://www.freertos.org/> |

> **V9.0.0 不是 MIT**：FreeRTOS 自 V10.0.0 起才改为 MIT。
> 例外条款允许把内核与其他许可的组件组合分发，不要求这些组件整体开源；
> 但内核源码本身仍受 GPLv2 约束，修改后再分发需按 GPLv2 提供对应源码。

## 2. STM32H7 HAL Driver / CMSIS

| 项 | 内容 |
|---|---|
| HAL 位置 | `Drivers/STM32H7xx_HAL_Driver/` |
| CMSIS 位置 | `Drivers/CMSIS/` |
| 许可 | HAL：BSD-3-Clause；CMSIS：Apache-2.0 |
| 全文 | `LICENSES/BSD-3-Clause.txt`、`LICENSES/Apache-2.0.txt` |
| 说明 | 仓库完整保留 HAL/CMSIS 源码，未做裁剪；`Drivers/` 下的 `LICENSE.txt` 为最终依据 |

`Drivers/STM32H7xx_HAL_Driver/LICENSE.txt` 明确写道：

> If you received this software component outside of a package or without
> applicable license terms, the terms of the BSD-3-Clause license shall apply.

因此本仓库（独立分发、非完整 STM32Cube 包）按 BSD-3-Clause 处理 HAL 驱动。

## 3. STM32CubeMX 生成代码

- `Core/Inc/`、`Core/Src/` 中 `USER CODE BEGIN/END` 之外的部分由 CubeMX 生成，版权归 STMicroelectronics，按 BSD-3-Clause 分发。
- `cmake/stm32cubemx/CMakeLists.txt` 同为 CubeMX 生成文件，请勿手改；本项目额外的 Core 源文件在根 `CMakeLists.txt` 中补充。
- `USER CODE` 区内的原创代码按根目录 MIT 分发。

## 4. 传感器驱动

`BSP/sensor/bsp_ap3216c.*`、`BSP/sensor/bsp_mpu6050.*` 为本项目自行编写：

- 寄存器地址、位定义、上电时序取自 AP3216C / MPU-6050 公开数据手册（事实性信息）；
- 开发过程中参考了野火（WildFire）教学例程的寄存器操作思路；
- 代码结构、函数命名、错误码与 `bsp_i2c_bus` 总线加锁逻辑为原创，未原样复制第三方源文件。

野火的教学例程、数据手册 PDF、原理图与板卡图片**未包含**在本仓库中。

## 5. 工具链

- 构建使用 `arm-none-eabi-gcc`、CMake、Ninja、OpenOCD，均不随仓库分发。
- 仓库不包含 Keil MDK 工程、ARM Compiler、Device Family Pack 或 STM32CubeMX 安装包。

## 6. 合规提示

再分发本仓库或其中包含的第三方组件时：

1. 保留各目录下的 `LICENSE.txt` 与源文件中的版权声明，不要删除或修改；
2. 在衍生产品文档中保留本声明；
3. Apache-2.0 组件（CMSIS）如被修改，需在文件中标注修改说明；
4. FreeRTOS 内核若被修改并再分发，需按 GPLv2 提供对应源码；
5. 不得暗示 STMicroelectronics、Arm 或 Real Time Engineers Ltd. 对本项目提供背书。

---

# Third-Party Notices (English)

This repository's original code (`App/`, `BSP/`, `User/FreeRTOSConfig.h`, project CMake logic, scripts, docs) is MIT-licensed. The following components remain under their own licenses:

- `FreeRTOS/` — FreeRTOS Kernel V9.0.0, **GPL-2.0 WITH FreeRTOS-exception** (not MIT; FreeRTOS switched to MIT only from V10.0.0)
- `Drivers/STM32H7xx_HAL_Driver/` — BSD-3-Clause, © STMicroelectronics
- `Drivers/CMSIS/` — Apache-2.0, © Arm Limited
- `startup_stm32h743xx.s`, `STM32H743XX_FLASH.ld`, CubeMX-generated `Core/` — BSD-3-Clause, © STMicroelectronics

Full license texts are in `LICENSES/`. Keep all copyright notices and license files when redistributing.
