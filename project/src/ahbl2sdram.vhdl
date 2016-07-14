library ieee;
use ieee.std_logic_1164.all;
use work.read_fsm_pkg.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;





entity AHBL2SDRAM is
	port (
-- AHB-LITE Interface {{{

-- Global signals ---------------------------------------------------------------------------------------------------------------
		HCLK              : in  std_logic;                     -- Bus clock
		HRESETn           : in  std_logic;                     -- Reset
-- AHB Slave inputs ---------------------------------------------------------------------------------------------------
		HSEL              : in  std_logic;                     -- Slave select
		HADDR             : in  std_logic_vector(31 downto 0); -- Slave address
		HWRITE            : in  std_logic;                     -- Diretion: 0: Master read, 1: Master write
		HSIZE             : in  std_logic_vector( 2 downto 0); -- Transfer Word size: 000: Byte, 001: Halfword, 010: Word, others: undefined
		-- HBURST         : in  std_logic_vector( 2 downto 0)  -- NOT IMPLEMENTED
		-- HPROT          : in  std_logic_vector( 3 downto 0)  -- NOT IMPLEMENTED, Could be used to create a seperated cache for instructions and data.
		-- HTRANS         : in  std_logic_vector( 1 downto 0); -- Transaction status: 00: IDLE, 01: BUSY, 10: NON-SEQUENTIAL, 11: SEQUENTIAL
		-- HMASTLOCK      : in  std_logic;                     -- NOT IMPLEMENTED
		HREADY            : in  std_logic;                     -- Master's ready signal: 0: Busy, 1: Ready for next transaction

		HWDATA            : in  std_logic_vector(31 downto 0); -- Incomming Data from master
-- AHB Slave outputs --------------------------------------------------------------------------------------------------
		HREADYOUT         : out std_logic;                     -- Slave's ready signal: 0: Busy, 1: Ready
		HRESP             : out std_logic;                     -- Transfer response: 0: Okay, 1: Error. Needs one additional wait state with HREADYout low.
		HRDATA            : out std_logic_vector(31 downto 0); -- Outgoing Data to master }}}

-- Memory Controller Interface {{{

-- Command Path -------------------------------------------------------------------------------------------------------
		pX_cmd_clk        : out std_logic;                     -- User clock for the command FIFO
		pX_cmd_instr      : out std_logic_vector(2 downto 0);  -- Current instruction. 000: Wrtie, 001: Read, 010: Read w. precharge, 011: ...
		pX_cmd_addr       : out std_logic_vector(29 downto 0); -- Byte start address for current transaction.
		pX_cmd_bl         : out std_logic_vector(5 downto 0);  -- Busrst length-1, eg. 0 indicates a burst of one word
		pX_cmd_en         : out std_logic;                     -- Write enable for the command FIFO: 0: Diabled, 1: Enabled
		pX_cmd_empty      : in  std_logic;                     -- Command FIFO empty bit: 0: Not empty, 1: Empty
		pX_cmd_error      : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
		pX_cmd_full       : in  std_logic;                     -- Command FIFO full bit: 0: Not full, 1: Full
-- Write Datapath -----------------------------------------------------------------------------------------------------
		pX_wr_clk         : out std_logic;                     -- Clock for the write data FIFO
		pX_wr_data        : out std_logic_vector(31 downto 0); -- Data to be stored in the FIFO and be written to the DDR2-DRAM.
		pX_wr_mask        : out std_logic_vector(3 downto 0);  -- Mask write data. A high bit means Corresponding byte is not written to the RAM.
		pX_wr_en          : out std_logic;                     -- Write enable for the write data FIFO
		pX_wr_count       : in  std_logic_vector( 6 downto 0); -- Write data FIFO fill level: 0: empty. Note longer latency than pX_wr_empty!
		pX_wr_empty       : in  std_logic;                     -- Write data FIFO empty bit: 0: Not empty, 1: Empty
		pX_wr_error       : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
		pX_wr_full        : in  std_logic;                     -- Write data FIFO full bit: 0: Not full, 1: Full
		pX_wr_underrun    : in  std_logic;                     -- Underrun flag. 0: All ok, 1: Underrun. Last valid data is written repeatedly.
-- Read Datapath ------------------------------------------------------------------------------------------------------
		pX_rd_clk         : out std_logic;                     -- Clock for the read data FIFO
		pX_rd_en          : out std_logic;                     -- Read enable bit for the read data FIFO: 0: Diabled, 1: Enabled
		pX_rd_data        : in  std_logic_vector(31 downto 0); -- Data read from the RAM
		pX_rd_full        : in  std_logic;                     -- Read data FIFO full bit: 0: All ok, 1: Full. Data will be discarded.
		pX_rd_empty       : in  std_logic;                     -- Read data FIFO empty bit: 0: Not empty, 1: Empty. Cannot read data from FIFO.
		pX_rd_count       : in  std_logic_vector(6 downto 0);  -- Read data FIFO fill level: 0: empty. Note longer latency than pX_rd_full!
		pX_rd_overflow    : in  std_logic;                     -- Overflow flag: 0: All ok, 1: Data was lost because the FIFO overflowed.
		pX_rd_error       : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve. }}}

-- Double speed internal clock
		DCLK              : in std_logic);                     -- Clock used to speed up the internal logic. MUST BE SYNCHRONISED WITH HCLK!!

