module uart   
  # (parameter CLKS_PER_BIT = 217)
  (
    input logic clock, 
    input logic reset, 
    output logic [7:0] uartReadingData,
    input logic [7:0] uartWritingData,  
    input logic isTX, 
    input logic RXserial, 
    output logic TXserial,
    output logic RXfull,
    output logic TXbusy
  );
  
  logic currentTXserial; 

  uart_RX #(
    .CLKS_PER_BIT(217)
  )
  UART_RX
    (
    .clock(clock),
    .reset(reset),
    .RXserial(RXserial),
    .RXvalid(RXfull),
    .RXbyte(uartReadingData)
    );

  uart_TX #(
    .CLKS_PER_BIT(217)
  )
  UART_TX
    (
      .clock(clock),
      .reset(reset),
      .TXvalid(isTX),
      .TXbyte(uartWritingData),
      .TXactive(TXbusy),
      .TXserial(currentTXserial)
    );

  // drive UART transmitter high when transmitter is inactive
  assign TXserial = TXbusy ? currentTXserial : 1'b1; 

endmodule
