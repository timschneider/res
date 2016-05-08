----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

package signal_generator_pkg is
	procedure generate_pulse_train ( width, separation : in time; number : in integer; signal s : out std_logic );
end signal_generator_pkg;

package body signal_generator_pkg is
	procedure generate_pulse_train ( width, separation : in time; number : in integer; signal s : out std_logic ) is
	begin
		for count in 1 to number loop
			s <= '1', '0' after width;
			wait for width + separation;
		end loop;
	end procedure generate_pulse_train;
end signal_generator_pkg;
