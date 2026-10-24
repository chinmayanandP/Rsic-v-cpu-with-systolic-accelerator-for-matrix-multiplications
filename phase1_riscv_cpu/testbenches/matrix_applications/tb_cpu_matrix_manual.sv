`timescale 1ns/1ps

module tb_cpu_matrix_manual;

    localparam integer CLOCK_PERIOD_NS = 10;

    localparam integer A_WORD_BASE   = 0;
    localparam integer B_WORD_BASE   = 1024;
    localparam integer C_WORD_BASE   = 2048;

    localparam integer M_WORD        = 3072;
    localparam integer K_WORD        = 3073;
    localparam integer N_WORD        = 3074;
    localparam integer OVERFLOW_WORD = 3075;
    localparam integer DONE_WORD     = 3076;

    localparam integer MAX_CYCLES    = 20000000;

    string input_file;
    string output_file;

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

    integer cycles;
    integer m;
    integer k;
    integer n;
    integer row;
    integer column;
    integer output_handle;
    integer errors;

    logic saw_exception;
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

    /*
     * 100 MHz clock:
     *
     * Clock period = 10 ns
     * Half period  = 5 ns
     */
    always #(CLOCK_PERIOD_NS / 2) clk = ~clk;

    /*
     * Count CPU execution cycles and monitor errors.
     */
    always @(posedge clk) begin
        if (reset) begin
            cycles        <= 0;
            saw_exception <= 1'b0;
            saw_bus_fault <= 1'b0;
        end
        else begin
            cycles <= cycles + 1;

            if (exception_valid_out)
                saw_exception <= 1'b1;

            if (dut.cpu_response_valid &&
                dut.cpu_access_fault)
                saw_bus_fault <= 1'b1;
        end
    end

    initial begin
        clk           = 1'b0;
        reset         = 1'b1;
        external_halt = 1'b0;
        errors        = 0;

        input_file  = "matrix_input.mem";
        output_file = "matrix_output.txt";

        if (!$value$plusargs("MATRIX_INPUT=%s", input_file))
            input_file = "matrix_input.mem";

        if (!$value$plusargs("MATRIX_OUTPUT=%s", output_file))
            output_file = "matrix_output.txt";

        $display("Matrix input file: %s", input_file);
        $display("Matrix output file: %s", output_file);

        /*
         * Load matrices, dimensions and control values
         * into SoC data memory.
         */
        #1;
        $readmemh(
            input_file,
            dut.u_data_memory.memory
        );

        /*
         * Read automatically detected dimensions.
         */
        m = dut.u_data_memory.memory[M_WORD];
        k = dut.u_data_memory.memory[K_WORD];
        n = dut.u_data_memory.memory[N_WORD];

        /*
         * Check dimension range.
         */
        if ((m < 1) || (m > 32) ||
            (k < 1) || (k > 32) ||
            (n < 1) || (n > 32)) begin

            $fatal(
                1,
                "Invalid dimensions in matrix_input.mem: M=%0d K=%0d N=%0d",
                m,
                k,
                n
            );
        end

        /*
         * Hold reset for four clock cycles.
         */
        repeat (4) @(posedge clk);

        /*
         * Release reset away from the positive edge.
         */
        @(negedge clk);
        reset = 1'b0;

        /*
         * Wait until the CPU matrix program writes
         * DONE = 1 into data memory.
         */
        while (
            (dut.u_data_memory.memory[DONE_WORD] !== 32'd1) &&
            (cycles < MAX_CYCLES)
        ) begin
            @(posedge clk);
        end

        /*
         * Wait for the CPU program to reach EBREAK.
         */
        while (
            !system_event_valid_out &&
            (cycles < MAX_CYCLES)
        ) begin
            @(posedge clk);
        end

        #1;

        /*
         * Check timeout and CPU/SoC errors.
         */
        if (cycles >= MAX_CYCLES) begin
            errors = errors + 1;
            $display(
                "FAIL: Matrix calculation timed out"
            );
        end

        if (saw_exception) begin
            errors = errors + 1;
            $display(
                "FAIL: Unexpected CPU exception"
            );
        end

        if (saw_bus_fault) begin
            errors = errors + 1;
            $display(
                "FAIL: Unexpected SoC-bus access fault"
            );
        end

        /*
         * Open output result file.
         */
        output_handle = $fopen(
            output_file,
            "w"
        );

        if (output_handle == 0) begin
            $fatal(
                1,
                "Could not create %s",
                output_file
            );
        end

        /*
         * Display result in the XSim console.
         */
        $display("");
        $display("CPU MATRIX RESULT");
        $display(
            "A dimensions: %0dx%0d",
            m,
            k
        );
        $display(
            "B dimensions: %0dx%0d",
            k,
            n
        );
        $display(
            "C dimensions: %0dx%0d",
            m,
            n
        );
        $display(
            "CPU cycles: %0d",
            cycles
        );
        $display(
            "Clock frequency: 100 MHz"
        );
        $display(
            "Clock period: %0d ns",
            CLOCK_PERIOD_NS
        );
        $display(
            "Execution time: %0d ns",
            cycles * CLOCK_PERIOD_NS
        );
        $display(
            "Execution time: %0.3f us",
            $itor(cycles * CLOCK_PERIOD_NS) / 1000.0
        );
        $display(
            "Execution time: %0.6f ms",
            $itor(cycles * CLOCK_PERIOD_NS) / 1000000.0
        );
        $display(
            "Overflow flag: %0d",
            dut.u_data_memory.memory[OVERFLOW_WORD]
        );
        $display("Matrix C:");

        /*
         * Write result information into matrix_output.txt.
         */
        $fdisplay(
            output_handle,
            "CPU MATRIX RESULT"
        );
        $fdisplay(
            output_handle,
            "A dimensions: %0dx%0d",
            m,
            k
        );
        $fdisplay(
            output_handle,
            "B dimensions: %0dx%0d",
            k,
            n
        );
        $fdisplay(
            output_handle,
            "C dimensions: %0dx%0d",
            m,
            n
        );
        $fdisplay(
            output_handle,
            "CPU cycles: %0d",
            cycles
        );
        $fdisplay(
            output_handle,
            "Clock frequency: 100 MHz"
        );
        $fdisplay(
            output_handle,
            "Clock period: %0d ns",
            CLOCK_PERIOD_NS
        );
        $fdisplay(
            output_handle,
            "Execution time: %0d ns",
            cycles * CLOCK_PERIOD_NS
        );
        $fdisplay(
            output_handle,
            "Execution time: %0.3f us",
            $itor(cycles * CLOCK_PERIOD_NS) / 1000.0
        );
        $fdisplay(
            output_handle,
            "Execution time: %0.6f ms",
            $itor(cycles * CLOCK_PERIOD_NS) / 1000000.0
        );
        $fdisplay(
            output_handle,
            "Overflow flag: %0d",
            dut.u_data_memory.memory[OVERFLOW_WORD]
        );
        $fdisplay(
            output_handle,
            "Matrix C:"
        );

        /*
         * Display and save Matrix C.
         */
        for (
            row = 0;
            row < m;
            row = row + 1
        ) begin

            for (
                column = 0;
                column < n;
                column = column + 1
            ) begin

                $write(
                    "%0d ",
                    $signed(
                        dut.u_data_memory.memory[
                            C_WORD_BASE +
                            row * n +
                            column
                        ]
                    )
                );

                $fwrite(
                    output_handle,
                    "%0d ",
                    $signed(
                        dut.u_data_memory.memory[
                            C_WORD_BASE +
                            row * n +
                            column
                        ]
                    )
                );
            end

            $display("");
            $fdisplay(output_handle, "");
        end

        /*
         * Final pass/fail status.
         */
        if (errors == 0) begin
            $display(
                "MANUAL CPU MATRIX MULTIPLICATION PASSED"
            );

            $fdisplay(
                output_handle,
                "STATUS: MANUAL CPU MATRIX MULTIPLICATION PASSED"
            );
        end
        else begin
            $display(
                "MANUAL CPU MATRIX MULTIPLICATION FAILED: %0d error(s)",
                errors
            );

            $fdisplay(
                output_handle,
                "STATUS: FAILED WITH %0d ERROR(S)",
                errors
            );
        end

        $fclose(output_handle);
        $finish;
    end

endmodule