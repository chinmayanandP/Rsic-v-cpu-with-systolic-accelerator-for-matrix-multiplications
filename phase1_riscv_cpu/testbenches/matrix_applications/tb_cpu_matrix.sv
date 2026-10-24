`timescale 1ns/1ps

module tb_cpu_matrix;

    localparam integer A_WORD_BASE  = 0;
    localparam integer B_WORD_BASE  = 1024;
    localparam integer C_WORD_BASE  = 2048;

    localparam integer M_WORD        = 3072;
    localparam integer K_WORD        = 3073;
    localparam integer N_WORD        = 3074;
    localparam integer OVERFLOW_WORD = 3075;
    localparam integer DONE_WORD     = 3076;

    localparam integer MAX_CYCLES = 200000;

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
        if (reset) begin
            cycles        <= 0;
            saw_bus_fault <= 1'b0;
        end
        else begin
            cycles <= cycles + 1;

            if (dut.cpu_response_valid &&
                dut.cpu_access_fault)
                saw_bus_fault <= 1'b1;
        end
    end

    function automatic integer matrix_m(
        input integer test_id
    );
        begin
            case (test_id)
                1: matrix_m = 2;
                2: matrix_m = 2;
                3: matrix_m = 4;
                4: matrix_m = 4;
                5: matrix_m = 1;
                6: matrix_m = 1;
                default: matrix_m = 1;
            endcase
        end
    endfunction

    function automatic integer matrix_k(
        input integer test_id
    );
        begin
            case (test_id)
                1: matrix_k = 2;
                2: matrix_k = 3;
                3: matrix_k = 4;
                4: matrix_k = 4;
                5: matrix_k = 3;
                6: matrix_k = 3;
                default: matrix_k = 1;
            endcase
        end
    endfunction

    function automatic integer matrix_n(
        input integer test_id
    );
        begin
            case (test_id)
                1: matrix_n = 2;
                2: matrix_n = 4;
                3: matrix_n = 4;
                4: matrix_n = 4;
                5: matrix_n = 1;
                6: matrix_n = 1;
                default: matrix_n = 1;
            endcase
        end
    endfunction

    function automatic integer signed matrix_a_value(
        input integer test_id,
        input integer row,
        input integer column
    );
        integer element;

        begin
            element = row * matrix_k(test_id) + column;
            matrix_a_value = 0;

            case (test_id)
                1: begin
                    case (element)
                        0: matrix_a_value = 1;
                        1: matrix_a_value = 2;
                        2: matrix_a_value = 3;
                        3: matrix_a_value = 4;
                    endcase
                end

                2: begin
                    case (element)
                        0: matrix_a_value = 1;
                        1: matrix_a_value = -2;
                        2: matrix_a_value = 3;
                        3: matrix_a_value = 4;
                        4: matrix_a_value = 5;
                        5: matrix_a_value = -6;
                    endcase
                end

                3: begin
                    case (element)
                         0: matrix_a_value = 1;
                         1: matrix_a_value = -2;
                         2: matrix_a_value = 3;
                         3: matrix_a_value = -4;
                         4: matrix_a_value = -5;
                         5: matrix_a_value = 6;
                         6: matrix_a_value = -7;
                         7: matrix_a_value = 8;
                         8: matrix_a_value = 9;
                         9: matrix_a_value = -10;
                        10: matrix_a_value = 11;
                        11: matrix_a_value = -12;
                        12: matrix_a_value = -13;
                        13: matrix_a_value = 14;
                        14: matrix_a_value = -15;
                        15: matrix_a_value = 16;
                    endcase
                end

                4: begin
                    case (element)
                         0: matrix_a_value = -3;
                         1: matrix_a_value = 0;
                         2: matrix_a_value = 5;
                         3: matrix_a_value = 6;
                         4: matrix_a_value = 0;
                         5: matrix_a_value = -8;
                         6: matrix_a_value = 0;
                         7: matrix_a_value = 10;
                         8: matrix_a_value = 11;
                         9: matrix_a_value = 12;
                        10: matrix_a_value = -13;
                        11: matrix_a_value = 0;
                        12: matrix_a_value = 15;
                        13: matrix_a_value = 0;
                        14: matrix_a_value = 17;
                        15: matrix_a_value = -18;
                    endcase
                end

                5: matrix_a_value = 32767;
                6: matrix_a_value = -32768;
            endcase
        end
    endfunction

    function automatic integer signed matrix_b_value(
        input integer test_id,
        input integer row,
        input integer column
    );
        integer element;

        begin
            element = row * matrix_n(test_id) + column;
            matrix_b_value = 0;

            case (test_id)
                1: begin
                    case (element)
                        0: matrix_b_value = 5;
                        1: matrix_b_value = 6;
                        2: matrix_b_value = 7;
                        3: matrix_b_value = 8;
                    endcase
                end

                2: begin
                    case (element)
                         0: matrix_b_value = 7;
                         1: matrix_b_value = 8;
                         2: matrix_b_value = -9;
                         3: matrix_b_value = 10;
                         4: matrix_b_value = 11;
                         5: matrix_b_value = -12;
                         6: matrix_b_value = 13;
                         7: matrix_b_value = 14;
                         8: matrix_b_value = 15;
                         9: matrix_b_value = 16;
                        10: matrix_b_value = 17;
                        11: matrix_b_value = -18;
                    endcase
                end

                3: begin
                    case (element)
                         0: matrix_b_value = 2;
                         1: matrix_b_value = 3;
                         2: matrix_b_value = -1;
                         3: matrix_b_value = 4;
                         4: matrix_b_value = -2;
                         5: matrix_b_value = 1;
                         6: matrix_b_value = 5;
                         7: matrix_b_value = -3;
                         8: matrix_b_value = 4;
                         9: matrix_b_value = -1;
                        10: matrix_b_value = 2;
                        11: matrix_b_value = 6;
                        12: matrix_b_value = 3;
                        13: matrix_b_value = 5;
                        14: matrix_b_value = -4;
                        15: matrix_b_value = 1;
                    endcase
                end

                4: begin
                    if (row == column)
                        matrix_b_value = 1;
                    else
                        matrix_b_value = 0;
                end

                5: matrix_b_value = 32767;
                6: matrix_b_value = 32767;
            endcase
        end
    endfunction

    task automatic run_matrix_test(
        input integer test_id,
        input string test_name
    );
        integer m;
        integer k;
        integer n;

        integer row;
        integer column;
        integer inner;
        integer memory_index;

        integer signed a_element;
        integer signed b_element;

        longint signed reference_sum;

        logic [31:0] expected_word;
        logic [31:0] actual_word;
        logic expected_overflow;

        begin
            @(negedge clk);
            reset = 1'b1;

            repeat (4) @(posedge clk);
            @(negedge clk);

            for (
                memory_index = 0;
                memory_index < 4096;
                memory_index = memory_index + 1
            ) begin
                dut.u_data_memory.memory[memory_index] =
                    32'h0000_0000;
            end

            m = matrix_m(test_id);
            k = matrix_k(test_id);
            n = matrix_n(test_id);

            dut.u_data_memory.memory[M_WORD] = m;
            dut.u_data_memory.memory[K_WORD] = k;
            dut.u_data_memory.memory[N_WORD] = n;

            dut.u_data_memory.memory[OVERFLOW_WORD] = 0;
            dut.u_data_memory.memory[DONE_WORD] = 0;

            for (row = 0; row < m; row = row + 1) begin
                for (
                    column = 0;
                    column < k;
                    column = column + 1
                ) begin
                    dut.u_data_memory.memory[
                        A_WORD_BASE + row * k + column
                    ] = matrix_a_value(
                        test_id,
                        row,
                        column
                    );
                end
            end

            for (row = 0; row < k; row = row + 1) begin
                for (
                    column = 0;
                    column < n;
                    column = column + 1
                ) begin
                    dut.u_data_memory.memory[
                        B_WORD_BASE + row * n + column
                    ] = matrix_b_value(
                        test_id,
                        row,
                        column
                    );
                end
            end

            reset = 1'b0;

            while (
                (
                    dut.u_data_memory.memory[DONE_WORD]
                    !== 32'd1
                ) &&
                (cycles < MAX_CYCLES)
            ) begin
                @(posedge clk);
            end

            while (
                !system_event_valid_out &&
                (cycles < MAX_CYCLES)
            ) begin
                @(posedge clk);
            end

            #1;

            $display("");
            $display("MATRIX TEST: %s", test_name);
            $display(
                "Dimensions: M=%0d K=%0d N=%0d",
                m,
                k,
                n
            );
            $display("CPU cycles: %0d", cycles);

            if (cycles >= MAX_CYCLES) begin
                errors = errors + 1;
                $display(
                    "FAIL: Matrix program timed out"
                );
            end
            else begin
                $display(
                    "PASS: Matrix program completed"
                );
            end

            if (
                dut.u_data_memory.memory[DONE_WORD]
                === 32'd1
            ) begin
                $display("PASS: DONE flag = 1");
            end
            else begin
                errors = errors + 1;
                $display(
                    "FAIL: DONE flag was not set"
                );
            end

            if (exception_valid_out) begin
                errors = errors + 1;
                $display(
                    "FAIL: Unexpected CPU exception"
                );
            end
            else begin
                $display(
                    "PASS: No CPU exception"
                );
            end

            if (saw_bus_fault) begin
                errors = errors + 1;
                $display(
                    "FAIL: Unexpected SoC-bus access fault"
                );
            end
            else begin
                $display(
                    "PASS: No SoC-bus access fault"
                );
            end

            expected_overflow = 1'b0;

            for (row = 0; row < m; row = row + 1) begin
                for (
                    column = 0;
                    column < n;
                    column = column + 1
                ) begin
                    reference_sum = 0;

                    for (
                        inner = 0;
                        inner < k;
                        inner = inner + 1
                    ) begin
                        a_element = matrix_a_value(
                            test_id,
                            row,
                            inner
                        );

                        b_element = matrix_b_value(
                            test_id,
                            inner,
                            column
                        );

                        reference_sum =
                            reference_sum +
                            a_element * b_element;
                    end

                    if (
                        reference_sum >
                        64'sd2147483647
                    ) begin
                        expected_word =
                            32'h7fff_ffff;

                        expected_overflow =
                            1'b1;
                    end
                    else if (
                        reference_sum <
                        -64'sd2147483648
                    ) begin
                        expected_word =
                            32'h8000_0000;

                        expected_overflow =
                            1'b1;
                    end
                    else begin
                        expected_word =
                            reference_sum[31:0];
                    end

                    actual_word =
                        dut.u_data_memory.memory[
                            C_WORD_BASE +
                            row * n +
                            column
                        ];

                    if (
                        actual_word ===
                        expected_word
                    ) begin
                        $display(
                            "PASS: C[%0d][%0d] = %08h",
                            row,
                            column,
                            actual_word
                        );
                    end
                    else begin
                        errors = errors + 1;

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

            actual_word =
                dut.u_data_memory.memory[
                    OVERFLOW_WORD
                ];

            if (
                actual_word ===
                {31'd0, expected_overflow}
            ) begin
                $display(
                    "PASS: Overflow flag = %0d",
                    expected_overflow
                );
            end
            else begin
                errors = errors + 1;

                $display(
                    "FAIL: Overflow expected=%0d actual=%08h",
                    expected_overflow,
                    actual_word
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
        saw_bus_fault = 1'b0;

        run_matrix_test(
            1,
            "2x2 basic multiplication"
        );

        run_matrix_test(
            2,
            "2x3 multiplied by 3x4"
        );

        run_matrix_test(
            3,
            "4x4 signed values"
        );

        run_matrix_test(
            4,
            "4x4 zero and identity"
        );

        run_matrix_test(
            5,
            "Positive overflow saturation"
        );

        run_matrix_test(
            6,
            "Negative overflow saturation"
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL CPU MATRIX FUNCTIONAL CHECKS PASSED"
            );
        end
        else begin
            $display(
                "CPU MATRIX TESTS FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule