`timescale 1ns / 10ps

module clk_div (
    input logic clk, n_rst, counter_clear,
    input logic en_clk_div,
    output logic clk_divider
);

    logic c8_rollover_flag, c3_rollover_flag, cnt_en, n_cnt_en, tx_packet_flag;
    logic [3:0] zero;

    flex_counter #(4) counter8 (.clk(clk), .n_rst(n_rst), .clear(counter_clear), .count_enable(cnt_en), .rollover_val(4'd8), .count_out(zero), .rollover_flag(c8_rollover_flag));
    flex_counter #(3) counter3 (.clk(clk), .n_rst(n_rst), .clear(counter_clear), .count_enable(c8_rollover_flag), .rollover_val(3'd3), .count_out(), .rollover_flag(c3_rollover_flag));

    always_ff @( posedge clk, negedge n_rst ) begin
        if (n_rst == 0) begin
            cnt_en <= 0;
        end
        else begin
            cnt_en <= n_cnt_en;
        end
    end

    always_comb begin : counter_enable
        if (en_clk_div != 0) begin
            if (cnt_en == 0) begin
                n_cnt_en = 1;
            end
            else begin
                if ((c8_rollover_flag == 1) & (c3_rollover_flag == 1)) begin
                    n_cnt_en = 0;
                end
                else begin
                    n_cnt_en = 1;
                end
            end
        end
        else begin
            n_cnt_en = 0;
        end

        clk_divider = ((c8_rollover_flag && !c3_rollover_flag) || !cnt_en) && en_clk_div && (zero != 0);

    end
endmodule