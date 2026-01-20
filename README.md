# AXI-Like Out-of-Order Memory Slave - UVM Testbench

A complete UVM verification environment for an **Out-of-Order (OoO) Memory Slave** implementing AXI-like protocol semantics with per-ID ordering guarantees and variable latency transaction processing.

---

## Table of Contents

- [Overview](#overview)
- [Protocol Specification](#protocol-specification)
- [Design Architecture](#design-architecture)
- [UVM Testbench Architecture](#uvm-testbench-architecture)
- [File Structure](#file-structure)
- [Running the Simulation](#running-the-simulation)
- [Verification Strategy](#verification-strategy)

---

## Overview

This project implements a **256-byte memory slave** with separate Write and Read channels that supports:

- **Out-of-order completion** across different transaction IDs
- **In-order completion** within the same transaction ID
- **Variable latency** (0-16 cycles) per transaction
- **Per-ID queuing** (16 IDs, 8 deep queues)
- **Backpressure** via ready/valid handshaking
- **Concurrent Read/Write** operations

---

## Protocol Specification

### Ordering Rules

The design enforces **AXI-like ordering semantics**:

1. **Intra-ID Ordering (Strict)**: All transactions with the **same ID** complete in request order
2. **Inter-ID Ordering (Relaxed)**: Transactions with **different IDs** may complete out-of-order
3. **Channel Independence**: Write and Read channels operate independently (no cross-channel ordering)

### Signal Interface

```
┌─────────────────────────────────────────────────────────────┐
│                    AXI-Like Memory Slave                    │
├─────────────────────────────────────────────────────────────┤
│  WRITE CHANNEL (Master → Slave)                             │
│    • wr_valid    : Write request valid                      │
│    • wr_data[7:0]: Write data                               │
│    • wr_addr[7:0]: Write address                            │
│    • awid[3:0]   : Write transaction ID                     │
│    • wr_rdy      : Write ready (backpressure)               │
│                                                             │
│  WRITE RESPONSE (Slave → Master)                            │
│    • wr_resp_valid : Write response valid                   │
│    • wr_resp_id[3:0]: Completed write ID                    │
│    • wr_resp[1:0]  : Response status (00=OK, 01=ERR)        │
│                                                             │
│  READ CHANNEL (Master → Slave)                              │
│    • rd_valid    : Read request valid                       │
│    • rd_addr[7:0]: Read address                             │
│    • arid[3:0]   : Read transaction ID                      │
│    • rd_rdy      : Read ready (backpressure)                │
│                                                             │
│  READ RESPONSE (Slave → Master)                             │
│    • rd_resp_valid : Read response valid                    │
│    • rd_resp_id[3:0]: Completed read ID                     │
│    • rd_resp[1:0]  : Response status                        │
│    • rd_data[7:0]  : Read data                              │
└─────────────────────────────────────────────────────────────┘
```

### Out-of-Order Execution Example

```
Time:  T0    T1    T2    T3    T4    T5    T6    T7    T8
       │     │     │     │     │     │     │     │     │
Req:   WR_A  WR_B  WR_C  RD_D  ─     ─     ─     ─     ─
       ID=1  ID=2  ID=1  ID=3

       ┌─────────────────────────────────────────────────┐
       │         Per-ID Queues (Internal)                │
       ├─────────────────────────────────────────────────┤
       │  ID=1: [WR_A(delay=5)] → [WR_C(delay=2)]        │
       │  ID=2: [WR_B(delay=1)]                          │
       │  ID=3: [RD_D(delay=3)]                          │
       └─────────────────────────────────────────────────┘

Resp:  ─     ─     ─     WR_B  ─     WR_C  RD_D  ─     WR_A
                         ID=2        ID=1  ID=3        ID=1

       ┌─────────────────────────────────────────────────┐
       │  Observation:                                   │
       │  • WR_B (ID=2) completes BEFORE WR_A (ID=1)     │
       │    → Inter-ID out-of-order ✓                    │
       │  • WR_C (ID=1) completes AFTER WR_A (ID=1)      │
       │    → Intra-ID in-order ✓                        │
       └─────────────────────────────────────────────────┘
```

---

## Design Architecture

### RTL Block Diagram

```
                    ┌──────────────────────────────────────────┐
    wr_valid ───────┤                                          │
    wr_data[7:0] ───┤         Request Acceptance               │
    wr_addr[7:0] ───┤         (Handshake Logic)                │
    awid[3:0] ──────┤                                          │
                    └────────────┬─────────────────────────────┘
                                 │
                                 ▼
                    ┌──────────────────────────────────────────┐
                    │      Per-ID Queuing Structure            │
                    │  ┌────────┐  ┌────────┐      ┌────────┐  │
                    │  │ ID=0   │  │ ID=1   │ ...  │ ID=15  │  │
                    │  │ WR[$:8]│  │ WR[$:8]│      │ WR[$:8]│  │
                    │  │ RD[$:8]│  │ RD[$:8]│      │ RD[$:8]│  │
                    │  └────────┘  └────────┘      └────────┘  │
                    │                                          │
                    │  Each entry contains:                    │
                    │    • addr[7:0]                           │
                    │    • data[7:0] (write only)              │
                    │    • delay[4:0] (random 0-16)            │
                    │    • valid                               │
                    └────────────┬─────────────────────────────┘
                                 │
                                 ▼
                    ┌──────────────────────────────────────────┐
                    │    Delay Countdown & Arbitration         │
                    │  • Decrement all delays each cycle       │
                    │  • Find first entry with delay==0        │
                    │  • Process ONE write + ONE read/cycle    │
                    └────────────┬─────────────────────────────┘
                                 │
                                 ▼
                    ┌──────────────────────────────────────────┐
                    │         Memory Array (256 x 8)           │
                    │      logic [7:0] mem [0:255]             │
                    └────────────┬─────────────────────────────┘
                                 │
                                 ▼
                    ┌──────────────────────────────────────────┐
    wr_resp_valid ──┤                                          │
    wr_resp_id ─────┤      Response Generation                 │
    wr_resp[1:0] ───┤      (OKAY/ERROR status)                 │
    rd_resp_valid ──┤                                          │
    rd_resp_id ─────┤                                          │
    rd_data[7:0] ───┤                                          │
                    └──────────────────────────────────────────┘
```

### Key Design Features

- **Random Latency Injection**: Each transaction gets `$urandom_range(0,16)` delay
- **Single Completion/Cycle**: Maximum 1 write + 1 read completion per clock
- **FIFO Per ID**: Maintains ordering within each ID stream
- **Backpressure**: Asserts `wr_rdy=0` or `rd_rdy=0` when any queue reaches depth 8

---

## UVM Testbench Architecture

### Component Hierarchy

```
                    ┌─────────────────────────────────────────┐
                    │          uvm_test (test.sv)             │
                    │  • Configures environment               │
                    │  • Selects sequence                     │
                    │  • Controls test phases                 │
                    └──────────────┬──────────────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────────────┐
                    │           uvm_env (env.sv)              │
                    │  • Instantiates agent                   │
                    │  • Instantiates scoreboard              │
                    │  • Connects analysis ports              │
                    └──────┬──────────────────┬───────────────┘
                           │                  │
              ┌────────────▼──────┐    ┌──────▼──────────────┐
              │   uvm_agent       │    │   uvm_scoreboard    │
              │   (agent.sv)      │    │   (scoreboard.sv)   │
              │                   │    │                     │
              │  ┌─────────────┐  │    │  • Reference model  │
              │  │  Sequencer  │  │    │  • Per-ID queues    │
              │  │             │  │    │  • Data checking    │
              │  └──────┬──────┘  │    │  • Coverage         │
              │         │         │    └──────▲──────────────┘
              │  ┌──────▼──────┐  │           │
              │  │   Driver    │  │           │
              │  │ (driver.sv) │  │           │
              │  │             │  │           │
              │  │  FSM:       │  │           │
              │  │  IDLE→DELAY │  │           │
              │  │  →CMD→IDLE  │  │           │
              │  └──────┬──────┘  │           │
              │         │         │           │
              │  ┌──────▼──────┐  │           │
              │  │   Monitor   │──┼───────────┘
              │  │(monitor.sv) │  │  (analysis_port)
              │  │             │  │
              │  │ • Captures  │  │
              │  │   requests  │  │
              │  │ • Captures  │  │
              │  │   responses │  │
              │  └──────┬──────┘  │
              └─────────┼─────────┘
                        │
                        │ (virtual interface)
                        │
              ┌─────────▼─────────────────────────────────────┐
              │         DUT: axi_ooo (design.sv)              │
              │                                               │
              │  [See Design Architecture diagram above]      │
              └───────────────────────────────────────────────┘
```

### Component Descriptions

| Component           | File                          | Responsibility                                                       |
| ------------------- | ----------------------------- | -------------------------------------------------------------------- |
| **Transaction**     | `transaction.sv`              | Sequence item with randomizable fields (op, addr, data, ID, delay)   |
| **Sequence**        | `sequence.sv`                 | Base sequence class (`generator`) - creates 15 random transactions   |
| **Specialized Seq** | `wr_rd_sequence_random_id.sv` | Extended sequence with random ID generation                          |
| **Driver**          | `driver.sv`                   | 3-state FSM (IDLE→DELAY→CMD) drives DUT inputs via virtual interface |
| **Monitor**         | `monitor.sv`                  | Passive observer: captures requests & responses, sends to scoreboard |
| **Scoreboard**      | `scoreboard.sv`               | Golden reference model with per-ID queues, validates read data       |
| **Agent**           | `agent.sv`                    | Container for sequencer, driver, monitor                             |
| **Environment**     | `env.sv`                      | Top-level container, connects agent to scoreboard                    |
| **Test**            | `test.sv`                     | Test configuration, sequence selection, phase control                |
| **Testbench**       | `tb.sv`                       | DUT instantiation, clock generation, interface binding               |
| **Interface**       | `interface.sv`                | SystemVerilog interface for signal grouping                          |
| **Package**         | `ooo_pkg.sv`                  | Package for type definitions and imports                             |

---

## File Structure

```
.
├── README.md                          # This file
├── design.sv                          # RTL: Out-of-order memory slave
├── interface.sv                       # Virtual interface definition
├── ooo_pkg.sv                         # Package with type definitions
├── transaction.sv                     # UVM sequence item
├── sequence.sv                        # Base sequence (generator)
├── wr_rd_sequence_random_id.sv        # Randomized ID sequence
├── driver.sv                          # UVM driver with FSM
├── monitor.sv                         # UVM monitor (passive)
├── scoreboard.sv                      # Reference model + checker
├── agent.sv                           # UVM agent container
├── env.sv                             # UVM environment
├── test.sv                            # UVM test
├── tb.sv                              # Top-level testbench module
└── testbench.sv                       # Compilation wrapper
```

---

## Running the Simulation

### Option 1: EDA Playground (Recommended for Quick Start)

Click here to run immediately in your browser:  
🔗 **[Launch on EDA Playground](https://www.edaplayground.com/x/aajt)**

### Option 2: Local Simulation

#### Prerequisites

- SystemVerilog simulator (QuestaSim, VCS, Xcelium, or Verilator)
- UVM 1.2 library

#### QuestaSim/ModelSim

```bash
# Compile
vlog -sv \
  +incdir+$UVM_HOME/src \
  $UVM_HOME/src/uvm_pkg.sv \
  design.sv \
  ooo_pkg.sv \
  interface.sv \
  transaction.sv \
  sequence.sv \
  wr_rd_sequence_random_id.sv \
  driver.sv \
  monitor.sv \
  scoreboard.sv \
  agent.sv \
  env.sv \
  test.sv \
  tb.sv

# Simulate
vsim -c tb \
  +UVM_TESTNAME=test \
  +UVM_VERBOSITY=UVM_LOW \
  -do "run -all; quit"
```

#### VCS

```bash
vcs -sverilog \
  +incdir+$VCS_HOME/etc/uvm-1.2 \
  -ntb_opts uvm-1.2 \
  design.sv ooo_pkg.sv interface.sv \
  transaction.sv sequence.sv wr_rd_sequence_random_id.sv \
  driver.sv monitor.sv scoreboard.sv \
  agent.sv env.sv test.sv tb.sv

./simv +UVM_TESTNAME=test +UVM_VERBOSITY=UVM_LOW
```

#### Expected Output

```
UVM_INFO @ 0: reporter [RNTST] Running test test...
UVM_INFO driver.sv(28) @ 20: uvm_test_top.env.a.d [DRV] Asserting reset
UVM_INFO driver.sv(41) @ 100: uvm_test_top.env.a.d [DRV] Reset complete
UVM_INFO monitor.sv(29) @ 100: uvm_test_top.env.a.m [MON] Monitor Started....
UVM_INFO scoreboard.sv(51) @ 100: uvm_test_top.env.sb [SCO] Scoreboard Started....
...
UVM_INFO scoreboard.sv(131) @ 450: uvm_test_top.env.sb [SCO]   [PASS][RD_RESP] ID=3 Addr=0x42 - Data Match! Data=0xa5
...
UVM_INFO scoreboard.sv(181) @ 1200: uvm_test_top.env.sb [SCO]   [PASS] All transactions in mon_data tlm_fifo has been processed
--- UVM Report Summary ---
** Report counts by severity
UVM_INFO :   127
UVM_WARNING :     0
UVM_ERROR :       0
UVM_FATAL :       0
```

---

## Verification Strategy

### Scoreboard Checking

The scoreboard implements a **golden reference model** that:

1. **Mirrors DUT Queues**: Maintains per-ID queues matching the DUT structure
2. **Tracks Memory State**: Updates reference memory on write completions
3. **Validates Read Data**: Compares DUT read responses against reference memory
4. **Enforces Ordering**: Ensures FIFO order within each ID by using `pop_front()`
5. **Detects Leaks**: Checks for leftover transactions in `extract_phase`

### Coverage Goals

- All 16 IDs exercised
- Queue full conditions (backpressure)
- Simultaneous read/write requests
- Simultaneous read/write responses
- Variable delay distribution (0-16 cycles)
- Address range coverage (0x00-0xFF)

### Test Scenarios

| Scenario             | Description                                                           |
| -------------------- | --------------------------------------------------------------------- |
| **Random ID Test**   | `wr_rd_sequence_random_id` - exercises inter-ID out-of-order behavior |
| **Same ID Stress**   | Multiple transactions with same ID to verify intra-ID ordering        |
| **Backpressure**     | Fill queues to depth 8, verify `wr_rdy`/`rd_rdy` deassertion          |
| **Read-After-Write** | Verify data coherency with RAW hazards                                |

---

## Key Verification Insights

### What Makes This OoO?

Unlike a simple FIFO memory:

- Transactions **do not** complete in global arrival order
- Completion order depends on **random delay** assigned to each transaction
- Only **per-ID ordering** is guaranteed (like AXI)

### Scoreboard Architecture

The scoreboard uses **per-ID queues** (not a single global queue) to model the DUT:

```systemverilog
// Scoreboard maintains 16 separate queues (one per ID)
t_wr wr_pend_arr [0:15] [$];  // Write queues
t_rd rd_pend_arr [0:15] [$];  // Read queues

// On request: push to ID-specific queue
wr_pend_arr[tr.awid].push_back('{...});

// On response: pop from ID-specific queue (FIFO order)
wr_entry = wr_pend_arr[tr.wr_resp_id].pop_front();
```

This ensures the scoreboard **expects** the same ordering behavior as the DUT.

---

## Simulation Waveform Guide

Key signals to observe:

- `wr_valid` & `wr_rdy` - Write channel handshake
- `awid` - Watch for different IDs interleaving
- `wr_resp_id` - Compare response order vs request order
- `wr_arr[*].delay` - Internal delay counters (shows why reordering occurs)

---

## License

This is an educational/reference implementation. Feel free to use and modify.

---

## Contributing

Suggestions for improvement:

- Add functional coverage
- Implement constrained-random address aliasing tests
- Add performance counters (throughput, latency histograms)
- Extend to 32-bit data/address widths

---

**Author**: Aritra Manna  
**EDA Playground**: https://www.edaplayground.com/x/aajt
