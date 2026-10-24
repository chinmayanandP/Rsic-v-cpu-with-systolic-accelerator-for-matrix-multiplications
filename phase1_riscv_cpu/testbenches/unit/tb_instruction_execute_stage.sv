`timescale 1ns/1ps

module tb_instruction_execute_stage;

    localparam logic [2:0] ALU_CLASS_ADD       = 3'b000;
    localparam logic [2:0] ALU_CLASS_BRANCH    = 3'b001;
    localparam logic [2:0] ALU_CLASS_REGISTER  = 3'b010;
    localparam logic [2:0] ALU_CLASS_IMMEDIATE = 3'b011;
    localparam logic [2:0] ALU_CLASS_LUI       = 3'b100;
    localparam logic [2:0] ALU_CLASS_NONE      = 3'b111;

    localparam logic [1:0] RESULT_ALU    = 2'b00;
    localparam logic [1:0] RESULT_MEMORY = 2'b01;
    localparam logic [1:0] RESULT_PC4    = 2'b10;
    localparam logic [1:0] RESULT_NONE   = 2'b11;

    logic clk;
    logic reset;
    logic enable;
    logic flush;

    logic valid_in;
    logic fault_in;
    logic illegal_in;

    logic [31:0] pc_in;
    logic [31:0] pc_plus4_in;
    logic [31:0] rs1_value_in;
    logic [31:0] rs2_value_in;
    logic [31:0] immediate_in;

    logic [4:0] rd_in;
    logic [2:0] funct3_in;
    logic [6:0] funct7_in;

    logic [2:0] alu_operation_class_in;
    logic alu_source_a_pc_in;
    logic alu_source_b_immediate_in;

    logic branch_in;
    logic jump_in;
    logic jump_register_in;

    logic register_write_in;
    logic memory_read_in;
    logic memory_write_in;
    logic [1:0] result_source_in;

    logic system_instruction_in;
    logic fence_instruction_in;

    logic branch_taken_out;
    logic redirect_valid_out;
    logic [31:0] redirect_target_out;
    logic target_misaligned_out;

    logic valid_out;
    logic fault_out;
    logic illegal_out;

    logic [31:0] pc_plus4_out;
    logic [31:0] alu_result_out;
    logic [31:0] store_data_out;

    logic [4:0] rd_out;
    logic [2:0] funct3_out;

    logic register_write_out;
    logic memory_read_out;
    logic memory_write_out;
    logic [1:0] result_source_out;

    logic system_instruction_out;
    logic fence_instruction_out;

    integer errors;

    instruction_execute_stage dut (
        .clk                         (clk),
        .reset                       (reset),
        .enable                      (enable),
        .flush                       (flush),

        .valid_in                    (valid_in),
        .fault_in                    (fault_in),
        .illegal_in                  (illegal_in),

        .pc_in                       (pc_in),
        .pc_plus4_in                 (pc_plus4_in),
        .rs1_value_in                (rs1_value_in),
        .rs2_value_in                (rs2_value_in),
        .immediate_in                (immediate_in),

        .rd_in                       (rd_in),
        .funct3_in                   (funct3_in),
        .funct7_in                   (funct7_in),

        .alu_operation_class_in      (
            alu_operation_class_in
        ),
        .alu_source_a_pc_in          (alu_source_a_pc_in),
        .alu_source_b_immediate_in   (
            alu_source_b_immediate_in
        ),

        .branch_in                   (branch_in),
        .jump_in                     (jump_in),
        .jump_register_in            (jump_register_in),

        .register_write_in           (register_write_in),
        .memory_read_in              (memory_read_in),
        .memory_write_in             (memory_write_in),
        .result_source_in            (result_source_in),

        .system_instruction_in       (system_instruction_in),
        .fence_instruction_in        (fence_instruction_in),

        .branch_taken_out            (branch_taken_out),
        .redirect_valid_out          (redirect_valid_out),
        .redirect_target_out         (redirect_target_out),
        .target_misaligned_out       (target_misaligned_out),

        .valid_out                   (valid_out),
        .fault_out                   (fault_out),
        .illegal_out                 (illegal_out),

        .pc_plus4_out                (pc_plus4_out),
        .alu_result_out              (alu_result_out),
        .store_data_out              (store_data_out),

        .rd_out                      (rd_out),
        .funct3_out                  (funct3_out),

        .register_write_out          (register_write_out),
        .memory_read_out             (memory_read_out),
        .memory_write_out            (memory_write_out),
        .result_source_out           (result_source_out),

        .system_instruction_out      (
            system_instruction_out
        ),
        .fence_instruction_out       (fence_instruction_out)
    );

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;

    task automatic set_defaults;
        begin
            reset                       = 1'b0;
            enable                      = 1'b1;
            flush                       = 1'b0;

            valid_in                    = 1'b1;
            fault_in                    = 1'b0;
            illegal_in                  = 1'b0;

            pc_in                       = 32'h00000100;
            pc_plus4_in                 = 32'h00000104;
            rs1_value_in                = 32'h00000000;
            rs2_value_in                = 32'h00000000;
            immediate_in                = 32'h00000000;

            rd_in                       = 5'd0;
            funct3_in                   = 3'b000;
            funct7_in                   = 7'b0000000;

            alu_operation_class_in      = ALU_CLASS_NONE;
            alu_source_a_pc_in          = 1'b0;
            alu_source_b_immediate_in   = 1'b0;

            branch_in                   = 1'b0;
            jump_in                     = 1'b0;
            jump_register_in            = 1'b0;

            register_write_in           = 1'b0;
            memory_read_in              = 1'b0;
            memory_write_in             = 1'b0;
            result_source_in            = RESULT_NONE;

            system_instruction_in       = 1'b0;
            fence_instruction_in        = 1'b0;
        end
    endtask

    task automatic capture;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic pass(input string test_name);
        begin
            $display("PASS: %s", test_name);
        end
    endtask

    task automatic fail(input string test_name);
        begin
            errors = errors + 1;
            $display("FAIL: %s", test_name);
        end
    endtask

    initial begin
        errors = 0;
        set_defaults();

        /*
         * Test 1: synchronous reset.
         */
        reset = 1'b1;
        capture();

        if (!valid_out &&
            !fault_out &&
            !illegal_out &&
            !register_write_out &&
            !memory_read_out &&
            !memory_write_out) begin

            pass("Integrated EX-stage reset");
        end
        else begin
            fail("Integrated EX-stage reset");
        end

        /*
         * Test 2: ADD x3,x1,x2.
         */
        set_defaults();

        rs1_value_in           = 32'd5;
        rs2_value_in           = 32'd7;
        rd_in                  = 5'd3;

        alu_operation_class_in = ALU_CLASS_REGISTER;
        register_write_in      = 1'b1;
        result_source_in       = RESULT_ALU;

        capture();

        if (valid_out &&
            alu_result_out == 32'd12 &&
            rd_out == 5'd3 &&
            register_write_out &&
            !fault_out &&
            !illegal_out) begin

            pass("Integrated ADD execution");
        end
        else begin
            fail("Integrated ADD execution");
        end

        /*
         * Test 3: ADDI x4,x1,9.
         */
        set_defaults();

        rs1_value_in                = 32'd5;
        immediate_in                = 32'd9;
        rd_in                       = 5'd4;
        funct3_in                   = 3'b000;

        alu_operation_class_in      = ALU_CLASS_IMMEDIATE;
        alu_source_b_immediate_in   = 1'b1;

        register_write_in           = 1'b1;
        result_source_in            = RESULT_ALU;

        capture();

        if (alu_result_out == 32'd14 &&
            rd_out == 5'd4 &&
            register_write_out &&
            !illegal_out) begin

            pass("Integrated ADDI execution");
        end
        else begin
            fail("Integrated ADDI execution");
        end

        /*
         * Test 4: LUI.
         */
        set_defaults();

        immediate_in                = 32'h12345000;
        rd_in                       = 5'd5;

        alu_operation_class_in      = ALU_CLASS_LUI;
        alu_source_b_immediate_in   = 1'b1;

        register_write_in           = 1'b1;
        result_source_in            = RESULT_ALU;

        capture();

        if (alu_result_out == 32'h12345000 &&
            register_write_out &&
            !illegal_out) begin

            pass("Integrated LUI execution");
        end
        else begin
            fail("Integrated LUI execution");
        end

        /*
         * Test 5: AUIPC.
         */
        set_defaults();

        pc_in                       = 32'h00001000;
        pc_plus4_in                 = 32'h00001004;
        immediate_in                = 32'h00002000;
        rd_in                       = 5'd6;

        alu_operation_class_in      = ALU_CLASS_ADD;
        alu_source_a_pc_in          = 1'b1;
        alu_source_b_immediate_in   = 1'b1;

        register_write_in           = 1'b1;
        result_source_in            = RESULT_ALU;

        capture();

        if (alu_result_out == 32'h00003000 &&
            register_write_out) begin

            pass("Integrated AUIPC execution");
        end
        else begin
            fail("Integrated AUIPC execution");
        end

        /*
         * Test 6: load effective-address calculation.
         */
        set_defaults();

        rs1_value_in                = 32'h00002000;
        immediate_in                = 32'd12;
        rd_in                       = 5'd7;
        funct3_in                   = 3'b010;

        alu_operation_class_in      = ALU_CLASS_ADD;
        alu_source_b_immediate_in   = 1'b1;

        register_write_in           = 1'b1;
        memory_read_in              = 1'b1;
        result_source_in            = RESULT_MEMORY;

        capture();

        if (alu_result_out == 32'h0000200c &&
            memory_read_out &&
            register_write_out &&
            result_source_out == RESULT_MEMORY) begin

            pass("Integrated load-address calculation");
        end
        else begin
            fail("Integrated load-address calculation");
        end

        /*
         * Test 7: store address and data.
         */
        set_defaults();

        rs1_value_in                = 32'h00003000;
        rs2_value_in                = 32'hdeadbeef;
        immediate_in                = 32'd16;
        funct3_in                   = 3'b010;

        alu_operation_class_in      = ALU_CLASS_ADD;
        alu_source_b_immediate_in   = 1'b1;
        memory_write_in             = 1'b1;

        capture();

        if (alu_result_out == 32'h00003010 &&
            store_data_out == 32'hdeadbeef &&
            memory_write_out) begin

            pass("Integrated store address and store data");
        end
        else begin
            fail("Integrated store address and store data");
        end

        /*
         * Test 8: taken BEQ.
         */
        set_defaults();

        pc_in                       = 32'h00000100;
        pc_plus4_in                 = 32'h00000104;
        rs1_value_in                = 32'd25;
        rs2_value_in                = 32'd25;
        immediate_in                = 32'd8;
        funct3_in                   = 3'b000;

        alu_operation_class_in      = ALU_CLASS_BRANCH;
        branch_in                   = 1'b1;

        #1;

        if (branch_taken_out &&
            redirect_valid_out &&
            redirect_target_out == 32'h00000108 &&
            !target_misaligned_out) begin

            pass("Integrated BEQ redirect");
        end
        else begin
            fail("Integrated BEQ redirect");
        end

        capture();

        /*
         * Test 9: non-taken BEQ.
         */
        set_defaults();

        rs1_value_in                = 32'd1;
        rs2_value_in                = 32'd2;
        immediate_in                = 32'd8;
        funct3_in                   = 3'b000;

        alu_operation_class_in      = ALU_CLASS_BRANCH;
        branch_in                   = 1'b1;

        #1;

        if (!branch_taken_out &&
            !redirect_valid_out) begin

            pass("Integrated non-taken branch");
        end
        else begin
            fail("Integrated non-taken branch");
        end

        capture();

        /*
         * Test 10: JAL.
         */
        set_defaults();

        pc_in                       = 32'h00000200;
        pc_plus4_in                 = 32'h00000204;
        immediate_in                = 32'd16;
        rd_in                       = 5'd1;

        jump_in                     = 1'b1;
        register_write_in           = 1'b1;
        result_source_in            = RESULT_PC4;
        alu_operation_class_in      = ALU_CLASS_NONE;

        #1;

        if (redirect_valid_out &&
            redirect_target_out == 32'h00000210) begin

            pass("Integrated JAL redirect");
        end
        else begin
            fail("Integrated JAL redirect");
        end

        capture();

        if (pc_plus4_out == 32'h00000204 &&
            register_write_out &&
            result_source_out == RESULT_PC4 &&
            !illegal_out) begin

            pass("JAL PC+4 pipeline payload");
        end
        else begin
            fail("JAL PC+4 pipeline payload");
        end

        /*
         * Test 11: JALR.
         */
        set_defaults();

        rs1_value_in                = 32'h00000301;
        immediate_in                = 32'd3;

        jump_in                     = 1'b1;
        jump_register_in            = 1'b1;

        alu_operation_class_in      = ALU_CLASS_ADD;
        alu_source_b_immediate_in   = 1'b1;

        register_write_in           = 1'b1;
        result_source_in            = RESULT_PC4;

        #1;

        if (redirect_valid_out &&
            redirect_target_out == 32'h00000304 &&
            !target_misaligned_out) begin

            pass("Integrated JALR redirect");
        end
        else begin
            fail("Integrated JALR redirect");
        end

        capture();

        /*
         * Test 12: misaligned instruction target.
         */
        set_defaults();

        pc_in                       = 32'h00000400;
        pc_plus4_in                 = 32'h00000404;
        immediate_in                = 32'd2;
        rd_in                       = 5'd1;

        jump_in                     = 1'b1;
        register_write_in           = 1'b1;
        result_source_in            = RESULT_PC4;
        alu_operation_class_in      = ALU_CLASS_NONE;

        #1;

        if (target_misaligned_out &&
            !redirect_valid_out) begin

            pass("Misaligned target detected");
        end
        else begin
            fail("Misaligned target detected");
        end

        capture();

        if (fault_out &&
            !register_write_out) begin

            pass("Misaligned target fault propagation");
        end
        else begin
            fail("Misaligned target fault propagation");
        end

        /*
         * Test 13: illegal ALU control encoding.
         */
        set_defaults();

        rs1_value_in                = 32'd5;
        rs2_value_in                = 32'd7;
        rd_in                       = 5'd3;

        funct3_in                   = 3'b001;
        funct7_in                   = 7'b0100000;

        alu_operation_class_in      = ALU_CLASS_REGISTER;
        register_write_in           = 1'b1;
        result_source_in            = RESULT_ALU;

        capture();

        if (illegal_out &&
            !register_write_out) begin

            pass("Illegal ALU control propagation");
        end
        else begin
            fail("Illegal ALU control propagation");
        end

        /*
         * Test 14: pipeline stall.
         */
        set_defaults();

        enable                      = 1'b0;
        rs1_value_in                = 32'h11111111;
        rs2_value_in                = 32'h22222222;
        alu_operation_class_in      = ALU_CLASS_REGISTER;

        capture();

        if (illegal_out &&
            !register_write_out) begin

            pass("EX/MEM stall holds previous payload");
        end
        else begin
            fail("EX/MEM stall holds previous payload");
        end

        /*
         * Test 15: pipeline flush.
         */
        set_defaults();

        flush = 1'b1;
        capture();

        if (!valid_out &&
            !fault_out &&
            !illegal_out &&
            !register_write_out &&
            !memory_read_out &&
            !memory_write_out) begin

            pass("Integrated EX-stage flush");
        end
        else begin
            fail("Integrated EX-stage flush");
        end

        if (errors == 0) begin
            $display(
                "\nALL 15 INTEGRATED EX-STAGE CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nINTEGRATED EX-STAGE TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule