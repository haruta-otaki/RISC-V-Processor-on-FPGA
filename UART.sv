module uart   
  # (parameter CLKS_PER_BIT = 217)
  (
    input logic clock, 
    input logic reset, 
    input logic RXserial, 
    output logic TXserial
  );
  
  wire [7:0] w_Binary_Count; 
  wire w_RX_DV; 

  wire w_TX_Active; 
  wire w_TX_Serial; 

  uart_RX #(
    .CLKS_PER_BIT(217)
  )
  UART_RX
    (
    .clock(clock),
    .reset(reset),
    .RXserial(RXserial),
    .RXvalid(w_RX_DV),
    .RXbyte(w_Binary_Count)
    );

  uart_TX #(
    .CLKS_PER_BIT(217)
  )
  UART_TX
    (
      .clock(clock),
      .reset(reset),
      .TXvalid(w_RX_DV),
      .TXbyte(w_Binary_Count),
      .TXactive(w_TX_Active),
      .TXserial(w_TX_Serial),
      .TXdone()
    );

  // drive UART transmitter high when transmitter is inactive
  assign TXserial = w_TX_Active ? w_TX_Serial : 1'b1; 

  reg [3:0] r_Count_1 = w_Binary_Count >> 4; 
  reg [3:0] r_Count_2 = w_Binary_Count[3:0]; 
endmodule
