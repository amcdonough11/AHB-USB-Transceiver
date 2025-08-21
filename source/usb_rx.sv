`timescale 1ns / 10ps

module usb_rx #(
    // parameters
) (
    input logic clk, n_rst, 
    input logic dp_in, dm_in, crc_right, crc_wrong,bitstuff_error,
    input logic [6:0] buffer_occupancy,
    output logic RX_data_ready, RX_transfer_active, RX_error,
    output logic flush, store_RX_packet_data,
    output logic [2:0] RX_packet,
    output logic [7:0] RX_packet_data
);
    logic dp_in_sync, dm_in_sync;
    logic clk_div; 
    logic d_edge; 
    logic  d_orig; 
    logic [7:0]  packet_data; 
    // logic        bitstuff_error;
    logic eop, eop_error; 
    logic EOP_en;
    // logic        crc_right, crc_wrong;
    logic crc_check;
    logic clear; 
    logic byte_strobe;
    logic en_clk_div;
    logic shift_in;
    logic store_data;
    logic send_packet;
    logic NRZI_en;
    logic rollover_flag_3;
    logic clear_4clk;
    logic clear_clk;
    logic addr_right;
    logic addr_wrong;
    logic store_packet;
    logic shift_enable;
    logic clk_4_en;
    logic count_en;
    logic readjust;
    logic clear_diff_count;

sync #(1)DPIN (.clk(clk), .n_rst(n_rst), .async_in(dp_in), .sync_out(dp_in_sync));
sync #(0)DMIN(.clk(clk), .n_rst(n_rst), .async_in(dm_in), .sync_out(dm_in_sync));
EOP_det EOP(.clk(clk), .n_rst(n_rst), .dp_in(dp_in_sync) , .dm_in(dm_in_sync), .eop(eop), .eop_error(eop_error), .clear(clear), .en(EOP_en));
clk_div_rx TWLV_MHZ(.clk(clk), .n_rst(n_rst), .counter_clear(clear_clk), .en_clk_div(en_clk_div & ~readjust), .readjust(readjust), .clk_divider(clk_div) );
NRZI_decoder NRZI(.clk(clk), .n_rst(n_rst), .dp_in(dp_in_sync), .d_edge(d_edge), .d_orig(d_orig)  ,.en(NRZI_en));
data_reg BUFF(.clk(clk) , .n_rst(n_rst), .shift_in(shift_in), .store_data(store_data), .send_packet(send_packet), .addr_right(addr_right),.addr_wrong(addr_wrong),.addr_check(addr_check) ,
              .packet_data(packet_data) ,.rx_packet(RX_packet), .rx_packet_data(RX_packet_data), .store_packet(store_packet), .flush(flush));

rx_controller   RX_CONTROLLER(
    .clk                 (clk),
    .clk_div             (clk_div),
    .n_rst               (n_rst),
    .byte_strobe         (byte_strobe),
    .bitstuff_error      (bitstuff_error),
    .d_edge              (d_edge),
    .buffer_occupancy    (buffer_occupancy),
    .packet_data         (packet_data),
    .eop                 (eop),
    .eop_error           (eop_error),
    .EOP_en              (EOP_en),
    .crc_right           (crc_right),
    .crc_wrong           (crc_wrong),
    .flush               (flush),
    .rx_error            (RX_error),
    .rx_dr               (RX_data_ready),
    .rx_busy             (RX_transfer_active),
    .store_rx_data       (store_RX_packet_data),
    .crc_check           (crc_check),
    .en_clk_div          (en_clk_div),
    .store_data          (store_data),
    .shift_in            (shift_in),
    .send_packet         (send_packet),
    .clear               (clear),
    .addr_right(addr_right),
    .addr_wrong(addr_wrong),
    .addr_check(addr_check),
    .shift_en(shift_enable),
    .clear_clk(clear_clk),
    .count_en(count_en),
    .store_packet(store_packet),
    .rollover_flag_3 (rollover_flag_3),
    .clk_4_en (clk_4_en),
    .NRZI_en(NRZI_en),
    .clear_4clk (clear_4clk)
);

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        clear_diff_count <= 0 ;
    end
    else begin
        clear_diff_count <= readjust;
    end
end

flex_sr STP8(.clk(clk), .n_rst(n_rst), .shift_enable(shift_enable), .load_enable(), .serial_in(d_orig) , .parallel_in() , .serial_out(), .parallel_out(packet_data));
flex_counter #(4) BYTE_COUNTS(.clk(clk), .n_rst(n_rst) ,.clear(clear), .count_enable(count_en), .rollover_val(4'd8), .count_out() ,.rollover_flag(byte_strobe));
flex_counter #(3) FOUR_clk(.clk(clk), .n_rst(n_rst) ,.clear(clear_4clk), .count_enable(clk_4_en), .rollover_val(3'd2), .count_out() ,.rollover_flag(rollover_flag_3));
flex_counter #(8) DIV_COUNT(.clk(clk), .n_rst(n_rst), .clear(clear_diff_count), .count_enable(clk_div) , .rollover_val(8'd45) , .rollover_flag(readjust));

endmodule


