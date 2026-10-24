`timescale 1ns/1ps

module tb_cpu_matrix_batch;

    localparam integer MATRIX_SIZE     = 8;
    localparam integer MATRIX_ELEMENTS = 64;

    localparam integer A_WORD_BASE   = 0;
    localparam integer B_WORD_BASE   = 1024;
    localparam integer C_WORD_BASE   = 2048;
    localparam integer M_WORD        = 3072;
    localparam integer K_WORD        = 3073;
    localparam integer N_WORD        = 3074;
    localparam integer OVERFLOW_WORD = 3075;
    localparam integer DONE_WORD     = 3076;

    localparam integer MAX_CYCLES_PER_JOB = 20000000;

    localparam string INPUT_FILE =
        "E:/project/Project Final riscv/dct_batch_input.mem";

    localparam string OUTPUT_FILE =
        "E:/project/Project Final riscv/dct_batch_output.txt";

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

    integer input_handle;
    integer output_handle;
    integer scan_count;
    integer job_count;
    integer job_index;
    integer job_id;
    integer row;
    integer column;
    integer cycles;
    integer errors;
    integer job_errors;
    integer completed_jobs;

    longint total_cycles;

    logic [31:0] input_word;
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

    always #5 clk = ~clk;

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

    task automatic load_next_job;
        integer index;

        begin
            scan_count = $fscanf(
                input_handle,
                "%d",
                job_id
            );

            if (scan_count != 1) begin
                $fatal(
                    1,
                    "Could not read job ID for batch job %0d",
                    job_index
                );
            end

            for (
                index = 0;
                index < MATRIX_ELEMENTS;
                index = index + 1
            ) begin
                scan_count = $fscanf(
                    input_handle,
                    "%h",
                    input_word
                );

                if (scan_count != 1) begin
                    $fatal(
                        1,
                        "Could not read Matrix A element %0d for job %0d",
                        index,
                        job_id
                    );
                end

                dut.u_data_memory.memory[
                    A_WORD_BASE + index
                ] = input_word;
            end

            for (
                index = 0;
                index < MATRIX_ELEMENTS;
                index = index + 1
            ) begin
                scan_count = $fscanf(
                    input_handle,
                    "%h",
                    input_word
                );

                if (scan_count != 1) begin
                    $fatal(
                        1,
                        "Could not read Matrix B element %0d for job %0d",
                        index,
                        job_id
                    );
                end

                dut.u_data_memory.memory[
                    B_WORD_BASE + index
                ] = input_word;
            end

            for (
                index = 0;
                index < MATRIX_ELEMENTS;
                index = index + 1
            ) begin
                dut.u_data_memory.memory[
                    C_WORD_BASE + index
                ] = 32'd0;
            end

            dut.u_data_memory.memory[M_WORD] =
                MATRIX_SIZE;

            dut.u_data_memory.memory[K_WORD] =
                MATRIX_SIZE;

            dut.u_data_memory.memory[N_WORD] =
                MATRIX_SIZE;

            dut.u_data_memory.memory[OVERFLOW_WORD] =
                32'd0;

            dut.u_data_memory.memory[DONE_WORD] =
                32'd0;
        end
    endtask

    task automatic write_job_result;
        begin
            $fdisplay(
                output_handle,
                "JOB %0d",
                job_id
            );

            $fdisplay(
                output_handle,
                "CYCLES %0d",
                cycles
            );

            $fdisplay(
                output_handle,
                "OVERFLOW %0d",
                dut.u_data_memory.memory[
                    OVERFLOW_WORD
                ]
            );

            $fdisplay(
                output_handle,
                "MATRIX_C"
            );

            for (
                row = 0;
                row < MATRIX_SIZE;
                row = row + 1
            ) begin
                for (
                    column = 0;
                    column < MATRIX_SIZE;
                    column = column + 1
                ) begin
                    $fwrite(
                        output_handle,
                        "%0d ",
                        $signed(
                            dut.u_data_memory.memory[
                                C_WORD_BASE
                                + row * MATRIX_SIZE
                                + column
                            ]
                        )
                    );
                end

                $fdisplay(
                    output_handle,
                    ""
                );
            end

            if (job_errors == 0) begin
                $fdisplay(
                    output_handle,
                    "JOB_STATUS PASS"
                );
            end
            else begin
                $fdisplay(
                    output_handle,
                    "JOB_STATUS FAIL %0d",
                    job_errors
                );
            end

            $fdisplay(
                output_handle,
                "END_JOB"
            );
        end
    endtask

    initial begin
        clk            = 1'b0;
        reset          = 1'b1;
        external_halt  = 1'b0;
        cycles         = 0;
        total_cycles   = 0;
        errors         = 0;
        completed_jobs = 0;
        saw_exception  = 1'b0;
        saw_bus_fault  = 1'b0;

        input_handle = $fopen(
            INPUT_FILE,
            "r"
        );

        if (input_handle == 0) begin
            $fatal(
                1,
                "Could not open %s",
                INPUT_FILE
            );
        end

        output_handle = $fopen(
            OUTPUT_FILE,
            "w"
        );

        if (output_handle == 0) begin
            $fatal(
                1,
                "Could not create %s",
                OUTPUT_FILE
            );
        end

        scan_count = $fscanf(
            input_handle,
            "%d",
            job_count
        );

        if ((scan_count != 1) ||
            (job_count < 1)) begin
            $fatal(
                1,
                "Invalid batch job count in %s",
                INPUT_FILE
            );
        end

        $display("");
        $display(
            "RISC-V CPU MATRIX BATCH TEST"
        );

        $display(
            "Jobs requested: %0d",
            job_count
        );

        $fdisplay(
            output_handle,
            "BATCH_MATRIX_RESULTS"
        );

        $fdisplay(
            output_handle,
            "JOB_COUNT %0d",
            job_count
        );

        for (
            job_index = 0;
            job_index < job_count;
            job_index = job_index + 1
        ) begin
            job_errors = 0;

            @(negedge clk);
            reset = 1'b1;

            repeat (4) @(posedge clk);
            @(negedge clk);

            load_next_job();

            $display(
                "Starting batch job %0d/%0d, ID=%0d",
                job_index + 1,
                job_count,
                job_id
            );

            reset = 1'b0;

            while (
                (dut.u_data_memory.memory[DONE_WORD]
                    !== 32'd1) &&
                (cycles < MAX_CYCLES_PER_JOB)
            ) begin
                @(posedge clk);
            end

            while (
                !system_event_valid_out &&
                (cycles < MAX_CYCLES_PER_JOB)
            ) begin
                @(posedge clk);
            end

            #1;

            if (
                cycles >= MAX_CYCLES_PER_JOB
            ) begin
                job_errors = job_errors + 1;

                $display(
                    "FAIL: Job %0d timed out",
                    job_id
                );
            end

            if (saw_exception) begin
                job_errors = job_errors + 1;

                $display(
                    "FAIL: Job %0d caused a CPU exception",
                    job_id
                );
            end

            if (saw_bus_fault) begin
                job_errors = job_errors + 1;

                $display(
                    "FAIL: Job %0d caused a SoC-bus fault",
                    job_id
                );
            end

            if (
                dut.u_data_memory.memory[DONE_WORD]
                !== 32'd1
            ) begin
                job_errors = job_errors + 1;

                $display(
                    "FAIL: Job %0d did not set DONE",
                    job_id
                );
            end

            write_job_result();

            total_cycles =
                total_cycles + cycles;

            completed_jobs =
                completed_jobs + 1;

            errors =
                errors + job_errors;

            if (job_errors == 0) begin
                $display(
                    "PASS: Job ID=%0d completed in %0d cycles, overflow=%0d",
                    job_id,
                    cycles,
                    dut.u_data_memory.memory[
                        OVERFLOW_WORD
                    ]
                );
            end
        end

        $fdisplay(
            output_handle,
            "COMPLETED_JOBS %0d",
            completed_jobs
        );

        $fdisplay(
            output_handle,
            "TOTAL_CYCLES %0d",
            total_cycles
        );

        $fdisplay(
            output_handle,
            "TOTAL_ERRORS %0d",
            errors
        );

        if (errors == 0) begin
            $display("");

            $display(
                "ALL RISC-V CPU MATRIX BATCH JOBS PASSED"
            );

            $display(
                "Completed jobs: %0d",
                completed_jobs
            );

            $display(
                "Total CPU cycles: %0d",
                total_cycles
            );

            $fdisplay(
                output_handle,
                "STATUS PASS"
            );
        end
        else begin
            $display("");

            $display(
                "RISC-V CPU MATRIX BATCH FAILED: %0d error(s)",
                errors
            );

            $fdisplay(
                output_handle,
                "STATUS FAIL"
            );
        end

        $fclose(input_handle);
        $fclose(output_handle);

        $finish;
    end

endmodule