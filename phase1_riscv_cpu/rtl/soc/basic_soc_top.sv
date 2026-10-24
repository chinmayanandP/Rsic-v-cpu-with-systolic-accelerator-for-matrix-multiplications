`timescale 1ns/1ps

module basic_soc_top #(
    parameter integer INSTRUCTION_WORDS = 64,
    parameter logic [31:0] RESET_PC = 32'h0000_0000,
    parameter logic [31:0] INSTRUCTION_BASE = 32'h0000_0000,
    parameter INSTRUCTION_INIT_FILE = "soc_smoke_program.hex",

    parameter integer DATA_MEMORY_WORDS = 4096,
    parameter logic [31:0] DATA_MEMORY_BASE = 32'h0000_0000,
    parameter string DATA_MEMORY_INIT_FILE = ""
)(
    input logic clk,
    input logic reset,
    input logic external_halt,

    output logic halted_out,
    output logic pipeline_stalled_out,
    output logic pipeline_flushed_out,
    output logic instruction_retired_out,
    output logic exception_valid_out,
    output logic system_event_valid_out,
    output logic fence_completed_out,

    output logic register_write_enable_out,
    output logic [4:0] register_write_address_out,
    output logic [31:0] register_write_data_out,

    output logic [31:0] fetch_pc_out,
    output logic memory_busy_out,
    output logic load_use_hazard_out,
    output logic redirect_valid_out,
    output logic [31:0] redirect_target_out
);

    // CPU master-bus signals
    logic cpu_request_valid;
    logic cpu_request_ready;
    logic cpu_write_enable;
    logic [31:0] cpu_address;
    logic [31:0] cpu_write_data;
    logic [3:0] cpu_byte_enable;

    logic cpu_response_valid;
    logic [31:0] cpu_read_data;
    logic cpu_access_fault;

    // Data-memory slave signals
    logic data_memory_request;
    logic data_memory_write_enable;
    logic [31:0] data_memory_address;
    logic [31:0] data_memory_write_data;
    logic [3:0] data_memory_byte_enable;

    logic data_memory_response_valid;
    logic [31:0] data_memory_read_data;
    logic data_memory_access_fault;

    // Accelerator-stub slave signals
    logic accelerator_request;
    logic accelerator_write_enable;
    logic [31:0] accelerator_address;
    logic [31:0] accelerator_write_data;
    logic [3:0] accelerator_byte_enable;

    logic accelerator_response_valid;
    logic [31:0] accelerator_read_data;
    logic accelerator_access_fault;

    riscv_cpu #(
        .INSTRUCTION_WORDS     (INSTRUCTION_WORDS),
        .RESET_PC              (RESET_PC),
        .INSTRUCTION_BASE      (INSTRUCTION_BASE),
        .INSTRUCTION_INIT_FILE (INSTRUCTION_INIT_FILE)
    ) u_cpu (
        .clk                        (clk),
        .reset                      (reset),
        .external_halt              (external_halt),

        .data_bus_request_valid     (cpu_request_valid),
        .data_bus_request_ready     (cpu_request_ready),
        .data_bus_write_enable      (cpu_write_enable),
        .data_bus_address           (cpu_address),
        .data_bus_write_data        (cpu_write_data),
        .data_bus_byte_enable       (cpu_byte_enable),

        .data_bus_response_valid    (cpu_response_valid),
        .data_bus_read_data         (cpu_read_data),
        .data_bus_access_fault      (cpu_access_fault),

        .halted_out                 (halted_out),
        .pipeline_stalled_out       (pipeline_stalled_out),
        .pipeline_flushed_out       (pipeline_flushed_out),
        .instruction_retired_out    (instruction_retired_out),
        .exception_valid_out        (exception_valid_out),
        .system_event_valid_out     (system_event_valid_out),
        .fence_completed_out        (fence_completed_out),

        .register_write_enable_out  (
            register_write_enable_out
        ),
        .register_write_address_out (
            register_write_address_out
        ),
        .register_write_data_out    (
            register_write_data_out
        ),

        .fetch_pc_out               (fetch_pc_out),
        .memory_busy_out            (memory_busy_out),
        .load_use_hazard_out        (load_use_hazard_out),
        .redirect_valid_out         (redirect_valid_out),
        .redirect_target_out        (redirect_target_out)
    );

    system_bus u_system_bus (
        .clk                         (clk),
        .reset                       (reset),

        .master_request_valid        (cpu_request_valid),
        .master_request_ready        (cpu_request_ready),
        .master_write_enable         (cpu_write_enable),
        .master_address              (cpu_address),
        .master_write_data           (cpu_write_data),
        .master_byte_enable          (cpu_byte_enable),

        .master_response_valid       (cpu_response_valid),
        .master_read_data            (cpu_read_data),
        .master_access_fault         (cpu_access_fault),

        .data_memory_request         (data_memory_request),
        .data_memory_write_enable    (data_memory_write_enable),
        .data_memory_address         (data_memory_address),
        .data_memory_write_data      (data_memory_write_data),
        .data_memory_byte_enable     (data_memory_byte_enable),

        .data_memory_response_valid  (
            data_memory_response_valid
        ),
        .data_memory_read_data       (data_memory_read_data),
        .data_memory_access_fault    (
            data_memory_access_fault
        ),

        .accelerator_request         (accelerator_request),
        .accelerator_write_enable    (accelerator_write_enable),
        .accelerator_address         (accelerator_address),
        .accelerator_write_data      (accelerator_write_data),
        .accelerator_byte_enable     (accelerator_byte_enable),

        .accelerator_response_valid  (
            accelerator_response_valid
        ),
        .accelerator_read_data       (accelerator_read_data),
        .accelerator_access_fault    (
            accelerator_access_fault
        )
    );

    data_memory #(
        .WORDS        (DATA_MEMORY_WORDS),
        .BASE_ADDRESS (DATA_MEMORY_BASE),
        .INIT_FILE    (DATA_MEMORY_INIT_FILE)
    ) u_data_memory (
        .clk            (clk),
        .reset          (reset),
        .request        (data_memory_request),
        .write_enable   (data_memory_write_enable),
        .address        (data_memory_address),
        .write_data     (data_memory_write_data),
        .byte_enable    (data_memory_byte_enable),
        .response_valid (data_memory_response_valid),
        .read_data      (data_memory_read_data),
        .access_fault   (data_memory_access_fault)
    );

    accelerator_stub u_accelerator_stub (
        .clk            (clk),
        .reset          (reset),
        .request        (accelerator_request),
        .write_enable   (accelerator_write_enable),
        .address        (accelerator_address),
        .write_data     (accelerator_write_data),
        .byte_enable    (accelerator_byte_enable),
        .response_valid (accelerator_response_valid),
        .read_data      (accelerator_read_data),
        .access_fault   (accelerator_access_fault)
    );

endmodule