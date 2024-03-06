----------------------------------------------------------------------------------
-- Company: DTICH
-- Engineer: Daniel Jim�nez Mazure
-- *********************************************************************
-- Author		  : $Autor: dasjimaz@gmail.com $
-- Date           : $Date: 2018-07-21 04:54:27 +0200 (sá., 21 jul. 2018) $
-- Revision       : $Revision: 109 $
-- *********************************************************************
-- Additional Comments:
-- Se implementa un generador de patrones de resoluci�n 640x480
-- 14/07/2018 --> Hay que asegurarse de que durante los peridos de blanking es
-- necesario dar HSYNCS o no.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


entity test_pattern_generator is
  generic(
    G_PATTERN_TYPE : integer := 0;
    G_BITS         : integer := 48;
    G_PPC          : integer := 2;      -- Pixels per clock
    G_HVALID       : integer := 1920;
    G_VVALID       : integer := 1080;
    G_HBLANK       : integer := 280;
    G_VBLANK       : integer := 45;
    G_HSYNC_START  : integer := 2008;
    G_HSYNC_END    : integer := 2052;
    G_VSYNC_START  : integer := 1083;
    G_VSYNC_END    : integer := 1088
    );
  port(
    CLK    : in  std_logic;
    RST    : in  std_logic;
    HBLANK : out std_logic;
    VBLANK : out std_logic;
    AV     : out std_logic;
    HSYNC  : out std_logic;
    VSYNC  : out std_logic;
    DOUT   : out std_logic_vector(G_BITS-1 downto 0)
    );
end test_pattern_generator;

-------------------------------------------------------------------------------
-- Arch
-------------------------------------------------------------------------------

architecture rtl of test_pattern_generator is


  -----------------------------------------------------------------------------
  -- Constantes
  -----------------------------------------------------------------------------
  --constant C_HVALID : unsigned(10 downto 0) := 640;
  --constant C_VVALID : unsigned(10 downto 0) := 480;
  --constant C_HBLANK : unsigned(10 downto 0) := 160;
  --constant C_VBLANK : unsigned(10 downto 0) := 120;

  constant C_HVALID : integer := G_HVALID;
  constant C_VVALID : integer := G_VVALID;
  constant C_HBLANK : integer := G_HBLANK;
  constant C_VBLANK : integer := G_VBLANK;

  constant C_HSYNC_START : integer := G_HSYNC_START;
  constant C_HSYNC_END   : integer := G_HSYNC_END;
  constant C_VSYNC_START : integer := G_VSYNC_START;
  constant C_VSYNC_END   : integer := G_VSYNC_END;

  -----------------------------------------------------------------------------
  -- types
  -----------------------------------------------------------------------------
  type type_fsm is (IDLE, ACTIVE_VIDEO);

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  signal r_hcnt  : unsigned(12 downto 0)       := (others => '0');
  signal r_vcnt  : unsigned(12 downto 0)       := (others => '0');
  --
  signal r_hsync : std_logic                   := '0';
  signal r_vsync : std_logic                   := '0';
  --
  signal r_fv    : std_logic                   := '0';
  signal r_lv    : std_logic                   := '0';
  --
  signal r_dout  : unsigned(G_BITS-1 downto 0) := (others => '0');

begin  -- architecture rtl



  BLANK_GEN : process(CLK)
  begin
    if rising_edge(CLK) then
      if RST = '1' then
        r_hcnt <= (others => '0');
        r_vcnt <= (others => '0');
        --
        r_fv   <= '0';
        r_lv   <= '0';
      else
        r_hcnt <= r_hcnt + G_PPC;
        if r_hcnt < C_HVALID - G_PPC then
          r_lv <= '1';
        elsif r_hcnt < (C_HVALID + C_HBLANK -1) then
          r_lv <= '0';
        else
          r_hcnt <= (others => '0');
          r_lv   <= '1';
          r_vcnt <= r_vcnt + 1;
          --
          if r_vcnt < C_VVALID-1 then
            r_fv <= '1';
          elsif r_vcnt < (C_VVALID + C_VBLANK - 1) then
            r_fv <= '0';
          else
            r_fv   <= '1';
            r_vcnt <= (others => '0');
          end if;
        end if;
      end if;
    end if;
  end process;

  SYNC_GEN : process(CLK)
  begin
    if rising_edge(CLK) then
      if RST = '1' then
        r_hsync <= '0';
        r_vsync <= '0';
      else
        r_hsync <= '0';
        r_vsync <= '0';
        --
        if (r_hcnt > C_HSYNC_START) and (r_hcnt < C_HSYNC_END) then
          r_hsync <= '1';
        end if;
        if (r_vcnt > C_VSYNC_START) and (r_vcnt < C_VSYNC_END) then
          r_vsync <= '1';
        end if;
      end if;
    end if;
  end process;

  GEN_PATTERN_TYPE_0 : if G_PATTERN_TYPE = 0 generate
    PIXEL_GEN : process(CLK)
    begin
      if rising_edge(CLK) then
        if RST = '1' then
          r_dout <= (others => '0');
        else
          r_dout(23 downto 16) <= x"22";
          r_dout(15 downto 8) <= x"44";
          r_dout(7 downto 0) <= x"88";
          if r_hcnt > (C_HVALID/2 -1) and r_hcnt < C_HVALID then
            r_dout(23 downto 16) <= x"33";
            r_dout(15 downto 8) <= x"55";
            r_dout(7 downto 0) <= x"77";
          end if;
        end if;
      end if;
    end process;
  end generate GEN_PATTERN_TYPE_0;

  GEN_PATTERN_TYPE_1 : if G_PATTERN_TYPE = 1 generate
    PIXEL_GEN : process(CLK)
    begin
      if rising_edge(CLK) then
        if RST = '1' then
          r_dout <= (others => '0');
        else
          r_dout <= (others => '1');
          if r_hcnt > (C_HVALID/2 -1) and r_hcnt < C_HVALID then
            r_dout <= (others => '0');
          end if;
        end if;
      end if;
    end process;
  end generate GEN_PATTERN_TYPE_1;

  VBLANK <= not r_fv;
  HBLANK <= not r_lv;
  AV     <= r_lv and r_fv;

  HSYNC <= r_hsync;
  VSYNC <= r_vsync;

  DOUT <= std_logic_vector(r_dout);


end architecture rtl;
