`timescale 1ns / 10ps

module flex_sr #(
    parameter SIZE = 8,
    parameter MSB_FIRST = 0
) (
    input logic clk,
    input logic n_rst,
    input logic shift_enable,
    input logic load_enable,
    input logic serial_in,
    input logic [SIZE-1:0] parallel_in,
    output logic serial_out,
    output logic [SIZE-1:0] parallel_out
);
logic [SIZE-1:0] next_parallel_out;

always_comb begin 
    if (load_enable) begin
        next_parallel_out = parallel_in;
    end
    else if (shift_enable) begin 
        if(!MSB_FIRST) begin
            next_parallel_out = {serial_in, parallel_out[SIZE-1:1]};
        end
        else begin
            next_parallel_out = {parallel_out[SIZE-2:0], serial_in};
        end 
    end
    else begin
        next_parallel_out = parallel_out;
    end
end

always_ff @ ( posedge clk, negedge n_rst) begin
    if (!n_rst) begin 
        parallel_out <= {(SIZE){1'b1}};
        serial_out <= 1;
    end
    else begin
        parallel_out <= next_parallel_out;
        serial_out <= (!MSB_FIRST) ? next_parallel_out[0] : next_parallel_out[SIZE-1];
    end
end

endmodule