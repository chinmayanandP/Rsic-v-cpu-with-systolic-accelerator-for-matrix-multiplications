`timescale 1ns/1ps

module tb_cpu_grayscale_batch;

    string input_file;
    string output_file;

    localparam integer MAX_CYCLES = 2000000;

    // Data-memory locations expressed as 32-bit word indices.
    localparam integer A_BASE        = 0;
    localparam integer B_BASE        = 1024;
    localparam integer C_BASE        = 2048;
    localparam integer M_WORD        = 3072;
    localparam integer K_WORD        = 3073;
    localparam integer N_WORD        = 3074;
    localparam integer OVERFLOW_WORD = 3075;
    localparam integer DONE_WORD     = 3076;

    logic clk = 0;
    logic reset = 1;

    wire exception_valid;
    wire system_event_valid;

    integer cycles = 0;
    logic saw_exception = 0;
    logic saw_bus_fault = 0;
    logic saw_event = 0;

    integer input_handle;
    integer output_handle;
    integer scan_count;
    integer job_count;
    integer job_index;
    integer pixel_count;
    integer row;
    integer column;
    integer value;
    integer weight;
    integer expected_sum [0:31];

    longint total_cycles = 0;
    longint total_pixels = 0;

    basic_soc_top #(
        .INSTRUCTION_WORDS     (128),
        .RESET_PC              (32'h00000000),
        .INSTRUCTION_BASE      (32'h00000000),
        .INSTRUCTION_INIT_FILE ("matrix_cpu_program.hex"),
        .DATA_MEMORY_WORDS     (4096),
        .DATA_MEMORY_BASE      (32'h00000000),
        .DATA_MEMORY_INIT_FILE ("")
    ) dut (
        .clk                    (clk),
        .reset                  (reset),
        .external_halt          (1'b0),
        .exception_valid_out    (exception_valid),
        .system_event_valid_out (system_event_valid)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            cycles        <= 0;
            saw_exception <= 0;
            saw_bus_fault <= 0;
            saw_event     <= 0;
        end
        else begin
            cycles <= cycles + 1;

            if (exception_valid !== 1'b0)
                saw_exception <= 1;

            if (dut.cpu_response_valid &&
                dut.cpu_access_fault)
                saw_bus_fault <= 1;

            if (system_event_valid === 1'b1)
                saw_event <= 1;
        end
    end

    initial begin
        input_file = "grayscale_input.txt";
        output_file = "grayscale_output.txt";

        if (!$value$plusargs("GRAYSCALE_INPUT=%s", input_file))
            input_file = "grayscale_input.txt";

        if (!$value$plusargs("GRAYSCALE_OUTPUT=%s", output_file))
            output_file = "grayscale_output.txt";

        $display("Grayscale input file: %s", input_file);
        $display("Grayscale output file: %s", output_file);

        input_handle = $fopen(input_file, "r");

        if (input_handle == 0)
            $fatal(1, "Cannot open %s", input_file);

        output_handle = $fopen(output_file, "w");

        if (output_handle == 0)
            $fatal(1, "Cannot create %s", output_file);

        scan_count = $fscanf(input_handle, "%d", job_count);

        if (scan_count != 1 || job_count < 1)
            $fatal(1, "Invalid grayscale job count");

        $fdisplay(output_handle, "GRAYSCALE_RESULTS %0d", job_count);
        $display("RISC-V grayscale batch: %0d jobs", job_count);

        for (job_index = 0;
             job_index < job_count;
             job_index = job_index + 1) begin

            @(negedge clk);
            reset = 1;

            repeat (4) @(posedge clk);
            @(negedge clk);

            scan_count = $fscanf(input_handle, "%d", pixel_count);

            if (scan_count != 1 ||
                pixel_count < 1 ||
                pixel_count > 32)
                $fatal(1, "Invalid pixel count for job %0d", job_index);

            // Matrix A: one RGB pixel per row.
            for (row = 0; row < pixel_count; row = row + 1) begin
                expected_sum[row] = 0;

                for (column = 0; column < 3; column = column + 1) begin
                    scan_count = $fscanf(input_handle, "%d", value);

                    if (scan_count != 1 || value < 0 || value > 255)
                        $fatal(1, "Invalid RGB value in job %0d", job_index);

                    dut.u_data_memory.memory[
                        A_BASE + row * 3 + column
                    ] = value;

                    case (column)
                        0: weight = 77;
                        1: weight = 150;
                        default: weight = 29;
                    endcase

                    // Reference calculation used only for verification.
                    expected_sum[row] =
                        expected_sum[row] + value * weight;
                end

                dut.u_data_memory.memory[C_BASE + row] = 0;
            end

            // Matrix B: grayscale weights.
            dut.u_data_memory.memory[B_BASE]     = 77;
            dut.u_data_memory.memory[B_BASE + 1] = 150;
            dut.u_data_memory.memory[B_BASE + 2] = 29;

            dut.u_data_memory.memory[M_WORD]        = pixel_count;
            dut.u_data_memory.memory[K_WORD]        = 3;
            dut.u_data_memory.memory[N_WORD]        = 1;
            dut.u_data_memory.memory[OVERFLOW_WORD] = 0;
            dut.u_data_memory.memory[DONE_WORD]     = 0;

            reset = 0;

            while (saw_event !== 1'b1 && cycles < MAX_CYCLES)
                @(negedge clk);

            if (cycles >= MAX_CYCLES)
                $fatal(1, "Timeout in grayscale job %0d", job_index);

            if (saw_exception !== 1'b0 || saw_bus_fault !== 1'b0)
                $fatal(1, "CPU or bus fault in job %0d", job_index);

            if (dut.u_data_memory.memory[DONE_WORD] !== 32'd1)
                $fatal(1, "Missing DONE flag in job %0d", job_index);

            if (dut.u_data_memory.memory[OVERFLOW_WORD] !== 32'd0)
                $fatal(1, "Unexpected overflow in job %0d", job_index);

            for (row = 0; row < pixel_count; row = row + 1) begin
                if (dut.u_data_memory.memory[C_BASE + row]
                    !== expected_sum[row])
                    $fatal(
                        1,
                        "Incorrect result: job %0d, pixel %0d",
                        job_index,
                        row
                    );
            end

            $fdisplay(
                output_handle,
                "JOB %0d %0d %0d",
                job_index,
                pixel_count,
                cycles
            );

            for (row = 0; row < pixel_count; row = row + 1)
                $fdisplay(
                    output_handle,
                    "%0d",
                    $signed(dut.u_data_memory.memory[C_BASE + row])
                );

            total_cycles = total_cycles + cycles;
            total_pixels = total_pixels + pixel_count;

            if (job_index == 0 ||
                ((job_index + 1) % 100) == 0 ||
                job_index == job_count - 1)
                $display(
                    "PASS: Completed %0d/%0d grayscale jobs",
                    job_index + 1,
                    job_count
                );
        end

        $fdisplay(output_handle, "TOTAL_PIXELS %0d", total_pixels);
        $fdisplay(output_handle, "TOTAL_CYCLES %0d", total_cycles);
        $fdisplay(output_handle, "STATUS PASS");

        $fclose(input_handle);
        $fclose(output_handle);

        $display("ALL RISC-V GRAYSCALE BATCH CHECKS PASSED");
        $display("Total pixels: %0d", total_pixels);
        $display("Total CPU cycles: %0d", total_cycles);

        $finish;
    end

endmodule