`timescale 1ns/1ps

module instruction_fetch_stage #(
    parameter integer WORDS = 16,
    parameter logic [31:0] RESET_PC = 32'h00000000,
    parameter logic [31:0] BASE_ADDR = 32'h00000000,
    parameter INIT_FILE = "program16.hex"
)(
    input  logic        clk,
    input  logic        reset,

    input  logic        stall,

    input  logic        redirect_valid,
    input  logic [31:0] redirect_pc,

    output logic [31:0] fetch_pc,

    output logic [31:0] if_id_pc,
    output logic [31:0] if_id_pc_plus4,
    output logic [31:0] if_id_instruction,
    output logic        if_id_valid,
    output logic        if_id_fault
);

    logic [31:0] pc;
    logic [31:0] pc_plus4;
    logic [31:0] next_pc;
    logic        pc_enable;

    logic        memory_read_enable;
    logic [31:0] memory_instruction;
    logic        memory_valid;
    logic        memory_fault;

    /*
     * Metadata belonging to the outstanding synchronous
     * instruction-memory request.
     */
    logic [31:0] response_pc;
    logic [31:0] response_pc_plus4;
    logic        response_pending;

    /*
     * One-entry response buffer.
     *
     * If instruction memory returns an instruction while IF/ID is
     * stalled, the response is stored here until the stall ends.
     */
    logic [31:0] buffered_pc;
    logic [31:0] buffered_pc_plus4;
    logic [31:0] buffered_instruction;
    logic        buffered_fault;
    logic        buffered_valid;

    logic [31:0] selected_pc;
    logic [31:0] selected_pc_plus4;
    logic [31:0] selected_instruction;
    logic        selected_valid;
    logic        selected_fault;

    /*
     * Redirect priority:
     *
     * redirect → update PC
     * stall    → hold PC
     * normal   → PC + 4
     */
    always_comb begin
        if (redirect_valid) begin
            pc_enable = 1'b1;
            next_pc   = redirect_pc;
        end
        else if (stall) begin
            pc_enable = 1'b0;
            next_pc   = pc;
        end
        else begin
            pc_enable = 1'b1;
            next_pc   = pc_plus4;
        end
    end

    /*
     * Do not issue a new memory request during reset, stall,
     * or redirect.
     */
    assign memory_read_enable =
        (!reset) &&
        (!stall) &&
        (!redirect_valid);

    assign fetch_pc = pc;

    program_counter #(
        .RESET_PC(RESET_PC)
    ) program_counter_inst (
        .clk       (clk),
        .reset     (reset),
        .pc_enable (pc_enable),
        .next_pc   (next_pc),
        .pc        (pc)
    );

    pc_plus4 pc_plus4_inst (
        .pc                 (pc),
        .pc_next_sequential (pc_plus4)
    );

    instruction_memory #(
        .WORDS     (WORDS),
        .BASE_ADDR (BASE_ADDR),
        .INIT_FILE (INIT_FILE)
    ) instruction_memory_inst (
        .clk               (clk),
        .reset             (reset),
        .read_enable       (memory_read_enable),
        .address           (pc),
        .instruction       (memory_instruction),
        .instruction_valid (memory_valid),
        .instruction_fault (memory_fault)
    );

    /*
     * Save the PC associated with each memory request.
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            response_pc       <= RESET_PC;
            response_pc_plus4 <= RESET_PC + 32'd4;
            response_pending  <= 1'b0;
        end
        else if (redirect_valid) begin
            response_pc       <= redirect_pc;
            response_pc_plus4 <= redirect_pc + 32'd4;
            response_pending  <= 1'b0;
        end
        else if (memory_read_enable) begin
            response_pc       <= pc;
            response_pc_plus4 <= pc_plus4;
            response_pending  <= 1'b1;
        end
    end

    /*
     * Capture an instruction-memory response if IF/ID is stalled.
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            buffered_pc          <= RESET_PC;
            buffered_pc_plus4    <= RESET_PC + 32'd4;
            buffered_instruction <= 32'h00000013;
            buffered_fault       <= 1'b0;
            buffered_valid       <= 1'b0;
        end
        else if (redirect_valid) begin
            /*
             * A redirect makes the buffered sequential instruction
             * incorrect, so discard it.
             */
            buffered_pc          <= redirect_pc;
            buffered_pc_plus4    <= redirect_pc + 32'd4;
            buffered_instruction <= 32'h00000013;
            buffered_fault       <= 1'b0;
            buffered_valid       <= 1'b0;
        end
        else begin
            if (stall &&
                memory_valid &&
                response_pending &&
                !buffered_valid) begin

                buffered_pc          <= response_pc;
                buffered_pc_plus4    <= response_pc_plus4;
                buffered_instruction <= memory_instruction;
                buffered_fault       <= memory_fault;
                buffered_valid       <= 1'b1;
            end
            else if (!stall && buffered_valid) begin
                /*
                 * The buffered response is consumed by IF/ID.
                 */
                buffered_valid <= 1'b0;
            end
        end
    end

    /*
     * Give buffered data priority over the direct memory response.
     */
    always_comb begin
        if (buffered_valid) begin
            selected_pc          = buffered_pc;
            selected_pc_plus4    = buffered_pc_plus4;
            selected_instruction = buffered_instruction;
            selected_valid       = 1'b1;
            selected_fault       = buffered_fault;
        end
        else begin
            selected_pc          = response_pc;
            selected_pc_plus4    = response_pc_plus4;
            selected_instruction = memory_instruction;
            selected_valid       = memory_valid &&
                                   response_pending;
            selected_fault       = memory_fault;
        end
    end

    if_id_pipeline_register if_id_pipeline_register_inst (
        .clk             (clk),
        .reset           (reset),
        .enable          (!stall),
        .flush           (redirect_valid),

        .pc_in           (selected_pc),
        .pc_plus4_in     (selected_pc_plus4),
        .instruction_in  (selected_instruction),
        .valid_in        (selected_valid),
        .fault_in        (selected_fault),

        .pc_out          (if_id_pc),
        .pc_plus4_out    (if_id_pc_plus4),
        .instruction_out (if_id_instruction),
        .valid_out       (if_id_valid),
        .fault_out       (if_id_fault)
    );

endmodule