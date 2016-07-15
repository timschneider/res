library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.write_fsm_pkg.all;
--use ieee.std_logic_unsigned.all;

entity WRITE_FSM is
	port (
		DCLK      : in  std_logic; -- 2xHCLK
		RES_n     : in  std_logic; -- HRESETn

		-- The input variables to the state machine
		REQUEST   : in  std_logic; -- HWRITE && HREADY && ( HSEL or HSEL & HPROT for non-unified cache )
		DRAM_BUSY : in  std_logic; -- pX_cmd_full || pX_rd_empty
		HIT       : in  std_logic; -- The cache hit or miss information
		HCLK      : in  std_logic; -- HCLK

		-- The state register
		state     : out write_fsm_state_type
        );
end WRITE_FSM;

architecture syn of WRITE_FSM is


	signal current_state, next_state : write_fsm_state_type := idl_rdt;

begin
	--{{{
	calculate_next_state: process(current_state, REQUEST, HIT, DRAM_BUSY, HCLK)
	begin
		next_state        <= current_state        after 1 ns; -- default assignement

		case current_state is
			when idl_rdt =>
				if( REQUEST = '1' ) then
					next_state        <= cmp_sto after 1 ns;
				end if;

			when cmp_sto =>
				if( dram_busy = '1' ) then
					next_state <= wait_sto after 1 ns;
				elsif( REQUEST = '1' ) then
					next_state <= cmp_sto after 1 ns;
				else
					next_state <= idl_rdt after 1 ns;
				end if;

			when wait_sto =>
				if( dram_busy = '1' ) then
					next_state <= wait_sto after 1 ns;
				else
					if ( HCLK = '1' ) then -- First phase of HCLK
	 					next_state <= sync after 1 ns;
					else -- HCLK = '0' -- Second phase of HCLK
						if( REQUEST = '0' ) then
							next_state <= idl_rdt after 1 ns;
						else
							next_state <= cmp_sto after 1 ns;
						end if;
					end if;
				end if;

			when sync =>
				if ( REQUEST = '0' ) then
					next_state <= idl_rdt after 1 ns;
				else -- REQUEST = '1'
					next_state <= cmp_sto after 1 ns;
				end if;

			when others =>
				-- shouldn't happen
				assert true report "Write FSM has encountered an invalid state" severity failure;
				next_state <= idl_rdt after 1 ns;
		end case;

	end process;
	--}}}

	--{{{
	adopt_next_state: process(DCLK)
	begin
		if(rising_edge(DCLK)) then
			if( RES_n = '1' ) then
				current_state        <= idl_rdt;
			else
				current_state        <= next_state;
			end if;
		end if;
	end process;
	--}}}
end syn;
