//============================================================================
// spi_rx.v  -  Приймач SPI (зсувний регістр, MSB first)
//----------------------------------------------------------------------------
// Порти:
//   clk       - системний тактовий сигнал
//   rst       - синхронне скидання (активний рівень 1)
//   sample_en - імпульс: зчитати біт з miso (по наростаючому фронту SCK)
//   miso      - послідовний вхід від Slave
//   data_out  - зібране паралельне слово (валідне після DATA_W бітів)
//============================================================================
module spi_rx #(
    parameter DATA_W = 8
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              sample_en,
    input  wire              miso,
    output wire [DATA_W-1:0] data_out
);
    reg [DATA_W-1:0] sh_reg;   // зсувний регістр приймача

    always @(posedge clk) begin
        if (rst)
            sh_reg <= {DATA_W{1'b0}};
        else if (sample_en)
            sh_reg <= {sh_reg[DATA_W-2:0], miso};     // нові біти входять справа
    end

    assign data_out = sh_reg;
endmodule
