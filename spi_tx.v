//============================================================================
// spi_tx.v  -  Передавач SPI (зсувний регістр, MSB first)
//----------------------------------------------------------------------------
// Порти:
//   clk      - системний тактовий сигнал
//   rst      - синхронне скидання (активний рівень 1)
//   load     - імпульс: завантажити data_in у зсувний регістр
//   shift_en - імпульс: зсунути регістр на 1 біт (по спадному фронту SCK)
//   data_in  - паралельні дані для передачі
//   mosi     - послідовний вихід (старший біт регістра)
//============================================================================
module spi_tx #(
    parameter DATA_W = 8
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              load,
    input  wire              shift_en,
    input  wire [DATA_W-1:0] data_in,
    output wire              mosi
);
    reg [DATA_W-1:0] sh_reg;   // зсувний регістр передавача

    always @(posedge clk) begin
        if (rst)
            sh_reg <= {DATA_W{1'b0}};
        else if (load)
            sh_reg <= data_in;                        // паралельне завантаження
        else if (shift_en)
            sh_reg <= {sh_reg[DATA_W-2:0], 1'b0};     // зсув вліво (MSB first)
    end

    assign mosi = sh_reg[DATA_W-1];                   // MSB іде на лінію MOSI
endmodule
