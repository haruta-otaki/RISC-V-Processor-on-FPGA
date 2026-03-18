module uart   
  # (parameter CLKS_PER_BIT = 217)
  (
    input clock, 
    input reset, 
    input UART_RX, 
    output UART_TX
  );
  
  wire [7:0] w_Binary_Count; 
  wire w_RX_DV; 

  wire w_TX_Active; 
  wire w_TX_Serial; 

  UART_RX #(
    .CLKS_PER_BIT(217)
  )
  UART_RX_INST
    (
    .clock(clock),
    .reset(reset),
    .i_RX_Serial(UART_RX),
    .o_RX_DV(w_RX_DV),
    .o_RX_Byte(w_Binary_Count)
    );

  UART_TX #(
    .CLKS_PER_BIT(217)
  )
  UART_TX_INST
    (
      .clock(clock),
      .i_TX_DV(w_RX_DV),
      .i_TX_Byte(w_Binary_Count),
      .o_TX_Active(w_TX_Active),
      .o_TX_Serial(w_TX_Serial),
      .o_TX_Done()
    );

  // drive UART transmitter high when transmitter is inactive
  assign UART_TX = w_TX_Active ? w_TX_Serial : 1'b1; 

  reg [3:0] r_Count_1 = w_Binary_Count >> 4; 
  reg [3:0] r_Count_2 = w_Binary_Count[3:0]; 
endmodule
