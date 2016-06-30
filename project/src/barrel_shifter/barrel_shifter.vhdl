--
-- A simple byte-wise barrel sifter for 4-byte words
--

library ieee;
use ieee.std_logic_1164.all;

entity barrel_shifter is
    port (distance : in  std_logic_vector(1  downto 0);
          di       : in  std_logic_vector(31 downto 0);
          do       : out std_logic_vector(31 downto 0));
end barrel_shifter;

architecture syn of barrel_shifter is
begin
	process (distance, di)
	begin
		case distance is
			when "00" => do <= di(31 downto 0);
			when "01" => do <= di(7 downto 0) & di(31 downto 8);
			when "10" => do <= di(15 downto 0) & di(31 downto 16);
			when "11" => do <= di(23 downto 0) & di(31 downto 24);
			when others => do <=  (others => 'X');
		end case;
	end process;
end syn;
