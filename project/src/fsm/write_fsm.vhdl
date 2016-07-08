library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

entity WRITE_FSM is
	port (
		CLK                                : in  std_logic; -- HCLK or QCLK
		RES_n                              : in  std_logic; -- HRESETn
		REQUEST                            : in  std_logic; -- HWRITE && HREADY && ( HSEL or HSEL & HPROT for non-unified cache )
		DRAM_BUSY                          : in  std_logic; -- pX_cmd_full || pX_rd_empty
		HIT                                : in  std_logic; -- The cache hit or miss information

		-- Aways: If Request: save address and size to first register stage and read tag_ram[address]
		PROPARGATE_WRITE_DRAM0             : out std_logic; -- Propagate address and size to second register stage and write dram[address in first reg stage]
		WRITE_DRAM1                        : out std_logic; -- write dram[address in second reg stage]
		MAP_DRAM_BUSY_2_HREADYOUT          : out std_logic  -- Connect hreadyout to not dram_busy
        );
end WRITE_FSM;

architecture syn of WRITE_FSM is

	--{{{ States: s_idle, s_tag, s_wait

	--       State                                  Encoding    Condition   -> Next State   Description
	constant s_idle : std_logic_vector(2 downto 0) := "000"; -- REQUEST     -> s_tag    Wait for request, if request read TAG SRAM...

	constant s_tag  : std_logic_vector(2 downto 0) := "101"; -- dram_bysy   -> s_wait   Compare tag from TAG SRAM with address tag bits,
			                                                 -- REQUEST     -> s_tag    ...write data to DRAM and tie HREADYOUT to DRAM_CMD_FULL.
			                                                 -- !REQUEST    -> s_idle   ...When HIT, update DATA SRAM with new value.
	                                                         -- NOTE: Use this state to increase HIT/MISS counters, eg: if state == s_tag && hit -> hitcount++

	constant s_wait : std_logic_vector(2 downto 0) := "011"; -- dram_bysy   -> s_wait   Wait until the DRAM FIFO interface has space and write...
	                                                         -- REQUEST     -> s_tag    ...the data.
                                                             -- !REQUEST    -> s_idle
	-- Note: In FPGAs all FlipFlops are at zero after reset
	--}}}

	signal current_state,         next_state        : std_logic_vector(2 downto 0) := s_idle;

begin
	--{{{
	calculate_next_state: process(current_state, REQUEST, HIT, DRAM_BUSY)
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
				else
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
	adopt_next_state: process(CLK)
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

	--{{{ Assign output

	PROPARGATE_WRITE_DRAM0    <= current_state(2);
	WRITE_DRAM1               <= current_state(1);
	MAP_DRAM_BUSY_2_HREADYOUT <= current_state(0);
	--}}}
end syn;
