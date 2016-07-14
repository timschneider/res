--
-- Simple Dual-Port BRAM Write-First Mode (recommended template)
--

 library ieee;
 use ieee.std_logic_1164.all;
 use ieee.numeric_std.all;
 --use ieee.std_logic_unsigned.all;

 entity TAG_SRAM is
     port (clk  : in std_logic;
           -- Port A
           en_A   : in std_logic;
           we_A   : in std_logic;
           addr_A : in std_logic_vector( 9 downto 0);
           di_A   : in std_logic_vector(15 downto 0);
           do_A   : out std_logic_vector(15 downto 0);

           -- Port B
           en_B   : in std_logic;
           we_B   : in std_logic;
           addr_B : in std_logic_vector( 9 downto 0);
           di_B   : in std_logic_vector(15 downto 0);
           do_B   : out std_logic_vector(15 downto 0)
    );
 end TAG_SRAM;

 architecture syn of TAG_SRAM is
     type ram_type is array (1024 downto 0) of std_logic_vector (15 downto 0);
     signal RAM : ram_type;
 begin
     process (clk)
     begin
         if clk'event and clk = '1' then
             if en_A = '1' then
                 if we_A = '1' then
                     RAM(to_integer(unsigned(addr_A))) <= di_A;
                     do_A <= di_A;
                 else
                     do_A <= RAM(to_integer(unsigned(addr_A)));
                 end if;
             end if;
         end if;
     end process;

     process (clk)
     begin
         if clk'event and clk = '1' then
             if en_B = '1' then
                 if we_B = '1' then
                     RAM(to_integer(unsigned(addr_B))) <= di_B;
                     do_B <= di_B;
                 else
                     do_B <= RAM(to_integer(unsigned(addr_B)));
                 end if;
             end if;
         end if;
     end process;
 end syn;


-- library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;
-- --use ieee.std_logic_unsigned.all;
-- 
-- entity TAG_SRAM is
--     port (
-- 			di_a     : in  std_logic_vector(15 downto 0);
-- 			dip_a    : in  std_logic_vector( 1 downto 0);
-- 			addr_a   : in  std_logic_vector( 9 downto 0);
-- 			we_a     : in  std_logic;
-- 			en_a     : in  std_logic;
-- 			rst_a    : in  std_logic;
-- 			clk_a    : in  std_logic;
-- 			do_a     : in  std_logic_vector(15 downto 0);
-- 			dop_a    : in  std_logic_vector( 1 downto 0);
-- 			regce_a  : in  std_logic;
-- 
-- 			di_b     : in  std_logic_vector(15 downto 0);
-- 			dip_b    : in  std_logic_vector( 1 downto 0);
-- 			addr_b   : in  std_logic_vector( 9 downto 0);
-- 			we_b     : in  std_logic;
-- 			en_b     : in  std_logic;
-- 			rst_b    : in  std_logic;
-- 			clk_b    : in  std_logic;
-- 			do_b     : in  std_logic_vector(15 downto 0);
-- 			dop_b    : in  std_logic_vector( 1 downto 0);
-- 			regce_b  : in  std_logic;
-- )
-- end TAG_SRAM;
-- 
-- architecture syn of TAG_SRAM is
--     type ram_type is array (1024 downto 0) of std_logic_vector (16 downto 0);
--     signal RAM : ram_type;
-- begin
-- 
--     process (clk)
--     begin
--         if clk'event and clk = '1' then
--             if en = '1' then
--                 if we = '1' then
--                     -- RAM(conv_integer(addr)) <= di;
--                     RAM(to_integer(unsigned(addr))) <= di;
--                     do <= di;
--                 else
--                     --do <= RAM( conv_integer(addr));
--                     do <= RAM(to_integer(unsigned(addr)));
--                 end if;
--             end if;
--         end if;
--     end process;
-- 
-- end syn;







