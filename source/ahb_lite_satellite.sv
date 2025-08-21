`timescale 1ns / 10ps

module ahb_lite_satellite (
    input logic clk,
    input logic n_rst,
    //rx
    input logic [2:0] RX_packet,
    input logic RX_data_ready,
    input logic RX_transfer_active,
    input logic RX_error,
    //data buffer
    input logic [6:0] buffer_occupancy, raddr,
    input logic [7:0] RX_data,
    input logic clear_done,
    output logic d_mode,
    output logic get_RX_data,
    output logic store_TX_data,
    output logic [7:0] TX_data,
    output logic clear,
    //tx
    input logic TX_error,
    input logic TX_transfer_active,
    input logic packet_done,
    output logic [2:0] TX_packet,
    //satellite
    input logic hsel,
    input logic [3:0] haddr,
    input logic [2:0] hsize,
    input logic [1:0] htrans,
    input logic hwrite,
    input logic [2:0] hburst,
    input logic [31:0] hwdata,
    output logic hready,
    output logic [31:0] hrdata,
    output logic hresp
);

    logic stall, error, last_hwrite, RX_transfer_ready, last_hwrite_RAW;
    logic [31:0] data_buffer_reg;
    logic [31:0] next_data_buffer_reg;
    logic [7:0] next_tx_packet_control_reg, next_flush_buffer_control_reg;
    logic [15:0] error_reg, status_reg;
    logic [7:0] buffer_occupancy_reg, tx_packet_control_reg, flush_buffer_control_reg;
    logic [3:0] last_haddr, last_haddr_RAW;
    logic TX_transfer_ready;
    logic w_error, r_error;
    logic [2:0] last_hsize;

    typedef enum logic [4:0] {TX_IDLE, LOAD0, LOAD1, LOAD2, LOAD3, WAIT0, WAIT1, WAIT2, WAIT3} TX_state_t; 
    TX_state_t TX_state, next_TX_state;
    logic [1:0] TX_current_hsize, next_TX_current_hsize;

    typedef enum logic [4:0] {WAIT_RX_READY, RX_IDLE, ADDR0, ADDR1, ADDR2, ADDR3, WAIT_ADDR0, WAIT_ADDR1, WAIT_ADDR2, WAIT_ADDR3} RX_state_t; 
    RX_state_t RX_state, next_RX_state;
    logic [1:0] RX_current_hsize, next_RX_current_hsize;

    typedef enum logic [1:0] {WAIT, ERROR1, ERROR2, HIGH} hready_state_t;
    hready_state_t hready_state, next_hready_state;

    assign d_mode = TX_transfer_active;
    assign error = w_error || r_error;

    //Phase of the AHB
    typedef enum logic [1:0] {
        IDLE = 0,
        BUSY = 1, 
        NONSEQ = 2, 
        SEQ = 3
    }state_t;
    state_t state, last_state, last_state_RX;
    assign state = (htrans <= 3) ? state_t'(htrans) : IDLE;

    
    //HREADY and HRESP logic 
    always_ff @( posedge clk, negedge n_rst ) begin
        if (~n_rst) begin
            last_hwrite <= 0;
            last_haddr <= 0;
            last_hsize <= 0;
            last_state_RX <= IDLE;
        end else if (hready) begin
            last_hwrite <= hwrite;
            last_haddr <= haddr;
            last_hsize <= hsize;
            last_state_RX <= state;
        end 
    end

    always_ff @( posedge clk, negedge n_rst ) begin
        if (~n_rst) begin
            last_hwrite_RAW <= 0;
            last_haddr_RAW <= 0;
            last_state <= IDLE;
        end else begin
            last_hwrite_RAW <= hwrite;
            last_haddr_RAW<= haddr;
            last_state <= state;
        end 
    end

    //assign TX_transfer_ready = (hsel && (last_state == NONSEQ || last_state == SEQ) && last_hwrite && (last_haddr == 0 || last_haddr == 1 || last_haddr == 2 || last_haddr == 3)) ? 1 : 0;
    assign TX_transfer_ready = (hsel && (state == NONSEQ || state == SEQ) && hwrite && (haddr == 0 || haddr == 1 || haddr == 2 || haddr == 3)) ? 1 : 0;
    assign RX_transfer_ready = (hsel && (state == NONSEQ || state == SEQ) && ~hwrite && (haddr == 0 || haddr == 1 || haddr == 2 || haddr == 3)) ? 1 : 0;

    always_comb begin
    next_hready_state = hready_state;
    case(hready_state)
        HIGH: begin
            hready = 1;
            hresp = 0;
            if(error) next_hready_state = ERROR1;
            else if (stall) next_hready_state = WAIT;
            else next_hready_state = HIGH;
        end
        ERROR1: begin
            hready = 0;
            hresp = 1;
            next_hready_state = ERROR2;
        end
        ERROR2: begin
            hready = 1;
            hresp = 1;
            if(error) next_hready_state = ERROR1;
            else if (stall) next_hready_state = WAIT;
            else next_hready_state = HIGH;
        end
        WAIT: begin
            hready = 0;
            hresp = 0;
            if(error) next_hready_state = ERROR1;
            else if (stall) next_hready_state = WAIT;
            else next_hready_state = HIGH;
        end
        default: begin
            hready = 1;
            hresp = 0;
            if(error) next_hready_state = ERROR1;
            else if (stall) next_hready_state = WAIT;
            else next_hready_state = HIGH;
        end
    endcase

    //RAW HAZARD stalls
    if(hsel && (state == NONSEQ || state == SEQ) && ~hwrite && last_hwrite_RAW && (last_haddr_RAW == haddr)) hready = 0;
    end

    //TX_packet
    assign TX_packet = tx_packet_control_reg[2:0];

    //READ Registers
    assign status_reg = {7'b0, TX_transfer_active, RX_transfer_active, 3'b0, RX_packet, RX_data_ready}; 
    assign error_reg = {7'b0, TX_error, 7'b0,RX_error};
    assign buffer_occupancy_reg = {1'b0, buffer_occupancy};

    //WRITE Registers
    assign clear = flush_buffer_control_reg[0];
    always_ff @( posedge clk, negedge n_rst ) begin
        if(~n_rst)begin
            data_buffer_reg <= 0;
            tx_packet_control_reg <= 0;
            flush_buffer_control_reg <= 0;
            hready_state <= HIGH;
        end else begin
            hready_state <= next_hready_state;
            data_buffer_reg <= next_data_buffer_reg;
            tx_packet_control_reg <= next_tx_packet_control_reg;
            flush_buffer_control_reg <= next_flush_buffer_control_reg;
        end
    end

    //WRITE logic
    always_comb begin

        next_data_buffer_reg = data_buffer_reg;
        next_flush_buffer_control_reg = flush_buffer_control_reg;
        next_tx_packet_control_reg = tx_packet_control_reg;
        stall = 0;

        if(hsel && (last_state == NONSEQ || last_state == SEQ)) begin 
            if(last_hwrite) begin
                case(last_hsize)
                    0: begin
                        case(last_haddr)
                            4'h0: next_data_buffer_reg[7:0] = hwdata[7:0];
                            4'h1: next_data_buffer_reg[15:8] = hwdata[15:8];
                            4'h2: next_data_buffer_reg[23:16] = hwdata[23:16];
                            4'h3: next_data_buffer_reg[31:24] = hwdata[31:24];
                            4'hC: next_tx_packet_control_reg[7:0] = hwdata[7:0];
                            4'hD: next_flush_buffer_control_reg[7:0] = hwdata[15:8];

                        endcase
                    end
                    1: begin
                        case(last_haddr)
                            4'h0: next_data_buffer_reg[15:0] = hwdata[15:0];
                            4'h2: next_data_buffer_reg[31:16] = hwdata[31:16];
                            //check condition where reg size is a byte and trying to read 2 bytes
                            4'hC: begin
                                next_tx_packet_control_reg[7:0] = hwdata[7:0];
                                next_flush_buffer_control_reg[7:0] = hwdata[15:8];
                            end
                            4'hD: next_flush_buffer_control_reg[7:0] = hwdata[15:8];

                        endcase
                    end
                    2: begin
                        case(last_haddr)
                            4'h0: next_data_buffer_reg = hwdata;
                            //check condition where reg size is a byte and trying to read 4 bytes
                            4'hC: begin
                                next_tx_packet_control_reg[7:0] = hwdata[7:0];
                                next_flush_buffer_control_reg[7:0] = hwdata[15:8];
                            end
                            4'hD: next_flush_buffer_control_reg[7:0] = hwdata[15:8];

                        endcase
                    end
                endcase
            end
        end

        TX_data = 0;
        store_TX_data = 0;
        case(TX_state)
            TX_IDLE: begin
                stall = (TX_transfer_ready) ? 1 : 0;
                store_TX_data = 0;
            end
            LOAD0: begin
                stall = 1;
                TX_data = data_buffer_reg[7:0];
                store_TX_data = 1; // assuming data buffer will sample on next cycle
            end
            LOAD1: begin 
                stall = 1;
                TX_data = data_buffer_reg[15:8];
                store_TX_data = 1;
            end
            LOAD2: begin
                stall = 1;
                TX_data = data_buffer_reg[23:16];
                store_TX_data = 1;
            end
            LOAD3: begin 
                stall = 1;
                TX_data = data_buffer_reg[31:24];
                store_TX_data = 1;
            end
            WAIT0: begin
                if (TX_current_hsize == 1) stall = 1;
                else if (TX_current_hsize == 2) stall = 1;
                else stall = 0;
                TX_data = data_buffer_reg[7:0];
                store_TX_data = 0;
            end
            WAIT1: begin
                if (TX_current_hsize == 2) stall = 1;
                else stall = 0;
                TX_data = data_buffer_reg[15:8];
                store_TX_data = 0;
            end
            WAIT2: begin
                if (TX_current_hsize == 1) stall = 1;
                else if (TX_current_hsize == 2) stall = 1;
                else stall = 0;
                TX_data = data_buffer_reg[23:16];
                store_TX_data = 0;
            end
            WAIT3: begin 
                stall = 0;
                TX_data = data_buffer_reg[31:24];
                store_TX_data = 0;
            end

        endcase   

        get_RX_data = 0;
        case(RX_state)
            RX_IDLE: begin 
                stall = (RX_transfer_ready) ? 1 : (stall);
                get_RX_data = 0;
            end
            WAIT_RX_READY: begin
                stall = 1;
                get_RX_data = 0;
            end
            ADDR0:begin 
                stall = 1;
                next_data_buffer_reg[7:0] = RX_data;
                get_RX_data = 1;
            end
            ADDR1:begin
                stall = 1;
                get_RX_data = 1; 
                next_data_buffer_reg[15:8] = RX_data;
            end
            ADDR2:begin 
                stall = 1;
                get_RX_data = 1;
                next_data_buffer_reg[23:16] = RX_data;
            end
            ADDR3:begin 
                stall = 1;
                get_RX_data = 1;
                next_data_buffer_reg[31:24] = RX_data;
            end
            WAIT_ADDR0: begin 
                if (RX_current_hsize == 1) stall = 1;
                else if (RX_current_hsize == 2) stall = 1;
                else stall = 0;
                //next_data_buffer_reg[7:0] = RX_data;
                get_RX_data = 0;
            end
            WAIT_ADDR1: begin 
                if (RX_current_hsize == 2) stall = 1;
                else stall = 0;
                //next_data_buffer_reg[15:8] = RX_data;
                get_RX_data = 0;
            end
            WAIT_ADDR2: begin 
                if (RX_current_hsize == 1) stall = 1;
                else if (RX_current_hsize == 2) stall = 1;
                else stall = 0;
                //next_data_buffer_reg[23:16] = RX_data;
                get_RX_data = 0;
            end
            WAIT_ADDR3: begin
                stall = 0;
                //next_data_buffer_reg[31:24] = RX_data;
                get_RX_data = 0;
            end
            default: begin
                stall = (RX_transfer_ready) ? 1 : 0; 
                get_RX_data = 0;
            end
        endcase

        if(clear_done) next_flush_buffer_control_reg = 0;
        if(packet_done) next_tx_packet_control_reg = 0;
    end

    //READ logic 
    always_comb begin
        r_error = 0;
        w_error = 0;
        hrdata = 0;

        if(hsel && (state == NONSEQ || state == SEQ) && ~hresp) begin 
            if(~hwrite) begin
                case(hsize)
                    0: begin
                        case(haddr)
                            4'h0: r_error = 0;
                            4'h1: r_error = 0;
                            4'h2: r_error = 0;
                            4'h3: r_error = 0;
                            4'h4: r_error = 0;
                            4'h5: r_error = 0;
                            4'h6: r_error = 0;
                            4'h7: r_error = 0;
                            4'h8: r_error = 0;
                            4'hC: r_error = 0;
                            4'hD: r_error = 0;
                            default: r_error = 1;
                        endcase
                    end
                    1: begin
                        case(haddr)
                            4'h0: r_error = 0;
                            4'h2: r_error = 0;
                            4'h4: r_error = 0;
                            4'h6: r_error = 0;
                            //check condition where reg size is a byte and trying to read 2 bytes
                            4'h8: r_error = 0;
                            4'hC: begin
                                r_error = 0;
                            end
                            4'hD: r_error = 0;
                            default: r_error = 1;
                        endcase
                    end
                    2: begin
                        case(haddr)
                            4'h0: r_error = 0;
                            //check condition where reg size is a byte and trying to read 4 bytes
                            4'h4: r_error = 0;
                            4'h6: r_error = 0;
                            4'h8: r_error = 0;
                            4'hC: begin
                                r_error = 0;
                                r_error = 0;
                            end
                            4'hD: r_error = 0;
                            default: r_error = 1;
                        endcase
                    end
                endcase 
            end

            //write errors
            if(hwrite) begin
                case(hsize)
                    0: begin
                        case(haddr)
                            4'h0: w_error = 0;
                            4'h1: w_error = 0;
                            4'h2: w_error = 0;
                            4'h3: w_error = 0;
                            4'hC: w_error = 0;
                            4'hD: w_error = 0;
                            default: w_error = 1;
                        endcase
                    end
                    1: begin
                        case(haddr)
                            4'h0: w_error = 0;
                            4'h2: w_error = 0;
                            //check condition where reg size is a byte and trying to read 2 bytes
                            4'hC: w_error = 0;
                            4'hD: w_error = 0;
                            default: w_error = 1;
                        endcase
                    end
                    2: begin
                        case(haddr)
                            4'h0: w_error = 0;
                            //check condition where reg size is a byte and trying to read 4 bytes
                            4'hC: w_error = 0;
                            4'hD: w_error = 0;
                            default: w_error = 1;
                        endcase
                    end
                endcase
            end
        end

        if(hsel && (last_state_RX == NONSEQ || last_state_RX == SEQ) && ~hresp) begin 
            if(~last_hwrite) begin
                case(last_hsize)
                    0: begin
                        case(last_haddr)
                            4'h0: hrdata[7:0] = data_buffer_reg[7:0];
                            4'h1: hrdata[15:8] = data_buffer_reg[15:8];
                            4'h2: hrdata[23:16] = data_buffer_reg[23:16];
                            4'h3: hrdata[31:24] = data_buffer_reg[31:24];
                            4'h4: hrdata[7:0] = status_reg[7:0];
                            4'h5: hrdata[15:8] = status_reg[15:8];
                            4'h6: hrdata[23:16] = error_reg[7:0];
                            4'h7: hrdata[31:24] = error_reg[15:8];
                            4'h8: hrdata[7:0] = buffer_occupancy_reg[7:0];
                            4'hC: hrdata[7:0] = tx_packet_control_reg[7:0];
                            4'hD: hrdata[15:8] = flush_buffer_control_reg[7:0];
                        endcase
                    end
                    1: begin
                        case(last_haddr)
                            4'h0: hrdata[15:0] = data_buffer_reg[15:0];
                            4'h2: hrdata[31:16] = data_buffer_reg[31:16];
                            4'h4: hrdata[15:0] = status_reg[15:0];
                            4'h6: hrdata[31:16] = error_reg[15:0];
                            //check condition where reg size is a byte and trying to read 2 bytes
                            4'h8: hrdata[7:0] = buffer_occupancy_reg[7:0];
                            4'hC: begin
                                hrdata[7:0] = tx_packet_control_reg[7:0];
                                hrdata[15:8] = flush_buffer_control_reg[7:0];
                            end
                            4'hD: hrdata[15:8] = flush_buffer_control_reg[7:0];
                        endcase
                    end
                    2: begin
                        case(last_haddr)
                            4'h0: hrdata[31:0] = data_buffer_reg[31:0];
                            //check condition where reg size is a byte and trying to read 4 bytes
                            4'h4: hrdata[15:0] = status_reg[15:0];
                            4'h6: hrdata[31:16] = error_reg[15:0];
                            4'h8: hrdata[7:0] = buffer_occupancy_reg[7:0];
                            4'hC: begin
                                hrdata[7:0] = tx_packet_control_reg[7:0];
                                hrdata[15:8] = flush_buffer_control_reg[7:0];
                            end
                            4'hD: hrdata[15:8] = flush_buffer_control_reg[7:0];
                        endcase
                    end
                endcase 
            end
        end
    end

    //TX State Transfer logic
    always_ff @( posedge clk, negedge n_rst ) begin
        if (~n_rst) begin
            TX_state <= TX_IDLE;
            TX_current_hsize <= 0;
        end else begin
            TX_state <= next_TX_state;
            TX_current_hsize <= next_TX_current_hsize;
        end
    end

    always_comb begin
        next_TX_current_hsize = TX_current_hsize;
        case(TX_state)
            TX_IDLE: begin
                if (TX_transfer_ready && ~hresp) begin
                    next_TX_current_hsize = hsize;
                    case(haddr)
                        0: next_TX_state = LOAD0;
                        1: next_TX_state = LOAD1;
                        2: next_TX_state = LOAD2;
                        3: next_TX_state = LOAD3;
                        default: next_TX_state = TX_IDLE;
                    endcase
                end else begin
                    next_TX_state = TX_IDLE;
                    next_TX_current_hsize = 0;
                end
            end
            LOAD0: begin
                next_TX_state = WAIT0;
            end
            LOAD1: next_TX_state = WAIT1;
            LOAD2: next_TX_state = WAIT2;
            LOAD3: next_TX_state = WAIT3;
            WAIT0: begin
                if (TX_current_hsize == 1) next_TX_state = LOAD1;
                else if (TX_current_hsize == 2) next_TX_state = LOAD1;
                else next_TX_state = TX_IDLE;
            end
            WAIT1: begin
                if (TX_current_hsize == 2) next_TX_state = LOAD2;
                else next_TX_state = TX_IDLE;
            end
            WAIT2: begin
                if (TX_current_hsize == 1) next_TX_state = LOAD3;
                else if (TX_current_hsize == 2) next_TX_state = LOAD3;
                else next_TX_state = TX_IDLE;
            end
            WAIT3: next_TX_state = TX_IDLE;
            default: next_TX_state = TX_IDLE;
        endcase        
    end

    //RX State Transfer logic
    always_ff @( posedge clk, negedge n_rst ) begin
        if (~n_rst) begin
            RX_state <= RX_IDLE;
            RX_current_hsize <= 0;
        end else begin
            RX_state <= next_RX_state;
            RX_current_hsize <= next_RX_current_hsize;
        end
    end


//TX and RX Transfer logic
    always_comb begin
        next_RX_current_hsize = RX_current_hsize;
        case(RX_state)
            RX_IDLE: begin 
                if (RX_transfer_ready && ~hresp) begin
                    next_RX_state = WAIT_RX_READY;
                end else begin
                    next_RX_state = RX_IDLE;
                end
                next_RX_current_hsize = hsize;
            end
            WAIT_RX_READY: begin
                if (RX_data_ready) begin
                    case(last_haddr)
                        0: next_RX_state = ADDR0;
                        1: next_RX_state = ADDR1;
                        2: next_RX_state = ADDR2;
                        3: next_RX_state = ADDR3;
                        default: next_RX_state = RX_IDLE;
                    endcase
                end else begin
                    next_RX_state = WAIT_RX_READY;
                end
            end
            ADDR0:begin 
                next_RX_state = WAIT_ADDR0;
            end
            ADDR1:begin 
                next_RX_state = WAIT_ADDR1;
            end
            ADDR2:begin 
                next_RX_state = WAIT_ADDR2;
            end
            ADDR3:begin 
                next_RX_state = WAIT_ADDR3;
            end
            WAIT_ADDR0: begin 
                if((RX_current_hsize == 1) || (RX_current_hsize == 2))next_RX_state = ADDR1;
                else next_RX_state = RX_IDLE;
            end
            WAIT_ADDR1: begin 
                if((RX_current_hsize == 2))next_RX_state = ADDR2;
                else next_RX_state = RX_IDLE;
            end
            WAIT_ADDR2: begin 
                if((RX_current_hsize == 1) || (RX_current_hsize == 2))next_RX_state = ADDR3;
                else next_RX_state = RX_IDLE;
            end
            WAIT_ADDR3: begin
                next_RX_state = RX_IDLE;
            end
            default: begin 
                next_RX_state = RX_IDLE; 
            end
        endcase
    end
endmodule

