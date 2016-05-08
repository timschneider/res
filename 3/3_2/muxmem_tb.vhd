library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
use work.adress_generator_pkg.all;

entity memtb is
        generic ( bits : integer := 4 );
end entity;

architecture m of memtb is 
    component muxmem
        generic ( bits : integer := 4 );
        port (
            adr : in std_logic_vector( 3 downto 0);
            dat : in std_logic_vector( bits-1 downto 0);
            wrt : in std_logic;
            clk : in std_logic;
            o : out std_logic_vector( bits-1 downto 0)
        );
    end component;

    signal adr_in : std_logic_vector(bits-1 downto 0);
    signal dat_in : std_logic_vector(bits-1 downto 0);
    signal o_out  : std_logic_vector(bits-1 downto 0);
    signal wrt_in : std_logic;
    signal clk_in : std_logic;

    constant clock : time := 10 ns;    
begin
    h1: muxmem port map (
        adr => adr_in,
        dat => dat_in,
        wrt => wrt_in,
        clk => clk_in,
        o   => o_out
    );
    adr_gen : process 
    begin
        generate_adress (
            wdh     => 4,
            delay   => clock,
            adress  => adr_in    
        );
    end process;
    data_gen : process 
    begin 
        generate_adress (
            wdh     => 4,
            delay   => clock,
            adress  => dat_in    
        );
    end process;
    process
    begin
        wrt_in <= '1';
        for i in 0 to 15 loop -- write cycle
            clk_in <= '1';
            wait for clock/2;
            clk_in <= '0';
            wait for clock/2;
        end loop;
        wrt_in <= '0';
        for i in 0 to 15 loop -- read cycle
            clk_in <= '1';
            wait for clock/2;
            clk_in <= '0';
            wait for clock/2;
        end loop;
    end process;
end m;
