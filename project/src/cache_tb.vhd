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
use ieee.numeric_std.all;

entity cache_tb is
end entity;

architecture rw_test of cache_tb is 

	--{{{
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
                p1_cmd_addr       : out std_logic_vector(29 downto 0); -- Byte start address for current transaction.
                p1_cmd_bl         : out std_logic_vector(5 downto 0);  -- Busrst length-1, eg. 0 indicates a burst of one word
                p1_cmd_clk        : out std_logic;                     -- User clock for the command FIFO
                p1_cmd_empty      : in  std_logic;                     -- Command FIFO empty bit: 0: Not empty, 1: Empty
                p1_cmd_en         : out std_logic;                     -- Write enable for the command FIFO: 0: Diabled, 1: Enabled
                p1_cmd_error      : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
                p1_cmd_full       : in  std_logic;                     -- Command FIFO full bit: 0: Not full, 1: Full
                p1_cmd_instr      : out std_logic_vector(2 downto 0);  -- Current instruction. 000: Wrtie, 001: Read, 010: Read w. precharge, 011: ...
        -- Write Datapath -----------------------------------------------------------------------------------------------------
                p1_wr_clk         : out std_logic;                     -- Clock for the write data FIFO
                p1_wr_count       : in  std_logic_vector( 6 downto 0); -- Write data FIFO fill level: 0: empty. Note longer latency than p1_wr_empty!
                p1_wr_data        : out std_logic_vector(31 downto 0); -- Data to be stored in the FIFO and be written to the DDR2-DRAM.
                p1_wr_empty       : in  std_logic;                     -- Write data FIFO empty bit: 0: Not empty, 1: Empty
                p1_wr_en          : out std_logic;                     -- Write enable for the write data FIFO
                p1_wr_error       : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
                p1_wr_full        : in  std_logic;                     -- Write data FIFO full bit: 0: Not full, 1: Full
                p1_wr_mask        : out std_logic_vector(3 downto 0);  -- Mask write data. A high bit means Corresponding byte is not written to the RAM.
                p1_wr_underrun    : in  std_logic;                     -- Underrun flag. 0: All ok, 1: Underrun. Last valid data is written repeatedly.
        -- Read Datapath ------------------------------------------------------------------------------------------------------
                p1_rd_clk         : out std_logic;                     -- Clock for the read data FIFO
                p1_rd_en          : out std_logic;                     -- Read enable bit for the read data FIFO: 0: Diabled, 1: Enabled
                p1_rd_data        : in  std_logic_vector(31 downto 0); -- Data read from the RAM
                p1_rd_full        : in  std_logic;                     -- Read data FIFO full bit: 0: All ok, 1: Full. Data will be discarded.
                p1_rd_empty       : in  std_logic;                     -- Read data FIFO empty bit: 0: Not empty, 1: Empty. Cannot read data from FIFO.
                p1_rd_count       : in  std_logic_vector(6 downto 0);  -- Read data FIFO fill level: 0: empty. Note longer latency than p1_rd_full!
                p1_rd_overflow    : in  std_logic;                     -- Overflow flag: 0: All ok, 1: Data was lost because the FIFO overflowed.
                p1_rd_error       : in  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
        -- Quadruple speed internal clock
                DCLK              : in std_logic; 
                mem_calib_done         : in std_logic
        );
    end component;
	--}}}

	--{{{
    -- AHB Lite 
    signal hclk        :  std_logic := '0'; -- AHB Clock: 50 MHz
    signal hresetn     :  std_logic;
    signal haddr       :  std_logic_vector(31 downto 0);
    signal htrans      :  std_logic_vector(1 downto 0);
    signal hwdata      :  std_logic_vector(31 downto 0); 
    signal hwrite      :  std_logic;
    signal hsel        :  std_logic;
    signal hready      :  std_logic;
    signal hreadyout   :  std_logic;
    signal hrdata      :  std_logic_vector(31 downto 0);
    signal hsize       :  std_logic_vector(2 downto 0);

    -- Memory Controller
    signal p1_cmd_addr       :  std_logic_vector(29 downto 0); -- Byte start address for current transaction.
    signal p1_cmd_bl         :  std_logic_vector(5 downto 0);  -- Busrst length-1, eg. 0 dicates a burst of one word
    signal p1_cmd_clk        :  std_logic;                     -- User clock for the command FIFO
    signal p1_cmd_empty      :  std_logic;                     -- Command FIFO empty bit: 0: Not empty, 1: Empty
    signal p1_cmd_en         :  std_logic;                     -- Write enable for the command FIFO: 0: Diabled, 1: Enabled
    signal p1_cmd_error      :  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
    signal p1_cmd_full       :  std_logic;                     -- Command FIFO full bit: 0: Not full, 1: Full
    signal p1_cmd_instr      :  std_logic_vector(2 downto 0);  -- Current struction. 000: Wrtie, 001: Read, 010: Read w. precharge, 011: ...
-- Write Datapath -----------------------------------------------------------------------------------------------------
    signal p1_wr_clk         :  std_logic;                     -- Clock for the write data FIFO
    signal p1_wr_count       :  std_logic_vector( 6 downto 0); -- Write data FIFO fill level: 0: empty. Note longer latency than p1_wr_empty!
    signal p1_wr_data        :  std_logic_vector(31 downto 0); -- Data to be stored  the FIFO and be written to the DDR2-DRAM.
    signal p1_wr_empty       :  std_logic;                     -- Write data FIFO empty bit: 0: Not empty, 1: Empty
    signal p1_wr_en          :  std_logic;                     -- Write enable for the write data FIFO
    signal p1_wr_error       :  std_logic;                     -- Error bit. Need to reset the MCB to resolve.
    signal p1_wr_full        :  std_logic;                     -- Write data FIFO full bit: 0: Not full, 1: Full
    signal p1_wr_mask        :  std_logic_vector(3 downto 0);  -- Mask write data. A high bit means Correspondg byte is not written to the RAM.
    signal p1_wr_underrun    :  std_logic;                     -- Underrun flag. 0: All ok, 1: Underrun. Last valid data is written repeatedly.
-- Read Datapath ------------------------------------------------------------------------------------------------------
    signal p1_rd_clk         :  std_logic;                     -- Clock for the read data FIFO
    signal p1_rd_en          :  std_logic;                     -- Read enable bit for the read data FIFO: 0: Diabled, 1: Enabled
    signal p1_rd_data        :  std_logic_vector(31 downto 0); -- Data read from the RAM
    signal p1_rd_full        :  std_logic;                     -- Read data FIFO full bit: 0: All ok, 1: Full. Data will be discarded.
    signal p1_rd_empty       :  std_logic;                     -- Read data FIFO empty bit: 0: Not empty, 1: Empty. Cannot read data from FIFO.
    signal p1_rd_count       :  std_logic_vector(6 downto 0);  -- Read data FIFO fill level: 0: empty. Note longer latency than p1_rd_full!
    signal p1_rd_overflow    :  std_logic;                     -- Overflow flag: 0: All ok, 1: Data was lost because the FIFO overflowed.
    signal p1_rd_error       :  std_logic;                     -- Error bit. Need to reset the MCB to resolve.

    signal mem_calib_done         : std_logic;
    signal dclk              : std_logic := '0';
	--}}}

        signal cnt : unsigned(31 downto 0) := (others => '0');
