`timescale 1ns / 10ps

module data_buffer (
    input logic clk, n_rst, clear, flush, store_TX_data, store_RX_packet_data, get_RX_data, get_TX_packet_data,
    input logic [7:0] TX_data, RX_packet_data,
    output logic clear_done,
    output logic [7:0] RX_data, TX_packet_data,
    output logic [6:0] buffer_occupancy
);
    logic wcnt_enable, last_store_TX_data, last_store_RX_data;
    logic [6:0] waddr;
    logic [7:0] wdata;
    logic [63:0] wen;
    logic [63:0] [7:0] data_out;
    logic clear_flag;
    assign clear_flag = clear | flush;

    always_ff @( posedge clk, negedge n_rst ) begin
        if(~n_rst) begin
            last_store_TX_data <= 0;
            last_store_RX_data <= 0;
        end else begin
            last_store_TX_data <= store_TX_data;
            last_store_RX_data <= store_RX_packet_data;
        end
    end

    always_comb begin : writeCounter
        if (waddr < 64) begin
            wcnt_enable = last_store_RX_data | last_store_TX_data;
        end
        else begin
            wcnt_enable = 0;
        end
    end

    flex_counter #(7) wcounter (.clk(clk), .n_rst(n_rst), .clear(clear_flag), .count_enable(wcnt_enable), .rollover_val(7'd64), .count_out(waddr), .rollover_flag());

    always_comb begin
        if (last_store_RX_data == 1) begin
            wdata = RX_packet_data;
        end
        else begin
            wdata = TX_data;
        end
    end

    always_comb begin : writeEnable
        if (waddr < 64) begin
            if ((last_store_TX_data == 1) || (last_store_RX_data == 1)) begin
                wen = '0;
                wen[waddr] = 1;
            end
            else begin
                wen = '0;
            end
        end
        else begin
            wen = '0;
        end
    end

    bit8x64_data_reg dataregs (.clk(clk), .n_rst(n_rst), .clear(clear), .flush(flush), .waddr(waddr), .wen(wen), .wdata(wdata), .data_out(data_out));

    logic rcnt_enable;

    logic [6:0] raddr_temp;
    flex_counter #(7) rcounter (.clk(clk), .n_rst(n_rst), .clear(clear_flag) , .count_enable(rcnt_enable), .rollover_val(7'd64), .count_out(raddr_temp), .rollover_flag());

    always_comb begin : readEnable
        if (raddr_temp < waddr) begin
            rcnt_enable = get_TX_packet_data || get_RX_data;
        end
        else begin
            rcnt_enable = 0;
        end
    end

    logic [7:0] rdata, data, n_data;

    assign rdata = data_out[raddr_temp];

    // always_ff @( posedge clk, negedge n_rst ) begin
    //     if (n_rst == 0) begin
    //         data = '0;
    //     end
    //     else begin
    //         data = n_data;
    //     end
    // end

    always_comb begin
        TX_packet_data = '0;
        RX_data = '0;
        if ((get_RX_data == 1)) begin
            RX_data = rdata; 
        end
        else if (get_TX_packet_data == 1)begin
            TX_packet_data = rdata; 
        end
        else begin
            TX_packet_data = '0;
            RX_data = '0;
        end
    end


    // assign RX_data = rdata & (get_RX_data);
    // assign TX_packet_data = rdata & (get_TX_data);

    logic [6:0] buff_temp;
    logic count_en;

    always_comb begin
        if (buff_temp < 64) begin
            if ((last_store_RX_data == 1) || (last_store_TX_data == 1)) begin
                count_en = 1;
            end
            else begin
                count_en = 0;
            end
        end
        else begin
            count_en = 0;
        end

        if ((clear == 1) || (flush == 1)) begin
            clear_done = 1;
        end
        else begin
            clear_done = 0;
        end
    end

    flex_counter #(7) buff_counter (.clk(clk), .n_rst(n_rst), .clear(clear_flag), .count_enable(count_en), .rollover_val(7'd64), .count_out(buff_temp), .rollover_flag());
    assign buffer_occupancy = buff_temp - raddr_temp;

endmodule


`timescale 1ns / 10ps
module bit8x64_data_reg (
    input logic clk, n_rst, clear, flush,
    input logic [6:0] waddr,
    input logic [63:0] wen,
    input logic [7:0] wdata,
    output logic [63:0] [7:0]  data_out 
);
    logic [7:0] n_data;
    logic [63:0] [7:0]  data ;

    always_ff @( posedge clk, negedge n_rst ) begin : blockName
        if (n_rst == 0) begin
            data <= '0;
        end
        else begin
            data[waddr] <= n_data;
        end
    end

    always_comb begin
        if ((clear == 1) || (flush == 1)) begin
            n_data = '0;
        end
        else if (wen[waddr] == 1) begin
            n_data = wdata;
        end
        else begin
            n_data = data[waddr];
        end
    end

    assign data_out = data;

endmodule