`timescale 1ns/1ps

module tb_riscv_cpu;

    logic clk;
    logic reset;
    logic external_halt;

    logic halted_out;
    logic pipeline_stalled_out;
    logic pipeline_flushed_out;
    logic instruction_retired_out;
    logic exception_valid_out;
    logic system_event_valid_out;
    logic fence_completed_out;

    logic register_write_enable_out;
    logic [4:0]  register_write_address_out;
    logic [31:0] register_write_data_out;

    logic [31:0] fetch_pc_out;
    logic memory_busy_out;
    logic load_use_hazard_out;
    logic redirect_valid_out;
    logic [31:0] redirect_target_out;

    // CPU master bus signals
    logic        data_bus_request_valid;
    logic        data_bus_request_ready;
    logic        data_bus_write_enable;
    logic [31:0] data_bus_address;
    logic [31:0] data_bus_write_data;
    logic [3:0]  data_bus_byte_enable;

    logic        data_bus_response_valid;
    logic [31:0] data_bus_read_data;
    logic        data_bus_access_fault;

    // Data-memory slave signals
    logic        data_memory_request;
    logic        data_memory_write_enable;
    logic [31:0] data_memory_address;
    logic [31:0] data_memory_write_data;
    logic [3:0]  data_memory_byte_enable;

    logic        data_memory_response_valid;
    logic [31:0] data_memory_read_data;
    logic        data_memory_access_fault;

    // Accelerator-stub slave signals
    logic        accelerator_request;
    logic        accelerator_write_enable;
    logic [31:0] accelerator_address;
    logic [31:0] accelerator_write_data;
    logic [3:0]  accelerator_byte_enable;

    logic        accelerator_response_valid;
    logic [31:0] accelerator_read_data;
    logic        accelerator_access_fault;

    integer errors;
    integer cycles;
    integer retired_cycles;

    logic saw_load_use_hazard;
    logic saw_memory_busy;
    logic saw_branch_redirect;
    logic saw_jump_redirect;
    logic saw_data_bus_request;
    logic saw_data_bus_response;
    logic saw_data_bus_fault;

    riscv_cpu #(
        .INSTRUCTION_WORDS      (64),
        .RESET_PC               (32'h00000000),
        .INSTRUCTION_BASE       (32'h00000000),
        .INSTRUCTION_INIT_FILE  ("cpu_program.hex")
    ) dut (
        .clk                        (clk),
        .reset                      (reset),
        .external_halt              (external_halt),

        .data_bus_request_valid     (data_bus_request_valid),
        .data_bus_request_ready     (data_bus_request_ready),
        .data_bus_write_enable      (data_bus_write_enable),
        .data_bus_address           (data_bus_address),
        .data_bus_write_data        (data_bus_write_data),
        .data_bus_byte_enable       (data_bus_byte_enable),

        .data_bus_response_valid    (data_bus_response_valid),
        .data_bus_read_data         (data_bus_read_data),
        .data_bus_access_fault      (data_bus_access_fault),

        .halted_out                 (halted_out),
        .pipeline_stalled_out       (pipeline_stalled_out),
        .pipeline_flushed_out       (pipeline_flushed_out),
        .instruction_retired_out    (instruction_retired_out),
        .exception_valid_out        (exception_valid_out),
        .system_event_valid_out     (system_event_valid_out),
        .fence_completed_out        (fence_completed_out),

        .register_write_enable_out  (
            register_write_enable_out
        ),
        .register_write_address_out (
            register_write_address_out
        ),
        .register_write_data_out    (
            register_write_data_out
        ),

        .fetch_pc_out               (fetch_pc_out),
        .memory_busy_out            (memory_busy_out),
        .load_use_hazard_out        (load_use_hazard_out),
        .redirect_valid_out         (redirect_valid_out),
        .redirect_target_out        (redirect_target_out)
    );

    system_bus bus_inst (
        .clk                         (clk),
        .reset                       (reset),

        .master_request_valid        (data_bus_request_valid),
        .master_request_ready        (data_bus_request_ready),
        .master_write_enable         (data_bus_write_enable),
        .master_address              (data_bus_address),
        .master_write_data           (data_bus_write_data),
        .master_byte_enable          (data_bus_byte_enable),

        .master_response_valid       (data_bus_response_valid),
        .master_read_data            (data_bus_read_data),
        .master_access_fault         (data_bus_access_fault),

        .data_memory_request         (data_memory_request),
        .data_memory_write_enable    (data_memory_write_enable),
        .data_memory_address         (data_memory_address),
        .data_memory_write_data      (data_memory_write_data),
        .data_memory_byte_enable     (data_memory_byte_enable),

        .data_memory_response_valid  (
            data_memory_response_valid
        ),
        .data_memory_read_data       (data_memory_read_data),
        .data_memory_access_fault    (
            data_memory_access_fault
        ),

        .accelerator_request         (accelerator_request),
        .accelerator_write_enable    (accelerator_write_enable),
        .accelerator_address         (accelerator_address),
        .accelerator_write_data      (accelerator_write_data),
        .accelerator_byte_enable     (accelerator_byte_enable),

        .accelerator_response_valid  (
            accelerator_response_valid
        ),
        .accelerator_read_data       (accelerator_read_data),
        .accelerator_access_fault    (
            accelerator_access_fault
        )
    );

    data_memory #(
        .WORDS        (4096),
        .BASE_ADDRESS (32'h00000000),
        .INIT_FILE    ("")
    ) data_memory_inst (
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

    accelerator_stub accelerator_stub_inst (
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

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset) begin
            cycles <= cycles + 1;

            if (instruction_retired_out)
                retired_cycles <= retired_cycles + 1;

            if (load_use_hazard_out)
                saw_load_use_hazard <= 1'b1;

            if (memory_busy_out)
                saw_memory_busy <= 1'b1;

            if (data_bus_request_valid &&
                data_bus_request_ready)
                saw_data_bus_request <= 1'b1;

            if (data_bus_response_valid)
                saw_data_bus_response <= 1'b1;

            if (data_bus_response_valid &&
                data_bus_access_fault)
                saw_data_bus_fault <= 1'b1;

            if (redirect_valid_out &&
                redirect_target_out == 32'h00000028)
                saw_branch_redirect <= 1'b1;

            if (redirect_valid_out &&
                redirect_target_out == 32'h00000030)
                saw_jump_redirect <= 1'b1;
        end
    end

    task automatic check_value(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            if (actual === expected) begin
                $display(
                    "PASS: %s = %08h",
                    name,
                    actual
                );
            end
            else begin
                errors = errors + 1;

                $display(
                    "FAIL: %s expected=%08h received=%08h",
                    name,
                    expected,
                    actual
                );
            end
        end
    endtask

    task automatic check_flag(
        input string name,
        input logic actual
    );
        begin
            if (actual === 1'b1) begin
                $display("PASS: %s", name);
            end
            else begin
                errors = errors + 1;
                $display(
                    "FAIL: %s was not observed",
                    name
                );
            end
        end
    endtask

    initial begin
        clk                    = 1'b0;
        reset                  = 1'b1;
        external_halt          = 1'b0;

        errors                 = 0;
        cycles                 = 0;
        retired_cycles         = 0;

        saw_load_use_hazard    = 1'b0;
        saw_memory_busy        = 1'b0;
        saw_branch_redirect    = 1'b0;
        saw_jump_redirect      = 1'b0;
        saw_data_bus_request   = 1'b0;
        saw_data_bus_response  = 1'b0;
        saw_data_bus_fault     = 1'b0;

        /*
         * Keep reset asserted for four complete clock edges.
         * Deassert at the falling edge to avoid a reset race.
         */
        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (!system_event_valid_out &&
               cycles < 200)
            @(posedge clk);

        #1;

        if (!system_event_valid_out) begin
            errors = errors + 1;
            $display(
                "FAIL: CPU did not reach EBREAK within 200 cycles"
            );
        end
        else begin
            $display(
                "PASS: CPU reached EBREAK after %0d cycles",
                cycles
            );
        end

        check_flag(
            "CPU halted on SYSTEM instruction",
            halted_out
        );

        check_flag(
            "Load-use hazard detected",
            saw_load_use_hazard
        );

        check_flag(
            "External SoC-bus wait observed",
            saw_memory_busy
        );

        check_flag(
            "CPU data-bus request accepted",
            saw_data_bus_request
        );

        check_flag(
            "CPU data-bus response observed",
            saw_data_bus_response
        );

        check_flag(
            "Taken BEQ redirect observed",
            saw_branch_redirect
        );

        check_flag(
            "JAL redirect observed",
            saw_jump_redirect
        );

        if (saw_data_bus_fault) begin
            errors = errors + 1;
            $display(
                "FAIL: Unexpected data-bus access fault observed"
            );
        end
        else begin
            $display(
                "PASS: No unexpected data-bus access fault"
            );
        end

        check_value(
            "x0",
            dut.u_decode_stage.register_file_inst.registers[0],
            32'd0
        );

        check_value(
            "x1",
            dut.u_decode_stage.register_file_inst.registers[1],
            32'd5
        );

        check_value(
            "x2",
            dut.u_decode_stage.register_file_inst.registers[2],
            32'd7
        );

        check_value(
            "x3",
            dut.u_decode_stage.register_file_inst.registers[3],
            32'd12
        );

        check_value(
            "x4",
            dut.u_decode_stage.register_file_inst.registers[4],
            32'd7
        );

        check_value(
            "x5",
            dut.u_decode_stage.register_file_inst.registers[5],
            32'd12
        );

        check_value(
            "x6",
            dut.u_decode_stage.register_file_inst.registers[6],
            32'd17
        );

        check_value(
            "x7",
            dut.u_decode_stage.register_file_inst.registers[7],
            32'd17
        );

        check_value(
            "x8",
            dut.u_decode_stage.register_file_inst.registers[8],
            32'd0
        );

        check_value(
            "x9",
            dut.u_decode_stage.register_file_inst.registers[9],
            32'd44
        );

        check_value(
            "x10",
            dut.u_decode_stage.register_file_inst.registers[10],
            32'd0
        );

        check_value(
            "x11",
            dut.u_decode_stage.register_file_inst.registers[11],
            32'd45
        );

        check_value(
            "x12",
            dut.u_decode_stage.register_file_inst.registers[12],
            32'd45
        );

        check_value(
            "Data memory word 0",
            data_memory_inst.memory[0],
            32'd12
        );

        check_value(
            "Data memory word 1",
            data_memory_inst.memory[1],
            32'd45
        );

        $display("");

        if (errors == 0) begin
            $display(
                "ALL EXTERNAL-BUS RISC-V CPU CHECKS PASSED"
            );
        end
        else begin
            $display(
                "EXTERNAL-BUS RISC-V CPU TEST FAILED: %0d error(s)",
                errors
            );
        end

        $finish;
    end

endmodule