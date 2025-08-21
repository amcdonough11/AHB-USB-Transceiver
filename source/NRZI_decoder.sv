`timescale 1ns / 10ps

module NRZI_decoder  (
    input logic clk, n_rst, en,
    input logic dp_in,
    output logic d_orig, d_edge
);

logic dp_in_prev;
logic dp_in_r;

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        dp_in_prev <= 1;
    end
    else begin
        dp_in_prev <= dp_in_r;
    end
end

always_comb begin
    d_orig =  ~(dp_in ^ dp_in_prev); // change = 0, no change = 1;
    d_edge = dp_in ^ dp_in_prev; //no change = no edge
end

always_comb begin
    dp_in_r = dp_in_prev;
    if(en)
        dp_in_r = dp_in;
end
endmodule

