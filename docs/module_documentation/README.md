# Phase 1 RTL Module Map

This page maps each synthesizable Phase 1 module to its source file. Detailed port behaviour remains authoritative in the SystemVerilog source and its paired testbench.

## CPU top

| Module | Purpose | Source |
|---|---|---|
| `riscv_cpu` | Integrates all five pipeline stages and exposes the external data bus and status signals | [`riscv_cpu.sv`](../../phase1_riscv_cpu/rtl/cpu_top/riscv_cpu.sv) |

## Instruction fetch

| Module | Purpose | Source |
|---|---|---|
| `program_counter` | Resettable, enabled PC register | [`program_counter.sv`](../../phase1_riscv_cpu/rtl/instruction_fetch/program_counter.sv) |
| `pc_plus4` | Computes the sequential instruction address | [`pc_plus4.sv`](../../phase1_riscv_cpu/rtl/instruction_fetch/pc_plus4.sv) |
| `instruction_memory` | Synchronous initialized instruction memory with validity/fault signalling | [`instruction_memory.sv`](../../phase1_riscv_cpu/rtl/instruction_fetch/instruction_memory.sv) |
| `instruction_fetch_stage` | Coordinates PC, redirect, stall, memory request and one-entry response buffering | [`instruction_fetch_stage.sv`](../../phase1_riscv_cpu/rtl/instruction_fetch/instruction_fetch_stage.sv) |

## Instruction decode

| Module | Purpose | Source |
|---|---|---|
| `instruction_decoder` | Splits a 32-bit instruction into opcode, register and function fields | [`instruction_decoder.sv`](../../phase1_riscv_cpu/rtl/instruction_decode/instruction_decoder.sv) |
| `register_file` | Architectural integer register storage with two reads and one write | [`register_file.sv`](../../phase1_riscv_cpu/rtl/instruction_decode/register_file.sv) |
| `immediate_generator` | Produces sign-extended RV32I immediates | [`immediate_generator.sv`](../../phase1_riscv_cpu/rtl/instruction_decode/immediate_generator.sv) |
| `control_unit` | Decodes instruction class into pipeline control signals | [`control_unit.sv`](../../phase1_riscv_cpu/rtl/instruction_decode/control_unit.sv) |
| `instruction_decode_stage` | Combines decode, register reads, control and the ID/EX interface | [`instruction_decode_stage.sv`](../../phase1_riscv_cpu/rtl/instruction_decode/instruction_decode_stage.sv) |

## Execute

| Module | Purpose | Source |
|---|---|---|
| `alu` | Arithmetic, logical, comparison and shift operations | [`alu.sv`](../../phase1_riscv_cpu/rtl/instruction_execute/alu.sv) |
| `alu_control` | Converts decoded operation class and function fields into an ALU command | [`alu_control.sv`](../../phase1_riscv_cpu/rtl/instruction_execute/alu_control.sv) |
| `operand_muxes` | Selects register, PC and immediate ALU operands | [`operand_muxes.sv`](../../phase1_riscv_cpu/rtl/instruction_execute/operand_muxes.sv) |
| `branch_jump_logic` | Evaluates branch conditions and forms redirect targets | [`branch_jump_logic.sv`](../../phase1_riscv_cpu/rtl/instruction_execute/branch_jump_logic.sv) |
| `instruction_execute_stage` | Integrates operand selection, ALU, branch/jump and EX/MEM outputs | [`instruction_execute_stage.sv`](../../phase1_riscv_cpu/rtl/instruction_execute/instruction_execute_stage.sv) |

## Memory

| Module | Purpose | Source |
|---|---|---|
| `data_memory` | Byte-enabled SoC data memory with bounds/access-fault checking | [`data_memory.sv`](../../phase1_riscv_cpu/rtl/memory_stage/data_memory.sv) |
| `load_store_control` | Formats stores, extracts/sign-extends loads and detects invalid/misaligned operations | [`load_store_control.sv`](../../phase1_riscv_cpu/rtl/memory_stage/load_store_control.sv) |
| `memory_stage` | Executes valid/ready bus requests with IDLE, WAIT and HOLD states | [`memory_stage.sv`](../../phase1_riscv_cpu/rtl/memory_stage/memory_stage.sv) |

## Write back

