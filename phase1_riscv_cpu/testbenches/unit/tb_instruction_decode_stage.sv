`timescale 1ns/1ps

module tb_instruction_decode_stage;

    logic clk;
    logic reset;
    logic pipeline_enable;
    logic pipeline_flush;

    logic [31:0] if_id_pc;
    logic [31:0] if_id_pc_plus4;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;
    logic        if_id_fault;

    logic        wb_write_enable;
    logic [4:0]  wb_write_address;
    logic [31:0] wb_write_data;

    logic        ex_valid;
    logic        ex_fault;
    logic        ex_illegal;

    logic [31:0] ex_pc;
    logic [31:0] ex_pc_plus4;
    logic [31:0] ex_immediate;
    logic [31:0] ex_rs1_data;
    logic [31:0] ex_rs2_data;

    logic [4:0] ex_rs1;
    logic [4:0] ex_rs2;
    logic [4:0] ex_rd;

    logic [6:0] ex_opcode;
    logic [2:0] ex_funct3;
    logic [6:0] ex_funct7;

    logic ex_register_write;
    logic ex_memory_read;
    logic ex_memory_write;
    logic ex_branch;
    logic ex_jump;
    logic ex_jump_register;
    logic ex_alu_source_a_pc;
    logic ex_alu_source_b_immediate;
    logic ex_uses_rs1;
    logic ex_uses_rs2;
    logic [2:0] ex_alu_operation_class;
    logic [1:0] ex_result_source;
    logic ex_system_instruction;
    logic ex_fence_instruction;

    integer checks;
    integer errors;

    instruction_decode_stage dut (.*);

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_condition(
        input string test_name,
        input logic condition
    );
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %s", test_name);
            end
            else begin
                checks = checks + 1;
                $display("PASS: %s", test_name);
            end
        end
    endtask

    task automatic write_register(
        input logic [4:0] address,
        input logic [31:0] data
    );
        begin
            if_id_valid     = 1'b0;
            wb_write_enable = 1'b1;
            wb_write_address= address;
            wb_write_data   = data;

            @(posedge clk);
            #1;

            wb_write_enable = 1'b0;
        end
    endtask

    initial begin
        checks = 0;
        errors = 0;

        reset           = 1'b1;
        pipeline_enable = 1'b1;
        pipeline_flush  = 1'b0;

        if_id_pc          = 32'h00000000;
        if_id_pc_plus4    = 32'h00000004;
        if_id_instruction = 32'h00000013;
        if_id_valid       = 1'b0;
        if_id_fault       = 1'b0;

        wb_write_enable  = 1'b0;
        wb_write_address = 5'd0;
        wb_write_data    = 32'h00000000;

        /*
         * Test 1: reset.
         */
        repeat (2) begin
            @(posedge clk);
            #1;
        end

        check_condition(
            "Integrated ID-stage reset",
            !ex_valid &&
            !ex_register_write &&
            !ex_memory_write
        );

        reset = 1'b0;

        /*
         * Prepare x1=5 and x2=7 through the real WB interface.
         */
        write_register(5'd1, 32'd5);
        write_register(5'd2, 32'd7);

        check_condition(
            "Register initialization completed",
            1'b1
        );

        /*
         * Test 3: ADD x3,x1,x2.
         */
        if_id_pc          = 32'h00000008;
        if_id_pc_plus4    = 32'h0000000C;
        if_id_instruction = 32'h002081B3;
        if_id_valid       = 1'b1;
        if_id_fault       = 1'b0;

        @(posedge clk);
        #1;

        check_condition(
            "Integrated decode of ADD",
            ex_valid &&
            !ex_fault &&
            !ex_illegal &&
            (ex_pc == 32'h00000008) &&
            (ex_rs1 == 5'd1) &&
            (ex_rs2 == 5'd2) &&
            (ex_rd == 5'd3) &&
            (ex_rs1_data == 32'd5) &&
            (ex_rs2_data == 32'd7) &&
            ex_register_write &&
            ex_uses_rs1 &&
            ex_uses_rs2 &&
            (ex_alu_operation_class == 3'b010)
        );

        /*
         * Test 4: pipeline stall holds the ADD payload.
         */
        pipeline_enable   = 1'b0;
        if_id_pc          = 32'h0000000C;
        if_id_instruction = 32'hFFF08213;

        @(posedge clk);
        #1;

        check_condition(
            "ID-stage stall holds previous payload",
            (ex_pc == 32'h00000008) &&
            (ex_opcode == 7'b0110011) &&
            (ex_rd == 5'd3) &&
            (ex_rs1_data == 32'd5) &&
            (ex_rs2_data == 32'd7)
        );

        /*
         * Test 5: pipeline flush.
         */
        pipeline_enable = 1'b1;
        pipeline_flush  = 1'b1;

        @(posedge clk);
        #1;

        check_condition(
            "ID-stage flush inserts bubble",
            !ex_valid &&
            !ex_register_write &&
            !ex_memory_read &&
            !ex_memory_write
        );

        /*
         * Test 6: ADDI x4,x1,-1.
         */
        pipeline_flush      = 1'b0;
        if_id_pc            = 32'h0000000C;
        if_id_pc_plus4      = 32'h00000010;
        if_id_instruction   = 32'hFFF08213;
        if_id_valid         = 1'b1;

        @(posedge clk);
        #1;

        check_condition(
            "Integrated decode of ADDI",
            ex_valid &&
            !ex_illegal &&
            (ex_rs1 == 5'd1) &&
            (ex_rd == 5'd4) &&
            (ex_rs1_data == 32'd5) &&
            (ex_immediate == 32'hFFFFFFFF) &&
            ex_register_write &&
            ex_alu_source_b_immediate &&
            (ex_alu_operation_class == 3'b011)
        );

        /*
         * Test 7: LW x4,12(x2).
         */
        if_id_pc          = 32'h00000010;
        if_id_pc_plus4    = 32'h00000014;
        if_id_instruction = 32'h00C12203;

        @(posedge clk);
        #1;

        check_condition(
            "Integrated decode of LW",
            ex_valid &&
            (ex_rs1 == 5'd2) &&
            (ex_rd == 5'd4) &&
            (ex_rs1_data == 32'd7) &&
            (ex_immediate == 32'd12) &&
            ex_register_write &&
            ex_memory_read &&
            !ex_memory_write &&
            (ex_result_source == 2'b01)
        );

        /*
         * Test 8:
         * Illegal RV32M MUL instruction.
         */
        if_id_pc          = 32'h00000014;
        if_id_pc_plus4    = 32'h00000018;
        if_id_instruction = 32'h022081B3;

        @(posedge clk);
        #1;

        check_condition(
            "Illegal instruction propagation",
            ex_valid &&
            ex_illegal &&
            !ex_register_write &&
            !ex_memory_write
        );

        /*
         * Test 9: instruction-memory fault propagation.
         */
        if_id_pc          = 32'h00000040;
        if_id_pc_plus4    = 32'h00000044;
        if_id_instruction = 32'h00000013;
        if_id_fault       = 1'b1;

        @(posedge clk);
        #1;

        check_condition(
            "Instruction fault propagation",
            ex_valid &&
            ex_fault &&
            !ex_register_write &&
            !ex_memory_write
        );

        /*
         * Test 10:
         * Same-cycle WB-to-ID bypass.
         *
         * ADDI x4,x3,1 while WB writes x3=A5A55A5A.
         */
        if_id_fault       = 1'b0;
        if_id_pc          = 32'h00000018;
        if_id_pc_plus4    = 32'h0000001C;
        if_id_instruction = 32'h00118213;

        wb_write_enable   = 1'b1;
        wb_write_address  = 5'd3;
        wb_write_data     = 32'hA5A55A5A;

        @(posedge clk);
        #1;

        wb_write_enable = 1'b0;

        check_condition(
            "Same-cycle WB-to-ID bypass",
            ex_valid &&
            (ex_rs1 == 5'd3) &&
            (ex_rs1_data == 32'hA5A55A5A) &&
            (ex_immediate == 32'd1) &&
            (ex_rd == 5'd4)
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d INTEGRATED ID-STAGE CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "INTEGRATED ID-STAGE TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule