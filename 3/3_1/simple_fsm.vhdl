library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity simple_fsm is
  -- res: reset, clk: clock, din: switch input, led0..3 outputs driving LEDs
  port (res, clk : in std_logic; din : in std_logic; led0, led1, led2, led3 : out std_logic);
end simple_fsm;

architecture rtl of simple_fsm is
   -- fsm states
	type fsmStates is (S0, S1, S2, S3, S4);
	signal current_state, next_state: fsmStates := S0;

	Signal leds_buffer: std_logic_vector(0 to 2) := "000";	-- the switch inputs are stored here until the fourth cycle
	Signal leds_output: std_logic_vector(0 to 3) := "0000";	-- the flipflops actually driving the LEDs
begin

   -- combinatorial stage
	cp: process(leds_buffer, leds_output, current_state)
	begin
		-- in the combinatorial stage we need a default assignement for next_state
		-- to prevent latch inference and to enable FSM detection
		-- we do not need a default assignement for the output, as it is pure combinatorial
		next_state <= current_state after 1 ns; -- default assignement 

		case current_state is
			when S0 =>
            leds_buffer <= "000";
      		leds_output <= "0000";
				
            next_state <= S1 after 1 ns;
					
			when S1 =>
				leds_buffer(0) <= din;			-- store the switch state to the appropriate position in the buffer

				next_state <= S2 after 1 ns;

         when S2 =>
				leds_buffer(1) <= din;			-- store the switch state to the appropriate position in the buffer

				next_state <= S3 after 1 ns;

		   when S3 =>
				leds_buffer(2) <= din;			-- store the switch state to the appropriate position in the buffer

				next_state <= S4 after 1 ns;

			when S4 =>
				leds_output(0 to 2) <= leds_buffer;	-- update the LED outputs
			   leds_output(3) <= din;

				next_state <= S1 after 1 ns;
		
			when others =>
				-- shouldn't happen
				assert true report "FSM has encountered an invalid state" severity failure;
				next_state <= S0 after 1 ns;
				
		end case;
			
	end process;

	p0: process
	begin
	wait until rising_edge(clk);
	if res = '1' then
      current_state <= S0;
	else
		current_state <= next_state;
	end if;
	end process;

	led0 <= leds_output(0);									-- connect the output flipflops
	led1 <= leds_output(1);									-- with the wires that are the
	led2 <= leds_output(2);									-- edge of the module
	led3 <= leds_output(3);									-- (and would actually drive the LEDs)

end rtl;
