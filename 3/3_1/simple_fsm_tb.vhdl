-- Compile and run with:
-- ghdl -a --ieee=standard simple_fsm.vhdl simple_fsm_tb.vhdl && ghdl -e --ieee=standard simple_fsm_tb && ghdl -r --ieee=standard simple_fsm_tb --vcd=simple_fsm.vcd --wave=simple_fsm.ghw


library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

--  A testbench has no ports.
entity simple_fsm_tb is
end simple_fsm_tb;

architecture behav of simple_fsm_tb is
	component simple_fsm
		port (res, clk : in std_logic; din : in std_logic; led0, led1, led2, led3 : out std_logic);
	end component;
	for simple_fsm_0: simple_fsm use entity work.simple_fsm(rtl);

		signal res_tb, clk_tb, din_tb, led0_tb, led1_tb, led2_tb, led3_tb : std_logic;
	begin
		simple_fsm_0: simple_fsm port map (res => res_tb, clk => clk_tb, din => din_tb, led0 => led0_tb, led1 => led1_tb, led2 => led2_tb, led3 => led3_tb);

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
		(('1', '0', '0',     '0', '0', '0', '0'),	-- Reset at the beginning. res has to stay asserted until clk
		 ('1', '1', '0',     '0', '0', '0', '0'),	-- rises because we use a syncronous reset.

		 ('0', '0', '1',     '0', '0', '0', '0'),
		 ('0', '1', '1',     '0', '0', '0', '0'),

		 ('0', '0', '1',     '0', '0', '0', '0'),
		 ('0', '1', '1',     '0', '0', '0', '0'),

		 ('0', '0', '0',     '0', '0', '0', '0'),
		 ('0', '1', '0',     '0', '0', '0', '0'),

		 ('0', '0', '1',     '0', '0', '0', '0'),	-- Outputs are set
		 ('0', '1', '1',     '1', '1', '0', '1'),	-- to 1100.

		 ('0', '0', '0',     '1', '1', '0', '1'),
		 ('0', '1', '0',     '1', '1', '0', '1'),

		 ('0', '0', '0',     '1', '1', '0', '1'),
		 ('0', '1', '0',     '1', '1', '0', '1'),

		 ('0', '0', '1',     '1', '1', '0', '1'),
		 ('0', '1', '1',     '1', '1', '0', '1'),

		 ('0', '0', '1',     '1', '1', '0', '1'),	-- Outputs are set
		 ('0', '1', '1',     '0', '0', '1', '1'),	-- to 0011

		 ('0', '0', '1',     '0', '0', '1', '1'),
		 ('0', '1', '1',     '0', '0', '1', '1'),

		 ('0', '0', '1',     '0', '0', '1', '1'),
		 ('0', '1', '1',     '0', '0', '1', '1'),

		 ('1', '0', '0',     '0', '0', '1', '1'),	-- Reset test
		 ('1', '1', '0',     '0', '0', '0', '0'),

		 ('0', '0', '1',     '0', '0', '0', '0'),	-- Outputs are not set here
		 ('0', '1', '1',     '0', '0', '0', '0'),

		 ('0', '0', '0',     '0', '0', '0', '0'),
		 ('0', '1', '0',     '0', '0', '0', '0'),

		 ('0', '0', '0',     '0', '0', '0', '0'),
		 ('0', '1', '0',     '0', '0', '0', '0'),

		 ('0', '0', '1',     '0', '0', '0', '0'),	-- Outputs are set here instead.
		 ('0', '1', '1',     '1', '0', '0', '1'),	-- to 1001

		 ('0', '0', '0',     '1', '0', '0', '1'),
		 ('0', '1', '0',     '1', '0', '0', '1'));
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

