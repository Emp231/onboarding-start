module spi_peripheral (
    input wire SCLK,
    input wire nCS,
    input wire COPI,
    input wire clk,
    input wire rst_n,

    output reg  [7:0] en_reg_out_7_0,
    output reg  [7:0] en_reg_out_15_8,
    output reg  [7:0] en_reg_pwm_7_0,
    output reg  [7:0] en_reg_pwm_15_8,
    output reg  [7:0] pwm_duty_cycle
);

reg SCLK_sync1, SCLK_sync2;
reg nCS_sync1, nCS_sync2;
reg COPI_sync1, COPI_sync2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
    // reset all
        nCS_sync1  <= 1'b1;
        nCS_sync2  <= 1'b1;
        SCLK_sync1 <= 1'b0;
        SCLK_sync2 <= 1'b0;
        COPI_sync1 <= 1'b0;
        COPI_sync2 <= 1'b0;
    
    end else begin

        SCLK_sync1 <= SCLK;
        SCLK_sync2 <= SCLK_sync1;
        nCS_sync1 <= nCS;
        nCS_sync2 <= nCS_sync1;
        COPI_sync1 <= COPI;
        COPI_sync2 <= COPI_sync1;
    
    end
end

wire SCLK_sync = SCLK_sync2;
wire COPI_sync = COPI_sync2;
wire nCS_sync = nCS_sync2;

reg SCLK_previous;
wire SCLK_rise = (SCLK_sync2 == 1'b1) && (SCLK_previous == 1'b0);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        SCLK_previous <= 1'b0;
    
    end else begin
        SCLK_previous <= SCLK_sync2;
    end
end

reg nCS_previous;
wire nCS_fall = (nCS_sync2 == 1'b0) && (nCS_previous == 1'b1);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        nCS_previous <= 1'b1;
    
    end else begin
        nCS_previous <= nCS_sync2;
    end
end

reg[15:0] shift_register;
reg[4:0] bit_count;
reg      frame;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        shift_register <= 16'd0;
        bit_count <= 5'd0;
        frame <= 1'b0;
        pwm_duty_cycle <= 8'd0;
    end else begin
        if(nCS_fall) begin
            frame <= 1'b1;
            bit_count <= 5'd0;
        end

        if(frame && SCLK_rise) begin
            shift_register <= {shift_register[14:0], COPI_sync};
            bit_count <= bit_count + 5'd1;

            if(bit_count == 5'd15) frame <= 1'b0;
        end

        if(nCS_sync) begin
            frame <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        en_out <= 16'd0;
        en_pwm_mode <= 16'd0;
        pwm_duty_cycle <= 8'd0;
    end else if(bit_count == 5'd15 && shift_register[15] == 1'b1) begin
        case(shift_register[14:8])
            7'h00: en_out[7:0]       <= shift_register[7:0];
            7'h01: en_out[15:8]      <= shift_register[7:0];
            7'h02: en_pwm_mode[7:0]  <= shift_register[7:0];
            7'h03: en_pwm_mode[15:8] <= shift_register[7:0];
            7'h04: pwm_duty_cycle    <= shift_register[7:0];
            default: ;
        endcase
    end
end


reg [15:0] en_out, en_pwm_mode;

assign en_reg_out_7_0   = en_out[7:0];
assign en_reg_out_15_8  = en_out[15:8];
assign en_reg_pwm_7_0   = en_pwm_mode[7:0];
assign en_reg_pwm_15_8  = en_pwm_mode[15:8];

endmodule