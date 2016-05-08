library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity muxmem is 
    generic (bits : integer := 32); -- mem-width
    port (
        adr : in std_logic_vector( 3 downto 0);
        dat : in std_logic_vector( bits-1 downto 0);
        wrt : in std_logic;
        clk : in std_logic;
        o : out std_logic_vector( bits-1 downto 0)
    );
end muxmem;

architecture a1 of muxmem is
    type arr is array (0 to (2**4)-1) of std_logic_vector(bits-1 downto 0);
    signal mem : arr;
begin
    process
    begin
        wait until rising_edge(clk);
        if wrt = '1' then -- write
            mem(to_integer(unsigned(adr))) <= dat;
        else -- read
            o <= mem(to_integer(unsigned(adr)));
        end if;
    end process;
end a1;
