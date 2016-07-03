library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;





entity AHBL2SDRAM is
	port (
-- AHB-LITE Interface
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
		HTRANS            : in  std_logic_vector( 1 downto 0); -- Transaction status: 00: IDLE, 01: BUSY, 10: NON-SEQUENTIAL, 11: SEQUENTIAL
		-- HMASTLOCK      : in  std_logic;                     -- NOT IMPLEMENTED
		HREADY            : in  std_logic;                     -- Master's ready signal: 0: Busy, 1: Ready for next transaction

		HWDATA            : in  std_logic_vector(31 downto 0); -- Incomming Data from master
-- AHB Slave outputs --------------------------------------------------------------------------------------------------
		HREADYOUT         : out std_logic;                     -- Slave's ready signal: 0: Busy, 1: Ready
		HRESP             : out std_logic;                     -- Transfer response: 0: Okay, 1: Error. Needs one additional wait state with HREADYout low.
		HRDATA            : out std_logic_vector(31 downto 0); -- Outgoing Data to master

-- Memory Controller Interface
-- Clock, Reset and Calibration Signals. We probably do not need these ------------------------------------------------
	--	asycn_rst         : out std_logic;                     -- Main reset for the memory controller
	--	calib_done        : in  std_logic;                     -- Operational readiness: 0: Still calibrating, 1: Ready to receive commands
	--	mcb_drp_clk       : out std_logic;                     -- ...
	--	pll_ce_0          : out std_logic;                     -- ...
	--	pll_ce_90         : out std_logic;                     -- ...
	--	pll_lock          : out std_logic;                     -- ...
	--	sysclk_2x         : out std_logic;                     -- ...
	--	sysclk_2x_180     : out std_logic;                     -- ...
-- Self-Refresh-Signals -----------------------------------------------------------------------------------------------
	--	selfrefresh_enter : out std_logic;                     -- Ask RAM to go to self-refresh mode. Hold high until selfrefresh_mode goes high.
	--	selfrefresh_mode  : in  std_logic;                     -- 0: Normal mode, 1: RAM is in selfrefresh mode.
-- Command Path. TODO: Replace X by appropriate port number -----------------------------------------------------------
		pX_cmd_addr       : out std_logic_vector(29 downto 0); -- Byte start address for current transaction.
		pX_cmd_bl         : out std_logic_vector(5 downto 0);  -- Busrst length-1, eg. 0 indicates a burst of one word
		pX_cmd_clk        : out std_logic;                     -- User clock for the command FIFO
		pX_cmd_empty      : in  std_logic;                     -- Command FIFO empty bit: 0: Not empty, 1: Empty
		pX_cmd_en         : out std_logic;                     -- Write enable for the command FIFO: 0: Diabled, 1: Enabled
		pX_cmd_error      : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
		pX_cmd_full       : in  std_logic;                     -- Command FIFO full bit: 0: Not full, 1: Full
		pX_cmd_instr      : out std_logic_vector(2 downto 0);  -- Current instruction. 000: Wrtie, 001: Read, 010: Read w. precharge, 011: ...
-- Write Datapath -----------------------------------------------------------------------------------------------------
		pX_wr_clk         : out std_logic;                     -- Clock for the write data FIFO
		pX_wr_count       : in  std_logic_vector( 6 downto 0); -- Write data FIFO fill level: 0: empty. Note longer latency than pX_wr_empty!
		pX_wr_data        : out std_logic_vector(31 downto 0); -- Data to be stored in the FIFO and be written to the DDR2-DRAM.
		pX_wr_empty       : in  std_logic;                     -- Write data FIFO empty bit: 0: Not empty, 1: Empty
		pX_wr_en          : out std_logic;                     -- Write enable for the write data FIFO
		pX_wr_error       : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
		pX_wr_full        : in  std_logic;                     -- Write data FIFO full bit: 0: Not full, 1: Full
		pX_wr_mask        : out std_logic_vector(3 downto 0);  -- Mask write data. A high bit means Corresponding byte is not written to the RAM.
		pX_wr_underrun    : in  std_logic;                     -- Underrun flag. 0: All ok, 1: Underrun. Last valid data is written repeatedly.
-- Read Datapath ------------------------------------------------------------------------------------------------------
		pX_rd_clk         : out std_logic;                     -- Clock for the read data FIFO
		pX_rd_en          : out std_logic;                     -- Read enable bit for the read data FIFO: 0: Diabled, 1: Enabled
		pX_rd_data        : in  std_logic_vector(31 downto 0); -- Data read from the RAM
		pX_rd_full        : in  std_logic;                     -- Read data FIFO full bit: 0: All ok, 1: Full. Data will be discarded.
		pX_rd_empty       : in  std_logic;                     -- Read data FIFO empty bit: 0: Not empty, 1: Empty. Cannot read data from FIFO.
		pX_rd_count       : in  std_logic_vector(6 downto 0);  -- Read data FIFO fill level: 0: empty. Note longer latency than pX_rd_full!
		pX_rd_overflow    : in  std_logic;                     -- Overflow flag: 0: All ok, 1: Data was lost because the FIFO overflowed.
		pX_rd_error       : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
-- Quadruple speed internal clock
		QCLK              : in std_logic);                     -- Clock used to speed up the internal logic. MUST BE SYNCHRONISED WITH HCLK!!
