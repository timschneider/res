library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

entity CACHE_WRITE_FSM is
	port (
		CLK               : in  std_logic;                      -- HCLK or QCLK
		RES_n             : in  std_logic;                      -- HRESETn
		REQUEST           : in  std_logic;                      -- HWRITE && HREADY && ( HSEL or HSEL & HPROT for non-unified cache )
		SIZE              : in  std_logic_vector( 2 downto 0);  -- HSIZE
		WORD_SELECT_IN    : in  std_logic_vector( 2 downto 0);  -- The Word Select part from HADDR
		HIT               : in  std_logic;                      -- The cache hit or miss information
		DRAM_CMD_FULL     : in  std_logic;                      -- pX_cmd_full
	    DRAM_WR_FULL      : in  std_logic;                      -- pX_rd_empty

		-- These should be one-hot encoded into the state variable
		LATCH_BUS         : out std_logic;                      -- Latch Bus signals
		READY             : out std_logic;                      -- HREADYOUT
		START_DRAM_WRITE  : out std_logic;                      -- start a read from the dram
		



		--ADDR_IN           : in  std_logic_vector(31 downto 0);  -- Full read address
		--ADDR_OUT          : out std_logic_vector(31 downto 0);  -- Full write address for the DDR2-RAM controller
		--HIT_2_HREADYOUT   : out std_logic;
		--shift_distance : out std_logic_vector( 1 downto 0);  -- For controlling the barrel shifter
		--cache_line_idx : out std_logic_vector( 9 downto 0)  -- For addressing the TAG- and DATA- SRAMS
         );
end CACHE_WRITE_FSM;