begin
    
	--{{{
    main : AHBL2SDRAM port map (
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
         HSIZE          => hsize,

    -- Command Path
         p1_cmd_addr    => p1_cmd_addr,
         p1_cmd_bl      => p1_cmd_bl,
         p1_cmd_clk     => p1_cmd_clk,
         p1_cmd_empty   => p1_cmd_empty,
         p1_cmd_en      => p1_cmd_en,
         p1_cmd_error   => p1_cmd_error,
         p1_cmd_full    => p1_cmd_full,
         p1_cmd_instr   => p1_cmd_instr,

    -- Write Datapath
         p1_wr_clk      => p1_wr_clk,
         p1_wr_count    => p1_wr_count, 
         p1_wr_data     => p1_wr_data, 
         p1_wr_empty    => p1_wr_empty,
         p1_wr_en       => p1_wr_en,
         p1_wr_error    => p1_wr_error,
         p1_wr_full     => p1_wr_full,
         p1_wr_mask     => p1_wr_mask,
         p1_wr_underrun => p1_wr_underrun,
    -- Read Datapath
         p1_rd_clk      => p1_rd_clk,
         p1_rd_en       => p1_rd_en,
         p1_rd_data     => p1_rd_data,
         p1_rd_full     => p1_rd_full,
         p1_rd_empty    => p1_rd_empty,
         p1_rd_count    => p1_rd_count,
         p1_rd_overflow => p1_rd_overflow,
         p1_rd_error    => p1_rd_error,
         
         DCLK           => dclk,
         mem_calib_done      => mem_calib_done
    );
	--}}}

    -- clock generator ( 20ns => 50 MHz )
    hclk <= not hclk after 20 ns;
    dclk <= not dclk after 10 ns;

    process(hclk)
    begin
    end process;

-- AHB Side
    -- test read commands
    hwrite <= '0'; -- we want to read in the next cycles
    haddr <= x"b00bb1e5";
    hwdata <= x"b00bb1e5" after 20 ns;
    hsize <= "111";
    hready <= '1';
    hsel <= '1';
    hsel <= '0' after 20 ns;

-- Memory Controller side
    -- all get the same stepping
    p1_rd_clk <= dclk;
    p1_wr_clk <= dclk;
    p1_cmd_clk <= dclk;
    p1_rd_empty <= '0';





    -- Command Path
         --p1_cmd_clk        : out
         --p1_cmd_instr      : out
         --p1_cmd_addr       : out
         --p1_cmd_bl         : out
         --p1_cmd_en         : out
         p1_cmd_empty      <= '0'; --: in 
         p1_cmd_error      <= '0'; --: in 
         p1_cmd_full       <= '0'; --: in 

    -- Write Datapath
         --p1_wr_clk         : out
         --p1_wr_data        : out
         --p1_wr_mask        : out
         --p1_wr_en          : out
         --p1_wr_count       : in 
         --p1_wr_empty       : in 
         p1_wr_error       <= '0'; --: in 
         p1_wr_full        <= '0'; --: in 
         p1_wr_underrun    <= '0'; --: in 
    -- Read Datapath
         --p1_rd_clk         : out
         --p1_rd_en          : out
         --p1_rd_data        : in 
         --p1_rd_full        : in 
         --p1_rd_empty       : in 
         --p1_rd_count       : in 
         --p1_rd_overflow    : in 
         p1_rd_error       <= '0'; --: in 











    -- write "fifo"

    -- read "fifo"
    process 
        -- variable that count the clock
    begin
        wait until rising_edge(p1_rd_clk);
        if (p1_rd_en = '1' ) then
            p1_rd_data <= std_logic_vector(cnt);
            cnt <= cnt + 1;
        else 
            cnt <= (others => '0');
        end if;
    end process; 








	stop_simulation :process
	begin
		wait for 100 ns; --run the simulation for this duration
		assert false report "simulation ended" severity failure;
	end process;



end rw_test;

