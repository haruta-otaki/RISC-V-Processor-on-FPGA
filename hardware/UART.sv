module uart   
  # (parameter CLKS_PER_BIT = 217)
  (
    input logic clock, 
    input logic reset, 
    output logic [7:0] ioReadingData,
    input logic [7:0] ioWritingData,  
    output logic isRX, 
    input logic isTX, 
    input logic RXserial, 
    output logic TXserial
  );
  
  logic [7:0] w_Binary_Count; 

  logic TXactive; 
  logic currentTXserial; 

  uart_RX #(
    .CLKS_PER_BIT(217)
  )
  UART_RX
    (
    .clock(clock),
    .reset(reset),
    .RXserial(RXserial),
    .RXvalid(isRX),
    .RXbyte(ioReadingData)
    );

  uart_TX #(
    .CLKS_PER_BIT(217)
  )
  UART_TX
    (
      .clock(clock),
      .reset(reset),
      .TXvalid(isTX),
      .TXbyte(ioWritingData),
      .TXactive(TXactive),
      .TXserial(currentTXserial),
      .TXdone()
    );

  // drive UART transmitter high when transmitter is inactive
  assign TXserial = TXactive ? currentTXserial : 1'b1; 
endmodule
