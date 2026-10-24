`timescale 1ns/1ps

module load_store_control (
    input  logic        memory_access_valid,

    input  logic        memory_read,
    input  logic        memory_write,

    input  logic [2:0]  funct3,
    input  logic [31:0] address,

    input  logic [31:0] store_data,
    input  logic [31:0] memory_read_data,

    output logic        memory_request,
    output logic        memory_write_enable,

    output logic [31:0] memory_address,
    output logic [31:0] memory_write_data,
    output logic [3:0]  memory_byte_enable,

    output logic [31:0] load_data,

    output logic        access_misaligned,
    output logic        illegal_memory_operation
);

    /*
     * RV32I load funct3 values.
     */
    localparam logic [2:0] LOAD_BYTE          = 3'b000;
    localparam logic [2:0] LOAD_HALFWORD      = 3'b001;
    localparam logic [2:0] LOAD_WORD          = 3'b010;
    localparam logic [2:0] LOAD_BYTE_UNSIGNED = 3'b100;
    localparam logic [2:0] LOAD_HALF_UNSIGNED = 3'b101;

    /*
     * RV32I store funct3 values.
     */
    localparam logic [2:0] STORE_BYTE     = 3'b000;
    localparam logic [2:0] STORE_HALFWORD = 3'b001;
    localparam logic [2:0] STORE_WORD     = 3'b010;

    logic [7:0]  selected_byte;
    logic [15:0] selected_halfword;

    /*
     * Select a byte from the returned 32-bit memory word.
     *
     * The implementation follows RISC-V little-endian byte order.
     */
    always_comb begin
        case (address[1:0])
            2'b00:
                selected_byte = memory_read_data[7:0];

            2'b01:
                selected_byte = memory_read_data[15:8];

            2'b10:
                selected_byte = memory_read_data[23:16];

            2'b11:
                selected_byte = memory_read_data[31:24];

            default:
                selected_byte = 8'h00;
        endcase
    end

    /*
     * Select the lower or upper halfword.
     */
    always_comb begin
        if (address[1] == 1'b0)
            selected_halfword = memory_read_data[15:0];
        else
            selected_halfword = memory_read_data[31:16];
    end

    /*
     * Main load/store control logic.
     */
    always_comb begin
        memory_request           = 1'b0;
        memory_write_enable      = 1'b0;

        memory_address           = address;
        memory_write_data        = 32'h00000000;
        memory_byte_enable       = 4'b0000;

        load_data                = 32'h00000000;

        access_misaligned        = 1'b0;
        illegal_memory_operation = 1'b0;

        if (memory_access_valid) begin
            /*
             * A memory operation cannot be both a load and store.
             */
            if (memory_read && memory_write) begin
                illegal_memory_operation = 1'b1;
            end

            /*
             * Load instruction handling.
             */
            else if (memory_read) begin
                case (funct3)

                    /*
                     * LB: signed byte load.
                     */
                    LOAD_BYTE: begin
                        memory_request = 1'b1;

                        load_data = {
                            {24{selected_byte[7]}},
                            selected_byte
                        };
                    end

                    /*
                     * LH: signed halfword load.
                     */
                    LOAD_HALFWORD: begin
                        if (address[0] != 1'b0) begin
                            access_misaligned = 1'b1;
                        end
                        else begin
                            memory_request = 1'b1;

                            load_data = {
                                {16{selected_halfword[15]}},
                                selected_halfword
                            };
                        end
                    end

                    /*
                     * LW: complete 32-bit word load.
                     */
                    LOAD_WORD: begin
                        if (address[1:0] != 2'b00) begin
                            access_misaligned = 1'b1;
                        end
                        else begin
                            memory_request = 1'b1;
                            load_data      = memory_read_data;
                        end
                    end

                    /*
                     * LBU: unsigned byte load.
                     */
                    LOAD_BYTE_UNSIGNED: begin
                        memory_request = 1'b1;

                        load_data = {
                            24'h000000,
                            selected_byte
                        };
                    end

                    /*
                     * LHU: unsigned halfword load.
                     */
                    LOAD_HALF_UNSIGNED: begin
                        if (address[0] != 1'b0) begin
                            access_misaligned = 1'b1;
                        end
                        else begin
                            memory_request = 1'b1;

                            load_data = {
                                16'h0000,
                                selected_halfword
                            };
                        end
                    end

                    default: begin
                        illegal_memory_operation = 1'b1;
                    end

                endcase
            end

            /*
             * Store instruction handling.
             */
            else if (memory_write) begin
                memory_write_enable = 1'b1;

                case (funct3)

                    /*
                     * SB: replicate the lower byte across all lanes.
                     * The byte-enable signal selects the actual lane.
                     */
                    STORE_BYTE: begin
                        memory_request = 1'b1;

                        memory_write_data = {
                            4{store_data[7:0]}
                        };

                        case (address[1:0])
                            2'b00:
                                memory_byte_enable = 4'b0001;

                            2'b01:
                                memory_byte_enable = 4'b0010;

                            2'b10:
                                memory_byte_enable = 4'b0100;

                            2'b11:
                                memory_byte_enable = 4'b1000;

                            default:
                                memory_byte_enable = 4'b0000;
                        endcase
                    end

                    /*
                     * SH: replicate the lower halfword.
                     * Alignment decides whether the lower or upper
                     * two byte lanes are enabled.
                     */
                    STORE_HALFWORD: begin
                        if (address[0] != 1'b0) begin
                            access_misaligned   = 1'b1;
                            memory_write_enable = 1'b0;
                        end
                        else begin
                            memory_request = 1'b1;

                            memory_write_data = {
                                2{store_data[15:0]}
                            };

                            if (address[1] == 1'b0)
                                memory_byte_enable = 4'b0011;
                            else
                                memory_byte_enable = 4'b1100;
                        end
                    end

                    /*
                     * SW: complete 32-bit word write.
                     */
                    STORE_WORD: begin
                        if (address[1:0] != 2'b00) begin
                            access_misaligned   = 1'b1;
                            memory_write_enable = 1'b0;
                        end
                        else begin
                            memory_request     = 1'b1;
                            memory_write_data  = store_data;
                            memory_byte_enable = 4'b1111;
                        end
                    end

                    default: begin
                        illegal_memory_operation = 1'b1;
                        memory_write_enable      = 1'b0;
                    end

                endcase
            end

            /*
             * A valid pipeline entry with neither read nor write
             * is not a memory transaction.
             */
            else begin
                memory_request      = 1'b0;
                memory_write_enable = 1'b0;
            end
        end
    end

endmodule