architecture syn of CACHE_WRITE_FSM is

	--{{{ Read FSM stuff

	--{{{ States: s_idle, s_tag, s_req0, s_req1, s_rd0, s_rd1, s_rd2, s_rd3, s_rd4, s_rd5, s_rd6, s_rd7

	-- Note: In FPGAs all FlipFlops are at zero after reset
	type state_type is( -- Next State
	s_idle, -- REQUEST                    -> s_tag    Wait for request, if request read TAG SRAM...

	s_tag,  --        && !REQUEST            -> s_idle   Compare tag from tag ram with address tag bits...
			--        && REQUEST             -> s_tag    ...When Hit, update cache
	        --       T                       -> s_req0   ...HIT to HREADYOUT.

	s_req0, -- DRAM_CMD_FULL              -> s_req0   Start DRAM read from addr, burstlength = 8 - WS
	        -- !DRAM_CMD_FULL             -> s_req1
	s_req1, -- DRAM_CMD_FULL              -> s_req1   Start DRAM read from (addr & !WS), ...
	        -- !DRAM_CMD_FULL             -> s_rd0    ...burstlength = WS.

	s_rd0,  -- DRAM_RD_EMPTY              -> s_rd0    Put DRAM data on the bus and write to SRAM...
	        -- !DRAM_RD_EMPTY             -> s_rd1    Connect !DRAM_RD_EMPTY to HREADYOUT and SRAM_WE.

	s_rd1,  -- DRAM_RD_EMPTY              -> s_rd1    write dram data to sram. Connect...
            -- !DRAM_RD_EMPTY             -> s_rd2    ...!DRAM_RD_EMPTY to sram_we.
	s_rd2,  --
	s_rd3,  -- .    .                     .    .      .    .
	s_rd4,  -- .    .                     .    .      .    .
	s_rd5,  -- .    .                     .    .      .    .
	s_rd6,  --
	s_rd7   -- DRAM_RD_EMPTY              -> s_rd7    write dram data to sram. Connect...
            -- !DRAM_RD_EMPTY && !REQUEST -> s_idle   ...!DRAM_RD_EMPTY to sram_we.
	        -- !DRAM_RD_EMPTY && REQUEST  -> s_tag
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
	next_state_logic: process(current_state, REQUEST, SIZE, HIT, DRAM_CMD_FULL, DRAM_RD_EMPTY)
	begin
		next_state        <= current_state        after 1 ns; -- default assignement
		next_word_select  <= current_word_select  after 1 ns;
		next_burst_length <= current_burst_length after 1 ns;

		case current_state is
			when s_idle =>
				if( REQUEST = '1' ) then
					next_state        <= s_tag after 1 ns;
					next_word_select  <= WORD_SELECT_IN after 1 ns;
					next_burst_length <= std_logic_vector(8 - unsigned(WORD_SELECT_IN)) after 1 ns;
				end if;

			when s_tag =>
				if( (HIT = '1') and ( REQUEST = '0' ) ) then
					next_state <= s_idle after 1 ns;
				elsif( ( HIT = '1' )  and ( REQUEST = '1' ) ) then
					next_state <= s_tag after 1 ns;
					-- next_word_select <= WORD_SELECT_IN after 1 ns;
					-- next_burst_length <= std_logic_vector(8 - unsigned(WORD_SELECT_IN)) after 1 ns;
				else -- Cache miss
					next_state <= s_req0 after 1 ns;
				end if;

			when s_req0 =>
				if( DRAM_CMD_FULL = '1' ) then
					next_state <= s_req0 after 1 ns;

				elsif( current_burst_length = "111" ) then
					next_state <= s_rd0 after 1 ns; -- omit second read phase if not neccessary
				else
					next_state <= s_req1 after 1 ns;
					next_burst_length <= current_word_select after 1 ns;
				end if;

			when s_req1 =>
				if( DRAM_CMD_FULL = '1' ) then
					next_state <= s_req1 after 1 ns;
				else
					next_state <= s_rd0 after 1 ns;
				end if;

			--{{{ s_rdN -> s_rd(N+1) if !DRAM_RD_EMPTY
			when s_rd0 =>
				if( DRAM_RD_EMPTY = '1' ) then
					next_state <= s_rd0 after 1 ns;
				else
					next_state       <= s_rd1 after 1 ns;
					next_word_select <= std_logic_vector(unsigned(current_word_select) + 1);
				end if;

			when s_rd1 =>
				if( DRAM_RD_EMPTY = '1' ) then
					next_state <= s_rd1 after 1 ns;
				else
					next_state       <= s_rd2 after 1 ns;
					next_word_select <= std_logic_vector(unsigned(current_word_select) + 1);
				end if;

			when s_rd2 =>
				if( DRAM_RD_EMPTY = '1' ) then
					next_state <= s_rd2 after 1 ns;
				else
					next_state       <= s_rd3 after 1 ns;
					next_word_select <= std_logic_vector(unsigned(current_word_select) + 1);
				end if;

			when s_rd3 =>
				if( DRAM_RD_EMPTY = '1' ) then
					next_state <= s_rd3 after 1 ns;
				else
					next_state       <= s_rd4 after 1 ns;
					next_word_select <= std_logic_vector(unsigned(current_word_select) + 1);
				end if;

			when s_rd4 =>
				if( DRAM_RD_EMPTY = '1' ) then
					next_state <= s_rd4 after 1 ns;
				else
					next_state       <= s_rd5 after 1 ns;
					next_word_select <= std_logic_vector(unsigned(current_word_select) + 1);
				end if;

			when s_rd5 =>
				if( DRAM_RD_EMPTY = '1' ) then
					next_state <= s_rd5 after 1 ns;
				else
					next_state       <= s_rd6 after 1 ns;
					next_word_select <= std_logic_vector(unsigned(current_word_select) + 1);
				end if;

			when s_rd6 =>
				if( DRAM_RD_EMPTY = '1' ) then
					next_state <= s_rd6 after 1 ns;
				else
					next_state       <= s_rd7 after 1 ns;
					next_word_select <= std_logic_vector(unsigned(current_word_select) + 1);
				end if;
			--}}}

			when s_rd7 =>
				if( DRAM_RD_EMPTY = '1' ) then
					next_state <= s_rd7 after 1 ns;
				elsif( REQUEST = '0' ) then
					next_state <= s_idle after 1 ns;
				else
					next_state        <= s_tag after 1 ns;
					next_word_select  <= WORD_SELECT_IN after 1 ns;
					next_burst_length <= std_logic_vector(8 - unsigned(WORD_SELECT_IN)) after 1 ns;
				end if;

			when others =>
				-- shouldn't happen
				assert true report "Read FSM has encountered an invalid state" severity failure;
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
				current_word_select  <= "000";
				current_burst_length <= "111";
			else
				current_state        <= next_state;
				current_word_select  <= next_word_select;
				current_burst_length <= next_burst_length;
			end if;
		end if;
	end process;
	--}}}
end syn;
