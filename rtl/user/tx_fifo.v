module uart_tx_fifo(
  input wire        rst_n,
  input wire        clk,
  output reg [7:0]  o_tx_data,
  input wire [31:0] i_tx_data,
  input wire [31:0] i_tx_num,
  input wire        i_tx_start_clear,
  output reg        o_clear_req,
  output reg        o_tx_start,
  input wire        i_tx_start,
  input wire        i_busy,
  output reg        o_busy
);

  parameter WAIT         = 4'd0;
  parameter READ         = 4'd1;
  parameter SEND         = 4'd2;
  parameter WAIT_READ    = 4'd3;

  reg [1:0] detect_posedge_start;
  reg [7:0] mem [0:511];
  reg [3:0] read_state, next_read_state;
  reg [3:0] send_state, next_send_state;
  reg [8:0] store_pos, read_pos;
  reg [8:0] data_num;
  reg add_flag, sub_flag;

  always @(posedge clk or negedge rst_n)begin
    if(!rst_n) 
      detect_posedge_start <= 2'b00;
    else 
      detect_posedge_start <= {detect_posedge_start[0], i_tx_start};
  end

  // tx FIFO read from CPU
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      store_pos <= 9'd0;
      data_num <= 9'd0;
      o_clear_req <= 1'b0;
      o_busy <= 1'b0;
      read_state <= WAIT;
      add_flag <= 1'b0;
    end else begin
      read_state <= next_read_state;
      case(read_state)
        WAIT:begin
          o_clear_req <= 1'b0;
          o_busy <= 1'b0;
          add_flag <= 1'b0;
        end
        READ:begin
          mem[store_pos] <= i_tx_data[7:0];
          o_clear_req <= 1'b1;
          o_busy <= 1'b1;
          store_pos <= store_pos + 9'd1;
          add_flag <= 1'b1;
          //data_num <= data_num + 9'd1;
        end
      endcase
    end
  end
  always @(*) begin
    case(read_state)
      WAIT:
        if(detect_posedge_start == 2'b01)
                next_read_state = READ;
        else    next_read_state = WAIT;
      READ:     next_read_state = WAIT;
    endcase
  end

  // tx FIFO send to tx
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      read_pos <= 9'd0;
      o_tx_data <= 7'd0;
      o_tx_start <= 1'b0;
      send_state <= WAIT;
      sub_flag <= 1'b0;
    end else begin
      send_state <= next_send_state;
      case(send_state)
        WAIT:begin
          o_tx_data <= 7'd0;
          o_tx_start <= 1'b0;
        end
        SEND:begin
          o_tx_data <= mem[read_pos];
          read_pos <= read_pos + 9'd1;
          sub_flag <= 1'b1;
          //data_num <= data_num - 9'd1;
          o_tx_start <= 1'b1;
        end
        WAIT_READ:begin
          if(i_tx_start_clear) begin
                o_tx_data <= 7'd0;
                o_tx_start <= 1'b0;
          end
          sub_flag <= 1'b0;
        end
      endcase
    end
  end
  always @(*) begin
    case(send_state)
      WAIT:
        if(data_num > 9'd0)
                next_send_state = SEND;
        else    next_send_state = WAIT;
      SEND:     next_send_state = WAIT_READ;
      WAIT_READ:
        if(i_tx_start_clear)
          if(data_num > 9'd0)
                next_send_state = SEND;
          else  next_send_state = WAIT;
        else    next_send_state = WAIT_READ;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin

    end else begin
        if(sub_flag == 1'b1 && add_flag == 1'b0)
            data_num <= data_num - 9'd1;
        else if(sub_flag == 1'b0 && add_flag == 1'b1)
            data_num <= data_num + 9'd1;
    end
  end
endmodule