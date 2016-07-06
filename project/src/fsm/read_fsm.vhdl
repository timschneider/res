library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

entity CACHE_READ_FSM is
	port (
		clk            : in  std_logic;
		res_n          : in  std_logic;
		write          : in  std_logic;                      -- 
		reday_in       : in  std_logic;
		ready_out      : out std_logic;
		--addr_in        : in  std_logic_vector(31 downto 0);  -- Full read address
		--addr_out       : out std_logic_vector(31 downto 0);  -- Full write address for the DDR2-RAM controller
		--shift_distance : out std_logic_vector( 1 downto 0);  -- For controlling the barrel shifter
		--cache_line_idx : out std_logic_vector( 9 downto 0)  -- For addressing the TAG- and DATA- SRAMS
		
		
         );
end CACHE_READ_FSM;

architecture syn of CACHE_READ_FSM is
-- In FPGAs all FlipFlops are at zero after reset
	type state_type is(  -- Encoding    Next State
	idle_state,          -- 0000 000    HSEL && HREADY && !HWRITE                    -> tag_deliver_state      Wait for request, if request read SRAMS...
	                     --                                                                                    ...and set WS.

	tag_deliver_state,   -- 1000 000    HIT && (!HSEL || !HREADY || HWRITE)          -> idle_state             Compare tag from tag ram with address tag...
	                     --             HIT && (HSEL && HREADY && !HWRITE)           -> tag_deliver_state      ...bits and put data on the bus. Connects...
	                     --             MISS                                         -> request_data_0_state   ...HIT to HREADYOUT.

	request_data_0_state -- 0100 000    pX_cmd_full                                  -> request_data_0_state   Start DRAM read from addr, burstlength = 8 - WS
	                     --             !pX_cmd_full                                 -> request_data_1_state
	request_data_1_state -- 0100 001    pX_cmd_full                                  -> request_data_1_state   Start DRAM read from (addr & !WS), ...
	                     --             !pX_cmd_full && pX_rd_empty                  -> wait_phase_0_state     ....burstlength = WS.
	                     --             !pX_cmd_full && !pX_rd_empty                 -> data_phase_0_state

	data_phase_0_state,  -- 0010 000    pX_rd_empty                                  -> data_phase_0_state     Put DRAM data on the bus and write to SRAM...
	                     --             !pX_rd_empty                                 -> data_phase_1_state     Connect !pX_rd_empty to HREADYOUT and SRAM_WE.

	data_phase_1_state,  -- 0010 001    pX_rd_empty                                  -> data_phase_1_state     write dram data to sram. Connect...
                         --             !pX_rd_empty                                 -> data_phase_2_state     ...!px_rd_empty to sram_we.
	data_phase_2_state,  -- 0010 010
	data_phase_3_state,  -- 0010 011    .                                            .  .                      .
	data_phase_4_state,  -- 0010 100    .                                            .  .                      .
	data_phase_5_state,  -- 0010 101    .                                            .  .                      .
	data_phase_6_state,  -- 0010 110
	data_phase_7_state,  -- 0010 111    pX_rd_empty                                  -> tag_deliver_state      write dram data to sram. Connect...
	                     --             !pX_rd_empty && (HSEL && HREADY && !HWRITE)  -> tag_deliver_state      ...!px_rd_empty to sram_we.
                         --             !pX_rd_empty && (!HSEL || !HREADY || HWRITE) -> idle_state
	);

-- ATTRIBUTE ENUM_ENCODING : STRING;
-- ATTRIBUTE ENUM_ENCODING OF state_type : TYPE IS " 00000000 01000000 ...";
signal current_state, next_state: state_type := idle_state;
signal word_select : std_logic_vector(2 downto 0);



begin

    process (clk)
    begin
        if clk'event and clk = '1' then

        end if;
    end process;

end syn;
