
# RISC-V CPU synthesis clock constraint
# 100 MHz clock has a period of 10 ns
create_clock -name cpu_clk -period 10.000 [get_ports clk]

