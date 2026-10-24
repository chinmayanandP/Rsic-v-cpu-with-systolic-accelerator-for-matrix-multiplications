`timescale 1ns/1ps

module tb_cpu_matrix_performance;

    localparam integer A_WORD_BASE   = 0;
    localparam integer B_WORD_BASE   = 1024;
    localparam integer C_WORD_BASE   = 2048;
    localparam integer M_WORD        = 3072;
    localparam integer K_WORD        = 3073;
    localparam integer N_WORD        = 3074;
    localparam integer OVERFLOW_WORD = 3075;
    localparam integer DONE_WORD     = 3076;
    localparam integer MAX_CYCLES    = 20000000;

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
    integer cycles_8;
    integer cycles_16;
    integer cycles_32;

    logic saw_bus_fault;

    basic_soc_top #(
        .INSTRUCTION_WORDS     (128),
        .RESET_PC              (32'h0000_0000),
        .INSTRUCTION_BASE      (32'h0000_0000),
        .INSTRUCTION_INIT_FILE ("matrix_cpu_program.hex"),
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
            cycles        <= 0;
            saw_bus_fault <= 1'b0;
        end
        else begin
            cycles <= cycles + 1;

            if (dut.cpu_response_valid && dut.cpu_access_fault)
                saw_bus_fault <= 1'b1;
        end
    end

    function automatic integer signed a_value(
        input integer row,
        input integer column
    );
        begin
            a_value = ((row * 3 + column * 5) % 17) - 8;
        end
    endfunction

    function automatic integer signed b_value(
        input integer row,
        input integer column
    );
        begin
            b_value = ((row * 7 + column * 2) % 13) - 6;
        end
    endfunction

    task automatic run_benchmark(
        input integer matrix_size,
        input string benchmark_name,
        output integer measured_cycles
    );

        integer row;
        integer column;
        integer inner;
        integer memory_index;
        integer local_errors;

        integer signed a_element;
        integer signed b_element;

        longint signed reference_sum;

        logic [31:0] expected_word;
        logic [31:0] actual_word;

        begin
            /*
             * Reset the processor before starting each matrix size.
             */
            @(negedge clk);
            reset = 1'b1;

            repeat (4) @(posedge clk);
            @(negedge clk);

            /*
             * Clear the complete 16 KiB data memory.
             */
            for (memory_index = 0;
                 memory_index < 4096;
                 memory_index = memory_index + 1)
                dut.u_data_memory.memory[memory_index] = 32'h0000_0000;

            /*
             * Program the matrix dimensions.
             *
             * For these performance tests:
             * M = K = N = matrix_size.
             */
            dut.u_data_memory.memory[M_WORD] = matrix_size;
            dut.u_data_memory.memory[K_WORD] = matrix_size;
            dut.u_data_memory.memory[N_WORD] = matrix_size;

            dut.u_data_memory.memory[OVERFLOW_WORD] = 0;
            dut.u_data_memory.memory[DONE_WORD]     = 0;

            /*
             * Fill matrices A and B using repeatable signed values.
             */
            for (row = 0; row < matrix_size; row = row + 1) begin
                for (column = 0;
                     column < matrix_size;
                     column = column + 1) begin

                    dut.u_data_memory.memory[
                        A_WORD_BASE + row * matrix_size + column
                    ] = a_value(row, column);

                    dut.u_data_memory.memory[
                        B_WORD_BASE + row * matrix_size + column
                    ] = b_value(row, column);
                end
            end

            /*
             * Release reset and start execution from address zero.
             */
            reset = 1'b0;

            /*
             * Wait until the CPU matrix program writes DONE = 1.
             */
            while ((dut.u_data_memory.memory[DONE_WORD] !== 32'd1) &&
                   (cycles < MAX_CYCLES))
                @(posedge clk);

            /*
             * Wait for the final EBREAK system event.
             */
            while (!system_event_valid_out &&
                   (cycles < MAX_CYCLES))
                @(posedge clk);

            #1;

            measured_cycles = cycles;
            local_errors    = 0;

            $display("");
            $display("PERFORMANCE TEST: %s", benchmark_name);
            $display("Matrix size: %0dx%0d",
                     matrix_size, matrix_size);
            $display("CPU cycles: %0d", measured_cycles);

            /*
             * Your clock period is 10 ns, so this reports execution
             * time for a 100 MHz clock.
             */
            $display("Execution time at 100 MHz: %0d ns",
                     measured_cycles * 10);

            if (cycles >= MAX_CYCLES) begin
                local_errors = local_errors + 1;
                $display("FAIL: Benchmark timed out");
            end

            if (exception_valid_out) begin
                local_errors = local_errors + 1;
                $display("FAIL: Unexpected CPU exception");
            end

            if (saw_bus_fault) begin
                local_errors = local_errors + 1;
                $display("FAIL: Unexpected SoC-bus access fault");
            end

            /*
             * Independently calculate every expected matrix element
             * and compare it with the CPU-generated result.
             */
            for (row = 0; row < matrix_size; row = row + 1) begin
                for (column = 0;
                     column < matrix_size;
                     column = column + 1) begin

                    reference_sum = 0;

                    for (inner = 0;
                         inner < matrix_size;
                         inner = inner + 1) begin

                        a_element = a_value(row, inner);
                        b_element = b_value(inner, column);

                        reference_sum =
                            reference_sum + a_element * b_element;
                    end

                    /*
                     * Apply the same signed 32-bit saturation rule
                     * used by the CPU matrix program.
                     */
                    if (reference_sum > 64'sd2147483647)
                        expected_word = 32'h7fff_ffff;
                    else if (reference_sum < -64'sd2147483648)
                        expected_word = 32'h8000_0000;
                    else
                        expected_word = reference_sum[31:0];

                    actual_word =
                        dut.u_data_memory.memory[
                            C_WORD_BASE +
                            row * matrix_size +
                            column
                        ];

                    if (actual_word !== expected_word) begin
                        local_errors = local_errors + 1;

                        $display(
                            "FAIL: C[%0d][%0d] expected=%08h actual=%08h",
                            row,
                            column,
                            expected_word,
                            actual_word
                        );
                    end
                end
            end

            /*
             * These benchmark patterns use small values, so no
             * signed 32-bit result should overflow.
             */
            if (dut.u_data_memory.memory[OVERFLOW_WORD] !== 32'd0) begin
                local_errors = local_errors + 1;
                $display("FAIL: Unexpected overflow flag");
            end

            if (local_errors == 0) begin
                $display("PASS: %s result verified", benchmark_name);
            end
            else begin
                errors = errors + local_errors;

                $display(
                    "FAIL: %s had %0d error(s)",
                    benchmark_name,
                    local_errors
                );
            end
        end
    endtask

    initial begin
        clk           = 1'b0;
        reset         = 1'b1;
        external_halt = 1'b0;

        errors        = 0;
        cycles        = 0;
        cycles_8      = 0;
        cycles_16     = 0;
        cycles_32     = 0;
        saw_bus_fault = 1'b0;

        run_benchmark(
            8,
            "8x8 CPU matrix multiplication",
            cycles_8
        );

        run_benchmark(
            16,
            "16x16 CPU matrix multiplication",
            cycles_16
        );

        run_benchmark(
            32,
            "32x32 CPU matrix multiplication",
            cycles_32
        );

        $display("");
        $display("CPU MATRIX PERFORMANCE SUMMARY");
        $display("8x8 cycles   = %0d", cycles_8);
        $display("16x16 cycles = %0d", cycles_16);
        $display("32x32 cycles = %0d", cycles_32);

        if (errors == 0)
            $display("ALL CPU MATRIX PERFORMANCE CHECKS PASSED");
        else
            $display(
                "CPU MATRIX PERFORMANCE TESTS FAILED: %0d error(s)",
                errors
            );

        $finish;
    end

endmodule