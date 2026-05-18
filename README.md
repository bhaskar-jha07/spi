# SPI (Verilog)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Description:** 8-bit Serial Peripheral Interface in Verilog for Altera/Intel FPGAs (Cyclone II / DE2), with a single top-level module that supports **master** or **slave** mode. Includes Quartus project files, DE2 pin assignments, and documentation for building and testing on hardware.

8-bit SPI master/slave RTL with selectable `MODE`, Quartus II project files, and DE2 pin constraints for `EP2C35F672C8`.

## Overview

The `assignment` module shifts one byte over SPI. In master mode it generates `sclk`, `cs`, and `mosi`; in slave mode it follows an external bus and drives `miso`. Parallel data is presented on `data_in` / `data_out`, with a `done` flag when a transfer completes.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MODE` | `"MASTER"` | `"MASTER"` or `"SLAVE"` — only one generate block is synthesized |
| `CLK_DIV_VAL` | `4` with `+define+SIMULATION`, else `50_000_000` | **Master only:** system clock cycles per SCLK half-period |

## Target hardware

| Item | Value |
|------|--------|
| FPGA family | Cyclone II |
| Device | `EP2C35F672C8` |
| Board | Altera DE2 (pin assignments in `assignment.qsf`) |
| Tools | Quartus II 13.0 SP1 |

## Repository files

| File | Purpose |
|------|---------|
| `assignment.v` | RTL top module |
| `assignment.qsf` | Device settings, source file list, pin locations |
| `assignment.qpf` | Quartus project file |
| `tb_assignment.v` | ModelSim testbench (master ↔ slave loopback) |
| `simulation/modelsim/assignment_run_msim_rtl_verilog.do` | ModelSim compile/run script |

## Simulation

From the repo root (or from `simulation/modelsim/` in ModelSim):

```tcl
cd simulation/modelsim
do assignment_run_msim_rtl_verilog.do
```

The testbench instantiates master and slave `assignment` modules on a shared SPI bus and runs self-checking byte transfers (including MSB-first patterns). Waveforms are written to `simulation/modelsim/tb_assignment.vcd`. The ModelSim script compiles RTL with `+define+SIMULATION` for a fast clock divider.

## Build

1. Open **Quartus II** and load `assignment.qpf`.
2. Run **Processing → Start Compilation**.
3. Program the device from `output_files/` (generated after compile).

Simulation is configured for **ModelSim-Altera (Verilog)** in the project settings.

## Interface

### Common

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk` | Input | System clock |
| `rst` | Input | Active-low reset |
| `start` | Input | Master: active-low starts a transfer |
| `data_in[7:0]` | Input | Byte to transmit (master) / preload (slave) |
| `data_out[7:0]` | Output | Received byte |
| `done` | Output | High when the current transfer finished |

### Master (`MODE = "MASTER"`)

| Signal | Direction | Description |
|--------|-----------|-------------|
| `sclk_out` | Output | SPI clock |
| `cs_out` | Output | Chip select (active low during transfer) |
| `mosi_out` | Output | Master out |
| `miso` | Input | Master in |

### Slave (`MODE = "SLAVE"`)

| Signal | Direction | Description |
|--------|-----------|-------------|
| `sclk_in` | Input | SPI clock from master |
| `cs_in` | Input | Chip select |
| `mosi_in` | Input | Data from master |
| `miso_out` | Output | Data to master |

To build a slave image, set `MODE` to `"SLAVE"` in `assignment.v` (or override the parameter in a wrapper) before compilation.
## Simulation Results

The waveform below demonstrates successful SPI communication between the master and slave modules.

- SPI Mode: 0
- 8-bit data transfer
- Correct MOSI/MISO operation
- Active-low chip select behavior

![SPI Waveform]("D:\New folder (2)\image\spi_waveform.png.png")

## Usage notes

- **Master start:** Assert `start` low in `IDLE` to begin an 8-bit transfer.
- **Clock divider (master):** Each SCLK half-period lasts `CLK_DIV_VAL` cycles of `clk`. Approximate SCLK frequency: \(f_{\mathrm{sclk}} \approx f_{\mathrm{clk}} / (2 \times \texttt{CLK\_DIV\_VAL})\). The source file defaults to `4` for simulation; set `50_000_000` before FPGA synthesis on the DE2.
- **SPI mode:** Mode 0 (CPOL=0, CPHA=0), MSB first, active-low CS. MSB is driven when CS asserts; bits are sampled on SCLK rising edges and updated on falling edges.
- **Slave:** Loads `data_in` when `cs_in` is high; shifts on `sclk_in` edges while `cs_in` is low.

## Pin assignments (DE2)

Key SPI and control pins are defined in `assignment.qsf`, including `clk` (PIN_N2), `rst` (PIN_V2), `start` (PIN_N23), switch inputs `data_in[7:0]`, LED outputs `data_out[7:0]`, and GPIO for `sclk`, `cs`, `mosi`, and `miso`.

## Community

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
Please report unacceptable behavior to **bhaskar050828@gmail.com**.

## License

This repository's Verilog and documentation are licensed under the [MIT License](LICENSE).

Quartus-generated headers in `assignment.qsf` and `assignment.qpf` remain subject to
Intel/Altera tool license terms when using Quartus II.
