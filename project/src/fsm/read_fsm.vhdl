library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

entity CACHE_READ_FSM is
	port (
		clk            : in  std_logic;
		res_n          : in  std_logic;
		write          : in  std_logic;                      -- 
		reday_in       : in  std_logic;
		ready_out      : out std_logic
		addr_in        : in  std_logic_vector(31 downto 0);  -- Full read address
		addr_out       : out std_logic_vector(31 downto 0);  -- Full write address for the DDR2-RAM controller
		shift_distance : out std_logic_vector( 1 downto 0);  -- For controlling the barrel shifter
		cache_line_idx : out std_logic_vector( 9 downto 0);  -- For addressing the TAG- and DATA- SRAMS
		
		
         );
end CACHE_READ_FSM;

architecture syn of CACHE_READ_FSM is
	type state_type IS (idle_state, read_state, );
	signal current_state, next_state: state_type := idle;

begin

    process (clk)
    begin
        if clk'event and clk = '1' then

        end if;
    end process;

end syn;
