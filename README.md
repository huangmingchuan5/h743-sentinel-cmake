# H743 Sentinel · FreeRTOS 环境与姿态监测记录仪（CMake 版）

基于 STM32H743XIH6 的多任务环境与姿态监测记录仪：I2C 传感器采样、LED/蜂鸣器告警、32 B 定长快照日志写入 QSPI Flash、串口控制台与独立健康监控（IWDG）。

本仓库是 Keil 版 [`h743-sentinel`](https://github.com/huangmingchuan5/h743-sentinel) 的 **CMake + GCC 移植版**：应用逻辑、任务划分与外设配置保持一致，构建链从 Keil AC5 换成 `arm-none-eabi-gcc + CMake + Ninja + OpenOCD`。

---

## 亮点

- **8 个业务任务**按截止时间分级（7 → 2），全部阻塞在队列/通知/延时上，没有忙等。
- **32 B 定长快照日志**：双队列收集 → 批量写 W25Q256 → 检查点提交，按扇区回绕，支持掉电恢复。
- **共享总线保护**：I2C4（EEPROM + 两颗传感器）、QSPI Flash、USART1 TX 各一把互斥量，避免多任务交错。
- **健康监控独立最高优先级**：`HLTH` 以 1 s 周期汇总各任务报活并喂 IWDG；日志写失败必须退避，防止低优先级任务被饿死。
- **串口控制台**：颜色/亮度、传感器实时值、日志导出、I2C 扫描、RTC 时间、报警与看门狗测试等 18 条命令。
- **GCC 移植细节**：FreeRTOS V9 的 `GCC/ARM_CM4F` 端口、newlib `_write → __io_putchar` 重定向、stdout 无缓冲。
- **构建结果**：`0 warning / 0 error`，FLASH 103 KB / 2 MB（4.9%），DTCM 55.5 KB / 128 KB（含 48 KB FreeRTOS heap）。

## 硬件

| 项目 | 配置 |
|---|---|
| MCU | STM32H743XIH6，Cortex-M7 @ 480 MHz，2 MB Flash / 1 MB RAM |
| 开发板 | 野火 STM32H743 Pro |
| 调试器 | DAPLink（CMSIS-DAP）或 ST-Link，SWD |
| 串口 | USART1，PA9/PA10，115200 8-N-1 |
| 三色 LED | 红 PB0（TIM3_CH3）、绿 PB1（TIM3_CH4）、蓝 PA3（TIM2_CH4），低电平点亮 |
| 按键 | KEY1 PA0、KEY2 PC13，EXTI 双边沿 |
| 蜂鸣器 | PI8，有源，高电平响 |
| EEPROM | AT24C02，I2C4（PB8/PB9），保存颜色/亮度/报警配置 |
| 传感器 | AP3216C（环境光/接近）、MPU6050（加速度/陀螺），共用 I2C4 |
| 外部 Flash | W25Q256，32 MB，QSPI：PB2 CLK、PG6 NCS、PF6–PF9 IO0–IO3 |
| 时基 | TIM7 作为 HAL 时基（1 ms），SysTick 专供 FreeRTOS |
| 看门狗 | IWDG，由 `HLTH` 任务按健康判据喂狗 |

## 任务与优先级

| 任务 | 优先级 | 栈（Byte） | 唤醒方式 | 职责 |
|---|---:|---:|---|---|
| `HLTH` | 7 | 1024 | 1 s 延时 | 汇总报活判据，喂 IWDG |
| `ENV` | 6 | 640 | 100 ms 周期 | 读 AP3216C，光照/接近判定 |
| `MOT` | 5 | 640 | 50 ms 周期 | 读 MPU6050，运动判定，32 B 快照入队 |
| `UI` | 4 | 1536 | 事件组 50 ms + 任务通知 | 灯效、蜂鸣器、按键消抖 |
| `CON` | 3 | 2048 | 任务通知（1 s 保活） | 行编辑、命令解析、打印 |
| `LOG` | 2 | 2048 | 任务通知（2 s 冲刷） | 双队列收集 → 写 Flash → 检查点 |
| `LED` | 2 | 512 | 500 ms 周期 | 心跳灯 |
| `MON` | 2 | 1024 | 3 s 延时 | tick/heap/任务栈水位统计 |
| `IDLE` / `Tmr Svc` | 0 / 2 | 512 / 1024 | 内核 | 空闲任务 / 软件定时器（30 s 自动静音） |

优先级按“截止时间”排而非“重要性”：采样最不能晚，`HLTH` 必须能抢占所有业务任务，否则日志任务卡住时只会表现为 IWDG 反复复位，掩盖真实故障。

## 数据流

```
AP3216C ─┐
         ├─ I2C4（互斥量）─ ENV / MOT ── 32B 快照 ── logQueue ─┐
MPU6050 ─┘                         └── 报警事件 ── evtQueue ──┤
                                                             ├─ LOG ── QSPI W25Q256
USART1 RX ── 环形缓冲 ── CON ── 命令 ── 配置/查询/导出 ───────┘
KEY1/KEY2 ── EXTI ── UI ── LED PWM / 蜂鸣器
HLTH ── 各任务报活时间戳 ── IWDG
```

## 目录结构

```
App/                 应用层
  Config/            配置结构（EEPROM 持久化）
  console/           命令行解析与打印
  log/               32 B 快照、环形日志、掉电恢复
  sample/            采样任务（ENV / MOT）
  system/            报警、事件组、UI、健康监控、FreeRTOS 钩子
BSP/                 板级驱动
  LED/ ee/ flash/ i2c/ pwm/ rtc/ sensor/ uart/
Core/                CubeMX 生成的外设初始化与中断（USER CODE 区为原创）
FreeRTOS/            V9.0.0 内核 + GCC/ARM_CM4F 端口 + heap_4
User/                FreeRTOSConfig.h
docs/                任务设计、日志格式、验收清单、代码阅读路线
cmake/               工具链与 CubeMX 生成规则
```

## 快速开始

### 依赖

- `arm-none-eabi-gcc` 15.3（验证版本 15.3.1）
- CMake ≥ 3.22（验证版本 4.4.5）
- Ninja 1.13
- OpenOCD 0.12（烧录）
- VS Code + clangd + Cortex-Debug（可选）

确保以上工具在 `PATH` 中。`run.sh` 对作者本机保留了 `D:/Embedded_Toolchain` 回退路径，可用环境变量覆盖：

```bash
export TOOLCHAIN_ROOT=/your/toolchain/root
```

### 编译与烧录

```bash
./run.sh          # 全新构建，生成 build/*.elf / *.bin / *.hex
./run.sh flash    # 构建后调用 OpenOCD 烧录
```

成功标志：末尾打印 `Memory region ... FLASH` 占用表，且无 `error:`。

### VS Code

- `clangd` 读取 `build/compile_commands.json`，代码补全与跳转与编译一致。
- `Cortex-Debug` 提供两个配置：DAPLink 与 ST-Link。
- `.vscode/settings.json`、`launch.json` 中的工具链路径是作者本机路径，换机器时改成自己的。

## 控制台命令

连接 USART1（115200 8-N-1），输入 `help` 查看：

```
help  color  pwm  save  load  info  dump  erase  i2c  sensor
live  time   alarm cfg   status wd     logpause
```

常用：

```text
> status           # 任务报活、堆余量、日志计数
> sensor           # AP3216C / MPU6050 实时值
> live 5           # 连续打印 5 行实时快照（约 100 ms 一行）
> dump 16          # 导出最近 16 条日志
> wd test          # 停止喂狗，验证 IWDG 复位（谨慎）
```

## 设计取舍

- **不用队列集**：V9 支持 Queue Set，但“任务通知 + 双队列”更容易看出是谁唤醒了 Logger，也少一层注册。
- **日志失败退避 200 ms**：QSPI 持续报错时若立即重试，prio 2 的 Logger 会反复占满 CPU，让 CON/LOG/MON 等任务得不到心跳；prio 7 的 HealthTask 虽能抢占，但会据此停喂 IWDG。退避给低优先级任务留出运行时间，也避免对故障 Flash 高频擦写。
- **QSPI 默认 60 MHz**：120 MHz 下能读 ID，但擦/写不稳定；`quadspi.c` 的 `ClockPrescaler=3` 是实测折中。
- **HAL 时基用 TIM7**：SysTick 归 FreeRTOS，HAL 的 `HAL_Delay`/超时仍能工作。
- **FreeRTOS 端口换 GCC 版**：V9 的 RVDS 端口是 armcc 语法，不能直接用 GCC 编译。

## 已知限制

- **本 CMake 版尚未上板验收**：编译、链接、符号与中断向量已检查，下载/断电/晃动/遮光需按 [`docs/04-验收清单.md`](docs/04-验收清单.md) 在板子上回填。
- QSPI 在 120 MHz 下不稳定，默认 60 MHz。
- 未使用 DMA；传感器采样率较低，CPU 轮询/中断足够。
- 日志环形区是追加写 + 扇区擦除，未做磨损均衡。
- 传感器未做温度补偿与零偏校准。

## 文档

- [`docs/02-任务与优先级设计.md`](docs/02-任务与优先级设计.md)
- [`docs/03-日志格式与掉电安全.md`](docs/03-日志格式与掉电安全.md)
- [`docs/04-验收清单.md`](docs/04-验收清单.md)
- [`docs/05-代码阅读路线.md`](docs/05-代码阅读路线.md)

## 许可证

本仓库原创部分（`App/`、`BSP/`、`User/FreeRTOSConfig.h`、项目级 CMake、脚本与文档）采用 **MIT**，见 [LICENSE](LICENSE)。

第三方组件不适用 MIT：

- `FreeRTOS/`：FreeRTOS Kernel **V9.0.0**，**GPL-2.0 WITH FreeRTOS-exception**（V10 起才是 MIT）
- `Drivers/`：STM32H7 HAL **BSD-3-Clause**，CMSIS **Apache-2.0**
- `startup_stm32h743xx.s`、`STM32H743XX_FLASH.ld`、CubeMX 生成的 `Core/`：**BSD-3-Clause**

第三方组件清单见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)；GPLv2、BSD-3-Clause、Apache-2.0 的**全文**在 [`LICENSES/`](LICENSES/)。其中 `LICENSES/FreeRTOS-exception.txt` 是 FreeRTOS 源文件头部例外条款声明的逐字摘录与官方链接说明，**不是一份独立的例外条款全文**，权威表述以内核源码头部及 FreeRTOS 官方页面为准。
