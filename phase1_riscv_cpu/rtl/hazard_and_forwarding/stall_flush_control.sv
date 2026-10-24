`timescale 1ns/1ps

module stall_flush_control (
    /*
     * Pipeline-control requests.
     */
    input logic pipeline_halt,
    input logic memory_busy,
    input logic redirect_valid,
    input logic load_use_hazard,

    /*
     * Program-counter and pipeline-register enables.
     */
    output logic pc_enable,

    output logic if_id_enable,
    output logic id_ex_enable,
    output logic ex_mem_enable,
    output logic mem_wb_enable,

    /*
     * Pipeline-register flush controls.
     */
    output logic if_id_flush,
    output logic id_ex_flush,
    output logic ex_mem_flush,
    output logic mem_wb_flush,

    /*
     * Status outputs for testing and processor monitoring.
     */
    output logic pipeline_stalled,
    output logic pipeline_flushed
);

    always_comb begin
        /*
         * Normal operation: all stages advance.
         */
        pc_enable     = 1'b1;

        if_id_enable  = 1'b1;
        id_ex_enable  = 1'b1;
        ex_mem_enable = 1'b1;
        mem_wb_enable = 1'b1;

        if_id_flush   = 1'b0;
        id_ex_flush   = 1'b0;
        ex_mem_flush  = 1'b0;
        mem_wb_flush  = 1'b0;

        pipeline_stalled = 1'b0;
        pipeline_flushed = 1'b0;

        /*
         * Highest priority: stop the CPU after an exception or
         * externally requested halt.
         */
        if (pipeline_halt) begin
            pc_enable     = 1'b0;

            if_id_enable  = 1'b0;
            id_ex_enable  = 1'b0;
            ex_mem_enable = 1'b0;
            mem_wb_enable = 1'b0;

            pipeline_stalled = 1'b1;
        end

        /*
         * Synchronous data memory is still processing a request.
         *
         * Hold PC through EX/MEM. MEM/WB remains enabled so that
         * the returning memory result can enter the WB stage.
         */
        else if (memory_busy) begin
            pc_enable     = 1'b0;

            if_id_enable  = 1'b0;
            id_ex_enable  = 1'b0;
            ex_mem_enable = 1'b0;

            mem_wb_enable = 1'b1;

            pipeline_stalled = 1'b1;
        end

        /*
         * A taken branch, JAL or JALR invalidates the sequential
         * instructions currently in IF and ID.
         *
         * The branch instruction itself is allowed to move from
         * EX into EX/MEM.
         */
        else if (redirect_valid) begin
            pc_enable     = 1'b1;

            if_id_enable  = 1'b1;
            id_ex_enable  = 1'b1;
            ex_mem_enable = 1'b1;
            mem_wb_enable = 1'b1;

            if_id_flush   = 1'b1;
            id_ex_flush   = 1'b1;

            pipeline_flushed = 1'b1;
        end

        /*
         * Load-use dependency:
         *
         * Hold the PC and IF/ID instruction.
         * Insert a bubble into ID/EX.
         * Allow the load already in EX to move into EX/MEM.
         */
        else if (load_use_hazard) begin
            pc_enable     = 1'b0;

            if_id_enable  = 1'b0;
            id_ex_enable  = 1'b1;
            ex_mem_enable = 1'b1;
            mem_wb_enable = 1'b1;

            id_ex_flush   = 1'b1;

            pipeline_stalled = 1'b1;
            pipeline_flushed = 1'b1;
        end
    end

endmodule