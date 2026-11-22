# Обмеження тактової частоти для spi_master (Quartus Timing Analyzer)
# Ціль: 100 МГц (період 10 нс). Fmax покаже, наскільки можна піднятися вище.
create_clock -name clk -period 10.000 [get_ports clk]

# Автоматичний облік невизначеності тактового сигналу
derive_clock_uncertainty
