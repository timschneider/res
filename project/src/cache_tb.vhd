----------------------------------------------------------------
 -- Authors: Rieber, Dennis; Noeltner, Moritz; Schneider, Tim
 -- Institute: University of Heidelberg, ZITI 
 -- Lecture: Reconfigurable Embedded Systems
 -------------------------------------------------------------------------
 -- Content: This module is a testbench for the internal cache controller, imitating 
 -- an AHB Master and Memeory Controller 
--------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity cache_tb is
    port (
    );
end entity;

architecture rw_test of cache_tb is 

    component AHBL2SDRAM
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
            --  asycn_rst         : out std_logic;                     -- Main reset for the memory controller
            --  calib_done        : in  std_logic;                     -- Operational readiness: 0: Still calibrating, 1: Ready to receive commands
            --  mcb_drp_clk       : out std_logic;                     -- ...
            --  pll_ce_0          : out std_logic;                     -- ...
            --  pll_ce_90         : out std_logic;                     -- ...
            --  pll_lock          : out std_logic;                     -- ...
            --  sysclk_2x         : out std_logic;                     -- ...
            --  sysclk_2x_180     : out std_logic;                     -- ...
        -- Self-Refresh-Signals -----------------------------------------------------------------------------------------------
            --  selfrefresh_enter : out std_logic;                     -- Ask RAM to go to self-refresh mode. Hold high until selfrefresh_mode goes high.
            --  selfrefresh_mode  : in  std_logic;                     -- 0: Normal mode, 1: RAM is in selfrefresh mode.
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
                QCLK              : in std_logic; 
        );
    end component;

    -- AHB Lite 
    signal hclk        :  std_logic; -- AHB Clock: 50 MHz
    signal hresetn     :  std_logic;
    signal haddr       :  std_logic_vector(31 downto 0);
    signal htrans      :  std_logic_vector(1 downto 0);
    signal hwdata      :  std_logic_vector(31 downto 0); 
    signal hwrite      :  std_logic;
    signal hsel        :  std_logic;
    signal hready      :  std_logic;
    signal hreadyout   :  std_logic;
    signal hrdata      :  std_logic_vector(31 downto 0);

    -- Memory Controller
    signal pX_cmd_addr       :  std_logic_vector(29 downto 0); -- Byte start address for current transaction.
    signal pX_cmd_bl         :  std_logic_vector(5 downto 0);  -- Busrst length-1, eg. 0 dicates a burst of one word
    signal pX_cmd_clk        :  std_logic;                     -- User clock for the command FIFO
    signal pX_cmd_empty      :  std_logic;                     -- Command FIFO empty bit: 0: Not empty, 1: Empty
    signal pX_cmd_en         :  std_logic;                     -- Write enable for the command FIFO: 0: Diabled, 1: Enabled
    signal pX_cmd_error      :  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
    signal pX_cmd_full       :  std_logic;                     -- Command FIFO full bit: 0: Not full, 1: Full
    signal pX_cmd_strin      :  std_logic_vector(2 downto 0);  -- Current struction. 000: Wrtie, 001: Read, 010: Read w. precharge, 011: ...
-- Write Datapath -----------------------------------------------------------------------------------------------------
    signal pX_wr_clk         :  std_logic;                     -- Clock for the write data FIFO
    signal pX_wr_count       :  std_logic_vector( 6 downto 0); -- Write data FIFO fill level: 0: empty. Note longer latency than pX_wr_empty!
    signal pX_wr_data        :  std_logic_vector(31 downto 0); -- Data to be stored  the FIFO and be written to the DDR2-DRAM.
    signal pX_wr_empty       :  std_logic;                     -- Write data FIFO empty bit: 0: Not empty, 1: Empty
    signal pX_wr_en          :  std_logic;                     -- Write enable for the write data FIFO
    signal pX_wr_error       :  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
    signal pX_wr_full        :  std_logic;                     -- Write data FIFO full bit: 0: Not full, 1: Full
    signal pX_wr_mask        :  std_logic_vector(3 downto 0);  -- Mask write data. A high bit means Correspondg byte is not written to the RAM.
    signal pX_wr_underrun    :  std_logic;                     -- Underrun flag. 0: All ok, 1: Underrun. Last valid data is written repeatedly.
