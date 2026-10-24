`timescale 1ns/1ps

module memory_stage (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic flush,

    // Inputs from EX/MEM
    input logic        valid_in,
    input logic        fault_in,
    input logic        illegal_in,
    input logic [31:0] pc_plus4_in,
    input logic [31:0] alu_result_in,
    input logic [31:0] store_data_in,
    input logic [4:0]  rd_in,
    input logic [2:0]  funct3_in,
    input logic        register_write_in,
    input logic        memory_read_in,
    input logic        memory_write_in,
    input logic [1:0]  result_source_in,
    input logic        system_instruction_in,
    input logic        fence_instruction_in,

    // Pipeline control
    output logic memory_busy_out,

    // External valid/ready bus request
    output logic        bus_request_valid,
    input  logic        bus_request_ready,
    output logic        bus_write_enable,
    output logic [31:0] bus_address,
    output logic [31:0] bus_write_data,
    output logic [3:0]  bus_byte_enable,

    // External bus response
    input logic        bus_response_valid,
    input logic [31:0] bus_read_data,
    input logic        bus_access_fault,

    // Outputs to MEM/WB
    output logic        valid_out,
    output logic        fault_out,
    output logic        illegal_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] memory_data_out,
    output logic [4:0]  rd_out,
    output logic        register_write_out,
    output logic [1:0]  result_source_out,
    output logic        system_instruction_out,
    output logic        fence_instruction_out
);

    localparam logic [1:0] STATE_IDLE = 2'b00;
    localparam logic [1:0] STATE_WAIT = 2'b01;
    localparam logic [1:0] STATE_HOLD = 2'b10;

    logic [1:0] state;

    logic current_access_valid;
    logic current_memory_request;
    logic current_memory_write_enable;
    logic [31:0] current_memory_address;
    logic [31:0] current_memory_write_data;
    logic [3:0]  current_memory_byte_enable;
    logic [31:0] current_load_data;
    logic current_access_misaligned;
    logic current_illegal_memory_operation;

    logic pending_valid;
    logic pending_fault;
    logic pending_illegal;
    logic [31:0] pending_pc_plus4;
    logic [31:0] pending_alu_result;
    logic [31:0] pending_store_data;
    logic [4:0]  pending_rd;
    logic [2:0]  pending_funct3;
    logic pending_register_write;
    logic pending_memory_read;
    logic pending_memory_write;
    logic [1:0] pending_result_source;
    logic pending_system_instruction;
    logic pending_fence_instruction;

    logic response_memory_request_unused;
    logic response_write_enable_unused;
    logic [31:0] response_address_unused;
    logic [31:0] response_write_data_unused;
    logic [3:0]  response_byte_enable_unused;
    logic [31:0] response_load_data;
    logic response_access_misaligned;
    logic response_illegal_memory_operation;

    logic held_valid;
    logic held_fault;
    logic held_illegal;
    logic [31:0] held_pc_plus4;
    logic [31:0] held_alu_result;
    logic [31:0] held_memory_data;
    logic [4:0]  held_rd;
    logic held_register_write;
    logic [1:0] held_result_source;
    logic held_system_instruction;
    logic held_fence_instruction;

    logic mem_wb_enable;
    logic mem_wb_valid;
    logic mem_wb_fault;
    logic mem_wb_illegal;
    logic [31:0] mem_wb_pc_plus4;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_memory_data;
    logic [4:0]  mem_wb_rd;
    logic mem_wb_register_write;
    logic [1:0] mem_wb_result_source;
    logic mem_wb_system_instruction;
    logic mem_wb_fence_instruction;

    logic current_direct_fault;
    logic current_direct_illegal;

    /*
     * A memory operation can begin only when the stage is idle,
     * enabled and contains a valid instruction without an earlier
     * fault or illegal-instruction indication.
     */
    assign current_access_valid =
        (state == STATE_IDLE) &&
        enable &&
        valid_in &&
        !fault_in &&
        !illegal_in &&
        (memory_read_in || memory_write_in);

    /*
     * Generate address, write data, byte enables and alignment
     * checks for the current instruction.
     */
    load_store_control u_request_control (
        .memory_access_valid      (current_access_valid),
        .memory_read              (memory_read_in),
        .memory_write             (memory_write_in),
        .funct3                   (funct3_in),
        .address                  (alu_result_in),
        .store_data               (store_data_in),
        .memory_read_data         (32'h00000000),
        .memory_request           (current_memory_request),
        .memory_write_enable      (current_memory_write_enable),
        .memory_address           (current_memory_address),
        .memory_write_data        (current_memory_write_data),
        .memory_byte_enable       (current_memory_byte_enable),
        .load_data                (current_load_data),
        .access_misaligned        (current_access_misaligned),
        .illegal_memory_operation (current_illegal_memory_operation)
    );

    /*
     * The request remains valid while the external bus is not ready.
     * The pipeline is stalled during this time, so the EX/MEM values
     * remain stable.
     */
    assign bus_request_valid = current_memory_request;
    assign bus_write_enable  = current_memory_write_enable;
    assign bus_address       = current_memory_address;
    assign bus_write_data    = current_memory_write_data;
    assign bus_byte_enable   = current_memory_byte_enable;

    /*
     * Format the word returned by the bus into LB, LBU, LH, LHU
     * or LW result data using the saved instruction information.
     */
    load_store_control u_response_control (
        .memory_access_valid      (state == STATE_WAIT),
        .memory_read              (pending_memory_read),
        .memory_write             (pending_memory_write),
        .funct3                   (pending_funct3),
        .address                  (pending_alu_result),
        .store_data               (pending_store_data),
        .memory_read_data         (bus_read_data),
        .memory_request           (response_memory_request_unused),
        .memory_write_enable      (response_write_enable_unused),
        .memory_address           (response_address_unused),
        .memory_write_data        (response_write_data_unused),
        .memory_byte_enable       (response_byte_enable_unused),
        .load_data                (response_load_data),
        .access_misaligned        (response_access_misaligned),
        .illegal_memory_operation (
            response_illegal_memory_operation
        )
    );

    assign current_direct_fault =
        fault_in |
        (
            current_access_valid &&
            current_access_misaligned
        );

    assign current_direct_illegal =
        illegal_in |
        (
            current_access_valid &&
            current_illegal_memory_operation
        );

    /*
     * Memory-stage transaction controller.
     *
     * IDLE:
     *   Wait for a legal request and valid/ready handshake.
     *
     * WAIT:
     *   Request has been accepted. Wait for the bus response.
     *
     * HOLD:
     *   A response arrived while MEM/WB was disabled. Preserve it.
     */
    always_ff @(posedge clk) begin
        if (reset || flush) begin
            state <= STATE_IDLE;

            pending_valid              <= 1'b0;
            pending_fault              <= 1'b0;
            pending_illegal            <= 1'b0;
            pending_pc_plus4           <= 32'h00000004;
            pending_alu_result         <= 32'h00000000;
            pending_store_data         <= 32'h00000000;
            pending_rd                 <= 5'd0;
            pending_funct3             <= 3'd0;
            pending_register_write     <= 1'b0;
            pending_memory_read        <= 1'b0;
            pending_memory_write       <= 1'b0;
            pending_result_source      <= 2'b11;
            pending_system_instruction <= 1'b0;
            pending_fence_instruction  <= 1'b0;

            held_valid                 <= 1'b0;
            held_fault                 <= 1'b0;
            held_illegal               <= 1'b0;
            held_pc_plus4              <= 32'h00000004;
            held_alu_result            <= 32'h00000000;
            held_memory_data           <= 32'h00000000;
            held_rd                    <= 5'd0;
            held_register_write        <= 1'b0;
            held_result_source         <= 2'b11;
            held_system_instruction    <= 1'b0;
            held_fence_instruction     <= 1'b0;
        end
        else begin
            case (state)
                STATE_IDLE: begin
                    /*
                     * Save the instruction only when the bus accepts
                     * the request.
                     */
                    if (current_memory_request &&
                        bus_request_ready) begin

                        pending_valid      <= valid_in;
                        pending_fault      <= fault_in;
                        pending_illegal    <= illegal_in;
                        pending_pc_plus4   <= pc_plus4_in;
                        pending_alu_result <= alu_result_in;
                        pending_store_data <= store_data_in;
                        pending_rd         <= rd_in;
                        pending_funct3     <= funct3_in;

                        pending_register_write <=
                            register_write_in;

                        pending_memory_read  <= memory_read_in;
                        pending_memory_write <= memory_write_in;

                        pending_result_source <=
                            result_source_in;

                        pending_system_instruction <=
                            system_instruction_in;

                        pending_fence_instruction <=
                            fence_instruction_in;

                        state <= STATE_WAIT;
                    end
                end

                STATE_WAIT: begin
                    if (bus_response_valid) begin
                        if (enable) begin
                            state <= STATE_IDLE;
                        end
                        else begin
                            held_valid <= pending_valid;

                            held_fault <=
                                pending_fault |
                                bus_access_fault |
                                response_access_misaligned;

                            held_illegal <=
                                pending_illegal |
                                response_illegal_memory_operation;

                            held_pc_plus4    <= pending_pc_plus4;
                            held_alu_result  <= pending_alu_result;
                            held_memory_data <= response_load_data;
                            held_rd          <= pending_rd;

                            held_register_write <=
                                pending_register_write &&
                                !(
                                    pending_fault |
                                    bus_access_fault |
                                    response_access_misaligned |
                                    pending_illegal |
                                    response_illegal_memory_operation
                                );

                            held_result_source <=
                                pending_result_source;

                            held_system_instruction <=
                                pending_system_instruction;

                            held_fence_instruction <=
                                pending_fence_instruction;

                            state <= STATE_HOLD;
                        end
                    end
                end

                STATE_HOLD: begin
                    if (enable)
                        state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

    /*
     * The complete CPU pipeline remains stalled until:
     *
     * 1. The bus accepts the request.
     * 2. The selected slave completes the transaction.
     * 3. The response can enter MEM/WB.
     */
    always_comb begin
        memory_busy_out = 1'b0;

        case (state)
            STATE_IDLE: begin
                memory_busy_out = current_memory_request;
            end

            STATE_WAIT: begin
                memory_busy_out =
                    !(bus_response_valid && enable);
            end

            STATE_HOLD: begin
                memory_busy_out = !enable;
            end

            default: begin
                memory_busy_out = 1'b0;
            end
        endcase
    end

    /*
     * Select the information that enters the MEM/WB pipeline
     * register.
     */
    always_comb begin
        mem_wb_enable      = 1'b0;
        mem_wb_valid       = valid_in;
        mem_wb_fault       = current_direct_fault;
        mem_wb_illegal     = current_direct_illegal;
        mem_wb_pc_plus4    = pc_plus4_in;
        mem_wb_alu_result  = alu_result_in;
        mem_wb_memory_data = 32'h00000000;
        mem_wb_rd          = rd_in;

        mem_wb_register_write =
            register_write_in &&
            valid_in &&
            !current_direct_fault &&
            !current_direct_illegal;

        mem_wb_result_source = result_source_in;

        mem_wb_system_instruction =
            system_instruction_in &&
            !current_direct_fault &&
            !current_direct_illegal;

        mem_wb_fence_instruction =
            fence_instruction_in &&
            !current_direct_fault &&
            !current_direct_illegal;

        case (state)
            STATE_IDLE: begin
                /*
                 * Legal memory operations wait for a response.
                 * Normal instructions and immediate memory exceptions
                 * can enter MEM/WB directly.
                 */
                if (current_memory_request)
                    mem_wb_enable = 1'b0;
                else
                    mem_wb_enable = enable;
            end

            STATE_WAIT: begin
                mem_wb_enable = bus_response_valid && enable;

                mem_wb_valid = pending_valid;

                mem_wb_fault =
                    pending_fault |
                    bus_access_fault |
                    response_access_misaligned;

                mem_wb_illegal =
                    pending_illegal |
                    response_illegal_memory_operation;

                mem_wb_pc_plus4    = pending_pc_plus4;
                mem_wb_alu_result  = pending_alu_result;
                mem_wb_memory_data = response_load_data;
                mem_wb_rd          = pending_rd;

                mem_wb_register_write =
                    pending_register_write &&
                    !mem_wb_fault &&
                    !mem_wb_illegal;

                mem_wb_result_source =
                    pending_result_source;

                mem_wb_system_instruction =
                    pending_system_instruction &&
                    !mem_wb_fault &&
                    !mem_wb_illegal;

                mem_wb_fence_instruction =
                    pending_fence_instruction &&
                    !mem_wb_fault &&
                    !mem_wb_illegal;
            end

            STATE_HOLD: begin
                mem_wb_enable      = enable;
                mem_wb_valid       = held_valid;
                mem_wb_fault       = held_fault;
                mem_wb_illegal     = held_illegal;
                mem_wb_pc_plus4    = held_pc_plus4;
                mem_wb_alu_result  = held_alu_result;
                mem_wb_memory_data = held_memory_data;
                mem_wb_rd          = held_rd;

                mem_wb_register_write =
                    held_register_write;

                mem_wb_result_source =
                    held_result_source;

                mem_wb_system_instruction =
                    held_system_instruction;

                mem_wb_fence_instruction =
                    held_fence_instruction;
            end

            default: begin
                mem_wb_enable = 1'b0;
            end
        endcase
    end

    mem_wb_pipeline_register u_mem_wb_pipeline_register (
        .clk                    (clk),
        .reset                  (reset),
        .enable                 (mem_wb_enable),
        .flush                  (flush),

        .valid_in               (mem_wb_valid),
        .fault_in               (mem_wb_fault),
        .illegal_in             (mem_wb_illegal),

        .pc_plus4_in            (mem_wb_pc_plus4),
        .alu_result_in          (mem_wb_alu_result),
        .memory_data_in         (mem_wb_memory_data),

        .rd_in                  (mem_wb_rd),

        .register_write_in      (mem_wb_register_write),
        .result_source_in       (mem_wb_result_source),

        .system_instruction_in  (mem_wb_system_instruction),
        .fence_instruction_in   (mem_wb_fence_instruction),

        .valid_out              (valid_out),
        .fault_out              (fault_out),
        .illegal_out            (illegal_out),

        .pc_plus4_out           (pc_plus4_out),
        .alu_result_out         (alu_result_out),
        .memory_data_out        (memory_data_out),

        .rd_out                 (rd_out),

        .register_write_out     (register_write_out),
        .result_source_out      (result_source_out),

        .system_instruction_out (system_instruction_out),
        .fence_instruction_out  (fence_instruction_out)
    );

endmodule