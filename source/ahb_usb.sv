`timescale 1ns / 10ps

module ahb_usb #(
    // parameters
) (
    input clk, n_rst,
    input logic hsel,
    input logic [3:0] haddr,
    input logic [2:0] hsize,
    input logic [1:0] htrans,
    input logic hwrite,
    input logic [2:0] hburst,
    input logic [31:0] hwdata,
    output logic hready,
    output logic [31:0] hrdata,
    output logic hresp,
    input logic dp_in,
    input logic dm_in,
    output logic dp_out,
    output logic dm_out,
    output logic d_mode
);
    logic [2:0] RX_packet, TX_packet;
    logic RX_data_ready, RX_transfer_active, RX_error;
    logic [6:0] buffer_occupancy, raddr;
    logic [7:0] RX_data, TX_data;

    logic clear_done, get_RX_data, store_TX_data, clear, TX_error, TX_transfer_active, packet_done;
    logic flush, store_RX_packet_data, get_TX_packet_data;
    logic [7:0] RX_packet_data, TX_packet_data;

    logic crc_right, crc_wrong, bitstuff_error;

    assign crc_right = 1;
    assign crc_wrong = 0;
    assign bitstuff_error = 0;


    ahb_lite_satellite AHB (.*);
    data_buffer DB (.*);
    usb_tx_wrapper TX (.*);
    usb_rx RX (.*);

endmodule

