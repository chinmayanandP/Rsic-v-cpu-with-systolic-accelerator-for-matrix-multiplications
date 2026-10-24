`timescale 1ns/1ps

module tb_basic_soc_top;

    logic clk;
    logic reset;
    logic external_halt;

    logic halted_out;
    logic pipeline_stalled_out;
    logic pipeline_flushed_out;
    logic instruction_retired_out;
    logic exception_valid_out;
    logic system_event_valid_out;
    logic fence_completed_out;

    logic register_write_enable_out;
    logic [4:0] register_write_address_out;
    logic [31:0] register_write_data_out;

    logic [31:0] fetch_pc_out;
    logic memory_busy_out;
    logic load_use_hazard_out;
    logic redirect_valid_out;
    logic [31:0] redirect_target_out;

    integer errors;
    integer cycles;

    logic saw_data_memory_request;
    logic saw_accelerator_request;
    logic saw_memory_busy;
    logic saw_bus_fault;

    basic_soc_top #(
        .INSTRUCTION_WORDS      (64),
        .RESET_PC               (32'h0000_0000),
        .INSTRUCTION_BASE       (32'h0000_0000),
        .INSTRUCTION_INIT_FILE  ("soc_smoke_program.hex"),

        .DATA_MEMORY_WORDS      (4096),
        .DATA_MEMORY_BASE       (32'h0000_0000),
        .DATA_MEMORY_INIT_FILE  ("")
    ) dut (
        .clk                        (clk),
        .reset                      (reset),
        .external_halt              (external_halt),

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

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset) begin
            cycles <= cycles + 1;

            if (dut.data_memory_request)
                saw_data_memory_request <= 1'b1;

            if (dut.accelerator_request)
                saw_accelerator_request <= 1'b1;

            if (memory_busy_out)
                saw_memory_busy <= 1'b1;

            if (dut.cpu_response_valid &&
                dut.cpu_access_fault)
                saw_bus_fault <= 1'b1;
        end
    end

    task automatic check_value(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            if (actual === expected) begin
                $display(
                    "PASS: %s = %08h",
                    name,
                    actual
                );
            end
            else begin
                errors = errors + 1;

                $display(
                    "FAIL: %s expected=%08h received=%08h",
                    name,
                    expected,
                    actual
                );
            end
        end
    endtask

    task automatic check_true(
        input string name,
        input logic actual
    );
        begin
            if (actual === 1'b1) begin
                $display("PASS: %s", name);
            end
            else begin
                errors = errors + 1;
                $display(
                    "FAIL: %s was not observed",
                    name
                );
            end
        end
    endtask

    initial begin
        clk                     = 1'b0;
        reset                   = 1'b1;
        external_halt           = 1'b0;

        errors                  = 0;
        cycles                  = 0;

        saw_data_memory_request = 1'b0;
        saw_accelerator_request = 1'b0;
        saw_memory_busy         = 1'b0;
        saw_bus_fault           = 1'b0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (!system_event_valid_out &&
               cycles < 200)
            @(posedge clk);

        #1;

        if (!system_event_valid_out) begin
            errors = errors + 1;
            $display(
                "FAIL: SoC did not reach EBREAK within 200 cycles"
            );
        end
        else begin
            $display(
                "PASS: SoC reached EBREAK after %0d cycles",
                cycles
            );
        end

        check_true(
            "CPU halted on EBREAK",
            halted_out
        );

        check_true(
            "Data-memory slave request observed",
            saw_data_memory_request
        );

        check_true(
            "Accelerator-stub request observed",
            saw_accelerator_request
        );

        check_true(
            "CPU waited for SoC-bus transactions",
            saw_memory_busy
        );

        if (saw_bus_fault) begin
            errors = errors + 1;
            $display(
                "FAIL: Unexpected SoC-bus access fault observed"
            );
        end
        else begin
            $display(
                "PASS: No unexpected SoC-bus access fault"
            );
        end

        check_value(
            "x1",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[1],
            32'd12
        );

        check_value(
            "x2",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[2],
            32'd12
        );

        check_value(
            "x3",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[3],
            32'd17
        );

        check_value(
            "x4",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[4],
            32'd17
        );

        check_value(
            "x5",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[5],
            32'h4000_0000
        );

        check_value(
            "x6",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[6],
            32'd0
        );

        check_value(
            "x7",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[7],
            32'd85
        );

        check_value(
            "x8",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[8],
            32'd0
        );

        check_value(
            "Data memory word 0",
            dut.u_data_memory.memory[0],
            32'd12
        );

        check_value(
            "Data memory word 1",
            dut.u_data_memory.memory[1],
            32'd17
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL BASIC SOC SMOKE CHECKS PASSED"
            );
        end
        else begin
            $display(
                "BASIC SOC SMOKE TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule