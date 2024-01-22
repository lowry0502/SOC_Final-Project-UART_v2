module uart_rx_fifo (
  input wire        rst_n,
  input wire        clk,
  input wire        i_fifo_rq,
  input wire [7:0]  i_rx_data,
  output reg        o_rx_finish,
  input wire        i_frame_err,
  input wire        i_rx_busy,
  output reg        irq,
  output reg        o_num_irq,
  output reg [31:0] o_rx_data,
  output reg [31:0] o_rx_num,
  input wire        i_rx_finish,
  input wire        i_rx_num_finish,
  output reg        frame_err,
  output reg        busy,
  output reg        send_signal
);

  parameter WAIT           = 4'd0;
  parameter WAIT_TO_READ   = 4'd1;
  parameter READ           = 4'd2;
  parameter SEND_NUM       = 4'd3;
  parameter WAIT_READ_NUM  = 4'd4;
  parameter SEND           = 4'd5;
  parameter WAIT_READ      = 4'd6;

  reg [3:0] read_state, next_read_state;
  reg [3:0] send_state, next_send_state;
  reg [7:0] mem [0:511];
  reg [8:0] data_num;
  reg rx_fifo_full;
  reg [8:0] store_pos, read_pos;
  reg [8:0] send_cnt;
  reg sub_flag, add_flag;
  
  // FIFO read from rx
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_num <= 9'd0;
        store_pos <= 9'd0;
        read_state <= WAIT;
        o_rx_finish <= 1'b0;
        add_flag <= 1'b0;
    end else begin
        read_state <= next_read_state;
        case(read_state)
            WAIT:begin
                o_rx_finish <= 1'b0;
                add_flag <= 1'b0;
            end
            WAIT_TO_READ:begin

            end
            READ:begin
                add_flag <= 1'b1;
                //data_num <= data_num + 9'd1;
                store_pos <= store_pos + 9'd1;
                mem[store_pos] <= i_rx_data;
                o_rx_finish <= 1'b1;
            end
        endcase
    end
  end
  always @(*)begin
    if(data_num == 9'd511)
            rx_fifo_full = 1'b1;
    else    rx_fifo_full = 1'b0;
    case(read_state)
        WAIT:
            if(i_fifo_rq)
                if(rx_fifo_full)
                    next_read_state = WAIT_TO_READ;
                else
                    next_read_state = READ;
            else    next_read_state = WAIT;
        WAIT_TO_READ:
            if(rx_fifo_full)
                    next_read_state = WAIT_TO_READ;
            else    next_read_state = READ;
        READ:       next_read_state = WAIT;
    endcase
  end

  // FIFO send to CPU
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        read_pos <= 9'd0;
        send_cnt <= 9'd0;
        o_rx_data <= 32'b0;
        o_rx_num <= 32'd0;
        irq <= 1'b0;
        o_num_irq <= 1'b0;
        send_signal <= 1'b0;
        frame_err <= 1'b0;
        busy <= 1'b0;
        send_state <= WAIT;
        sub_flag <= 1'b0;
    end else begin
        send_state <= next_send_state;
        case(send_state)
            WAIT:begin
                o_rx_data <= 32'b0;
                o_rx_num <= 32'd0;
                frame_err <= 1'b0;
                busy <= 1'b0;
            end
            SEND_NUM:begin
                o_rx_num <= {23'd0, data_num};
                o_num_irq <= 1'b1;
                irq <= 1'b1;
                busy <= 1'b1;
            end
            WAIT_READ_NUM:begin
                o_num_irq <= 1'b0;
                irq <= 1'b0;
                send_cnt <= 9'd0;
                busy <= 1'b0;
            end
            SEND:begin
                sub_flag <= 1'b1;
                //data_num <= data_num - 9'd1;
                read_pos <= read_pos + 9'd1;
                send_cnt <= send_cnt + 9'd1;
                o_rx_data <= {24'd0, mem[read_pos]};
                send_signal <= 1'b1;
                busy <= 1'b1;
            end
            WAIT_READ:begin
                sub_flag <= 1'b0;
                send_signal <= 1'b0;
                busy <= 1'b0;
            end
        endcase
    end
  end
  always @(*)begin
    case(send_state)
        WAIT:
            if(data_num >= 9'd5)
                    next_send_state = SEND_NUM;
            else    next_send_state = WAIT;
        SEND_NUM:   next_send_state = WAIT_READ_NUM;
        WAIT_READ_NUM:
            if(i_rx_num_finish)
                    next_send_state = SEND;
            else    next_send_state = WAIT_READ_NUM;
        SEND:       next_send_state = WAIT_READ;
        WAIT_READ:
            if(i_rx_finish)
                if(send_cnt == o_rx_num)
                    next_send_state = WAIT;
                else next_send_state = SEND;
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