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
  parameter WAIT_TO_SEND = 4'd2;
  parameter SEND         = 4'd3;
  parameter WAIT_READ    = 4'd4;

  reg [3:0] state, next_state;
  reg [1:0] detect_posedge_start;
  reg [31:0] tx_buffer, tx_num_buffer;
  reg [2:0] send_cnt;

  always @(posedge clk or negedge rst_n)begin
    if(!rst_n) 
      detect_posedge_start <= 2'b00;
    else 
      detect_posedge_start <= {detect_posedge_start[0], i_tx_start};
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        send_cnt <= 3'd0;
        o_tx_start <= 1'b0;
        o_busy <= 1'b0;
        o_clear_req <= 1'b0;
        tx_buffer <= 32'h00000000;
        tx_num_buffer <= 32'h00000000;
        o_tx_data <= 32'h00000000;
    end else begin
      state <= next_state;
      case(state)
        WAIT:begin
            o_busy <= 1'b0;
            o_clear_req <= 1'b0;
            send_cnt <= 3'd0;
            o_tx_start <= 1'b0;
            tx_buffer <= 32'h00000000;
            tx_num_buffer <= 32'h00000000;
            o_tx_data <= 32'h00000000;
        end
        READ:begin
            o_busy <= 1'b1;
            o_clear_req <= 1'b1;
            tx_buffer <= i_tx_data;
            tx_num_buffer <= i_tx_num;
        end
        SEND:begin
            o_clear_req <= 1'b0;
            o_busy <= 1'b1;
            send_cnt <= send_cnt + 3'd1;
            case(send_cnt)
                3'd0: o_tx_data <= tx_buffer[31:24];
                3'd1: o_tx_data <= tx_buffer[23:16];
                3'd2: o_tx_data <= tx_buffer[15:8];
                3'd3: o_tx_data <= tx_buffer[7:0];
                default: o_tx_data <= tx_buffer[31:24];
            endcase
            o_tx_start <= 1'b1;
        end
        WAIT_READ:begin
            if(i_tx_start_clear) begin
                o_tx_data <= 32'h00000000;
                o_tx_start <= 1'b0;
            end
        end
      endcase
    end
  end

  always @(*) begin
    case(state)
      WAIT:
        if(detect_posedge_start == 2'b01)
                next_state = READ;
        else    next_state = WAIT;
      READ:     
        if(!i_busy)
                next_state = SEND;
        else    next_state = WAIT_TO_SEND;
      WAIT_TO_SEND:
        if(!i_busy)
                next_state = SEND;
        else    next_state = WAIT_TO_SEND;
      SEND:     next_state = WAIT_READ;
      WAIT_READ:
        if(i_tx_start_clear)
            if(send_cnt == tx_num_buffer)
                next_state = WAIT;
            else
                next_state = SEND;
        else    next_state = WAIT_READ;
      default:  next_state = WAIT;
    endcase
  end

endmodule