| Module | Purpose | Source |
|---|---|---|
| `write_back_mux` | Selects ALU, memory or PC+4 result | [`write_back_mux.sv`](../../phase1_riscv_cpu/rtl/writeback_stage/write_back_mux.sv) |
| `register_write_back_logic` | Qualifies architectural register writes and suppresses invalid writes | [`register_write_back_logic.sv`](../../phase1_riscv_cpu/rtl/writeback_stage/register_write_back_logic.sv) |
| `write_back_stage` | Integrates result selection, register write, retirement, exception and system/fence status | [`write_back_stage.sv`](../../phase1_riscv_cpu/rtl/writeback_stage/write_back_stage.sv) |

## Pipeline registers

| Module | Boundary | Source |
|---|---|---|
| `if_id_pipeline_register` | IF to ID | [`if_id_pipeline_register.sv`](../../phase1_riscv_cpu/rtl/pipeline_registers/if_id_pipeline_register.sv) |
| `id_ex_pipeline_register` | ID to EX | [`id_ex_pipeline_register.sv`](../../phase1_riscv_cpu/rtl/pipeline_registers/id_ex_pipeline_register.sv) |
| `ex_mem_pipeline_register` | EX to MEM | [`ex_mem_pipeline_register.sv`](../../phase1_riscv_cpu/rtl/pipeline_registers/ex_mem_pipeline_register.sv) |
| `mem_wb_pipeline_register` | MEM to WB | [`mem_wb_pipeline_register.sv`](../../phase1_riscv_cpu/rtl/pipeline_registers/mem_wb_pipeline_register.sv) |

## Hazard, forwarding and pipeline control

| Module | Purpose | Source |
|---|---|---|
| `hazard_detection_unit` | Detects decode dependencies on an execute-stage load | [`hazard_detection_unit.sv`](../../phase1_riscv_cpu/rtl/hazard_and_forwarding/hazard_detection_unit.sv) |
| `forwarding_unit` | Selects EX/MEM or MEM/WB forwarding sources for execute operands | [`forwarding_unit.sv`](../../phase1_riscv_cpu/rtl/hazard_and_forwarding/forwarding_unit.sv) |
| `stall_flush_control` | Generates stage enables and flushes from halt, memory, redirect and hazard conditions | [`stall_flush_control.sv`](../../phase1_riscv_cpu/rtl/hazard_and_forwarding/stall_flush_control.sv) |
| `pipeline_control` | Integrates hazard detection, forwarding and stall/flush decisions | [`pipeline_control.sv`](../../phase1_riscv_cpu/rtl/hazard_and_forwarding/pipeline_control.sv) |

## SoC

| Module | Purpose | Source |
|---|---|---|
| `address_decoder` | Routes memory-mapped requests to RAM or the accelerator window | [`address_decoder.sv`](../../phase1_riscv_cpu/rtl/soc/address_decoder.sv) |
| `system_bus` | Captures one master request and returns the selected slave response | [`system_bus.sv`](../../phase1_riscv_cpu/rtl/soc/system_bus.sv) |
| `accelerator_stub` | Phase 1 placeholder used to validate accelerator-window transactions | [`accelerator_stub.sv`](../../phase1_riscv_cpu/rtl/soc/accelerator_stub.sv) |
| `basic_soc_top` | Integrates CPU, bus, data memory and accelerator stub | [`basic_soc_top.sv`](../../phase1_riscv_cpu/rtl/soc/basic_soc_top.sv) |

## Testbench mapping

The testbench filenames mirror their modules. Examples:

- [`tb_instruction_fetch_stage.sv`](../../phase1_riscv_cpu/testbenches/unit/tb_instruction_fetch_stage.sv)
- [`tb_pipeline_control.sv`](../../phase1_riscv_cpu/testbenches/unit/tb_pipeline_control.sv)
- [`tb_riscv_cpu.sv`](../../phase1_riscv_cpu/testbenches/cpu/tb_riscv_cpu.sv)
- [`tb_rv32i_regression.sv`](../../phase1_riscv_cpu/testbenches/cpu/tb_rv32i_regression.sv)
- [`tb_basic_soc_top.sv`](../../phase1_riscv_cpu/testbenches/soc/tb_basic_soc_top.sv)
- [`tb_cpu_matrix_performance.sv`](../../phase1_riscv_cpu/testbenches/matrix_applications/tb_cpu_matrix_performance.sv)
- [`tb_cpu_grayscale_batch.sv`](../../phase1_riscv_cpu/testbenches/matrix_applications/tb_cpu_grayscale_batch.sv)