-- Read Datapath ------------------------------------------------------------------------------------------------------
    signal pX_rd_clk         :  std_logic;                     -- Clock for the read data FIFO
    signal pX_rd_en          :  std_logic;                     -- Read enable bit for the read data FIFO: 0: Diabled, 1: Enabled
    signal pX_rd_data        :  std_logic_vector(31 downto 0); -- Data read from the RAM
    signal pX_rd_full        :  std_logic;                     -- Read data FIFO full bit: 0: All ok, 1: Full. Data will be discarded.
    signal pX_rd_empty       :  std_logic;                     -- Read data FIFO empty bit: 0: Not empty, 1: Empty. Cannot read data from FIFO.
    signal pX_rd_count       :  std_logic_vector(6 downto 0);  -- Read data FIFO fill level: 0: empty. Note longer latency than pX_rd_full!
    signal pX_rd_overflow    :  std_logic;                     -- Overflow flag: 0: All ok, 1: Data was lost because the FIFO overflowed.
    signal pX_rd_error       :  std_logic;                     -- Error bit. Need to reset the MCB to resolve.

begin
    
    port map (
    -- AHB Lite 
         HCLK           => hclk,
         HRESETn        => hresetN, 
         HADDR          => haddr,
         HTRANS         => htrans,
         HWDATA         => hwdata,
         HWRITE         => hwrite,
         HSEL           => hsel,
         HREADY         => hready,
         HREADYOUT      => hreadyout,
         HRDATA         => hrdata,
    -- Command Path
         pX_cmd_addr    => pX_cmd_addr,
         pX_cmd_bl      => pX_cmd_bl,
         pX_cmd_clk     => pX_cmd_clk,
         pX_cmd_empty   => pX_cmd_empty
         pX_cmd_en      => pX_cmd_en,
         pX_cmd_error   => pX_cmd_error,
         pX_cmd_full    => pX_cmd_full,
         pX_cmd_strin   => pX_cmd_strin,
    -- Write Datapath
         pX_wr_clk      => pX_wr_clk,
         pX_wr_count    => pX_wr_count, 
         pX_wr_data     => pX_wr_data, 
         pX_wr_empty    => pX_wr_empty,
         pX_wr_en       => pX_wr_en,
         pX_wr_error    => pX_wr_error,
         pX_wr_full     => pX_wr_full,
         pX_wr_mask     => pX_wr_mask,
         pX_wr_underrun => pX_wr_underrun,
    -- Read Datapath
         pX_rd_clk      => pX_rd_clk,
         pX_rd_en       => pX_rd_en,
         pX_rd_data     => pX_rd_data,
         pX_rd_full     => pX_rd_full,
         pX_rd_empty    => pX_rd_empty,
         pX_rd_count    => pX_rd_count,
         pX_rd_overflow => pX_rd_overflow,
         pX_rd_error    => pX_rd_error
    );
    -- clock generator ( 20ns => 50 MHz )
    hclk <= not hclk after 20 ns;


-- AHB Side
    -- test read commands
    hwrite <= '0'; -- we want to read in the next cycles
    haddr <= "";
    hwdata <= "0";
    hready <= '1';

    -- test write commands
    hwrite <= '1'; -- we want to write in the next cycles
    haddr <= "";
    hwdata <= "110101011101010100";
    hready <= '1';


-- Memory Controller side
    -- all get the same stepping
    pX_rd_clk <= hclk;
    pX_wr_clk <= hclk;
    pX_cmd_clk <= hclk;

    -- write "fifo"
    process 
    begin
        wait until rising_edge(pX_wr_clk) and rising_edge(pX_wr_clk)
        -- we can actually ignore the data....
    end process; 

    -- read "fifo"
    process 
        -- variable that count the clock
        variable cnt : integer := 0;
    begin
        wait until rising_edge(pX_rd_clk) and rising_edge(pX_rd_clk)
        if ( cnt = 8 ) then
            cnt = 0;
            pX_rd_data <= "1";
        else 
            cnt = cnt + 1;
        end if;
    end process; 

    -- cmd "fifo"
    process 
        -- variable that count the clock
        variable cnt : integer := 0;
    begin
        wait until rising_edge(pX_cmd_clk) and rising_edge(pX_cmd_clk)
    end process; 

end rw_test;

