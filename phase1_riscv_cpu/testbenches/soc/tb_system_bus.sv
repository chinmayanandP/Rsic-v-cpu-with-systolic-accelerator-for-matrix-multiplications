`timescale 1ns/1ps

module tb_system_bus;

    logic clk;
    logic reset;

    logic        master_request_valid;
    logic        master_request_ready;
    logic        master_write_enable;
    logic [31:0] master_address;
    logic [31:0] master_write_data;
    logic [3:0]  master_byte_enable;

    logic        master_response_valid;
    logic [31:0] master_read_data;
    logic        master_access_fault;

    logic        data_memory_request;
    logic        data_memory_write_enable;
    logic [31:0] data_memory_address;
    logic [31:0] data_memory_write_data;
    logic [3:0]  data_memory_byte_enable;

    logic        data_memory_response_valid;
    logic [31:0] data_memory_read_data;
    logic        data_memory_access_fault;

    logic        accelerator_request;
    logic        accelerator_write_enable;
    logic [31:0] accelerator_address;
    logic [31:0] accelerator_write_data;
    logic [3:0]  accelerator_byte_enable;

    logic        accelerator_response_valid;
    logic [31:0] accelerator_read_data;
    logic        accelerator_access_fault;

    logic [31:0] transaction_read_data;
    logic        transaction_access_fault;

    integer errors;
    integer timeout_count;
    integer data_memory_request_pulses;
    integer accelerator_request_pulses;
    integer memory_pulses_before;
    integer accelerator_pulses_before;

    /*
     * System bus under test.
     */
    system_bus dut (
        .clk                        (clk),
        .reset                      (reset),

        .master_request_valid       (master_request_valid),
        .master_request_ready       (master_request_ready),
        .master_write_enable        (master_write_enable),
        .master_address             (master_address),
        .master_write_data          (master_write_data),
        .master_byte_enable         (master_byte_enable),

        .master_response_valid      (master_response_valid),
        .master_read_data           (master_read_data),
        .master_access_fault        (master_access_fault),

        .data_memory_request        (data_memory_request),
        .data_memory_write_enable   (data_memory_write_enable),
        .data_memory_address        (data_memory_address),
        .data_memory_write_data     (data_memory_write_data),
        .data_memory_byte_enable    (data_memory_byte_enable),

        .data_memory_response_valid (data_memory_response_valid),
        .data_memory_read_data      (data_memory_read_data),
        .data_memory_access_fault   (data_memory_access_fault),

        .accelerator_request        (accelerator_request),
        .accelerator_write_enable   (accelerator_write_enable),
        .accelerator_address        (accelerator_address),
        .accelerator_write_data     (accelerator_write_data),
        .accelerator_byte_enable    (accelerator_byte_enable),

        .accelerator_response_valid (accelerator_response_valid),
        .accelerator_read_data      (accelerator_read_data),
        .accelerator_access_fault   (accelerator_access_fault)
    );

    /*
     * Existing 16 KiB normal data memory.
     */
    data_memory #(
        .WORDS        (4096),
        .BASE_ADDRESS (32'h0000_0000),
        .INIT_FILE    ("")
    ) memory_slave (
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

    /*
     * Existing Phase-1 accelerator placeholder.
     */
    accelerator_stub accelerator_slave (
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

    /*
     * 100 MHz clock:
     * period = 10 ns
     */
    always #5 clk = ~clk;

    /*
     * Count request pulses sent to each slave.
     */
    always @(posedge clk) begin
        if (data_memory_request) begin
            data_memory_request_pulses <=
                data_memory_request_pulses + 1;
        end

        if (accelerator_request) begin
            accelerator_request_pulses <=
                accelerator_request_pulses + 1;
        end
    end

    /*
     * Common PASS/FAIL reporting task.
     */
    task automatic report_check(
        input logic  condition,
        input string test_name
    );
        begin
            if (condition) begin
                $display("PASS: %s", test_name);
            end
            else begin
                errors = errors + 1;
                $display("FAIL: %s", test_name);
            end
        end
    endtask

    /*
     * Complete one master transaction.
     */
    task automatic bus_transaction(
        input  logic        write_enable_value,
        input  logic [31:0] address_value,
        input  logic [31:0] write_data_value,
        input  logic [3:0]  byte_enable_value,
        output logic [31:0] returned_read_data,
        output logic        returned_access_fault
    );
        begin
            /*
             * Wait until the bus can accept a request.
             */
            while (!master_request_ready) begin
                @(posedge clk);
            end

            /*
             * Drive request signals before the rising edge.
             */
            @(negedge clk);

            master_request_valid = 1'b1;
            master_write_enable  = write_enable_value;
            master_address       = address_value;
            master_write_data    = write_data_value;
            master_byte_enable   = byte_enable_value;

            /*
             * Request is accepted on this rising edge.
             */
            @(posedge clk);
            #1;

            report_check(
                !master_request_ready,
                "Bus becomes busy after accepting a request"
            );

            /*
             * Remove the master request after it has been accepted.
             */
            @(negedge clk);

            master_request_valid = 1'b0;
            master_write_enable  = 1'b0;
            master_address       = 32'h0000_0000;
            master_write_data    = 32'h0000_0000;
            master_byte_enable   = 4'b0000;

            /*
             * Wait for the bus response with a timeout.
             */
            timeout_count = 0;

            while (!master_response_valid &&
                   timeout_count < 20) begin

                @(posedge clk);
                #1;

                timeout_count = timeout_count + 1;
            end

            if (!master_response_valid) begin
                errors = errors + 1;

                $display(
                    "FAIL: Bus response timeout for address %08h",
                    address_value
                );

                returned_read_data    = 32'hXXXX_XXXX;
                returned_access_fault = 1'bx;
            end
            else begin
                returned_read_data    = master_read_data;
                returned_access_fault = master_access_fault;

                /*
                 * Allow the response state to finish.
                 */
                @(posedge clk);
                #1;
            end
        end
    endtask

    initial begin
        clk                        = 1'b0;
        reset                      = 1'b1;

        master_request_valid       = 1'b0;
        master_write_enable        = 1'b0;
        master_address             = 32'h0000_0000;
        master_write_data          = 32'h0000_0000;
        master_byte_enable         = 4'b0000;

        errors                     = 0;
        timeout_count              = 0;
        data_memory_request_pulses = 0;
        accelerator_request_pulses = 0;
        memory_pulses_before       = 0;
        accelerator_pulses_before  = 0;

        /*
         * Hold synchronous reset for three rising edges.
         */
        repeat (3) begin
            @(posedge clk);
        end

        /*
         * Deassert reset on a falling edge to prevent a reset race.
         */
        @(negedge clk);
        reset = 1'b0;
        #1;

        report_check(
            master_request_ready &&
            !master_response_valid,
            "Reset leaves bus idle and ready"
        );

        /*
         * Test 1: full-word data-memory write.
         */
        memory_pulses_before =
            data_memory_request_pulses;

        bus_transaction(
            1'b1,
            32'h0000_0020,
            32'h1122_3344,
            4'b1111,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            !transaction_access_fault,
            "Mapped data-memory write completes without a fault"
        );

        report_check(
            data_memory_request_pulses ==
            memory_pulses_before + 1,
            "Data-memory transaction produces exactly one request pulse"
        );

        /*
         * Test 2: full-word data-memory read.
         */
        bus_transaction(
            1'b0,
            32'h0000_0020,
            32'h0000_0000,
            4'b0000,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            !transaction_access_fault &&
            transaction_read_data == 32'h1122_3344,
            "Data-memory read returns the stored word"
        );

        /*
         * Test 3: byte-enable write.
         *
         * Original word: 11223344
         * Byte lane 1 becomes AA.
         * Expected word: 1122AA44
         */
        bus_transaction(
            1'b1,
            32'h0000_0020,
            32'h0000_AA00,
            4'b0010,
            transaction_read_data,
            transaction_access_fault
        );

        bus_transaction(
            1'b0,
            32'h0000_0020,
            32'h0000_0000,
            4'b0000,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            !transaction_access_fault &&
            transaction_read_data == 32'h1122_AA44,
            "Byte enables pass correctly through the bus"
        );

        /*
         * Test 4: last complete word of 16 KiB memory.
         */
        bus_transaction(
            1'b1,
            32'h0000_3FFC,
            32'hCAFE_BABE,
            4'b1111,
            transaction_read_data,
            transaction_access_fault
        );

        bus_transaction(
            1'b0,
            32'h0000_3FFC,
            32'h0000_0000,
            4'b0000,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            !transaction_access_fault &&
            transaction_read_data == 32'hCAFE_BABE,
            "Final normal-memory word is routed correctly"
        );

        /*
         * Test 5: accelerator control-window read.
         */
        accelerator_pulses_before =
            accelerator_request_pulses;

        bus_transaction(
            1'b0,
            32'h4000_0000,
            32'h0000_0000,
            4'b0000,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            !transaction_access_fault &&
            transaction_read_data == 32'h0000_0000,
            "Accelerator control-window read reaches the stub"
        );

        report_check(
            accelerator_request_pulses ==
            accelerator_pulses_before + 1,
            "Accelerator transaction produces exactly one request pulse"
        );

        /*
         * Test 6: accelerator matrix-A window.
         */
        bus_transaction(
            1'b1,
            32'h4000_1000,
            32'h0000_1234,
            4'b0011,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            !transaction_access_fault,
            "Accelerator A-window write reaches the stub"
        );

        /*
         * Test 7: accelerator matrix-B window.
         */
        bus_transaction(
            1'b0,
            32'h4000_2000,
            32'h0000_0000,
            4'b0000,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            !transaction_access_fault,
            "Accelerator B-window read reaches the stub"
        );

        /*
         * Test 8: final byte of accelerator matrix-C window.
         */
        bus_transaction(
            1'b0,
            32'h4000_30FF,
            32'h0000_0000,
            4'b0000,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            !transaction_access_fault,
            "Last accelerator C-window byte reaches the stub"
        );

        /*
         * Test 9: address immediately above normal memory.
         */
        memory_pulses_before =
            data_memory_request_pulses;

        accelerator_pulses_before =
            accelerator_request_pulses;

        bus_transaction(
            1'b0,
            32'h0000_4000,
            32'h0000_0000,
            4'b0000,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            transaction_access_fault &&
            transaction_read_data == 32'h0000_0000,
            "Unmapped address returns an access fault"
        );

        report_check(
            data_memory_request_pulses ==
                memory_pulses_before &&
            accelerator_request_pulses ==
                accelerator_pulses_before,
            "Unmapped request is not forwarded to a slave"
        );

        /*
         * Test 10: gap above accelerator-control window.
         */
        bus_transaction(
            1'b0,
            32'h4000_0100,
            32'h0000_0000,
            4'b0000,
            transaction_read_data,
            transaction_access_fault
        );

        report_check(
            transaction_access_fault,
            "Gap above accelerator-control window faults"
        );

        /*
         * Test 11: idle behavior.
         */
        repeat (3) begin
            @(posedge clk);
            #1;
        end

        report_check(
            master_request_ready &&
            !master_response_valid &&
            !data_memory_request &&
            !accelerator_request,
            "Idle bus produces no slave request or response"
        );

        $display("");

        if (errors == 0) begin
            $display("ALL SYSTEM BUS CHECKS PASSED");
        end
        else begin
            $display(
                "SYSTEM BUS TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule