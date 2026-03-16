module Bounch_Switch   
  (
    input i_Clk, input i_UART_RX, output o_UART_TX,
    output o_Segment1_A, output o_Segment1_B, output o_Segment1_C, output o_Segment1_D, 
    output o_Segment1_E, output o_Segment1_F, output o_Segment1_G,
    output o_Segment2_A, output o_Segment2_B, output o_Segment2_C, output o_Segment2_D, 
    output o_Segment2_E, output o_Segment2_F, output o_Segment2_G
  );

  reg r_Switch_1 = 1'b0;
  reg [3:0] r_Count = 4'b0000; 
  wire w_Segment_A_1; 
  wire w_Segment_B_1; 
  wire w_Segment_C_1; 
  wire w_Segment_D_1; 
  wire w_Segment_E_1; 
  wire w_Segment_F_1; 
  wire w_Segment_G_1; 
  wire w_Segment_A_2; 
  wire w_Segment_B_2; 
  wire w_Segment_C_2; 
  wire w_Segment_D_2; 
  wire w_Segment_E_2; 
  wire w_Segment_F_2; 
  wire w_Segment_G_2; 

  wire [7:0] w_Binary_Count; 
  wire w_RX_DV; 

  wire w_TX_Active; 
  wire w_TX_Serial; 

  UART_RX #(
    .CLKS_PER_BIT(217)
  )
  UART_RX_INST
    (
    .i_Clock(i_Clk),
    .i_RX_Serial(i_UART_RX),
    .o_RX_DV(w_RX_DV),
    .o_RX_Byte(w_Binary_Count)
    );

  UART_TX #(
    .CLKS_PER_BIT(217)
  )
  UART_TX_INST
    (
      .i_Clock(i_Clk),
      .i_TX_DV(w_RX_DV),
      .i_TX_Byte(w_Binary_Count),
      .o_TX_Active(w_TX_Active),
      .o_TX_Serial(w_TX_Serial),
      .o_TX_Done()
    );

  // drive UART transmitter high when transmitter is inactive
  assign o_UART_TX = w_TX_Active ? w_TX_Serial : 1'b1; 
  // wire w_Switch_1; 
  // Debounce_Switch Debounce_Switch_Instance 
  //   (
  //     .i_Clk(i_Clk),
  //     .i_Switch(i_Switch_1),
  //     .o_Switch(w_Switch_1),
  //   );

  // always @(posedge i_Clk) 
  // begin
  //   r_Switch_1 <= w_Switch_1; 
  //   if (w_Switch_1 == 1'b0 && r_Switch_1 == 1'b1) 
  //     begin
  //       r_Count <= r_Count + 1; 
  //       if (r_Count == 9) 
  //         r_Count <= 0; 
  //     end
  // end

  reg [3:0] r_Count_1 = w_Binary_Count >> 4; 
  reg [3:0] r_Count_2 = w_Binary_Count[3:0]; 

  Seven_Segment_Display Seven_Segment_Display_Instance 
    (
      .i_Clk(i_Clk),
      .i_Binary_Count_1(r_Count_1),
      .i_Binary_Count_2(r_Count_2),
      .o_Segment_A_1(w_Segment_A_1),
      .o_Segment_B_1(w_Segment_B_1),
      .o_Segment_C_1(w_Segment_C_1),
      .o_Segment_D_1(w_Segment_D_1),
      .o_Segment_E_1(w_Segment_E_1),
      .o_Segment_F_1(w_Segment_F_1),
      .o_Segment_G_1(w_Segment_G_1),
      .o_Segment_A_2(w_Segment_A_2),
      .o_Segment_B_2(w_Segment_B_2),
      .o_Segment_C_2(w_Segment_C_2),
      .o_Segment_D_2(w_Segment_D_2),
      .o_Segment_E_2(w_Segment_E_2),
      .o_Segment_F_2(w_Segment_F_2),
      .o_Segment_G_2(w_Segment_G_2),
    );

  assign o_Segment1_A = ~w_Segment_A_1;
  assign o_Segment1_B = ~w_Segment_B_1;
  assign o_Segment1_C = ~w_Segment_C_1;
  assign o_Segment1_D = ~w_Segment_D_1;
  assign o_Segment1_E = ~w_Segment_E_1;
  assign o_Segment1_F = ~w_Segment_F_1;
  assign o_Segment1_G = ~w_Segment_G_1;

  assign o_Segment2_A = ~w_Segment_A_2;
  assign o_Segment2_B = ~w_Segment_B_2;
  assign o_Segment2_C = ~w_Segment_C_2;
  assign o_Segment2_D = ~w_Segment_D_2;
  assign o_Segment2_E = ~w_Segment_E_2;
  assign o_Segment2_F = ~w_Segment_F_2;
  assign o_Segment2_G = ~w_Segment_G_2;
endmodule
