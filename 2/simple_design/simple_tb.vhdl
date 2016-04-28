library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

--  A testbench has no ports.
entity simple_tb is
end simple_tb;

architecture behav of simple_tb is
	component simple
		port (res, clk : in std_logic; din : in std_logic; led0, led1, led2, led3 : out std_logic);
	end component;
	for simple_0: simple use entity work.simple(rtl);

		signal res_tb, clk_tb, din_tb, led0_tb, led1_tb, led2_tb, led3_tb : std_logic;
	begin
		simple_0: simple port map (res => res_tb, clk => clk_tb, din => din_tb, led0 => led0_tb, led1 => led1_tb, led2 => led2_tb, led3 => led3_tb);

		process
		type pattern_type is record
		   --  The inputs of the adder.
			res, clk, din : std_logic;
		   --  The expected outputs of the adder.
			led0, led1, led2, led3 : std_logic;
		end record;
	   --  The patterns to apply.
		type pattern_array is array (natural range <>) of pattern_type;
		constant patterns : pattern_array :=
		(('0', '0', '0', '0', '0', '0', '0'),
		 ('0', '0', '0', '0', '0', '0', '0'),
		 ('0', '0', '0', '0', '0', '0', '0'),
		 ('0', '0', '0', '0', '0', '0', '0'),
		 ('0', '0', '0', '0', '0', '0', '0'),
		 ('0', '0', '0', '0', '0', '0', '0'),
		 ('0', '0', '0', '0', '0', '0', '0'),
		 ('0', '0', '0', '0', '0', '0', '0'));
		begin
		   --  Check each pattern.
			for i in patterns'range loop
			   --  Set the inputs.
				res_tb <= patterns(i).res;
				clk_tb <= patterns(i).clk;
				din_tb <= patterns(i).din;
			   --  Wait for the results.
				wait for 1 ns;
			   --  Check the outputs.
				assert led0_tb = patterns(i).led0
				report "led0_tb wrong" severity error;
				assert led1_tb = patterns(i).led1
				report "led1_tb wrong" severity error;
				assert led2_tb = patterns(i).led2
				report "led2_tb wrong" severity error;
				assert led3_tb = patterns(i).led3
				report "led3_tb wrong" severity error;
			end loop;
		   -- assert false report "end of test" severity note;
		   --  Wait forever; this will finish the simulation.
			wait;
		end process;
	end behav;

