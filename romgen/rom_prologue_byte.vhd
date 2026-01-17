
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eightthirtytwo_rom is
generic	(
	ADDR_WIDTH : integer := 8; -- ROM's address width (words, not bytes)
	COL_WIDTH  : integer := 8;  -- Column width (8bit -> byte)
	NB_COL     : integer := 2  -- Number of columns in memory
	);
port (
	clk : in std_logic;
	reset_n : in std_logic := '1';
	addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
	q : out std_logic_vector(COL_WIDTH*NB_COL-1 downto 0);
	-- Allow writes - defaults supplied to simplify projects that don't need to write.
	d : in std_logic_vector(COL_WIDTH*NB_COL-1 downto 0) := (others => '0');
	we : in std_logic := '0';
	bytesel : in std_logic_vector(NB_COL-1 downto 0) := (others => '1')
);
end entity;

architecture rtl of eightthirtytwo_rom is

	signal addr1 : integer range 0 to 2**ADDR_WIDTH-1;

	--  build up 2D array to hold the memory
	type word_t is array (0 to NB_COL-1) of std_logic_vector(7 downto 0);
	type ram_t is array (0 to 2 ** ADDR_WIDTH - 1) of word_t;

	signal ram : ram_t:=
	(

