`timescale 1ns/1ps

module tb_stall_flush_control;

    logic pipeline_halt;
    logic memory_busy;
    logic redirect_valid;
    logic load_use_hazard;

    logic pc_enable;

    logic if_id_enable;
    logic id_ex_enable;
    logic ex_mem_enable;
    logic mem_wb_enable;

    logic if_id_flush;
    logic id_ex_flush;
    logic ex_mem_flush;
    logic mem_wb_flush;

    logic pipeline_stalled;
    logic pipeline_flushed;

    integer errors;

    stall_flush_control dut (
        .pipeline_halt   (pipeline_halt),
        .memory_busy     (memory_busy),
        .redirect_valid  (redirect_valid),
        .load_use_hazard (load_use_hazard),

        .pc_enable       (pc_enable),

        .if_id_enable    (if_id_enable),
        .id_ex_enable    (id_ex_enable),
        .ex_mem_enable   (ex_mem_enable),
        .mem_wb_enable   (mem_wb_enable),

        .if_id_flush     (if_id_flush),
        .id_ex_flush     (id_ex_flush),
        .ex_mem_flush    (ex_mem_flush),
        .mem_wb_flush    (mem_wb_flush),

        .pipeline_stalled(pipeline_stalled),
        .pipeline_flushed(pipeline_flushed)
    );

    task automatic defaults;
        begin
            pipeline_halt  = 1'b0;
            memory_busy    = 1'b0;
            redirect_valid = 1'b0;
            load_use_hazard= 1'b0;
        end
    endtask

    task automatic pass(input string name);
        begin
            $display("PASS: %s", name);
        end
    endtask

    task automatic fail(input string name);
        begin
            errors = errors + 1;
            $display("FAIL: %s", name);
        end
    endtask

    initial begin
        errors = 0;

        /*
         * Test 1: normal pipeline operation.
         */
        defaults();
        #1;

        if (pc_enable &&
            if_id_enable &&
            id_ex_enable &&
            ex_mem_enable &&
            mem_wb_enable &&
            !if_id_flush &&
            !id_ex_flush &&
            !ex_mem_flush &&
            !mem_wb_flush &&
            !pipeline_stalled &&
            !pipeline_flushed) begin

            pass("Normal pipeline operation");
        end
        else begin
            fail("Normal pipeline operation");
        end

        /*
         * Test 2: load-use hazard.
         */
        defaults();

        load_use_hazard = 1'b1;
        #1;

        if (!pc_enable &&
            !if_id_enable &&
            id_ex_enable &&
            ex_mem_enable &&
            mem_wb_enable &&
            !if_id_flush &&
            id_ex_flush &&
            !ex_mem_flush &&
            !mem_wb_flush &&
            pipeline_stalled &&
            pipeline_flushed) begin

            pass("Load-use hazard control");
        end
        else begin
            fail("Load-use hazard control");
        end

        /*
         * Test 3: redirect flush.
         */
        defaults();

        redirect_valid = 1'b1;
        #1;

        if (pc_enable &&
            if_id_enable &&
            id_ex_enable &&
            ex_mem_enable &&
            mem_wb_enable &&
            if_id_flush &&
            id_ex_flush &&
            !ex_mem_flush &&
            !mem_wb_flush &&
            !pipeline_stalled &&
            pipeline_flushed) begin

            pass("Branch and jump redirect control");
        end
        else begin
            fail("Branch and jump redirect control");
        end

        /*
         * Test 4: memory busy.
         */
        defaults();

        memory_busy = 1'b1;
        #1;

        if (!pc_enable &&
            !if_id_enable &&
            !id_ex_enable &&
            !ex_mem_enable &&
            mem_wb_enable &&
            !if_id_flush &&
            !id_ex_flush &&
            !ex_mem_flush &&
            !mem_wb_flush &&
            pipeline_stalled &&
            !pipeline_flushed) begin

            pass("Synchronous memory wait control");
        end
        else begin
            fail("Synchronous memory wait control");
        end

        /*
         * Test 5: pipeline halt.
         */
        defaults();

        pipeline_halt = 1'b1;
        #1;

        if (!pc_enable &&
            !if_id_enable &&
            !id_ex_enable &&
            !ex_mem_enable &&
            !mem_wb_enable &&
            pipeline_stalled &&
            !pipeline_flushed) begin

            pass("Pipeline halt control");
        end
        else begin
            fail("Pipeline halt control");
        end

        /*
         * Test 6: memory busy has priority over redirect.
         */
        defaults();

        memory_busy    = 1'b1;
        redirect_valid = 1'b1;
        #1;

        if (!pc_enable &&
            !if_id_enable &&
            !id_ex_enable &&
            !ex_mem_enable &&
            mem_wb_enable &&
            !if_id_flush &&
            !id_ex_flush &&
            pipeline_stalled &&
            !pipeline_flushed) begin

            pass("Memory wait priority over redirect");
        end
        else begin
            fail("Memory wait priority over redirect");
        end

        /*
         * Test 7: redirect has priority over load-use hazard.
         */
        defaults();

        redirect_valid  = 1'b1;
        load_use_hazard = 1'b1;
        #1;

        if (pc_enable &&
            if_id_enable &&
            if_id_flush &&
            id_ex_flush &&
            !pipeline_stalled &&
            pipeline_flushed) begin

            pass("Redirect priority over load-use hazard");
        end
        else begin
            fail("Redirect priority over load-use hazard");
        end

        /*
         * Test 8: pipeline halt has priority over all requests.
         */
        defaults();

        pipeline_halt   = 1'b1;
        memory_busy     = 1'b1;
        redirect_valid  = 1'b1;
        load_use_hazard = 1'b1;
        #1;

        if (!pc_enable &&
            !if_id_enable &&
            !id_ex_enable &&
            !ex_mem_enable &&
            !mem_wb_enable &&
            !if_id_flush &&
            !id_ex_flush &&
            !ex_mem_flush &&
            !mem_wb_flush &&
            pipeline_stalled &&
            !pipeline_flushed) begin

            pass("Pipeline halt has highest priority");
        end
        else begin
            fail("Pipeline halt has highest priority");
        end

        /*
         * Test 9: releasing memory busy restores operation.
         */
        defaults();

        memory_busy = 1'b1;
        #1;

        memory_busy = 1'b0;
        #1;

        if (pc_enable &&
            if_id_enable &&
            id_ex_enable &&
            ex_mem_enable &&
            mem_wb_enable &&
            !pipeline_stalled &&
            !pipeline_flushed) begin

            pass("Pipeline resumes after memory wait");
        end
        else begin
            fail("Pipeline resumes after memory wait");
        end

        /*
         * Test 10: releasing load-use hazard restores operation.
         */
        defaults();

        load_use_hazard = 1'b1;
        #1;

        load_use_hazard = 1'b0;
        #1;

        if (pc_enable &&
            if_id_enable &&
            id_ex_enable &&
            ex_mem_enable &&
            mem_wb_enable &&
            !if_id_flush &&
            !id_ex_flush &&
            !pipeline_stalled) begin

            pass("Pipeline resumes after load-use hazard");
        end
        else begin
            fail("Pipeline resumes after load-use hazard");
        end

        /*
         * Test 11: redirect never flushes the branch itself.
         */
        defaults();

        redirect_valid = 1'b1;
        #1;

        if (!ex_mem_flush &&
            ex_mem_enable) begin

            pass("Redirect preserves executing branch");
        end
        else begin
            fail("Redirect preserves executing branch");
        end

        /*
         * Test 12: memory response path remains active.
         */
        defaults();

        memory_busy = 1'b1;
        #1;

        if (mem_wb_enable &&
            !mem_wb_flush) begin

            pass("MEM/WB remains active during memory wait");
        end
        else begin
            fail("MEM/WB remains active during memory wait");
        end

        if (errors == 0) begin
            $display(
                "\nALL 12 STALL-FLUSH CONTROL CHECKS PASSED"
            );
        end
        else begin
            $display(
                "\nSTALL-FLUSH CONTROL TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule