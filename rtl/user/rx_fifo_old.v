module uart_rx_fifo (
  input wire        rst_n,
  input wire        clk,
  input wire        i_fifo_rq,
  input wire [7:0]  i_rx_data,
  output reg        o_rx_finish,
  input wire        i_frame_err,
  input wire        i_rx_busy,
  output reg        irq,
  output reg [31:0] o_rx_data,
  output reg [31:0] o_rx_num,
  input wire        i_rx_finish,
  output reg        frame_err,
  output reg        busy
);

  parameter WAIT        = 4'd0;
  parameter READ        = 4'd1;
  parameter IRQ         = 4'd2;
  parameter WAIT_READ   = 4'd3;
  parameter RST         = 4'd4;

  reg [3:0]  state, next_state;
  reg [1:0]  cnt;
  reg [31:0] idle_cnt;

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        o_rx_finish <= 1'b0;
        irq <= 1'b0;
        frame_err <= 1'b0;
        busy <= 1'b0;
        o_rx_data <= 32'b0;
        o_rx_num <= 32'b0;
        cnt <= 2'b00;
        idle_cnt <= 32'd0;
    end else begin
        state <= next_state;
        case(state)
        WAIT:begin
            o_rx_finish <= 1'b0;
            irq <= 1'b0;
            frame_err <= 1'b0;
            busy <= 1'b0;
            idle_cnt <= idle_cnt + 32'd1;
        end
        READ:begin
            case(cnt)
                2'b00: o_rx_data[31:24] <= i_rx_data;
                2'b01: o_rx_data[23:16] <= i_rx_data;
                2'b10: o_rx_data[15:8] <= i_rx_data;
                2'b11: o_rx_data[7:0] <= i_rx_data;
            endcase
            o_rx_num <= cnt + 32'd1;
            o_rx_finish <= 1'b1;
            busy <= 1'b1;
            if(cnt == 2'b11)
                    cnt <= 2'b00;
            else    cnt <= cnt + 2'b01;
            idle_cnt <= 32'd0;
        end
        IRQ:begin
            o_rx_finish <= 1'b0;
            irq <= 1'b1;
            busy <= 1'b0;
            frame_err <= 1'b0;
            idle_cnt <= 32'd0;
        end
        WAIT_READ:begin
            irq <= 1'b0;
            busy <= 1'b0;
            frame_err <= 1'b0;
        end
        RST:begin
            o_rx_data <= 32'b0;
            o_rx_num <= 32'b0;
            cnt <= 2'b00;
        end
        default:begin
            o_rx_finish <= 1'b0;
            irq <= 1'b0;
            frame_err <= 1'b0;
        end
        endcase
    end
  end

  always @(*) begin
    case(state)
    WAIT:
        if(i_fifo_rq) 
                next_state = READ;
        else if(idle_cnt > 32'd60000 && cnt > 2'b00)
                next_state = IRQ;
        else    next_state = WAIT;
    READ:
        if(cnt == 2'b11)     
                next_state = IRQ;
        else    next_state = WAIT;
    IRQ:        next_state = WAIT_READ;
    WAIT_READ:
        if(i_rx_finish)
                next_state = RST;
        else    next_state = WAIT_READ;
    RST:        next_state = WAIT;
    default:    next_state = WAIT;
    endcase
  end

endmodule