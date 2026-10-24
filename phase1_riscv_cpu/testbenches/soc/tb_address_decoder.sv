`timescale 1ns/1ps

module tb_address_decoder;

    logic        request_valid;
    logic [31:0] address;

    logic data_memory_select;
    logic accelerator_select;
    logic unmapped_address;

    integer errors;

    address_decoder dut (
        .request_valid      (request_valid),
        .address            (address),
        .data_memory_select (data_memory_select),
        .accelerator_select (accelerator_select),
        .unmapped_address   (unmapped_address)
    );

    task automatic check_decode(
        input logic [31:0] test_address,
        input logic        test_valid,
        input logic        expected_memory_select,
        input logic        expected_accelerator_select,
        input logic        expected_unmapped,
        input string       test_name
    );
        begin
            address       = test_address;
            request_valid = test_valid;
            #1;

            if ((data_memory_select === expected_memory_select) &&
                (accelerator_select === expected_accelerator_select) &&
                (unmapped_address === expected_unmapped)) begin
                $display(
                    "PASS: %s address=%08h memory=%0b accelerator=%0b unmapped=%0b",
                    test_name,
                    address,
                    data_memory_select,
                    accelerator_select,
                    unmapped_address
                );
            end
            else begin
                errors = errors + 1;

                $display(
                    "FAIL: %s address=%08h received memory=%0b accelerator=%0b unmapped=%0b expected memory=%0b accelerator=%0b unmapped=%0b",
                    test_name,
                    address,
                    data_memory_select,
                    accelerator_select,
                    unmapped_address,
                    expected_memory_select,
                    expected_accelerator_select,
                    expected_unmapped
                );
            end
        end
    endtask

    initial begin
        request_valid = 1'b0;
        address       = 32'h0000_0000;
        errors        = 0;

        // No slave may be selected when there is no valid request.
        check_decode(
            32'h4000_0000,
            1'b0,
            1'b0,
            1'b0,
            1'b0,
            "Invalid request remains inactive"
        );

        // Normal data-memory boundaries.
        check_decode(
            32'h0000_0000,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            "First data-memory byte"
        );

        check_decode(
            32'h0000_3FFF,
            1'b1,
            1'b1,
            1'b0,
            1'b0,
            "Last data-memory byte"
        );

        check_decode(
            32'h0000_4000,
            1'b1,
            1'b0,
            1'b0,
            1'b1,
            "Address immediately above data memory"
        );

        // Accelerator control-register window boundaries.
        check_decode(
            32'h4000_0000,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            "First accelerator-control byte"
        );

        check_decode(
            32'h4000_00FF,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            "Last accelerator-control byte"
        );

        check_decode(
            32'h4000_0100,
            1'b1,
            1'b0,
            1'b0,
            1'b1,
            "Gap above accelerator control"
        );

        // Reserved matrix-A window boundaries.
        check_decode(
            32'h4000_1000,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            "First matrix-A byte"
        );

        check_decode(
            32'h4000_10FF,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            "Last matrix-A byte"
        );

        check_decode(
            32'h4000_1100,
            1'b1,
            1'b0,
            1'b0,
            1'b1,
            "Gap above matrix-A window"
        );

        // Reserved matrix-B window boundaries.
        check_decode(
            32'h4000_2000,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            "First matrix-B byte"
        );

        check_decode(
            32'h4000_20FF,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            "Last matrix-B byte"
        );

        // Reserved matrix-C window boundaries.
        check_decode(
            32'h4000_3000,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            "First matrix-C byte"
        );

        check_decode(
            32'h4000_30FF,
            1'b1,
            1'b0,
            1'b1,
            1'b0,
            "Last matrix-C byte"
        );

        check_decode(
            32'h4000_3100,
            1'b1,
            1'b0,
            1'b0,
            1'b1,
            "Address above matrix-C window"
        );

        // A completely unrelated address must also report unmapped.
        check_decode(
            32'hFFFF_FFFF,
            1'b1,
            1'b0,
            1'b0,
            1'b1,
            "Maximum unmapped address"
        );

        $display("");

        if (errors == 0)
            $display("ALL ADDRESS DECODER CHECKS PASSED");
        else
            $display("ADDRESS DECODER TEST FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
