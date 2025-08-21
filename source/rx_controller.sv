`timescale 1ns / 10ps

module rx_controller #(
    // parameters
) (
    input logic clk, n_rst, clk_div,
    input logic byte_strobe ,bitstuff_error, d_edge,
    input logic [6:0] buffer_occupancy,
    input logic [7:0] packet_data, 
    input logic  eop, eop_error,crc_right,crc_wrong,addr_right, addr_wrong,rollover_flag_3,
    output logic flush, rx_error, rx_dr, rx_busy, store_rx_data, crc_check, en_clk_div, addr_check, clk_4_en,
    output logic store_data, shift_in, send_packet, store_packet, clear, shift_en, clear_clk, count_en, EOP_en, NRZI_en, clear_4clk
);

logic buffer_full; //make comb logic to check if buffer is full or not

typedef enum logic [5:0]  {IDLE,START, SAMPLE, SYNC_WAIT, SYNC, PID_WAIT, PID,FLUSH,FLUSH_WAIT, START_SHIFT, DATA_WAIT, DATA_WAIT2, DATA_SHIFT, STORE_DATA, DATA_CRC,
                           CRC_WAIT, DATA_EOP, DATA_IDLE, DATA_ERROR, TOKEN_SHIFT,TOKEN_WAIT1,TOKEN_WAIT2,TOKEN_WAIT3, TOKEN_DATA1, TOKEN_DATA2,TOKEN_ADDR_WAIT, TOKEN_ADDR, TOKEN_CRC, TOKEN_CRC_WAIT, TOKEN_EOP,
                           ACK_SHIFT,ACK_WAIT,ACK_SEND, EIDLE, EOP_CHECK} state_t;
state_t state, next_state;

always_ff @(posedge clk, negedge n_rst) begin
    if(~n_rst) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end


//NEXT_STATE LOGIC:
always_comb begin
    next_state = state;
    case(state)
    IDLE: next_state = eop ? EIDLE : d_edge ? START : IDLE ; 
    START: next_state = eop ? EIDLE : rollover_flag_3 ? SAMPLE : START;
    SAMPLE: next_state = eop? EIDLE : SYNC_WAIT;
    SYNC_WAIT: next_state = eop ? EIDLE : byte_strobe ? SYNC : SYNC_WAIT ; 
    SYNC: next_state = eop ? EIDLE: (packet_data == 8'h80) ? PID_WAIT : EIDLE ;
    PID_WAIT: next_state = eop  ? EIDLE : byte_strobe? PID : PID_WAIT;
    PID: begin
        if(eop)
            next_state = EIDLE;
        case(packet_data)
        8'b11100001, 8'b01101001: next_state = TOKEN_SHIFT; //OUT TOKEN, IN TOKEN
        8'b11000011, 8'b01001011: next_state = FLUSH; //DATA0, DATA1
        8'b11010010: next_state = ACK_SHIFT; //ACK
        default: next_state = EIDLE;
        endcase
    end
    //----------
    //DATA STATES
    //----------
    FLUSH: next_state = (eop ||bitstuff_error) ? EIDLE : FLUSH_WAIT; 
    FLUSH_WAIT: next_state = (eop ||bitstuff_error) ? EIDLE : byte_strobe ? START_SHIFT : FLUSH_WAIT;
    START_SHIFT: next_state = (eop || bitstuff_error) ? EIDLE : byte_strobe ? DATA_WAIT : START_SHIFT;
    DATA_WAIT: next_state = (eop_error ||bitstuff_error) ? EIDLE : eop ? DATA_CRC : byte_strobe ? DATA_SHIFT : DATA_WAIT;
    //shift store repetition starts here
    DATA_SHIFT: next_state = (eop_error || bitstuff_error || buffer_full) ? DATA_ERROR : eop ? DATA_CRC : DATA_WAIT2;
    DATA_WAIT2: next_state = (eop_error || bitstuff_error) ? DATA_ERROR : eop ? DATA_CRC : byte_strobe ? STORE_DATA : DATA_WAIT2;
    STORE_DATA: next_state = (eop_error || bitstuff_error || buffer_full) ? DATA_ERROR : eop ? DATA_CRC : DATA_SHIFT;
    DATA_ERROR: next_state = EIDLE;
    DATA_CRC: next_state = eop_error ? DATA_ERROR : CRC_WAIT;
    CRC_WAIT: next_state = crc_wrong ? EIDLE : crc_right ? DATA_EOP : CRC_WAIT; 
    DATA_EOP: next_state = DATA_IDLE; 
    DATA_IDLE : next_state = d_edge ? START : DATA_IDLE;
    //-----------
    //TOKEN STATES
    //------------
    TOKEN_SHIFT: next_state =  (eop || bitstuff_error) ? EIDLE : TOKEN_WAIT1;
    TOKEN_WAIT1:next_state = (eop || bitstuff_error) ? EIDLE : byte_strobe ? TOKEN_DATA1 : TOKEN_WAIT1;
    TOKEN_DATA1: next_state = (eop|| bitstuff_error) ? EIDLE : TOKEN_WAIT2;
    TOKEN_WAIT2: next_state = (eop || bitstuff_error) ? EIDLE : byte_strobe ? TOKEN_DATA2 : TOKEN_WAIT2;
    TOKEN_DATA2: next_state = (eop || bitstuff_error) ? EIDLE : TOKEN_WAIT3;
    TOKEN_WAIT3: next_state = (eop_error || bitstuff_error || addr_wrong) ? EIDLE : eop ? TOKEN_ADDR_WAIT : TOKEN_WAIT3;
    TOKEN_ADDR_WAIT: next_state = (eop_error) ? EIDLE : TOKEN_ADDR;
    TOKEN_ADDR: next_state = (eop_error || addr_wrong) ? EIDLE : addr_right ?  TOKEN_CRC : TOKEN_ADDR;
    TOKEN_CRC: next_state = TOKEN_CRC_WAIT;
    TOKEN_CRC_WAIT: next_state = (crc_wrong || eop_error || bitstuff_error) ? EIDLE : crc_right ? TOKEN_EOP : TOKEN_CRC_WAIT;
    TOKEN_EOP: next_state = IDLE;
    //---------
    //ACK STATES
    //---------
    ACK_SHIFT: next_state = (eop_error ||bitstuff_error) ? EIDLE: ACK_WAIT;
    ACK_WAIT: next_state = (eop_error ||bitstuff_error) ? EIDLE: eop? ACK_SEND : ACK_WAIT;
    ACK_SEND: next_state = EOP_CHECK;
    EOP_CHECK: next_state = eop_error ? EIDLE : eop? EOP_CHECK : IDLE;
    //EIDLE
    EIDLE: next_state = d_edge ? START : EIDLE;
    default: next_state = IDLE;
    endcase
end

 //Output Logic
always_comb begin
    flush = 0;
    rx_error = 0; 
    rx_dr = 0;
    rx_busy = 1;
    store_rx_data = 0;
    store_data = 0;
    crc_check = 0;
    send_packet = 0;
    shift_in = 0;
    clear = 0;
    en_clk_div = 1;
    store_packet = 0;
    addr_check = 0;
    shift_en = ((clk_div == 1) || (rollover_flag_3 == 1 ));
    NRZI_en = ((clk_div == 1)) || (rollover_flag_3 == 1);
    count_en = ((clk_div == 1)) || (rollover_flag_3 == 1);
    EOP_en = clk_div;
    clear_clk = 0;
    clk_4_en = 0;
    clear_4clk = 0;
    case(state)
    IDLE: begin
        en_clk_div = 0;
        rx_busy = 0;
        clear = 1;
        clear_4clk = 1;
        send_packet = 1;
        shift_en = 0;
        count_en = 0;
        clear_clk = 1;
    end
    START: begin
        en_clk_div = 0;
        clk_4_en = 1;
    end
    SAMPLE: begin
        en_clk_div = 1;
        clear_4clk = 1;

    end
    SYNC_WAIT: begin
        en_clk_div = 1;
        
    end
    SYNC: begin
        en_clk_div = 1;
        clear = 1;    
    end
    PID_WAIT: begin
        en_clk_div = 1; 
    end
    PID: begin //COMING BACK HERE LATER 
        en_clk_div = 1;
        clear = 1;
    end
    //----------
    //DATA STATES
    //----------
    FLUSH: begin
        flush = 1;
        shift_in  = 1;
        en_clk_div = 1;        
    end
    FLUSH_WAIT: begin
        flush = 0;
        shift_in = 0;
        store_packet = 1;
    end
    START_SHIFT: begin
        en_clk_div = 1;
        shift_in = 1;
        store_data = 0;
        clear = 1;
    end
    DATA_WAIT: begin 
        en_clk_div = 1;
        shift_in = 0;
    end
    //shift store repetition starts here
    DATA_SHIFT: begin
        en_clk_div = 1;
        store_data = 0;
        shift_in = 1;
        clear = 1;
    end
    DATA_WAIT2: begin 
        en_clk_div = 1;
        shift_in = 0;
    end
    STORE_DATA: begin
        en_clk_div = 1;
        store_data = 1;
        shift_in  = 0;
        store_rx_data = 1;
        clear = 1;
    end
    DATA_ERROR: begin
        rx_error = 1;
        flush = 1; //does flush need to be seen for multiple clk cycles? no.
        clear = 1;
    end
    DATA_CRC: begin
        en_clk_div = 1;
        store_data = 0;
        crc_check = 1;
        shift_in = 0;
        store_data = 0; 
    end
    CRC_WAIT: begin
        en_clk_div = 1;
        crc_check = 0;
    end
    DATA_EOP: begin
        en_clk_div = 1;
        rx_dr = 1; //does this need to be on for multi cycless?
        clear = 1;
    end
    DATA_IDLE: begin
        rx_dr = 1;
        rx_busy = 0;
        clear = 1;
        send_packet = 1;
        clear_clk = 1;
        clear_4clk = 1;
        en_clk_div = 0;
    end
    //------------
    //TOKEN STATES
    //------------
    TOKEN_SHIFT:begin
        en_clk_div = 1;
        shift_in = 1;
        store_packet  = 1;
        clear = 1;
    end
    TOKEN_WAIT1:begin
        en_clk_div = 1;
        shift_in = 0;
    end
    TOKEN_DATA1: begin
        en_clk_div = 1;
        shift_in= 1;
        clear = 1;
    end
    TOKEN_WAIT2:begin
        en_clk_div = 1;
        shift_in = 0;
    end
    TOKEN_DATA2: begin
        en_clk_div = 1;
        shift_in= 1;
        clear = 1;
    end
    TOKEN_WAIT3:begin
        en_clk_div = 1;
        shift_in = 0;
    end
    TOKEN_ADDR_WAIT: begin
        en_clk_div = 1;
        addr_check = 1;
    end
    TOKEN_ADDR: begin
        en_clk_div = 1;
        addr_check = 1;
    end
    TOKEN_CRC: begin
        en_clk_div = 1;
        crc_check = 1;
    end
    TOKEN_CRC_WAIT: begin 
        en_clk_div = 1;
        crc_check = 0;
    end
    TOKEN_EOP: begin
        send_packet = 1;
        clear = 1;
    end
    //---------
    //ACK STATES
    //---------
    ACK_SHIFT: begin
        shift_in = 1;//ack is three
    end
    ACK_WAIT: begin
        store_packet = 1;
    end
    ACK_SEND: begin
        send_packet = 1;
    end
    EOP_CHECK: begin
        clear = 1;
    end
    //EIDLE
    EIDLE: begin
        rx_error = 1;
        rx_busy = 0; //not 100% sure if this should be 0, 
        clear = 1;
        clear_clk = 1;
        clear_4clk = 1;
        en_clk_div = 0;
    end
    endcase
end

//buffer full logic
always_comb begin
    if(buffer_occupancy == 7'd64)
        buffer_full = 1;
    else 
        buffer_full = 0;
end
endmodule
