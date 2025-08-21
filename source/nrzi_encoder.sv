`timescale 1ns / 10ps

module nrzi_encoder(
    input logic [7:0] data,
    output logic [7:0] encoded_data
);
    assign encoded_data[7] = data[7] ? 1 : 0;
    assign encoded_data[6] = data[6] ? encoded_data[7] : ~encoded_data[7];
    assign encoded_data[5] = data[5] ? encoded_data[6] : ~encoded_data[6];
    assign encoded_data[4] = data[4] ? encoded_data[5] : ~encoded_data[5];
    assign encoded_data[3] = data[3] ? encoded_data[4] : ~encoded_data[4];
    assign encoded_data[2] = data[2] ? encoded_data[3] : ~encoded_data[3];
    assign encoded_data[1] = data[1] ? encoded_data[2] : ~encoded_data[2];
    assign encoded_data[0] = data[0] ? encoded_data[1] : ~encoded_data[1];

endmodule