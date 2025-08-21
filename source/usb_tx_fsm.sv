`timescale 1ns / 10ps

module usb_tx_fsm (
    input logic clk, n_rst, c8bit_rollover_flag, clk_div,
    input logic [2:0] tx_packet,
    input logic [6:0] buff_occupancy,
    input logic [7:0] encoded_tx_packet_data, pidbyte,
    output logic packet_done, get_tx_packet_data, tx_transfer_active, clear, counter_clear, bit_counter_en,
    output logic DP_OUT, DM_OUT
);
    logic [7:0] syncbyte, crcbyte1, crcbyte2, parallel_in;
    logic shift_enable, load_enable;
    logic serial_out;
    logic serial_out_dp, serial_out_sr;

    assign syncbyte = 8'b01010100;
    assign crcbyte1 = 8'b00010001;
    assign crcbyte2 = 8'b00100010;

    typedef enum logic [4:0] {
        IDLE,
        LoadSYNC,
        ShiftSYNC,
        SYNCWait,
        LoadPID,
        PIDWait,
        ShiftPID,
        LoadCRC1,
        CRC1Wait,
        ShiftCRC1,
        LoadCRC2,
        CRC2Wait,
        ShiftCRC2,
        LoadDATA,
        DATAWait,
        ShiftDATA,
        LoadEOP,
        ShiftEOP,
        EOPWait,
        PacketDone
    } tx_states;

    tx_states state, n_state;

    always_ff @( posedge clk, negedge n_rst ) begin
        if (n_rst == 0) begin
            state <= IDLE;
        end
        else begin
            state <= n_state;
        end
    end

    always_comb begin : Transition
        case (state)
            IDLE : begin
                if ((tx_packet > 0) && (tx_packet < 6)) begin
                    n_state = LoadSYNC;
                end
                else begin
                    n_state = IDLE;
                end
            end
            LoadSYNC : begin
                n_state = SYNCWait;
            end
            ShiftSYNC : begin
                n_state = SYNCWait;
            end
            SYNCWait : begin
                if ((clk_div == 1) && (c8bit_rollover_flag != 1)) begin
                    n_state = ShiftSYNC;
                end
                else if (((clk_div == 1) && (c8bit_rollover_flag == 1))) begin
                    n_state = LoadPID;
                end
                else begin
                    n_state = SYNCWait;
                end
            end

            LoadPID : begin
                n_state = PIDWait;
            end
            ShiftPID : begin
                    n_state = PIDWait;
            end
            PIDWait : begin
                if ((clk_div == 1) && (c8bit_rollover_flag != 1)) begin
                    n_state = ShiftPID;
                end
                else if ((clk_div == 1) && (c8bit_rollover_flag == 1) && ((tx_packet == 1) || (tx_packet == 2)) ) begin
                    n_state = LoadDATA;
                end
                else if ((clk_div == 1) && (c8bit_rollover_flag == 1))begin
                    n_state = LoadCRC1;
                end
                else begin
                    n_state = PIDWait;
                end
            end

            LoadDATA : begin
                n_state = DATAWait;
            end
            ShiftDATA : begin
                n_state = DATAWait;
            end
            DATAWait : begin
                if ((clk_div == 1) && (c8bit_rollover_flag != 1)) begin
                    n_state = ShiftDATA;
                end
                else if ((clk_div == 1) && (c8bit_rollover_flag == 1) && (buff_occupancy != 0)) begin
                    n_state = LoadDATA;
                end
                else if ((clk_div == 1) && (c8bit_rollover_flag == 1) && (buff_occupancy == 0))begin
                    n_state = LoadCRC1;
                end
                else begin
                    n_state = DATAWait;
                end
            end

            LoadCRC1 : begin
                n_state = CRC1Wait;
            end
            ShiftCRC1 : begin
                n_state = CRC1Wait;
            end
            CRC1Wait : begin
                if ((clk_div == 1) && (c8bit_rollover_flag != 1)) begin
                    n_state = ShiftCRC1;
                end
                else if ((clk_div == 1) && (c8bit_rollover_flag == 1)) begin
                    n_state = LoadCRC2;
                end
                else begin
                    n_state = CRC1Wait;
                end
            end

            LoadCRC2 : begin
                n_state = CRC2Wait;
            end
            ShiftCRC2 : begin
                n_state = CRC2Wait;
            end
            CRC2Wait : begin
                if ((clk_div == 1) && (c8bit_rollover_flag != 1)) begin
                    n_state = ShiftCRC2;
                end
                else if ((clk_div == 1) && (c8bit_rollover_flag == 1)) begin
                    n_state = LoadEOP;
                end
                else begin
                    n_state = CRC2Wait;
                end
            end

            LoadEOP : begin
                if (clk_div == 1) begin
                    n_state = ShiftEOP;
                end
                else begin
                    n_state = state;
                end
            end
            ShiftEOP : n_state = EOPWait;
            EOPWait : begin
                if (clk_div == 1) begin
                    n_state = PacketDone;
                end
                else begin
                    n_state = state;
                end
            end
            PacketDone : n_state = IDLE;
            default: n_state = IDLE;
        endcase
    end

    always_comb begin : Output
        parallel_in = '0;
        serial_out_dp = 0;
        case (state)
            IDLE : begin
                clear = 0;
                counter_clear = 1;
                tx_transfer_active = 0;
                packet_done = 0;
                shift_enable = 0;
                load_enable = 1;
                bit_counter_en = 0;
                parallel_in = 8'h80;
                get_tx_packet_data = 0;
            end
            LoadSYNC : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 1;
                bit_counter_en = 0;
                parallel_in = syncbyte; // SYNC BYTE
                get_tx_packet_data = 0;
            end
            ShiftSYNC : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 0;
                bit_counter_en = 1;
                get_tx_packet_data = 0;
            end
            SYNCWait : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 0;
                load_enable = 0;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
            end
            LoadPID : begin
                clear = 0;
                counter_clear = 1;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 1;
                bit_counter_en = 0;
                parallel_in = pidbyte;
                get_tx_packet_data = 0;
            end
            PIDWait : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 0;
                load_enable = 0;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
            end
            ShiftPID : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 0;
                bit_counter_en = 1;
                get_tx_packet_data = 0;
            end
            LoadDATA : begin
                clear = 0;
                counter_clear = 1;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 1;
                bit_counter_en = 0;
                parallel_in = encoded_tx_packet_data;
                get_tx_packet_data = 1;
            end
            DATAWait : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 0;
                load_enable = 0;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
            end
            ShiftDATA : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 0;
                bit_counter_en = 1;
                get_tx_packet_data = 0;
            end
            LoadCRC1 : begin
                clear = 0;
                counter_clear = 1;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 1;
                bit_counter_en = 0;
                parallel_in = crcbyte1;
                get_tx_packet_data = 0;
            end
            CRC1Wait : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 0;
                load_enable = 0;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
            end
            ShiftCRC1 : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 0;
                bit_counter_en = 1;
                get_tx_packet_data = 0;
            end
            LoadCRC2 : begin
                clear = 0;
                counter_clear = 1;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 1;
                bit_counter_en = 1;
                parallel_in = crcbyte2;
                get_tx_packet_data = 0;
            end
            CRC2Wait : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 0;
                load_enable = 0;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
            end
            ShiftCRC2 : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 0;
                bit_counter_en = 1;
                get_tx_packet_data = 0;
            end
            LoadEOP : begin
                clear = 0;
                counter_clear = 1;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 1;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
            end
            ShiftEOP : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 1;
                load_enable = 0;
                bit_counter_en = 1;
                get_tx_packet_data = 0;
            end
            EOPWait : begin
                clear = 0;
                counter_clear = 0;
                tx_transfer_active = 1;
                packet_done = 0;
                shift_enable = 0;
                load_enable = 0;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
            end
            PacketDone : begin
                clear = 1;
                counter_clear = 1;
                tx_transfer_active = 0;
                packet_done = 1;
                shift_enable = 0;
                load_enable = 1;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
                parallel_in = 8'h80;
                serial_out_dp = 1;
            end
            default: begin
                clear = 1;
                counter_clear = 1;
                tx_transfer_active = 0;
                packet_done = 0;
                shift_enable = 0;
                load_enable = 1;
                bit_counter_en = 0;
                get_tx_packet_data = 0;
            end
        endcase
    end

    flex_sr #(.MSB_FIRST(1)) bit8sr (.clk(clk), .n_rst(n_rst), .shift_enable(shift_enable), .load_enable(load_enable), .serial_in(1'b0), .parallel_in(parallel_in), .serial_out(serial_out_sr), .parallel_out());
    
    assign serial_out = serial_out_sr || serial_out_dp;

    assign DP_OUT = serial_out;

    always_comb begin
        if ((state == LoadEOP) || (state == ShiftEOP) || (state == EOPWait)) begin
            DM_OUT = 0;
        end
        else begin
            DM_OUT = ~serial_out;
        end
    end

endmodule