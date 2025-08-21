`timescale 1ns / 10ps

module EOP_det #(
    // parameters
) (
    input logic clk, n_rst,en,
    input logic dp_in, dm_in, clear,
    output logic eop, eop_error
);

logic [1:0] eop_count, next_eop_count;
logic prev_dp_in,prev_dm_in;

always_ff @(posedge clk, negedge n_rst) begin  //This logic works as intended, however it is once cycle "late", since we've registered the dm_in and dp_in and our eop_count is based on these registerd bits. 
    if(~n_rst) begin
        eop_count <= 0;        
        prev_dm_in <= 0;
        prev_dp_in <= 1;
    end
    else if(clear) begin;
        eop_count <= 0; 
    end
    else if(en) begin
        eop_count <= next_eop_count;
        prev_dm_in <= dm_in;
        prev_dp_in <= dp_in;
    end
end

always_comb begin
    if(~prev_dp_in && ~prev_dm_in) begin
        next_eop_count = eop_count + 1;
    end
    else begin
        next_eop_count = 0;
    end
end

always_comb begin
    if(eop_count == 2'b10 && next_eop_count != 2'b11) begin
        eop = 1;
        eop_error = 0;
    end
    else if((eop_count == 2'b01 && next_eop_count == 2'b00) || (next_eop_count == 2'b11)) begin
        eop_error = 1;
        eop = 0;
    end
    else begin
        eop = 0;
        eop_error = 0;
    end
end
endmodule
