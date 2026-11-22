//============================================================================
// tb_spi_master.v  -  Testbench для SPI Master (режим 0)
// Містить модель Slave (приймає MOSI, видає свої дані на MISO) та
// автоматичну перевірку результатів.
//============================================================================
`timescale 1ns/1ps

module tb_spi_master;
    // ---- Сигнали ----
    reg        clk = 0;
    reg        rst = 1;
    reg        start = 0;
    reg  [7:0] data_in = 8'h00;
    wire [7:0] data_out;
    wire       busy, done, sclk, mosi, cs_n;
    reg        miso = 0;

    integer errors = 0;

    // ---- DUT ----
    spi_master #(.DATA_W(8), .CLK_DIV(4)) dut (
        .clk(clk), .rst(rst), .start(start), .data_in(data_in),
        .data_out(data_out), .busy(busy), .done(done),
        .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n)
    );

    // ---- Тактовий сигнал 100 МГц ----
    always #5 clk = ~clk;

    // ---- Модель Slave (режим 0) ----
    reg [7:0] slave_tx = 8'h00;   // що Slave відправляє Master-у
    reg [7:0] slave_rx = 8'h00;   // що Slave прийняв від Master-а
    integer   s_cnt = 0;

    always @(negedge cs_n) begin  // початок обміну: виставити MSB
        s_cnt = 0;
        miso  = slave_tx[7];
    end
    always @(posedge sclk)        // наростаючий фронт: Slave зчитує MOSI
        if (!cs_n) slave_rx = {slave_rx[6:0], mosi};
    always @(negedge sclk)        // спадний фронт: Slave виставляє наступний біт
        if (!cs_n) begin
            s_cnt = s_cnt + 1;
            if (s_cnt < 8) miso = slave_tx[7 - s_cnt];
        end

    // ---- Задача: один обмін + перевірка ----
    task transfer(input [7:0] m_data, input [7:0] s_data);
    begin
        slave_tx = s_data;
        @(posedge clk); #1;
        data_in = m_data;
        start   = 1;
        @(posedge clk); #1;
        start   = 0;
        @(posedge done); #1;
        if (data_out === s_data && slave_rx === m_data)
            $display("[%0t] PASS: Master TX=%h, Slave RX=%h | Slave TX=%h, Master RX=%h",
                     $time, m_data, slave_rx, s_data, data_out);
        else begin
            $display("[%0t] FAIL: Master TX=%h, Slave RX=%h | Slave TX=%h, Master RX=%h",
                     $time, m_data, slave_rx, s_data, data_out);
            errors = errors + 1;
        end
        repeat (5) @(posedge clk);
    end
    endtask

    // ---- Основний сценарій ----
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_spi_master);

        repeat (5) @(posedge clk);
        rst = 0;                       // зняти скидання
        repeat (5) @(posedge clk);

        transfer(8'hA5, 8'h3C);
        transfer(8'hFF, 8'h00);
        transfer(8'h55, 8'hAA);
        transfer(8'h01, 8'h80);
        transfer(8'hDE, 8'hAD);

        if (errors == 0) $display("=== ALL TESTS PASSED ===");
        else             $display("=== %0d TEST(S) FAILED ===", errors);
        $finish;
    end

    // Захист від зависання
    initial begin #200000; $display("TIMEOUT"); $finish; end
endmodule
