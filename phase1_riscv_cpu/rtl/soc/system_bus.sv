`timescale 1ns/1ps

module system_bus (
    input  logic        clk,
    input  logic        reset,

    // CPU/master request channel
    input  logic        master_request_valid,
    output logic        master_request_ready,
    input  logic        master_write_enable,
    input  logic [31:0] master_address,
    input  logic [31:0] master_write_data,
    input  logic [3:0]  master_byte_enable,

    // CPU/master response channel
    output logic        master_response_valid,
    output logic [31:0] master_read_data,
    output logic        master_access_fault,

    // Data-memory request channel
    output logic        data_memory_request,
    output logic        data_memory_write_enable,
    output logic [31:0] data_memory_address,
    output logic [31:0] data_memory_write_data,
    output logic [3:0]  data_memory_byte_enable,

    // Data-memory response channel
    input  logic        data_memory_response_valid,
    input  logic [31:0] data_memory_read_data,
    input  logic        data_memory_access_fault,

    // Accelerator request channel
    output logic        accelerator_request,
    output logic        accelerator_write_enable,
    output logic [31:0] accelerator_address,
    output logic [31:0] accelerator_write_data,
    output logic [3:0]  accelerator_byte_enable,

    // Accelerator response channel
    input  logic        accelerator_response_valid,
    input  logic [31:0] accelerator_read_data,
    input  logic        accelerator_access_fault
);

    typedef enum logic [1:0] {
        BUS_IDLE,
        BUS_ISSUE,
        BUS_WAIT,
        BUS_RESPONSE
    } bus_state_t;

    typedef enum logic {
        TARGET_DATA_MEMORY,
        TARGET_ACCELERATOR
    } target_t;

    bus_state_t state;
    target_t    saved_target;

    logic        saved_write_enable;
    logic [31:0] saved_address;
    logic [31:0] saved_write_data;
    logic [3:0]  saved_byte_enable;

    logic [31:0] response_read_data_register;
    logic        response_access_fault_register;

    logic decoder_request_valid;
    logic decoder_data_memory_select;
    logic decoder_accelerator_select;
    logic decoder_unmapped_address;

    /*
     * A new request can be accepted only while the bus is idle.
     */
    assign master_request_ready =
        (state == BUS_IDLE);

    /*
     * The response is valid while the bus is in BUS_RESPONSE.
     */
    assign master_response_valid =
        (state == BUS_RESPONSE);

    assign master_read_data =
        response_read_data_register;

    assign master_access_fault =
        response_access_fault_register;

    /*
     * A request is accepted only when VALID and READY are both high.
     */
    assign decoder_request_valid =
        master_request_valid && master_request_ready;

    /*
     * Existing address decoder.
     */
    address_decoder decoder (
        .request_valid      (decoder_request_valid),
        .address            (master_address),
        .data_memory_select (decoder_data_memory_select),
        .accelerator_select (decoder_accelerator_select),
        .unmapped_address   (decoder_unmapped_address)
    );

    /*
     * Forward the saved request to the selected slave.
     *
     * The selected slave receives exactly one request pulse during
     * the BUS_ISSUE state.
     */
    always_comb begin
        data_memory_request      = 1'b0;
        data_memory_write_enable = saved_write_enable;
        data_memory_address      = saved_address;
        data_memory_write_data   = saved_write_data;
        data_memory_byte_enable  = saved_byte_enable;

        accelerator_request      = 1'b0;
        accelerator_write_enable = saved_write_enable;
        accelerator_address      = saved_address;
        accelerator_write_data   = saved_write_data;
        accelerator_byte_enable  = saved_byte_enable;

        if (state == BUS_ISSUE) begin
            if (saved_target == TARGET_DATA_MEMORY) begin
                data_memory_request = 1'b1;
            end
            else begin
                accelerator_request = 1'b1;
            end
        end
    end

    /*
     * System-bus control state machine.
     */
    always_ff @(posedge clk) begin
        if (reset) begin
            state                          <= BUS_IDLE;
            saved_target                   <= TARGET_DATA_MEMORY;
            saved_write_enable             <= 1'b0;
            saved_address                  <= 32'h0000_0000;
            saved_write_data               <= 32'h0000_0000;
            saved_byte_enable              <= 4'b0000;
            response_read_data_register    <= 32'h0000_0000;
            response_access_fault_register <= 1'b0;
        end
        else begin
            case (state)

                BUS_IDLE: begin
                    if (decoder_request_valid) begin
                        /*
                         * Capture the complete master request.
                         */
                        saved_write_enable <= master_write_enable;
                        saved_address      <= master_address;
                        saved_write_data   <= master_write_data;
                        saved_byte_enable  <= master_byte_enable;

                        if (decoder_data_memory_select) begin
                            saved_target <= TARGET_DATA_MEMORY;
                            state        <= BUS_ISSUE;
                        end
                        else if (decoder_accelerator_select) begin
                            saved_target <= TARGET_ACCELERATOR;
                            state        <= BUS_ISSUE;
                        end
                        else begin
                            /*
                             * Unmapped addresses are not forwarded to
                             * either slave.
                             */
                            response_read_data_register <=
                                32'h0000_0000;

                            response_access_fault_register <=
                                1'b1;

                            state <= BUS_RESPONSE;
                        end
                    end
                end

                BUS_ISSUE: begin
                    /*
                     * The selected slave samples its request on this
                     * rising edge.
                     */
                    state <= BUS_WAIT;
                end

                BUS_WAIT: begin
                    /*
                     * Wait for the response from the selected slave.
                     */
                    if ((saved_target == TARGET_DATA_MEMORY) &&
                        data_memory_response_valid) begin

                        response_read_data_register <=
                            data_memory_read_data;

                        response_access_fault_register <=
                            data_memory_access_fault;

                        state <= BUS_RESPONSE;
                    end
                    else if ((saved_target == TARGET_ACCELERATOR) &&
                             accelerator_response_valid) begin

                        response_read_data_register <=
                            accelerator_read_data;

                        response_access_fault_register <=
                            accelerator_access_fault;

                        state <= BUS_RESPONSE;
                    end
                end

                BUS_RESPONSE: begin
                    /*
                     * The response is presented to the master for one
                     * complete clock cycle.
                     */
                    state <= BUS_IDLE;
                end

                default: begin
                    state <= BUS_IDLE;
                end

            endcase
        end
    end

endmodule