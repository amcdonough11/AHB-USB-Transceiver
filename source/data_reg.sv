`timescale 1ns / 10ps

module data_reg (
    input  logic clk, n_rst,
    input  logic shift_in, store_data, flush, send_packet,store_packet, addr_check,
    input  logic [7:0] packet_data,
    output logic [2:0] rx_packet,
    output logic [7:0] rx_packet_data,
    output logic addr_right, addr_wrong
);
    logic [15:0] data_register, next_data_register;
    logic [7:0] rx_packet_data_r, next_rx_packet_data;
    logic [2:0] rx_packet_r, next_rx_packet;

    assign rx_packet_data = rx_packet_data_r;
    assign rx_packet = send_packet ? rx_packet_r : rx_packet_r;

    always_ff @(posedge clk or negedge n_rst) begin
        if (~n_rst) begin
            data_register <= 16'b0;
            rx_packet_data_r <= 8'b0;
            rx_packet_r <= 3'b0;
        end 
        else begin
            data_register <= next_data_register;
            rx_packet_data_r <= next_rx_packet_data;
            rx_packet_r <= next_rx_packet;
        end
    end

    always_comb begin
         if (shift_in) begin
            next_data_register = {packet_data, data_register[15:8]};
        end
        else
            next_data_register = data_register;
    end

always_comb begin
    if (store_data) begin
        next_rx_packet_data = data_register[7:0];
    end
    else
        next_rx_packet_data = rx_packet_data_r;
end
always_comb begin
    next_rx_packet = rx_packet_r;
    if(store_packet) begin
            case (next_data_register[11:8])
            4'b0001: next_rx_packet = 3'b001; // OUT
            4'b1001: next_rx_packet = 3'b010; // IN
            4'b0010: next_rx_packet = 3'b011; // ACK
            4'b0011: next_rx_packet = 3'b100; //DATA0
            4'b1011: next_rx_packet = 3'b101; //DATA1
            default: next_rx_packet = 3'b000;
        endcase
    end
end

always_comb begin
    if(addr_check) begin
        if(data_register[10:0] == 11'b10111010101) begin
            addr_right = 1;
            addr_wrong = 0;
        end
        else begin
            addr_wrong = 1;
            addr_right = 0;
        end
    end
    else begin
        addr_right = 0;
        addr_wrong = 0;
    end
end
endmodule
