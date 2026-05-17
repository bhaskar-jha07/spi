# SPI (Verilog)

8-bit Serial Peripheral Interface for Altera/Intel FPGAs, with selectable **master** or **slave** behavior in a single top-level module.

## Overview

The `assignment` module shifts one byte over SPI. In master mode it generates `sclk`, `cs`, and `mosi`; in slave mode it follows an external bus and drives `miso`. Parallel data is presented on `data_in` / `data_out`, with a `done` flag when a transfer completes.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MODE` | `"MASTER"` | `"MASTER"` or `"SLAVE"` — only one generate block is synthesized |

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

## Usage notes

- **Master start:** Assert `start` low in `IDLE` to begin an 8-bit transfer.
- **Clock divider:** Master SCLK is derived from `clk` with `clk_div == 50_000_000` (intended for a ~50 MHz system clock; adjust for your board).
- **Slave:** Loads `data_in` when `cs_in` is high; shifts on `sclk_in` edges while `cs_in` is low.

## Pin assignments (DE2)

Key SPI and control pins are defined in `assignment.qsf`, including `clk` (PIN_N2), `rst` (PIN_V2), `start` (PIN_N23), switch inputs `data_in[7:0]`, LED outputs `data_out[7:0]`, and GPIO for `sclk`, `cs`, `mosi`, and `miso`.

## License

See repository license terms for Quartus-generated project headers in `.qsf` / `.qpf`.
