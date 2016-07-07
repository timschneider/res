library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

entity CACHE_WRITE_FSM is
	port (
		CLK                                : in  std_logic;                      -- HCLK or QCLK
		RES_n                              : in  std_logic;                      -- HRESETn
		REQUEST                            : in  std_logic;                      -- HWRITE && HREADY && ( HSEL or HSEL & HPROT for non-unified cache )
		HIT                                : in  std_logic;                      -- The cache hit or miss information
		DRAM_BUSY                          : in  std_logic;                      -- pX_cmd_full || pX_rd_empty

		-- These should be one-hot encoded into the state variable
		LATCH_BUS_IF_REQUEST               : out std_logic;                      -- Latch Bus signals
		MAP_DRAM_BUSY_2_READY              : out std_logic;                      -- HREADYOUT
		START_DRAM_WRITE                   : out std_logic                       -- start a read from the dram
        );
end CACHE_WRITE_FSM;

architecture syn of CACHE_WRITE_FSM is

	--{{{ Read FSM stuff

	--{{{ States: s_idle, s_tag, s_wait

	-- Note: In FPGAs all FlipFlops are at zero after reset
	type state_type is( -- Next State
	s_idle, -- REQUEST                    -> s_tag    Wait for request, if request read TAG SRAM...

	s_tag,  -- dram_bysy                  -> s_wait   Compare tag from TAG SRAM with address tag bits,
			-- REQUEST                    -> s_tag    ...write data to DRAM and tie HREADYOUT to DRAM_CMD_FULL.
			-- !REQUEST                   -> s_idle   ...When HIT, update DATA SRAM with new value.

	s_wait  -- dram_bysy                  -> s_wait   Wait until the DRAM FIFO interface has space and write...
	        -- REQUEST                    -> s_tag    ...the data.
            -- !REQUEST                   -> s_idle
	);

	--{{{ Encoding (IDEA):

	-- bit 0: latch address, read SRAMS if (enable && ready_in && !HWRITE)

	-- States: s_idle, s_tag, s_req0, s_req1, s_rd0, s_rd1, s_rd2, s_rd3, s_rd4, s_rd5, s_rd6, s_rd7
	-- ATTRIBUTE ENUM_ENCODING : STRING;
	-- ATTRIBUTE ENUM_ENCODING OF state_type : TYPE IS " 00000000 01000000 ...";
	-- LATCH_BUS READY START_DRAM_READ ZERO_WS_IN_READ DRAM_2_SRAM DRAM_2_OUTPUT SET_VALID_BIT 

	--}}}
	--}}}

	--{{{ Signals

	signal current_state,         next_state        : state_type := s_idle;
	signal current_word_select,   next_word_select  : std_logic_vector( 2 downto 0);
	signal current_burst_length,  next_burst_length : std_logic_vector( 2 downto 0);

	-- signal read_addr   : std_logic_vector(31 downto 0);
	-- signal read_size   : std_logic_vector( 2 downto 0);
	--}}}
	--}}}
begin
	--{{{
	next_state_logic: process(current_state, REQUEST, HIT, DRAM_BUSY)
	begin
		next_state        <= current_state        after 1 ns; -- default assignement

		case current_state is
			when s_idle =>
				if( REQUEST = '1' ) then
					next_state        <= s_tag after 1 ns;
				end if;

			when s_tag =>
				if( dram_busy = '1' ) then
					next_state <= s_wait after 1 ns;
				elsif( REQUEST = '1' ) then
					next_state <= s_tag after 1 ns;
				else -- Cache miss
					next_state <= s_idle after 1 ns;
				end if;

			when s_wait =>
				if( dram_busy = '1' ) then
					next_state <= s_wait after 1 ns;
				elsif( REQUEST = '1' ) then
					next_state <= s_tag after 1 ns;
				else -- Cache miss
					next_state <= s_idle after 1 ns;
				end if;

			when others =>
				-- shouldn't happen
				assert true report "Write FSM has encountered an invalid state" severity failure;
				next_state <= s_idle after 1 ns;
		end case;

	end process;
	--}}}

	--{{{
	sp: process(CLK)
	begin
		if(rising_edge(CLK)) then
			if( RES_n = '1' ) then
				current_state        <= s_idle;
			else
				current_state        <= next_state;
			end if;
		end if;
	end process;
	--}}}
end syn;
