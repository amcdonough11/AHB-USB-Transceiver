`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_ahb_lite_satellite ();

    localparam CLK_PERIOD = 10ns;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars;
    end

    logic clk, n_rst;
    logic hsel, hsize, hwrite, hresp;
    logic [3:0] haddr;
    logic [1:0] htrans;
    logic [31:0] hwdata, hrdata;

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
        @(posedge clk);
        @(posedge clk);
    end
    endtask

    ahb_lite_satellite #() DUT (.*);

        // bus model signals
    logic enqueue_transaction_en;
    logic transaction_write;
    logic transaction_fake;
    logic [3:0] transaction_addr;
    logic [15:0] transaction_data;
    logic transaction_error;
    logic [2:0] transaction_size;

    logic model_reset;
    logic enable_transactions;
    integer current_transaction_num;
    logic current_transaction_error;

    ahb_model_updated BFM (.clk(clk),
        // Testing setup signals
        .enqueue_transaction(enqueue_transaction_en),
        .transaction_write(transaction_write),
        .transaction_fake(transaction_fake),
        .transaction_addr(transaction_addr),
        .transaction_data(transaction_data),
        .transaction_error(transaction_error),
        .transaction_size(transaction_size),
        // Testing controls
        .model_reset(model_reset),
        .enable_transactions(enable_transactions),
        .current_transaction_num(current_transaction_num),
        .current_transaction_error(current_transaction_error),
        // AHB-Subordinate Side
        .hsel(hsel),
        .htrans(htrans),
        .haddr(haddr),
        .hsize(hsize),
        .hwrite(hwrite),
        .hwdata(hwdata),
        .hrdata(hrdata),
        .hresp(hresp)
    );

    task enqueue_transaction;
        input logic for_dut;
        input logic write_mode;
        input logic [3:0] address;
        input logic [15:0] data;
        input logic expected_error;
        input logic size;
    begin
        // Make sure enqueue flag is low (will need a 0->1 pulse later)
        enqueue_transaction_en = 1'b0;
        #(0.1ns);
    
        // Setup info about transaction
        transaction_fake  = ~for_dut;
        transaction_write = write_mode;
        transaction_addr  = address;
        transaction_data  = data;
        transaction_error = expected_error;
        transaction_size  = {2'b00,size};
    
        // Pulse the enqueue flag
        enqueue_transaction_en = 1'b1;
        #(0.1ns);
        enqueue_transaction_en = 1'b0;
    end
    endtask
    
    task execute_transactions;
        input integer num_transactions;
        integer wait_var;
    begin
        // Activate the bus model
        enable_transactions = 1'b1;
        @(posedge clk);
    
        // Process the transactions (all but last one overlap 1 out of 2 cycles
        for(wait_var = 0; wait_var < num_transactions; wait_var++) begin
            @(posedge clk);
        end
    
        // Run out the last one (currently in data phase)
        @(posedge clk);
    
        // Turn off the bus model
        @(negedge clk);
        enable_transactions = 1'b0;
    end
    endtask

    initial begin
        n_rst = 1;

        reset_dut;

        $finish;
    end
endmodule

/* verilator coverage_on */

