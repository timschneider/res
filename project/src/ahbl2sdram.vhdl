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
		HADDR             : in  std_logic_vector(31 downto 0); -- Slave address
		HTRANS            : in  std_logic_vector( 1 downto 0); -- Transaction status: 00: IDLE, 01: BUSY, 10: NON-SEQUENTIAL, 11: SEQUENTIAL
		HWRITE            : in  std_logic;                     -- Diretion: 0: Master read, 1: Master write
		HWDATA            : in  std_logic_vector(31 downto 0); -- Incomming Data from master
		HSEL              : in  std_logic;                     -- Slave select
		HREADY            : in  std_logic;                     -- Master's ready signal: 0: Busy, 1: Ready for next transaction
-- AHB Slave outputs --------------------------------------------------------------------------------------------------
		HRDATA            : in  std_logic_vector(31 downto 0); -- Outgoing Data to master
		HREADYOUT         : in  std_logic;                     -- Slave's ready signal: 0: Busy, 1: Ready

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
-- Self-Refresh-Signals -----------------------------------------------------------------------------------------------
		selfrefresh_enter : out std_logic;                     -- Ask RAM to go to self-refresh mode. Hold high until selfrefresh_mode goes high.
		selfrefresh_mode  : in  std_logic);                    -- 0: Normal mode, 1: RAM is in selfrefresh mode.
end AHBL2SDRAM;



architecture cache of AHBL2SDRAM is

    -- -- internal AHB signals ( not sure if we need every signal internally, but at least some if them )
    last_HADDR : IN std_logic_vector(31 downto 0); -- Slave addr
    last_HTRANS : IN std_logic_vector(1 downto 0); -- ascending order: (IDLE, BUSY, NON-SEQUENTIAL, SEQUENTIAL);
    -- iHWDATA : IN std_logic_vector(31 downto 0); -- incoming data from master
    last_HWRITE : IN std_logic; -- High: Master write, Low: Master Read
    last_HSEL : IN std_logic; -- signal form decoder
    -- iHREADY : IN std_logic; -- previous transaction of Master completed
    -- iHREADYOUT : OUT std_logic; -- signal to halt transaction until slave-data is ready
    -- iHRDATA : OUT std_logic_vector(31 downto 0); -- outgoing data to master

    -- further required wiring



	-- TODO: instantiate cache controller components


begin:
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
    process(HCLK_
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
    process(chit)
    begin
        if chit = '1' then -- cache hit, get data from cache
            HRDATA <= crdata; 
            -- some other signaling stuff????
            HREADYOUT <= '1' -- pull ready up since we are done
        else -- cache miss
            -- wait for DRAM to get the data...
        end if;
    end process;

end cache;

architecture no_cache of AHBL2SDRAM is
begin:
	-- TODO: Just pass each write and read operation directly to the DDR2-RAM
end no_cache;

