--
-- Single-Port BRAM Write-First Mode (recommended template)
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

entity data_sram is
    port (clk  : in std_logic;
          we   : in std_logic;
          en   : in std_logic;
          addr : in std_logic_vector(8 downto 0);
          di   : in std_logic_vector(31 downto 0);
          do   : out std_logic_vector(31 downto 0));
end data_sram;

architecture syn of data_sram is
    type ram_type is array (512 downto 0) of std_logic_vector (31 downto 0);
    signal RAM : ram_type;
begin

    process (clk)
    begin
        if clk'event and clk = '1' then
            if en = '1' then
                if we = '1' then
                    -- RAM(conv_integer(addr)) <= di;
                    RAM(to_integer(unsigned(addr))) <= di;
                    do <= di;
                else
                    --do <= RAM( conv_integer(addr));
                    do <= RAM(to_integer(unsigned(addr)));
                end if;
            end if;
        end if;
    end process;

end syn;
