library ieee;
use ieee.std_logic_1164.all;

package debug_jtag_plumbing is

type debug_jtag_to_reg is record
	tck : std_logic;
	tdi : std_logic;
	sel : std_logic;
	capture : std_logic;
	shift : std_logic;
	update : std_logic;
end record;

type debug_jtag_to_regs is array (0 to 1) of debug_jtag_to_reg;

type debug_jtag_from_reg is record
	tdo : std_logic;
end record;

type debug_jtag_from_regs is array (0 to 1) of debug_jtag_from_reg;

end package;


library ieee;
use ieee.std_logic_1164.all;

library work;
use work.debug_jtag_plumbing.all;

entity debug_virtualjtag is
port (
	from_regs : in debug_jtag_from_regs;
	to_regs : out debug_jtag_to_regs
);
end entity;

architecture rtl of debug_virtualjtag is
	signal jtck : std_logic;
	signal jtdi,jshift,jupdate,jrstn,jce1,jce2 : std_logic;
	signal tdo1,tdo2 : std_logic;
	signal jtdi_mux : std_logic;
	signal jtdi_latched : std_logic;
	signal jshift_d : std_logic;
	signal selectedreg : std_logic;

	component jtaggwrapper
	port (
		JTCK : out std_logic;
		JTDI : out std_logic;
		JSHIFT : out std_logic;
		JUPDATE : out std_logic;
		JRSTN : out std_logic;
		JCE1 : out std_logic;
		JCE2 : out std_logic;
		JRTI1 : out std_logic;
		JRTI2 : out std_logic;
		JTDO1 : in std_logic;
		JTDO2 : in std_logic
	);
	end component;

	signal jhold : std_logic;

begin

	-- The JTAGG instance
	jtg : component jtaggwrapper
	port map(
		JTCK => jtck,
		JTDI => jtdi,	-- Registered, so delayed by one tck
		JSHIFT => jshift,
		JUPDATE => jupdate,
		JRSTN => jrstn,
		JCE1 => jce1,
		JCE2 => jce2,
		JRTI1 => open,
		JRTI2 => open,
		JTDO1 => tdo1,
		JTDO2 => tdo2
	);

	tdo1 <= from_regs(0).tdo;
	tdo2 <= from_regs(1).tdo;
	
	to_regs(0).tck <= jtck;
	to_regs(1).tck <= jtck;

	to_regs(0).sel <= jce1;
	to_regs(1).sel <= jce2;

	process(jtck) begin
		if rising_edge(jtck) then
			jshift_d <= jshift;
			if jshift_d='1' then
				jtdi_latched <= jtdi;
			end if;
		end if;
	end process;

	to_regs(0).tdi <= jtdi when jshift_d='1' else jtdi_latched;
	to_regs(1).tdi <= jtdi when jshift_d='1' else jtdi_latched;

	-- The JTAGG primitive doesn't supply a capture signal, so we
	-- just capture any time we're not shifting or updating.
	-- This works OK provided no action is taken on capture other than
	-- loading the shift register.
	-- Advancing a FIFO or acknowledging a shift should be done on update instead.

	process(jtck) begin
		if rising_edge(jtck) then
			if jshift='1' then
				jhold <= '1';
			elsif jupdate='1' then
				jhold <= '0';
			end if;
		end if;
	end process;

	-- Record which register is being accessed, and filter jupdate accordingly.
	process(jtck) begin
		if rising_edge(jtck) then
			if (jce1 and jshift) = '1' then
				selectedreg<='0';
			end if;
			if (jce2 and jshift) = '1' then
				selectedreg<='1';
			end if;
		end if;
	end process;

	to_regs(0).update <= jupdate and not selectedreg;
	to_regs(1).update <= jupdate and selectedreg;
	to_regs(0).shift <= jce1 and jshift;
	to_regs(1).shift <= jce2 and jshift;
	to_regs(0).capture <= jce1 and (not jshift) and (not jhold);
	to_regs(1).capture <= jce2 and (not jshift) and (not jhold);

end architecture;

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.debug_jtag_plumbing.all;

entity vjtag_register is
generic (
	bits : integer := 32
);
port (
	-- JTAG clock domain
	from_jtag : in debug_jtag_to_reg;
	to_jtag : out debug_jtag_from_reg;

	-- System clock domain
	clk : in std_logic;
	d : in std_logic_vector(bits-1 downto 0);
	q : out std_logic_vector(bits-1 downto 0);
	upd_sys : out std_logic
);
end entity;

architecture rtl of vjtag_register is
	signal shiftreg : std_logic_vector(bits-1 downto 0);
	signal shift_next : std_logic_vector(bits-1 downto 0);
	signal tck_inv : std_logic;
	signal toggle : std_logic := '0';
	signal toggle_s : std_logic_vector(2 downto 0) := (others => '0');
begin
	to_jtag.tdo <= shiftreg(0);

	shift_next<=from_jtag.tdi & shiftreg(bits-1 downto 1);

	process(from_jtag.tck) begin
		if falling_edge(from_jtag.tck) then
			if from_jtag.shift='1' then
				shiftreg<=shift_next;
			end if;

			if from_jtag.capture='1' then
				shiftreg<=d;
			end if;
		end if;
	end process;

	process(from_jtag.tck) begin
		if falling_edge(from_jtag.tck) then
			if from_jtag.update='1' then
				q<=shift_next;
				toggle <= not toggle;
			end if;
		end if;
	end	process;

	-- Move the update pulse into the system clock domain

	process(clk) begin
		if rising_edge(clk) then
			toggle_s <= toggle & toggle_s(toggle_s'high downto 1);
			upd_sys <= toggle_s(1) xor toggle_s(0);
		end if;
	end process;

end architecture;

