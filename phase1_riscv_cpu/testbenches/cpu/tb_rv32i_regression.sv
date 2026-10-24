`timescale 1ns/1ps

module tb_rv32i_regression;

    localparam integer SIGNATURE_WORD_BASE = 256;
    localparam integer SIGNATURE_WORDS     = 41;
    localparam integer MAX_CYCLES          = 5000;

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

    logic [31:0] expected_signature [0:SIGNATURE_WORDS-1];

    integer errors;
    integer cycles;
    integer retired_instructions;
    integer redirect_count;
    integer index;

    logic saw_exception;
    logic saw_bus_fault;
    logic saw_fence;
    logic saw_memory_wait;
    logic saw_load_use_hazard;

    basic_soc_top #(
        .INSTRUCTION_WORDS     (128),
        .RESET_PC              (32'h0000_0000),
        .INSTRUCTION_BASE      (32'h0000_0000),
        .INSTRUCTION_INIT_FILE ("rv32i_regression.hex"),
        .DATA_MEMORY_WORDS     (4096),
        .DATA_MEMORY_BASE      (32'h0000_0000),
        .DATA_MEMORY_INIT_FILE ("")
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

        .register_write_enable_out  (register_write_enable_out),
        .register_write_address_out (register_write_address_out),
        .register_write_data_out    (register_write_data_out),

        .fetch_pc_out               (fetch_pc_out),
        .memory_busy_out            (memory_busy_out),
        .load_use_hazard_out        (load_use_hazard_out),
        .redirect_valid_out         (redirect_valid_out),
        .redirect_target_out        (redirect_target_out)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            cycles               <= 0;
            retired_instructions <= 0;
            redirect_count       <= 0;

            saw_exception        <= 1'b0;
            saw_bus_fault        <= 1'b0;
            saw_fence            <= 1'b0;
            saw_memory_wait      <= 1'b0;
            saw_load_use_hazard  <= 1'b0;
        end
        else begin
            cycles <= cycles + 1;

            if (instruction_retired_out)
                retired_instructions <= retired_instructions + 1;

            if (redirect_valid_out)
                redirect_count <= redirect_count + 1;

            if (exception_valid_out)
                saw_exception <= 1'b1;

            if (dut.cpu_response_valid &&
                dut.cpu_access_fault)
                saw_bus_fault <= 1'b1;

            if (fence_completed_out)
                saw_fence <= 1'b1;

            if (memory_busy_out)
                saw_memory_wait <= 1'b1;

            if (load_use_hazard_out)
                saw_load_use_hazard <= 1'b1;
        end
    end

    task automatic check_value(
        input string check_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            if (actual === expected) begin
                $display(
                    "PASS: %s = %08h",
                    check_name,
                    actual
                );
            end
            else begin
                errors = errors + 1;

                $display(
                    "FAIL: %s expected=%08h actual=%08h",
                    check_name,
                    expected,
                    actual
                );
            end
        end
    endtask

    task automatic check_observed(
        input string check_name,
        input logic condition
    );
        begin
            if (condition === 1'b1) begin
                $display("PASS: %s", check_name);
            end
            else begin
                errors = errors + 1;
                $display("FAIL: %s", check_name);
            end
        end
    endtask

    /*
     * Expected instruction results.
     *
     * The regression program writes each result into data memory
     * starting at byte address 0x00000400, which is memory word 256.
     */
    initial begin

        /*
         * OP-IMM instruction signatures.
         */
        expected_signature[0]  = 32'h0000_0005; // ADDI
        expected_signature[1]  = 32'hffff_fff8; // negative ADDI
        expected_signature[2]  = 32'h0000_0001; // SLTI
        expected_signature[3]  = 32'h0000_0000; // SLTIU
        expected_signature[4]  = 32'h0000_0007; // XORI
        expected_signature[5]  = 32'h0000_0055; // ORI
        expected_signature[6]  = 32'h0000_0005; // ANDI
        expected_signature[7]  = 32'h0000_0028; // SLLI
        expected_signature[8]  = 32'h3fff_fffe; // SRLI
        expected_signature[9]  = 32'hffff_fffe; // SRAI

        /*
         * Register-register ALU instruction signatures.
         */
        expected_signature[10] = 32'hffff_fffd; // ADD
        expected_signature[11] = 32'h0000_000d; // SUB
        expected_signature[12] = 32'h0000_0020; // SLL
        expected_signature[13] = 32'h0000_0001; // SLT
        expected_signature[14] = 32'h0000_0000; // SLTU
        expected_signature[15] = 32'hffff_fffd; // XOR
        expected_signature[16] = 32'h07ff_ffff; // SRL
        expected_signature[17] = 32'hffff_ffff; // SRA
        expected_signature[18] = 32'hffff_fffd; // OR
        expected_signature[19] = 32'h0000_0000; // AND

        /*
         * Upper-immediate and PC-relative instruction signatures.
         */
        expected_signature[20] = 32'h1234_5000; // LUI
        expected_signature[21] = 32'h0000_10b0; // AUIPC

        /*
         * Load/store instruction signatures.
         */
        expected_signature[22] = 32'h0000_007f; // LB positive
        expected_signature[23] = 32'hffff_ffff; // LB negative
        expected_signature[24] = 32'h0000_00ff; // LBU
        expected_signature[25] = 32'h0000_7f01; // LH positive
        expected_signature[26] = 32'hffff_80ff; // LH negative
        expected_signature[27] = 32'h0000_80ff; // LHU
        expected_signature[28] = 32'h80ff_7f01; // LW and SW
        expected_signature[29] = 32'hbeef_00aa; // SB and SH

        /*
         * BEQ, BNE, BLT, BGE, BLTU and BGEU.
         */
        expected_signature[30] = 32'h0000_0001;
        expected_signature[31] = 32'h0000_0001;
        expected_signature[32] = 32'h0000_0001;
        expected_signature[33] = 32'h0000_0001;
        expected_signature[34] = 32'h0000_0001;
        expected_signature[35] = 32'h0000_0001;

        /*
         * Intentionally unused signature word.
         */
        expected_signature[36] = 32'h0000_0000;

        /*
         * JAL, JALR and FENCE signatures.
         */
        expected_signature[37] = 32'h0000_005a;
        expected_signature[38] = 32'h0000_0188;
        expected_signature[39] = 32'h0000_01a0;
        expected_signature[40] = 32'h0000_0001;
    end

    initial begin
        clk           = 1'b0;
        reset         = 1'b1;
        external_halt = 1'b0;

        errors = 0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        reset = 1'b0;

        /*
         * Wait until the regression reaches EBREAK.
         */
        while (!system_event_valid_out &&
               cycles < MAX_CYCLES)
            @(posedge clk);

        #1;

        $display("");
        $display("RV32I INTEGRATION REGRESSION");
        $display("CPU cycles: %0d", cycles);
        $display(
            "Retired instructions: %0d",
            retired_instructions
        );
        $display(
            "Redirects observed: %0d",
            redirect_count
        );

        if (cycles >= MAX_CYCLES) begin
            errors = errors + 1;
            $display("FAIL: Regression timed out");
        end
        else begin
            $display("PASS: CPU reached EBREAK");
        end

        check_observed(
            "CPU halted on EBREAK",
            halted_out
        );

        check_observed(
            "FENCE completed",
            saw_fence
        );

        check_observed(
            "External memory wait states observed",
            saw_memory_wait
        );

        check_observed(
            "Load-use hazard observed",
            saw_load_use_hazard
        );

        if (!saw_exception) begin
            $display(
                "PASS: No unexpected CPU exception"
            );
        end
        else begin
            errors = errors + 1;

            $display(
                "FAIL: Unexpected CPU exception observed"
            );
        end

        if (!saw_bus_fault) begin
            $display(
                "PASS: No unexpected SoC-bus access fault"
            );
        end
        else begin
            errors = errors + 1;

            $display(
                "FAIL: Unexpected SoC-bus access fault observed"
            );
        end

        /*
         * Six conditional branches plus three jump redirects:
         * JAL to subroutine, JALR return and final JAL.
         */
        if (redirect_count >= 9) begin
            $display(
                "PASS: All branch/jump redirects observed"
            );
        end
        else begin
            errors = errors + 1;

            $display(
                "FAIL: Expected at least 9 redirects, observed %0d",
                redirect_count
            );
        end

        check_value(
            "x0 remains hardwired to zero",
            dut.u_cpu.u_decode_stage
                .register_file_inst.registers[0],
            32'h0000_0000
        );

        /*
         * Compare the CPU-generated architectural signatures.
         */
        for (index = 0;
             index < SIGNATURE_WORDS;
             index = index + 1) begin

            if (dut.u_data_memory.memory[
                    SIGNATURE_WORD_BASE + index
                ] !== expected_signature[index]) begin

                errors = errors + 1;

                $display(
                    "FAIL: Signature[%0d] expected=%08h actual=%08h",
                    index,
                    expected_signature[index],
                    dut.u_data_memory.memory[
                        SIGNATURE_WORD_BASE + index
                    ]
                );
            end
        end

        if (errors == 0) begin
            $display(
                "PASS: All 41 architectural signatures matched"
            );

            $display(
                "ALL RV32I INTEGRATION REGRESSION CHECKS PASSED"
            );
        end
        else begin
            $display(
                "RV32I INTEGRATION REGRESSION FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule