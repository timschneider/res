library ieee;
use ieee.std_logic_1164.all;

entity barrel_shifter_tb is
end entity;

architecture test of barrel_shifter_tb is

	signal indata_tb   : std_logic_vector(31 downto 0);
	signal outdata_tb  : std_logic_vector(31 downto 0);
	signal distance_tb : std_logic_vector( 1 downto 0);
	--signal c: std_logic; 


	component barrel_shifter
		port (distance : in  std_logic_vector(1  downto 0);
			  di       : in  std_logic_vector(31 downto 0);
			  do       : out std_logic_vector(31 downto 0));
	end component;

	constant ckTime: time := 10 ns;

begin

	uut: barrel_shifter
	port map (distance_tb, indata_tb, outdata_tb);

	pProc: process
	begin
	wait for 10 * ckTime;
	indata_tb <= X"aabbccdd";
	wait for 10 * ckTime;

	distance_tb <= B"00";
	wait for 1 * ckTime;
		assert (outdata_tb = X"aabbccdd") report "Wrong output value" severity failure;
	wait for 9 * ckTime;

	distance_tb <= B"01";
	wait for 1 * ckTime;
		assert (outdata_tb = X"ddaabbcc") report "Wrong output value" severity failure;
	wait for 9 * ckTime;

	distance_tb <= B"10";
	wait for 1 * ckTime;
		assert (outdata_tb = X"ccddaabb") report "Wrong output value" severity failure;
	wait for 9 * ckTime;

	distance_tb <= B"11";
	wait for 1 * ckTime;
		assert (outdata_tb = X"bbccddaa") report "Wrong output value" severity failure;
	wait for 9 * ckTime;

	indata_tb <= X"11223344";
	wait for 1 * ckTime;
		assert (outdata_tb = X"22334411") report "Wrong output value" severity failure;
	wait for 9 * ckTime;






	wait;
	end process;

end test;
