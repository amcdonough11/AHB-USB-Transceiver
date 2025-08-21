`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_ahb_usb ();

    localparam CLK_PERIOD = 10ns;
    localparam TIMEOUT = 1000;
    localparam DATA_PERIOD = 83.33ns;
    localparam OUT = 8'b11100001;
    localparam IN = 8'b01101001;
    localparam DATA0 = 8'b11000011;
    localparam DATA1 = 8'b01001011;
    localparam ACK = 8'b11010010; 
    localparam ADDRESS = 11'b10111010101;
    localparam ADDR_1END = 8'hD5;
    localparam END_CRC5 = 8'hAD;
    localparam DUMMY_DATA1 = 8'b11111101;
    localparam DUMMY_DATA2 = 8'b10100110;
    localparam CRC_DATA1 = 8'h88;
    localparam CRC_DATA2 = 8'h69;

    localparam BURST_SINGLE = 3'd0;
    localparam BURST_INCR   = 3'd1;
    localparam BURST_WRAP4  = 3'd2;
    localparam BURST_INCR4  = 3'd3;
    localparam BURST_WRAP8  = 3'd4;
    localparam BURST_INCR8  = 3'd5;
    localparam BURST_WRAP16 = 3'd6;
    localparam BURST_INCR16 = 3'd7;

    logic dp_in, dp_out, dm_in, dm_out, d_mode;

    initial begin
        $dumpfile("waveform.fst");
        $dumpvars;
    end

    logic clk, n_rst;

    // clockgen
    always begin
        clk = 0;
        #(CLK_PERIOD / 2.0);
        clk = 1;
        #(CLK_PERIOD / 2.0);
    end

    task reset_dut;
    begin
        n_rst = 0;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        n_rst = 1;
        @(negedge clk);
        @(negedge clk);
    end
    endtask

    logic hsel;
    logic [3:0] haddr;
    logic [2:0] hsize;
    logic [2:0] hburst;
    logic [1:0] htrans;
    logic hwrite;
    logic [31:0] hwdata;
    logic [31:0] hrdata;
    logic hresp;
    logic hready;

    ahb_usb DUT (.*);

    // bus model connections
    ahb_model_updated #(
        .ADDR_WIDTH(4),
        .DATA_WIDTH(4)
    ) BFM ( .clk(clk),
        // AHB-Subordinate Side
        .hsel(hsel),
        .haddr(haddr),
        .hsize(hsize),
        .htrans(htrans),
        .hburst(hburst),
        .hwrite(hwrite),
        .hwdata(hwdata),
        .hrdata(hrdata),
        .hresp(hresp),
        .hready(hready)
    );

    logic d_orig, d_edge;

    // Supporting Tasks
    task reset_model;
        BFM.reset_model();
    endtask

    // Read from a register without checking the value
    task enqueue_poll ( input logic [3:0] addr, input logic [1:0] size );
    logic [31:0] data [];
        begin
            data = new [1];
            data[0] = {32'hXXXX};
            //              Fields: hsel,  R/W, addr, data, exp err,         size, burst, chk prdata or not
            BFM.enqueue_transaction(1'b1, 1'b0, addr, data,    1'b0, {1'b0, size},  3'b0,            1'b0);
        end
    endtask

    // Read from a register until a requested value is observed
    task poll_until ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] data);
        int iters;
        begin
            for (iters = 0; iters < TIMEOUT; iters++) begin
                enqueue_poll(addr, size);
                execute_transactions(1);
                if(BFM.get_last_read() == data) break;
            end
            if(iters >= TIMEOUT) begin
                $error("Bus polling timeout hit.");
            end
        end
    endtask

    // Read Transaction, verifying a specific value is read
    task enqueue_read ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] exp_read );
        logic [31:0] data [];
        begin
            data = new [1];
            data[0] = exp_read;
            BFM.enqueue_transaction(1'b1, 1'b0, addr, data, 1'b0, {1'b0, size}, 3'b0, 1'b1);
        end
    endtask

    // Write Transaction
    task enqueue_write ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] wdata );
        logic [31:0] data [];
        begin
            data = new [1];
            data[0] = wdata;
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data, 1'b0, {2'b0, size}, 3'b0, 1'b0);
        end
    endtask

    // Write Transaction Intended for a different subordinate from yours
    task enqueue_fakewrite ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] wdata );
        logic [31:0] data [];
        begin
            data = new [1];
            data[0] = wdata;
            BFM.enqueue_transaction(1'b0, 1'b1, addr, data, 1'b0, {1'b0, size}, 3'b0, 1'b0);
        end
    endtask

    // Create a burst read of size based on the burst type.
    // If INCR, burst size dependent on dynamic array size
    task enqueue_burst_read ( input logic [3:0] base_addr, input logic [1:0] size, input logic [2:0] burst, input logic [31:0] data [] );
        BFM.enqueue_transaction(1'b1, 1'b0, base_addr, data, 1'b0, {1'b0, size}, burst, 1'b1);
    endtask

    // Create a burst write of size based on the burst type.
    task enqueue_burst_write ( input logic [3:0] base_addr, input logic [1:0] size, input logic [2:0] burst, input logic [31:0] data [] );
        BFM.enqueue_transaction(1'b1, 1'b1, base_addr, data, 1'b0, {1'b0, size}, burst, 1'b1);
    endtask

    // Run n transactions, where a k-beat burst counts as k transactions.
    task execute_transactions (input int num_transactions);
        BFM.run_transactions(num_transactions);
    endtask

    // Finish the current transaction
    task finish_transactions();
        BFM.wait_done();
    endtask

    task enqueue_read_err ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] exp_read );
        logic [31:0] data [];
        begin
            data = new [1];
            data[0] = exp_read;
            BFM.enqueue_transaction(1'b1, 1'b0, addr, data, 1'b1, {1'b0, size}, 3'b0, 1'b1);
        end
    endtask


    task enqueue_write_err ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] wdata );
        logic [31:0] data [];
        begin
            data = new [1];
            data[0] = wdata;
            $display("TB Level: %p", data);
            BFM.enqueue_transaction(1'b1, 1'b1, addr, data, 1'b1, {2'b0, size}, 3'b0, 1'b0);
        end
    endtask

    task send_packet;
        input [7:0] data;
        input time data_period;
        int i;
        begin
            // First synchronize to away from clock’s rising edge
            @(negedge clk);

            // Send data bits
            for (i = 0; i < 8; i = i + 1) begin
                dp_in = data[i];
                #data_period;
            end
        end
    endtask
    task send_packet_decoded;
    input logic [7:0] data;
    begin
    logic prev_dp_in;
    logic prev_dm_in;
    int i;
    time stamp;
        @(negedge clk)
        for (i = 0; i < 8; i = i + 1) begin
            prev_dp_in = dp_in;
            prev_dm_in = dm_in;
            if(data[i] == 1) begin
                dp_in = prev_dp_in;
                dm_in = prev_dm_in;
            end
            else begin
                dp_in = ~prev_dp_in;
                dm_in = ~prev_dm_in;
                end
            #DATA_PERIOD;
            
            end
    end
    endtask
    
    task send_eop;
        int i;
        time t1;
        begin
            // First synchronize to away from clock’s rising edge
            @(negedge clk);

            // Send data bits
            for (i = 0; i < 2; i = i + 1) begin
                dp_in = 0;
                dm_in = 0;
                #DATA_PERIOD;
            end
            dp_in = 1;
        t1 = $time;
        $display("Current Time:%t",t1);
        end
    endtask

    task send_eop_error;
        input x;
        int i;
        time t1;
        begin
            // First synchronize to away from clock’s rising edge
            @(negedge clk)
            // Send data bits
            for (i = 0; i < x; i = i + 1) begin
                dp_in = 0;
                dm_in = 0;
                #DATA_PERIOD;
            end
            dp_in = 1;
        t1 = $time;
        $display("Current Time:%t",t1);
        end
    endtask


    string test_name, sub_test;

    logic [31:0] data [];

    initial begin
        dp_in = 1;
        dm_in = 0;

        test_name = "reset";
        sub_test = "reset";
        n_rst = 1;
        reset_model();
        reset_dut();
        repeat (20) @(negedge clk);

        /*
            LEFT SIDE OF CHART
        */

        //IN -> NAK
        sub_test = "IN";
        test_name = "IN Transfer with Endpoint NAK	";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(IN);
        send_packet_decoded(ADDR_1END); 
        send_packet_decoded(END_CRC5);
        send_eop();
        repeat (800) @(negedge clk);


        sub_test = "NAK";
        enqueue_write(4'hc,0,32'h00000004);
        execute_transactions(1);
        repeat (800) @(negedge clk);

        //IN -> STALL

        test_name = "IN Transfer with Endpoint STALL";
        sub_test = "IN";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(IN); 
        send_packet_decoded(ADDR_1END); 
        send_packet_decoded(END_CRC5);
        send_eop();
        repeat (800) @(negedge clk);

        sub_test = "STALL";
        enqueue_write(4'hc,0,32'h00000005);
        execute_transactions(1);
        repeat (2000) @(negedge clk);

        //IN -> DATA -> ACK

        test_name = "IN Transfer with Successful Data Send (DATA0)";
        sub_test = "IN";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(IN); 
        send_packet_decoded(ADDR_1END); 
        send_packet_decoded(END_CRC5);
        send_eop();
        repeat (800) @(negedge clk);

        //fill data buffer
        sub_test = "Fill Data Buff";
        repeat (16) enqueue_write(4'h0,2,32'h44332211);
        execute_transactions(16);
        repeat (800) @(negedge clk);

        sub_test = "DATA0";
        enqueue_write(4'hc,0,32'h00000001);
        execute_transactions(1);
        repeat (5500) @(negedge clk);

        sub_test = "ACK";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(ACK); 
        send_eop();
        repeat (800) @(negedge clk);


        sub_test = "CLEAR DATA BUFF";
        enqueue_write(4'hd,0,32'h00000001);
        execute_transactions(1);
        repeat (800) @(negedge clk);



        test_name = "IN Transfer with Successful Data Send (DATA1)";
        sub_test = "IN";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(IN);
        send_packet_decoded(ADDR_1END);  
        send_packet_decoded(END_CRC5);
        send_eop();
        repeat (800) @(negedge clk);

        sub_test = "FILL DATA BUFF";
        //fill data buffer
        repeat (16) enqueue_write(4'h0,2,32'hddccbbaa);
        execute_transactions(16);
        repeat (800) @(negedge clk);


        sub_test = "DATA1";
        enqueue_write(4'hc,0,32'h00000002);
        execute_transactions(1);
        repeat (5500) @(negedge clk);

        sub_test = "ACK";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(ACK); 
        send_eop();
        repeat (800) @(negedge clk);

        sub_test = "CLEAR DATA BUFF";
        enqueue_write(4'hd,0,32'h00000001);
        execute_transactions(1);
        repeat (800) @(negedge clk);


        /*
            RIGHT SIDE OF CHART
        */

        test_name = "OUT Transfer with Successful Data Reception";

        sub_test = "OUT";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(OUT);
        send_packet_decoded(ADDR_1END);  
        send_packet_decoded(END_CRC5);
        send_eop();
        repeat (1000) @(negedge clk);

        sub_test = "DATA0";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(DATA0);
        repeat(32) begin
            send_packet_decoded(DUMMY_DATA1);
            send_packet_decoded(DUMMY_DATA2);
        end
        send_packet_decoded(CRC_DATA1);
        send_packet_decoded(CRC_DATA2);
        send_eop();
        repeat (1000) @(negedge clk);

        sub_test = "ACK";
        enqueue_write(4'hc,0,32'h00000003);
        execute_transactions(1);
        repeat (1000) @(negedge clk);


        sub_test = "Endpoint Read";
        repeat (16) enqueue_read(4'h0,2,32'ha6fda6fd);
        execute_transactions(16);
        repeat (1000) @(negedge clk);



        test_name = "OUT Transfer with Endpoint NAK	";


        sub_test = "OUT";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(OUT);
        send_packet_decoded(ADDR_1END);  
        send_packet_decoded(END_CRC5);
        send_eop();
        repeat (1000) @(negedge clk);


        sub_test = "DATA1";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(DATA1);
        repeat(16) begin
        send_packet_decoded(DUMMY_DATA1);
        send_packet_decoded(DUMMY_DATA2);
        end
        send_packet_decoded(CRC_DATA1);
        send_packet_decoded(CRC_DATA2);
        send_eop();
        repeat (1000) @(negedge clk);

        sub_test = "NACK";
        enqueue_write(4'hc,0,32'h00000004);
        execute_transactions(1);
        repeat (1000) @(negedge clk);




        test_name = "OUT Transfer with Endpoint STALL";

        sub_test = "OUT";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(OUT);
        send_packet_decoded(ADDR_1END);  
        send_packet_decoded(END_CRC5);
        send_eop();
        repeat (1000) @(negedge clk);

        sub_test = "DATA0";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(DATA0);
        repeat(16) begin
        send_packet_decoded(DUMMY_DATA1);
        send_packet_decoded(DUMMY_DATA2);
        end
        send_packet_decoded(CRC_DATA1);
        send_packet_decoded(CRC_DATA2);
        send_eop();
        repeat (1000) @(negedge clk);

        sub_test = "STALL";
        enqueue_write(4'hc,0,32'h00000005);
        execute_transactions(1);
        repeat (1000) @(negedge clk);

        test_name = "AHB-Lite bus 1,2,4 Byte Write"; 
        sub_test = "CLEAR DATA BUFF";
        enqueue_write(4'hd,0,32'h00000001);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        sub_test = "Iso 1 Byte";
        enqueue_write(4'h0,0,32'h00000011);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        enqueue_write(4'h1,0,32'h00000022);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        sub_test = "Iso 2 Byte";
        enqueue_write(4'h2,1,32'h00004433);
        execute_transactions(1);
        repeat (10) @(negedge clk);
        sub_test = "Iso 4 Byte";
        enqueue_write(4'h0,2,32'hffffffff);
        execute_transactions(1);
        repeat (15) @(negedge clk);


        test_name = "AHB-Lite bus 1,2,4 Byte Write";
        sub_test = "Overlapping 1,2 and 4 Byte";
        enqueue_write(4'h0,0,32'h000000aa);
        enqueue_write(4'h2,1,32'h000000bbbb);
        enqueue_write(4'h0,2,32'hcccccccc);
        execute_transactions(3);
        repeat (30) @(negedge clk);

        test_name = "AHB-Lite bus 1,2,4 Byte Read";
        sub_test = "Iso 1 Byte";
        enqueue_read(4'h0,0,32'h00000011);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        sub_test = "Iso 2 Byte";
        enqueue_read(4'h2,1,32'h00003322);
        execute_transactions(1);
        repeat (10) @(negedge clk);
        sub_test = "Iso 4 Byte";
        enqueue_read(4'h0,2,32'hffffff44);
        execute_transactions(1);
        repeat (15) @(negedge clk);

        sub_test = "Overlapping 1,2, and 4 Byte";
        enqueue_read(4'h0,0,32'h000000ff);
        enqueue_read(4'h2,1,32'h0000bbaa);
        enqueue_read(4'h0,2,32'hccccccbb);
        execute_transactions(3);
        repeat (30) @(negedge clk);

        test_name = "AHB-Lite RAW";
        sub_test = "RAW";
        enqueue_write(4'hc,0,32'h00000005);
        enqueue_read(4'hc,0,32'h00000005);
        execute_transactions(2);
        repeat (100) @(negedge clk);

        test_name = "AHB-Lite HRESP";
        sub_test = "Unmapped Address";
        enqueue_write_err(4'ha,0,32'h0);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        enqueue_read_err(4'hf,0,32'h0);
        execute_transactions(1);
        repeat (5) @(negedge clk);

        sub_test = "Write to RO";
        enqueue_write_err(4'h4,0,32'h0);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        enqueue_write_err(4'h5,0,32'h0);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        enqueue_write_err(4'h6,0,32'h0);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        enqueue_write_err(4'h7,0,32'h0);
        execute_transactions(1);
        repeat (5) @(negedge clk);
        enqueue_write_err(4'h8,0,32'h0);
        execute_transactions(1);
        repeat (5) @(negedge clk);

        test_name = "AHB-Lite BURST";
        sub_test = "Read 2 Byte Burst Wrap8";
        $display("Ignore Hresp for 2");
        data = new [8];
        data = {32'h00000005, 32'h00000000,32'h0000a6cc,32'h0000a6a6,32'h00000109,32'h00000000,32'h00000000,32'h00000000};
        enqueue_burst_read(4'hC, 1'b1, BURST_WRAP8, data);
        execute_transactions(10); 
        repeat(50) @(negedge clk);
        $display("Stop Ignore Hresp");

        sub_test = "Write 1 Byte Burst INCR8";
        $display("Ignore Hresp for 2");
        data = new [8];
        data = {32'h00000001, 32'h00000002,32'h00000003,32'h00000004,32'h00000005,32'h00000006,32'h00000007,32'h00000008};
        enqueue_burst_write(4'h0, 1'b0, BURST_INCR8, data);
        execute_transactions(10); 
        repeat(50) @(negedge clk);
        $display("Stop Ignore Hresp");

        test_name = "RX_Errors";
        sub_test = "WRONG SYNC";
        send_packet_decoded(8'h70); //WRONG SYNC
        repeat(20) @(negedge clk);

        sub_test = "WRONG PID";
        send_packet_decoded(8'h31);
        repeat(20) @(negedge clk);

        sub_test = "EARLY EOP";
        send_packet_decoded(8'h80); //IDLE
        send_packet_decoded(IN);
        send_eop();
        repeat(20) @(negedge clk);

        sub_test = "LONG EOP";
        send_packet_decoded(8'h80); //IDLE
        send_packet_decoded(IN);
        send_packet_decoded(ADDR_1END);
        send_packet_decoded(END_CRC5);
        send_eop_error(3);
        repeat(20) @(negedge clk);

        sub_test = "SHORT EOP";
        send_packet_decoded(8'h80); //IDLE
        send_packet_decoded(IN);
        send_packet_decoded(ADDR_1END);
        send_packet_decoded(END_CRC5);        test_name = "AHB-Lite BURST";

        send_eop_error(1);
        repeat(20) @(negedge clk);

        sub_test = "WRONG ADDR";
        send_packet_decoded(8'h80); //IDLE
        send_packet_decoded(IN);
        send_packet_decoded(8'hD9);
        send_packet_decoded(8'hFF);
        send_eop();
        repeat(20) @(negedge clk);
        

        sub_test = "DATA ERROR";
        send_packet_decoded(8'h80); //IDLE
        send_packet_decoded(DATA0);
        send_packet_decoded(DUMMY_DATA1);
        send_packet_decoded(DUMMY_DATA2);
        send_eop_error(1);
        repeat(20) @(negedge clk);




        test_name = "USB TX Error Handling";
        sub_test = "Sending Bad Packet to TX";
        enqueue_write(4'hc,0,32'h00000007);
        execute_transactions(1);
        repeat (1000) @(negedge clk);

        sub_test = "Sending Valid Packet to TX";
        enqueue_write(4'hc,0,32'h00000005);
        execute_transactions(1);
        repeat (1000) @(negedge clk);

        /*
        test_name = "1 byte TX";
        //addr size data
        enqueue_write(0,0,32'h00000011);
        execute_transactions(1);
        repeat (12) @(negedge clk);
        enqueue_write(4'hc,0,32'h00000001);
        execute_transactions(1);
        repeat (800) @(negedge clk);

        test_name = "low 2 byte TX";
        //addr size data
        enqueue_write(0,1,32'h00002211);
        execute_transactions(1);
        repeat (12) @(negedge clk);
        enqueue_write(4'hc,0,32'h00000001);
        execute_transactions(1);
        repeat (800) @(negedge clk);

        test_name = "high 2 byte TX";
        //addr size data
        enqueue_write(0,1,32'h44330000);
        execute_transactions(1);
        repeat (12) @(negedge clk);
        enqueue_write(4'hc,0,32'h00000001);
        execute_transactions(1);
        repeat (800) @(negedge clk);

        test_name = "4 byte TX";
        //addr size data
        enqueue_write(0,2,32'h87654321);
        execute_transactions(1);
        repeat (12) @(negedge clk);
        enqueue_write(4'hc,0,32'h00000001);
        execute_transactions(1);
        repeat (800) @(negedge clk);

        test_name = "IN RX"; 
        //addr size data
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(IN); 
        send_packet_decoded(ADDR_1END); //ADDR + EN1
        send_packet_decoded(END_CRC5); //EN2+CRC5
        send_eop();
        repeat (800) @(negedge clk);

        test_name = "ACK RX";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(ACK); 
        send_eop();
        repeat (800) @(negedge clk);

        test_name = "OUT RX";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(OUT);
        send_packet_decoded(ADDR_1END); //ADDR + EN1
        send_packet_decoded(END_CRC5); //EN2+CRC5 
        send_eop();
        repeat (800) @(negedge clk);

        test_name = "DATA RX";
        @(negedge clk);
        send_packet_decoded(8'h80); //SYNC
        send_packet_decoded(DATA0);
        repeat(16) begin
        send_packet_decoded(DUMMY_DATA1);
        send_packet_decoded(DUMMY_DATA2);
        end
        send_packet_decoded(CRC_DATA1);
        send_packet_decoded(CRC_DATA2);
        send_eop();
        repeat (800) @(negedge clk);
        */


        $finish;
    end
endmodule

/* verilator coverage_on */