-- Quadruple speed internal clock
--		QCLK              : in std_logic);                     -- Clock used to speed up the internal logic. MUST BE SYNCHRONISED WITH HCLK!!
end AHBL2SDRAM;


--{{{
architecture cache of AHBL2SDRAM is

	--{{{ Address Format:

	-- 31       23           1l      4   1  |
	-- |00000000|XXXXXXXXXXXX|XXXXXXX|XXX|XX|
	-- |00000000|TAG         |INDEX  |WS |BS|
	-- |8       |12          |7      |3  |2 |

	alias HADDR_NULLED      is HADDR(31 downto 24);
	alias HADDR_TAG         is HADDR(23 downto 12);
	alias HADDR_INDEX       is HADDR(11 downto  5);
	alias HADDR_WORD_SELECT is HADDR( 4 downto  2);
	alias HADDR_BYTE_SELECT is HADDR( 1 downto  0);
	--}}}

	--{{{ DRAM Aliases

	--{{{ DRAM Command Path Aliases

	constant CMD_BL_1                      : std_logic_vector( 5 downto 0) := "000000";
	constant CMD_BL_2                      : std_logic_vector( 5 downto 0) := "000001";
	constant CMD_BL_3                      : std_logic_vector( 5 downto 0) := "000010";
	constant CMD_BL_4                      : std_logic_vector( 5 downto 0) := "000011";
	constant CMD_BL_5                      : std_logic_vector( 5 downto 0) := "000100";
	constant CMD_BL_6                      : std_logic_vector( 5 downto 0) := "000101";
	constant CMD_BL_7                      : std_logic_vector( 5 downto 0) := "000110";
	constant CMD_BL_8                      : std_logic_vector( 5 downto 0) := "000111";
	constant CMD_EMPTY                     : std_logic                     := '1';
	constant CMD_NOT_EMPTY                 : std_logic                     := '0';
	constant CMD_ENABLE                    : std_logic                     := '1';
	constant CMD_DISABLE                   : std_logic                     := '0';
	constant CMD_ERROR                     : std_logic                     := '1';
	constant CMD_NO_ERROR                  : std_logic                     := '0';
	constant CMD_FULL                      : std_logic                     := '1';
	constant CMD_NOT_FULL                  : std_logic                     := '0';
	constant CMD_WRITE                     : std_logic_vector( 2 downto 0) := "000";
	constant CMD_READ                      : std_logic_vector( 2 downto 0) := "001";
	constant CMD_WRITE_WITH_AUTO_PRECHARGE : std_logic_vector( 2 downto 0) := "010";
	constant CMD_READ_WITH_AUTO_PRECHARGE  : std_logic_vector( 2 downto 0) := "011";
	constant CMD_REFRESH                   : std_logic_vector( 2 downto 0) := "100";
	--}}}

	--{{{ DRAM Write Path Aliases

	constant WRITE_EMPTY                   : std_logic                     := '1';
	constant WRITE_NOT_EMPTY               : std_logic                     := '0';
	constant WRITE_ENABLE                  : std_logic                     := '1';
	constant WRITE_DISABLE                 : std_logic                     := '0';
	constant WRITE_ERROR                   : std_logic                     := '1';
	constant WRITE_NO_ERROR                : std_logic                     := '0';
	constant WRITE_FULL                    : std_logic                     := '1';
	constant WRITE_NOT_FULL                : std_logic                     := '0';
	constant WRITE_BYTE_0_MASK             : std_logic_vector( 3 downto 0) := "1110";
	constant WRITE_BYTE_1_MASK             : std_logic_vector( 3 downto 0) := "1101";
	constant WRITE_BYTE_2_MASK             : std_logic_vector( 3 downto 0) := "1011";
	constant WRITE_BYTE_3_MASK             : std_logic_vector( 3 downto 0) := "0111";
	constant WRITE_LOW_HALFWORD_MASK       : std_logic_vector( 3 downto 0) := "1100";
	constant WRITE_HIGH_HALFWORD_MASK      : std_logic_vector( 3 downto 0) := "0011";
	constant WRITE_WORD_MASK               : std_logic_vector( 3 downto 0) := "0000";
	constant WRITE_UNDERRUN                : std_logic                     := '1';
	constant WRITE_NO_UNDERRUN             : std_logic                     := '0';
	--}}}

	--{{{ DRAM Read Path Aliases

	constant READ_ENABLE                   : std_logic                     := '1';
	constant READ_DISABLE                  : std_logic                     := '0';
	constant READ_FULL                     : std_logic                     := '1';
	constant READ_NOT_FULL                 : std_logic                     := '0';
	constant READ_EMPTY                    : std_logic                     := '1';
	constant READ_NOT_EMPTY                : std_logic                     := '0';
	constant READ_OVERFLOW                 : std_logic                     := '1';
	constant READ_NO_OVERFLOW              : std_logic                     := '0';
	constant READ_ERROR                    : std_logic                     := '1';
	constant READ_NO_ERROR                 : std_logic                     := '0';
	--}}}

	--}}}

	--{{{ Tag SRAM:

	signal tag_sram_en   : std_logic;
	signal tag_sram_we   : std_logic;
	signal tag_sram_idx  : std_logic_vector( 9 downto 0);
	signal tag_sram_do   : std_logic_vector(15 downto 0);
	alias  tag_sram_do_tag   is tag_sram_do(11 downto 0);
	alias  tag_sram_do_valid is tag_sram_do(         12);
	alias  tag_sram_do_busy  is tag_sram_do(         13);
	signal tag_sram_di   : std_logic_vector(15 downto 0);

	component tag_sram
		port (clk  : in std_logic;
		      en   : in std_logic;
		      we   : in std_logic;
		      addr : in std_logic_vector(9 downto 0);
		      di   : in std_logic_vector(15 downto 0);
		      do   : out std_logic_vector(15 downto 0));
	end component;
	--}}}

	--{{{ Data SRAM:

	signal data_sram_en         : std_logic;
	signal data_sram_we         : std_logic;
	signal data_sram_idx        : std_logic_vector(9 downto 0);
	signal data_sram_di         : std_logic_vector(31 downto 0);
	signal data_sram_do         : std_logic_vector(31 downto 0);

	component data_sram is
		port (clk  : in std_logic;
		      en   : in std_logic;
		      we   : in std_logic;
		      addr : in std_logic_vector(9 downto 0);
		      di   : in std_logic_vector(31 downto 0);
		      do   : out std_logic_vector(31 downto 0));
	end component;
	--}}}

	--{{{ Address and Data save registers

	signal SAVE0_HADDR   : std_logic_vector(31 downto  0);
	alias  Save0_HADDR_NULLED      is HADDR(31 downto 24);
	alias  Save0_HADDR_TAG         is HADDR(23 downto 12);
	alias  Save0_HADDR_INDEX       is HADDR(11 downto  5);
	alias  Save0_HADDR_WORD_SELECT is HADDR( 4 downto  2);
	alias  Save0_HADDR_BYTE_SELECT is HADDR( 1 downto  0);
	signal SAVE0_HSIZE   : std_logic_vector( 2 downto  0);

	signal hit                       : std_logic;

	--signal SAVE1_HADDR   : std_logic_vector(31 downto  0);
	--alias  Save1_HADDR_NULLED      is HADDR(31 downto 24);
	--alias  Save1_HADDR_TAG         is HADDR(23 downto 12);
	--alias  Save1_HADDR_INDEX       is HADDR(11 downto  5);
	--alias  Save1_HADDR_WORD_SELECT is HADDR( 4 downto  2);
	--alias  Save1_HADDR_BYTE_SELECT is HADDR( 1 downto  0);
	--signal SAVE1_HSIZE   : std_logic_vector( 2 downto  0);
	--signal SAVE1_DATA    : std_logic_vector(31 downto  0);
	--}}}

	--{{{ Write FSM

	--signal write_request             : std_logic;
	--signal write_dram_busy           : std_logic;
    --signal propargate_write_dram0    : std_logic;
    --signal write_dram1               : std_logic;
    --signal map_dram_busy_2_hreadyout : std_logic;

	--component WRITE_FSM is
	--port (
	--	CLK                                : in  std_logic; -- DCLK
	--	RES_n                              : in  std_logic; -- HRESETn
	--	REQUEST                            : in  std_logic; -- HWRITE && HREADY && ( HSEL or HSEL & HPROT for non-unified cache )
	--	DRAM_BUSY                          : in  std_logic; -- pX_cmd_full || pX_rd_empty
	--	HIT                                : in  std_logic; -- The cache hit or miss information

	--	-- Aways: If Request: save address and size to first register stage and read tag_ram[address]
	--	PROPARGATE_WRITE_DRAM0             : out std_logic; -- Propagate address and size to second register stage and write dram[address in first reg stage]
	--	WRITE_DRAM1                        : out std_logic; -- write dram[address in second reg stage]
	--	MAP_DRAM_BUSY_2_HREADYOUT          : out std_logic  -- Connect hreadyout to not dram_busy
    --    );
	--end component;
	--}}}

	--{{{ Read FSM
	signal read_request              : std_logic;
	signal read_dram_busy            : std_logic;
	signal read_dram_empty           : std_logic;
	signal read_ws_zero              : std_logic;
	signal read_current_state        : read_fsm_state_type;
	signal read_SAVE1_HADDR          : std_logic_vector(31 downto  0);
	signal read_SAVE1_HSIZE          : std_logic_vector( 2 downto  0);

	component READ_FSM is
	port (
		DCLK              : in  std_logic;                      -- 2xHCLK
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
	end component READ_FSM;
	--}}}

	--{{{ Hit and Miss Registers for statistics
		signal hit_counter  : unsigned (31 downto 0) := (others => '0');
		signal miss_counter : unsigned (31 downto 0) := (others => '0');
	---}}}

begin

	--{{{ Port Maps

	ts: tag_sram    port map(clk => DCLK, en => tag_sram_en,  we => tag_sram_we,  addr => tag_sram_idx,  di => tag_sram_di,  do => tag_sram_do);
	ds: data_sram   port map(clk => DCLK, en => data_sram_en, we => data_sram_we, addr => data_sram_idx, di => data_sram_di, do => data_sram_do);
	--w_fsm: WRITE_FSM port map(CLK => DCLK,
	--                          RES_n => HRESETn,
	--                          REQUEST => write_request,
	--                          DRAM_BUSY => write_dram_busy,
	--                          HIT => hit,
	--                          PROPARGATE_WRITE_DRAM0 => propargate_write_dram0,
	--                          WRITE_DRAM1 => write_dram1,
	--                          MAP_DRAM_BUSY_2_HREADYOUT => map_dram_busy_2_hreadyout
	--                          );
	--}}}

	--{{{ Common FSM signals

	hit                       <= '1' after 1 ns when (tag_sram_do_tag = save0_haddr_tag) else '0' after 1 ns;
	HREADYOUT                 <= not write_dram_busy after 1 ns when (map_dram_busy_2_hreadyout = '1') else '1' after 1 ns; -- TODO: Read FSM auch übernehmen.
	--HRESP
	--HRDATA
	--pX_cmd_clk
	--pX_cmd_instr
	--pX_cmd_addr
	--pX_cmd_bl
	--pX_cmd_en

	--pX_wr_clk
	--pX_wr_data
	--pX_wr_mask
	--pX_wr_en

	--pX_rd_clk
	--pX_rd_en

	tag_sram_clk
	tag_sram_en
	tag_sram_we
	tag_sram_idx
	tag_sram_di


	data_sram_clk
	data_sram_en
	data_sram_we
	data_sram_idx
	data_sram_di

	SAVE0_HADDR
	SAVE0_HSIZE
	SAVE1_HADDR
	SAVE1_HSIZE

	read_request
	read_dram_busy
	read_dram_empty
	read_ws_zero
	read_SAVE1_HADDR
	read_SAVE1_HSIZE

	read_current_state
	--}}}

	--{{{ Write FSM signals

	write_request             <= HWRITE and HREADY and HSEL after 1 ns;
	write_dram_busy           <= pX_cmd_full or pX_rd_empty after 1 ns;

    -- propargate_write_dram0    : std_logic;
    -- write_dram1               : std_logic;
    -- map_dram_busy_2_hreadyout : std_logic;

	--}}}
	-- hit counters
	process(hit)
	begin
		-- add to hitcounter
		if ( hit = '1') then 
			hit_counter <= hit_counter + "1";
		else
			miss_counter <= miss_counter + "1";
		end if;
	end process;

end cache;
--}}}

--{{{
architecture no_cache of AHBL2SDRAM is
	--{{{ foobar

	signal last_HADDR  : std_logic_vector(31 downto 0);     -- Slave addr
	--signal last_HTRANS : std_logic_vector(1 downto 0);      -- ascending order: (IDLE, BUSY, NON-SEQUENTIAL, SEQUENTIAL);
	signal last_HWRITE : std_logic;                         -- High: Master write, Low: Master Read
	signal last_HSEL   : std_logic;                         -- signal form decoder
	signal iHWDATA     : std_logic_vector(31 downto 0);     -- incoming data from master
	signal iHREADY     : std_logic;                         -- previous transaction of Master completed
	signal iHREADYOUT  : std_logic;                         -- signal to halt transaction until slave-data is ready
	signal iHRDATA     : std_logic_vector(31 downto 0);     -- outgoing data to master
	--}}}
	signal connect_not_pX_rd_empty : std_logic := '0';
begin
	HRDATA <= pX_rd_data;

	-- TODO: Just pass each write and read operation directly to the DDR2-RAM
	-- capture AHB address phase signals
	process(HCLK) -- MOX: We can start the TAG lookup during the address phase. Then, we can write or read the data immediately.
	begin
		if(rising_edge(HCLK)) then
			if HREADY = '1' then  -- check if previous transaction is actually finished
				last_HADDR  <= HADDR;
				--last_HTRANS <= HTRANS;
				last_HWRITE <= HWRITE;
				last_HSEL   <= HSEL;
			end if;
		end if;
	end process;

	 process(HCLK) -- MOX: We can start the TAG lookup during the address phase. Then, we can write or read the data immediately.
	 begin
		if(rising_edge(HCLK)) then
			if( HREADY = '1' and HSEL = '1' ) then
				if( HWRITE = '0' ) then -- read request
					pX_cmd_addr             <= HADDR(31 downto 2);
					pX_cmd_bl               <= "000000";
					pX_cmd_en               <= '1';
					pX_cmd_instr            <= "001";
					connect_not_pX_rd_empty <= '1';
					pX_rd_en                <= '1';
					--wait until rising_edge(HCLK) and pX_rd_empty = '0';
					connect_not_pX_rd_empty <= '0';
					pX_cmd_en <= '0';
					pX_rd_en <= '0';
				else	-- write request
					pX_cmd_addr             <= HADDR(31 downto 2);
					pX_cmd_bl               <= "000000";
					pX_cmd_en               <= '1';
					pX_cmd_instr            <= "000";


				end if;
		end if;
		end if;
	 end process;

	continuous: process(connect_not_pX_rd_empty)
	begin
		if ( connect_not_pX_rd_empty = '1' ) then 
			HREADYOUT <= not pX_rd_empty;
		end if; 
	end process;


end no_cache;
--}}}