end AHBL2SDRAM;



architecture cache of AHBL2SDRAM is

	signal last_HADDR  : std_logic_vector(31 downto 0);     -- Slave addr
	signal last_HTRANS : std_logic_vector(1 downto 0);      -- ascending order: (IDLE, BUSY, NON-SEQUENTIAL, SEQUENTIAL);
	signal last_HWRITE : std_logic;                         -- High: Master write, Low: Master Read
	signal last_HSEL   : std_logic;                         -- signal form decoder
--	signal iHWDATA     : std_logic_vector(31 downto 0);     -- incoming data from master
--	signal iHREADY     : std_logic;                         -- previous transaction of Master completed
--	signal iHREADYOUT  : std_logic;                         -- signal to halt transaction until slave-data is ready
--	signal iHRDATA     : std_logic_vector(31 downto 0);     -- outgoing data to master


	--{{{ The Signals for the Cache SRAM:
	signal tag_en      : std_logic;
	signal tag_we      : std_logic;
	signal tag_idx     : std_logic_vector(9 downto 0);
	signal tag_read    : std_logic_vector(15 downto 0);
	signal tag_write   : std_logic_vector(15 downto 0);

	component tag_sram
		port (clk  : in std_logic;
			  en   : in std_logic;
			  we   : in std_logic;
			  addr : in std_logic_vector(9 downto 0);
			  di   : in std_logic_vector(15 downto 0);
			  do   : out std_logic_vector(15 downto 0));
	end component;
	--}}}

	--{{{ The Signals for the Data SRAM:
	signal data_en      : std_logic;
	signal data_we      : std_logic;
	signal data_idx     : std_logic_vector(9 downto 0);
	signal data_read    : std_logic_vector(31 downto 0);
	signal data_write   : std_logic_vector(31 downto 0);

	component data_sram is
		port (clk  : in std_logic;
			  en   : in std_logic;
			  we   : in std_logic;
			  addr : in std_logic_vector(9 downto 0);
			  di   : in std_logic_vector(31 downto 0);
			  do   : out std_logic_vector(31 downto 0));
	end component;
	--}}}


	-- TODO: instantiate cache controller components


begin
	-- capture AHB address phase signals
	process(HCLK) -- MOX: We can start the TAG lookup during the address phase. Then, we can write or read the data immediately.
	begin
		if(rising_edge(HCLK)) then
			if HREADY = '1' then  -- check if previous transaction is actually finished
				last_HADDR  <= HADDR;
				last_HTRANS <= HTRANS;
				last_HWRITE <= HWRITE;
				last_HSEL   <= HSEL;
			end if;
		end if;
	end process;

    -- we are selected for this transfer, link signals to controllers
    process(HCLK)
    begin
		if(rising_edge(HCLK)) then
			HREADYOUT <= '0'; -- pull down until we have an something to deliver 
			if last_HWRITE = '1'  then -- write
            	-- write control signals
            	-- write data to Memory Controller
            	-- write addr to Memeory Controller
            	-- write data to Cache Contorller
            	-- write addr to Cache Conroller

            	-- do we have to wait for ready signal from someone??? I don't think so...

			else -- read
            	-- write control signals
            	-- write data to Memory Controller
            	-- write addr to Memeory Controller
            	-- write data to Cache Contorller
            	-- write addr to Cache Conroller
			end if;
		end if;
	end process;

    -- wait for status of cache controller if we read
    -- process(chit)
    -- begin
    --     if chit = '1' then -- cache hit, get data from cache
    --         HRDATA <= crdata; 
    --         -- some other signaling stuff????
    --         HREADYOUT <= '1' -- pull ready up since we are done
    --     else -- cache miss
    --         -- wait for DRAM to get the data...
    --     end if;
    -- end process;

end cache;

architecture no_cache of AHBL2SDRAM is
begin
	-- TODO: Just pass each write and read operation directly to the DDR2-RAM
end no_cache;

