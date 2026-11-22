//============================================================================
// spi_master.v  -  SPI Master, режим 0 (CPOL=0, CPHA=0), MSB first
//----------------------------------------------------------------------------
// Режим 0: SCK у спокої = 0; дані ЗМІНЮЮТЬСЯ по спадному фронту SCK,
//          а ЗЧИТУЮТЬСЯ по наростаючому фронту SCK.
//
// Параметри:
//   DATA_W  - розрядність слова (8)
//   CLK_DIV - к-сть тактів clk у півперіоді SCK. f_sck = f_clk / (2*CLK_DIV)
//
// Порти:
//   clk, rst  - тактування та скидання (rst активний = 1)
//   start     - імпульс запуску обміну (приймається, коли busy = 0)
//   data_in   - слово для передачі (фіксується в момент start)
//   data_out  - прийняте слово (валідне, коли done = 1)
//   busy      - 1 поки йде обмін
//   done      - імпульс на 1 такт: обмін завершено
//   sclk/mosi/miso/cs_n - лінії SPI (cs_n = SS, активний рівень 0)
//
// FSM:  IDLE -> SETUP -> TRANSFER -> HOLD -> IDLE
//============================================================================
module spi_master #(
    parameter DATA_W  = 8,
    parameter CLK_DIV = 4
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              start,
    input  wire [DATA_W-1:0] data_in,
    output wire [DATA_W-1:0] data_out,
    output wire              busy,
    output reg               done,
    output reg               sclk,
    output wire              mosi,
    input  wire              miso,
    output reg               cs_n
);
    // ---- Стани FSM ----
    localparam [1:0] S_IDLE     = 2'd0,  // очікування команди start
                     S_SETUP    = 2'd1,  // cs_n=0, пауза перед першим SCK
                     S_TRANSFER = 2'd2,  // генерація SCK, зсув бітів
                     S_HOLD     = 2'd3;  // пауза після останнього біта

    reg [1:0] state;
    reg [$clog2(CLK_DIV)+1:0] cnt;       // лічильник дільника частоти
    reg [$clog2(DATA_W)+1:0]  bit_cnt;   // лічильник переданих бітів

    wire tick = (cnt == CLK_DIV-1);      // кінець півперіоду SCK

    // Керуючі імпульси для Tx/Rx
    wire load      = (state == S_IDLE) && start;
    wire sample_en = (state == S_TRANSFER) && tick && !sclk;   // фронт 0->1
    wire shift_en  = (state == S_TRANSFER) && tick &&  sclk    // фронт 1->0
                     && (bit_cnt != DATA_W-1);                 // не зсуваємо після останнього біта

    assign busy = (state != S_IDLE);

    // ---- Передавач і приймач ----
    spi_tx #(.DATA_W(DATA_W)) u_tx (
        .clk(clk), .rst(rst), .load(load), .shift_en(shift_en),
        .data_in(data_in), .mosi(mosi)
    );

    spi_rx #(.DATA_W(DATA_W)) u_rx (
        .clk(clk), .rst(rst), .sample_en(sample_en),
        .miso(miso), .data_out(data_out)
    );

    // ---- FSM + генератор SCK ----
    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            cnt     <= 0;
            bit_cnt <= 0;
            sclk    <= 1'b0;
            cs_n    <= 1'b1;
            done    <= 1'b0;
        end else begin
            done <= 1'b0;                          // done - одиночний імпульс
            case (state)
                S_IDLE: begin
                    sclk <= 1'b0;
                    cnt  <= 0;
                    bit_cnt <= 0;
                    if (start) begin
                        cs_n  <= 1'b0;             // активуємо Slave
                        state <= S_SETUP;
                    end
                end

                S_SETUP: begin
                    if (tick) begin cnt <= 0; state <= S_TRANSFER; end
                    else      cnt <= cnt + 1'b1;
                end

                S_TRANSFER: begin
                    if (tick) begin
                        cnt  <= 0;
                        sclk <= ~sclk;
                        if (sclk) begin            // спадний фронт
                            if (bit_cnt == DATA_W-1) state <= S_HOLD;
                            else bit_cnt <= bit_cnt + 1'b1;
                        end
                    end else
                        cnt <= cnt + 1'b1;
                end

                S_HOLD: begin
                    if (tick) begin
                        cnt   <= 0;
                        cs_n  <= 1'b1;             // знімаємо вибір Slave
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end else
                        cnt <= cnt + 1'b1;
                end
            endcase
        end
    end
endmodule
