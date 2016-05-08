-- Compile and run with:
-- ghdl -a --ieee=standard debouncer.vhdl debouncer_tb.vhdl && ghdl -e --ieee=standard debouncer_tb && ghdl -r --ieee=standard debouncer_tb --vcd=debouncer.vcd

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

use work.signal_generator_pkg.all;

entity debouncer_tb is
end debouncer_tb;

architecture behav of debouncer_tb is
	component debouncer
		port (bouncing, clk : in std_logic; debounced : out std_logic);
	end component;
	for debouncer_I: debouncer use entity work.debouncer(deadtime);


	constant clk_half_period    : time      := 5 ns;	-- 100 MHz clock
	constant clk_quarter_period : time      := 2 ns;	-- 100 MHz clock
	constant bounce_half_period : time      := 500 us;
	signal clk                  : std_logic := '0';
	signal input                : std_logic	:= '0';
	signal output               : std_logic;
	begin
		debouncer_I : debouncer port map(bouncing => input, clk => clk, debounced => output);

		clk_process : process
		begin
			clk <= '0';
			wait for clk_half_period;  --for 0.5 ns signal is '0'.
			clk <= '1';
			wait for clk_half_period;  --for next 0.5 ns signal is '1'.
		end process;

		stimuli : process
		begin
			input <= '0';
			wait for bounce_half_period*5;
			generate_pulse_train ( width => bounce_half_period, separation => bounce_half_period / 3, number => 5, s => input );
			input <= '1';
			wait for bounce_half_period*10;
			generate_pulse_train ( width => bounce_half_period, separation => bounce_half_period / 3, number => 5, s => input );
			input <= '0';
			wait for bounce_half_period*10;
		end process;

	end behav;


