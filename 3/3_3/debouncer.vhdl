
--{{{ A simple syncronisation flipflop

library ieee;
use ieee.std_logic_1164.all;

entity sync_ff is
	port(clk, async_in : in std_logic; sync_out : out std_logic);
end sync_ff;

architecture foo of sync_ff is
	 signal ff1 : std_logic := '0';
	 signal ff2 : std_logic := '0';
begin
	propagate: process
	begin
		wait until rising_edge(clk);
		ff2 <= ff1;
		ff1 <= async_in;
	end process;
	sync_out <= ff2;
end foo;
--}}}










library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity debouncer is
	generic( bounce_time : integer := 100000); 					-- measured in clock cycles
  port (bouncing, clk : in std_logic; debounced : out std_logic);
end debouncer;

architecture deadtime of debouncer is -- modeled after Maxim Itegrated MAX6816 switch debouncer
	component sync_ff
		port(clk, async_in : in std_logic; sync_out : out std_logic);
	end component;
	for input_ff : sync_ff use entity work.sync_ff(foo);

	signal deadtime_count: natural range 0 to bounce_time;
	signal input_sync : std_logic;	-- This should become a simple wire
	signal output_ff : std_logic := '0';
begin
	input_ff : sync_ff port map (clk => clk, async_in => bouncing, sync_out => input_sync);
	debounce: process
	begin
		wait until rising_edge(clk);
		if input_sync = output_ff then
			deadtime_count <= 0;
		else
			if deadtime_count = bounce_time then
				deadtime_count <= 0;
				output_ff <= input_sync;
			else
				deadtime_count <= deadtime_count + 1;
			end if;
		end if;
	end process;
	debounced <= output_ff;
end deadtime;
