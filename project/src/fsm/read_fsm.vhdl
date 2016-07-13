library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.read_fsm_pkg.all;

entity READ_FSM is
	port (
		CLK               : in  std_logic;                      -- 2xHCLK
		HCLK              : in  std_logic;
		RES_n             : in  std_logic;                      -- HRESETn

		-- The input signals to the state machine
		REQUEST           : in  std_logic;                      -- !HWRITE && HREADY && ( HSEL or HSEL & HPROT for non-unified cache )
		HIT               : in  std_logic;                      -- The cache hit or miss information
		DRAM_BUSY         : in  std_logic;                      -- pX_cmd_full
	    DRAM_EMPTY        : in  std_logic;                      -- pX_rd_empty
		WS_ZERO           : in  std_logic;                      -- Whether the requested word was the first in cache line

		-- The state register
		state             : out read_fsm_state_type
         );
end READ_FSM;

architecture syn of READ_FSM is
	signal current_state,         next_state        : read_fsm_state_type := idl_rdt;
begin
	--{{{
	next_state_logic: process(current_state, REQUEST, HIT, DRAM_BUSY, DRAM_EMPTY)
	begin
		next_state        <= current_state        after 1 ns; -- default assignement

		case current_state is
			when idl_rdt =>
				if( REQUEST = '1' ) then
					next_state        <= cmp_dlv after 1 ns;
				end if;

			when cmp_dlv =>
				if ( HIT = '1' ) then
					if ( REQUEST = '0' ) then
						next_state <= idl_rdt after 1 ns;
					else -- REQUEST = '1'
						next_state <= cmp_dlv after 1 ns;
					end if;
				else -- HIT = '0'
					if ( DRAM_BUSY = '1' ) then
						next_state <= req0 after 1 ns;
					else -- DRAM_BUSY = '0'
						if ( WS_ZERO = '0' ) then
							next_state <= req1 after 1 ns;
						else -- WS_ZERO = '1'
							next_state <= rd0 after 1 ns;
						end if;
					end if;
				end if;

			when req0 =>
				if ( DRAM_BUSY = '1' ) then
					next_state <= req0 after 1 ns;
				else -- DRAM_BUSY = '0'
					if ( WS_ZERO = '0' ) then
						next_state <= req0 after 1 ns;
					else -- WS_ZERO = '1'
						next_state <= rd0 after 1 ns;
					end if;
				end if;

			when req1 =>
				if( DRAM_BUSY = '1' ) then
					next_state <= req1 after 1 ns;
				else
					next_state <= rd0 after 1 ns;
				end if;

			--{{{ rdN -> rd(N+1) if !DRAM_EMPTY

			when rd0 =>
				if( DRAM_EMPTY = '1' ) then
					next_state <= rd0 after 1 ns;
				else
					next_state       <= rd1_keep after 1 ns;
				end if;

			when rd1_keep =>
					next_state <= rd1 after 1 ns;

			when rd1 =>
				if( DRAM_EMPTY = '1' ) then
					next_state <= rd1 after 1 ns;
				else
					next_state       <= rd2 after 1 ns;
				end if;

			when rd2 =>
				if( DRAM_EMPTY = '1' ) then
					next_state <= rd2 after 1 ns;
				else
					next_state       <= rd3 after 1 ns;
				end if;

			when rd3 =>
				if( DRAM_EMPTY = '1' ) then
					next_state <= rd3 after 1 ns;
				else
					next_state       <= rd4 after 1 ns;
				end if;

			when rd4 =>
				if( DRAM_EMPTY = '1' ) then
					next_state <= rd4 after 1 ns;
				else
					next_state       <= rd5 after 1 ns;
				end if;

			when rd5 =>
				if( DRAM_EMPTY = '1' ) then
					next_state <= rd5 after 1 ns;
				else
					next_state       <= rd6 after 1 ns;
				end if;

			when rd6 =>
				if( DRAM_EMPTY = '1' ) then
					next_state <= rd6 after 1 ns;
				else
					next_state       <= rd7 after 1 ns;
				end if;
			--}}}

			when rd7 =>
				if( DRAM_EMPTY = '1' ) then
					next_state <= rd7 after 1 ns;
				else
					if ( HCLK = '1' ) then -- First phase of HCLK
						next_state <= sync after 1 ns;
					else -- HCLK = '0' -- Second phase of HCLK
						if( REQUEST = '0' ) then
							next_state <= idl_rdt after 1 ns;
						else
							next_state <= cmp_dlv after 1 ns;
						end if;
					end if;
				end if;

			when sync =>
				if ( REQUEST = '0' ) then
					next_state <= idl_rdt after 1 ns;
				else -- REQUEST = '1'
					next_state <= cmp_dlv after 1 ns;
				end if;


			when others =>
				-- shouldn't happen
				assert true report "Read FSM has encountered an invalid state" severity failure;
				next_state <= idl_rdt after 1 ns;

		end case;

	end process;
	--}}}

	--{{{
	sp: process(CLK)
	begin
		if(rising_edge(CLK)) then
			if( RES_n = '1' ) then
				current_state        <= idl_rdt;
			else
				current_state        <= next_state;
			end if;
		end if;
	end process;
	--}}}
end syn;
