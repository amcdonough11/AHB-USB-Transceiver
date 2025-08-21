`timescale 1ns / 10ps

module usb_tx_wrapper (
    input logic clk, n_rst,
    input logic [6:0] buffer_occupancy,
    input logic [2:0] TX_packet,
    input logic [7:0] TX_packet_data,
    output logic TX_error, packet_done, get_TX_packet_data, TX_transfer_active, dp_out, dm_out
);
    logic [7:0] encoded_TX_packet_data, parallel_in, pidbyte;
    logic c8bit_rollover_flag, clk_div, shift_enable, load_enable, clear, counter_clear, bit_counter_en, serial_out;
    logic en_clk_div;
    always_comb begin
        pidbyte = 8'h01; // added this - aidan
        case (TX_packet)
            1 : pidbyte = 8'b11010111;
            2 : pidbyte = 8'b00100111;
            3 : pidbyte = 8'b11001001;
            4 : pidbyte = 8'b00111001;
            5 : pidbyte = 8'b01000001;
            default: pidbyte = 8'h01;
        endcase
    end
    
    assign en_clk_div = (TX_packet < 6) && (TX_packet != 0);

    flex_counter #(4) bit_counter (.clk(clk), .n_rst(n_rst), .clear(counter_clear), .count_enable(bit_counter_en), .rollover_val(4'd8), .count_out(), .rollover_flag(c8bit_rollover_flag));
    clk_div divider (.clk(clk), .n_rst(n_rst), .counter_clear(clear), .en_clk_div(en_clk_div), .clk_divider(clk_div));

    nrzi_encoder encoder (.data(TX_packet_data), .encoded_data(encoded_TX_packet_data));
    usb_tx_fsm fsm (.clk(clk), .n_rst(n_rst), .c8bit_rollover_flag(c8bit_rollover_flag), .clk_div(clk_div), .tx_packet(TX_packet), .buff_occupancy(buffer_occupancy), .encoded_tx_packet_data(encoded_TX_packet_data), .pidbyte(pidbyte), .packet_done(packet_done), .get_tx_packet_data(get_TX_packet_data), .tx_transfer_active(TX_transfer_active), .clear(clear), .counter_clear(counter_clear), .bit_counter_en(bit_counter_en), .DP_OUT(dp_out), .DM_OUT(dm_out));

    always_comb begin
        if (TX_packet > 5) begin
            TX_error = 1;
        end
        else begin
            TX_error = 0;
        end
    end

endmodule