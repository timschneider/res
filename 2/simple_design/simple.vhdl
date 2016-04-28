library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity simple is
  -- res: reset, clk: clock, din: switch input, led0..3 outputs driving LEDs
  port (res, clk : in std_logic; din : in std_logic; led0, led1, led2, led3 : out std_logic);
end simple;

architecture rtl of simple is
	signal clock_count: natural range 0 to 3;				-- count the clock cycles so we can act on the fourth
	Signal leds_buffer: std_logic_vector(0 to 3) := "0000";	-- the switch inputs are stored here until the fourth cycle
	Signal leds_output: std_logic_vector(0 to 3) := "0000";	-- the flipflops actually driving the LEDs
begin

	p0: process
	begin
	wait until rising_edge(clk);
	if res = '1' then
		clock_count <= 0;
		leds_buffer <= "0000";
		leds_output <= "0000";
	else
		clock_count <= clock_count + 1;
		leds_buffer(integer(clock_count)) <= din;			-- store the switch state to the appropriate position in the buffer
		if clock_count = 3 then
			clock_count <= 0;								-- handle the overflow (might not be neccessary)
			leds_output <= leds_buffer;						-- update the LED outputs
		end if;
	end if;
	end process;

	led0 <= leds_output(0);									-- connect the output flipflops
	led1 <= leds_output(1);									-- with the wires that are the
	led2 <= leds_output(2);									-- edge of the module
	led3 <= leds_output(3);									-- (and would actually drive the LEDs)

end rtl;
