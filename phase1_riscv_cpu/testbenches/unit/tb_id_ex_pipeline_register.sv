`timescale 1ns/1ps

module tb_id_ex_pipeline_register;

    logic clk;
    logic reset;
    logic enable;
    logic flush;

    logic valid_in;
    logic fault_in;
    logic illegal_in;

    logic [31:0] pc_in;
    logic [31:0] pc_plus4_in;
    logic [31:0] immediate_in;
    logic [31:0] rs1_data_in;
    logic [31:0] rs2_data_in;

    logic [4:0] rs1_in;
    logic [4:0] rs2_in;
    logic [4:0] rd_in;

    logic [6:0] opcode_in;
    logic [2:0] funct3_in;
    logic [6:0] funct7_in;

    logic register_write_in;
    logic memory_read_in;
    logic memory_write_in;
    logic branch_in;
    logic jump_in;
    logic jump_register_in;
    logic alu_source_a_pc_in;
    logic alu_source_b_immediate_in;
    logic uses_rs1_in;
    logic uses_rs2_in;
    logic [2:0] alu_operation_class_in;
    logic [1:0] result_source_in;
    logic system_instruction_in;
    logic fence_instruction_in;

    logic valid_out;
    logic fault_out;
    logic illegal_out;

    logic [31:0] pc_out;
    logic [31:0] pc_plus4_out;
    logic [31:0] immediate_out;
    logic [31:0] rs1_data_out;
    logic [31:0] rs2_data_out;

    logic [4:0] rs1_out;
    logic [4:0] rs2_out;
    logic [4:0] rd_out;

    logic [6:0] opcode_out;
    logic [2:0] funct3_out;
    logic [6:0] funct7_out;

    logic register_write_out;
    logic memory_read_out;
    logic memory_write_out;
    logic branch_out;
    logic jump_out;
    logic jump_register_out;
    logic alu_source_a_pc_out;
    logic alu_source_b_immediate_out;
    logic uses_rs1_out;
    logic uses_rs2_out;
    logic [2:0] alu_operation_class_out;
    logic [1:0] result_source_out;
    logic system_instruction_out;
    logic fence_instruction_out;

    integer checks;
    integer errors;

    id_ex_pipeline_register dut (.*);

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_bubble(
        input string test_name
    );
        begin
            if ((valid_out          !== 1'b0) ||
                (register_write_out !== 1'b0) ||
                (memory_read_out    !== 1'b0) ||
                (memory_write_out   !== 1'b0) ||
                (branch_out         !== 1'b0) ||
                (jump_out           !== 1'b0)) begin

                errors = errors + 1;
                $display("FAIL: %s", test_name);
            end
            else begin
                checks = checks + 1;
                $display("PASS: %s", test_name);
            end
        end
    endtask

    task automatic check_addi_payload(
        input string test_name
    );
        begin
            if ((valid_out                  !== 1'b1)        ||
                (fault_out                  !== 1'b0)        ||
                (illegal_out                !== 1'b0)        ||
                (pc_out                     !== 32'h00000000)||
                (pc_plus4_out               !== 32'h00000004)||
                (immediate_out              !== 32'h00000005)||
                (rs1_data_out               !== 32'h00000000)||
                (rs2_data_out               !== 32'h11111111)||
                (rs1_out                    !== 5'd0)        ||
                (rs2_out                    !== 5'd5)        ||
                (rd_out                     !== 5'd1)        ||
                (opcode_out                 !== 7'b0010011) ||
                (funct3_out                 !== 3'b000)     ||
                (funct7_out                 !== 7'b0000000) ||
                (register_write_out         !== 1'b1)        ||
                (memory_read_out            !== 1'b0)        ||
                (memory_write_out           !== 1'b0)        ||
                (alu_source_b_immediate_out !== 1'b1)        ||
                (uses_rs1_out               !== 1'b1)        ||
                (uses_rs2_out               !== 1'b0)        ||
                (alu_operation_class_out    !== 3'b011)     ||
                (result_source_out          !== 2'b00)) begin

                errors = errors + 1;
                $display("FAIL: %s", test_name);
            end
            else begin
                checks = checks + 1;
                $display("PASS: %s", test_name);
            end
        end
    endtask

    initial begin
        checks = 0;
        errors = 0;

        reset  = 1'b1;
        enable = 1'b0;
        flush  = 1'b0;

        valid_in  = 1'b0;
        fault_in  = 1'b0;
        illegal_in= 1'b0;

        pc_in          = 32'h00000000;
        pc_plus4_in    = 32'h00000004;
        immediate_in   = 32'h00000000;
        rs1_data_in    = 32'h00000000;
        rs2_data_in    = 32'h00000000;

        rs1_in = 5'd0;
        rs2_in = 5'd0;
        rd_in  = 5'd0;

        opcode_in = 7'd0;
        funct3_in = 3'd0;
        funct7_in = 7'd0;

        register_write_in = 1'b0;
        memory_read_in    = 1'b0;
        memory_write_in   = 1'b0;
        branch_in         = 1'b0;
        jump_in           = 1'b0;
        jump_register_in  = 1'b0;

        alu_source_a_pc_in         = 1'b0;
        alu_source_b_immediate_in  = 1'b0;

        uses_rs1_in = 1'b0;
        uses_rs2_in = 1'b0;

        alu_operation_class_in = 3'b111;
        result_source_in       = 2'b11;

        system_instruction_in = 1'b0;
        fence_instruction_in  = 1'b0;

        /*
         * Test 1: synchronous reset.
         */
        @(posedge clk);
        #1;

        check_bubble("Reset creates ID/EX bubble");

        /*
         * Test 2: capture ADDI instruction information.
         */
        reset  = 1'b0;
        enable = 1'b1;
        flush  = 1'b0;

        valid_in   = 1'b1;
        fault_in   = 1'b0;
        illegal_in = 1'b0;

        pc_in        = 32'h00000000;
        pc_plus4_in  = 32'h00000004;
        immediate_in = 32'h00000005;
        rs1_data_in  = 32'h00000000;
        rs2_data_in  = 32'h11111111;

        rs1_in = 5'd0;
        rs2_in = 5'd5;
        rd_in  = 5'd1;

        opcode_in = 7'b0010011;
        funct3_in = 3'b000;
        funct7_in = 7'b0000000;

        register_write_in = 1'b1;
        memory_read_in    = 1'b0;
        memory_write_in   = 1'b0;
        branch_in         = 1'b0;
        jump_in           = 1'b0;
        jump_register_in  = 1'b0;

        alu_source_a_pc_in        = 1'b0;
        alu_source_b_immediate_in = 1'b1;

        uses_rs1_in = 1'b1;
        uses_rs2_in = 1'b0;

        alu_operation_class_in = 3'b011;
        result_source_in       = 2'b00;

        @(posedge clk);
        #1;

        check_addi_payload("Capture complete ADDI payload");

        /*
         * Test 3: enable=0 must hold all previous values.
         */
        enable = 1'b0;

        pc_in             = 32'hAAAAAAAA;
        immediate_in      = 32'hBBBBBBBB;
        rs1_data_in       = 32'hCCCCCCCC;
        register_write_in = 1'b0;
        memory_write_in   = 1'b1;

        @(posedge clk);
        #1;

        check_addi_payload("Stall holds ID/EX payload");

        /*
         * Test 4: flush has priority over enable.
         */
        enable = 1'b1;
        flush  = 1'b1;

        @(posedge clk);
        #1;

        check_bubble("Flush inserts ID/EX bubble");

        /*
         * Test 5: capture a faulted entry.
         */
        flush      = 1'b0;
        valid_in   = 1'b1;
        fault_in   = 1'b1;
        illegal_in = 1'b0;

        register_write_in = 1'b0;
        memory_read_in    = 1'b0;
        memory_write_in   = 1'b0;

        @(posedge clk);
        #1;

        if ((valid_out   !== 1'b1) ||
            (fault_out   !== 1'b1) ||
            (illegal_out !== 1'b0)) begin

            errors = errors + 1;
            $display("FAIL: Capture faulted pipeline entry");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Capture faulted pipeline entry");
        end

        /*
         * Test 6: capture an illegal instruction entry.
         */
        fault_in   = 1'b0;
        illegal_in = 1'b1;

        @(posedge clk);
        #1;

        if ((valid_out   !== 1'b1) ||
            (fault_out   !== 1'b0) ||
            (illegal_out !== 1'b1)) begin

            errors = errors + 1;
            $display("FAIL: Capture illegal pipeline entry");
        end
        else begin
            checks = checks + 1;
            $display("PASS: Capture illegal pipeline entry");
        end

        /*
         * Test 7: reset has highest priority.
         */
        reset  = 1'b1;
        flush  = 1'b1;
        enable = 1'b1;

        @(posedge clk);
        #1;

        check_bubble("Reset has highest priority");

        $display("");

        if (errors == 0) begin
            $display(
                "ALL %0d ID/EX PIPELINE REGISTER CHECKS PASSED",
                checks
            );
        end
        else begin
            $display(
                "ID/EX PIPELINE REGISTER TEST FAILED: %0d error(s)",
                errors
            );

            $fatal(1);
        end

        $finish;
    end

endmodule