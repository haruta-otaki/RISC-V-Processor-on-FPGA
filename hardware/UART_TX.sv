module uart_TX 
    // CLKS_PER_BIT = (Frequency of clock)/(Frequency of UART)
    // (25 MHz Clock)/(115200 baud) = 217
    #(parameter CLKS_PER_BIT = 217)
    (
    input logic clock,
    input logic reset, 
    input logic TXvalid,
    input logic [7:0] TXbyte, 
    output logic TXactive,
    output logic TXserial
    );

    parameter IDLE         = 2'b00;
    parameter TX_START_BIT = 2'b01;
    parameter TX_DATA_BITS = 2'b10;
    parameter TX_STOP_BIT  = 2'b11;

    logic [1:0] state;
    logic [$clog2(CLKS_PER_BIT):0] clockCount;
    logic [2:0] index;
    logic [7:0] TXdata;

    // Control TX state machine
    always @(posedge clock or posedge reset)
    begin
        if (reset)
        begin
            state <= IDLE; 
            clockCount <= 0;
            index <= 0;
            TXserial <= 1'b1;
            TXactive   <= 1'b0;
        end
        else 
        begin
            case (state)
                IDLE :
                begin
                    TXserial <= 1'b1; // Drive Line High for Idle
                    clockCount <= 0;
                    index <= 0;
                    
                    if (TXvalid == 1'b1)
                    begin
                        TXactive <= 1'b1;
                        // prevents conflicts for when TXbyte changes during processing
                        TXdata <= TXbyte;
                        state <= TX_START_BIT;
                    end
                    else
                        state <= IDLE;
                end 

                // Send out Start Bit, wait CLKS_PER_BIT-1 clock cycles 
                TX_START_BIT :
                begin
                    TXserial <= 1'b0;
                    if (clockCount < CLKS_PER_BIT-1)
                    begin
                        clockCount <= clockCount + 1;
                        state <= TX_START_BIT;
                    end
                    else
                    begin
                        clockCount <= 0;
                        state <= TX_DATA_BITS;
                    end
                end 
                
                TX_DATA_BITS :
                begin
                    TXserial <= TXdata[index];
                    
                    if (clockCount < CLKS_PER_BIT-1)
                    begin
                        clockCount <= clockCount + 1;
                        state <= TX_DATA_BITS;
                    end
                    else
                    begin
                        clockCount <= 0;
                        // check if we have sent out all bits
                        if (index < 7)
                        begin
                            index <= index + 1;
                            state <= TX_DATA_BITS;
                        end
                        else
                            state <= TX_STOP_BIT;
                    end 
                end 
                
                // Send out Stop bit
                TX_STOP_BIT :
                begin
                    TXserial <= 1'b1;
                    if (clockCount < CLKS_PER_BIT-1)
                    begin
                        clockCount <= clockCount + 1;
                        state <= TX_STOP_BIT;
                    end
                    else
                    begin
                        TXactive   <= 1'b0;
                        state     <= IDLE;
                    end 
                end 
                
                default :
                state <= IDLE;
            endcase
        end
  end
endmodule