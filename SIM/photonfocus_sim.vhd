


library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity photonfocus_sim is
  port (
    RST            : in  std_logic;
    XCLK_CAMLINK_P : out std_logic;
    XCLK_CAMLINK_N : out std_logic;
    CAMLINK_DATA_P : out std_logic_vector(3 downto 0);
    CAMLINK_DATA_N : out std_logic_vector(3 downto 0);
    CAMLINK_TFG_P  : out  std_logic;
    CAMLINK_TFG_N  : out  std_logic;
    CAMLINK_TC_P   : in  std_logic;
    CAMLINK_TC_N   : in  std_logic
    );
end photonfocus_sim;

architecture Behavioral of photonfocus_sim is

  -----------------------------------------------------------------------------
  -- Constantes
  -----------------------------------------------------------------------------
  constant C_BITCLK : time := 1.785 ns;
  --constant C_PXCLK  : time := 12.495 ns;
  --
  constant C_BITS  : integer := 24;
  
  -----------------------------------------------------------------------------
  -- Componentes
  -----------------------------------------------------------------------------
  
    component test_pattern_generator is
    generic (
      G_BITS : integer := 5;
      G_PPC  : integer := 2
      );
    port (
      CLK    : in  std_logic;
      RST    : in  std_logic;
      HBLANK : out std_logic;
      VBLANK : out std_logic;
      AV     : out std_logic;
      HSYNC  : out std_logic;
      VSYNC  : out std_logic;
      DOUT   : out std_logic_vector(G_BITS-1 downto 0)
      );
  end component test_pattern_generator;

  -----------------------------------------------------------------------------
  -- Señales
  -----------------------------------------------------------------------------
  --
  signal clk_7x            : std_logic;
  signal clk_1x            : std_logic;
  signal r_sevenfour_clk_p : std_logic_vector(6 downto 0) := "1100011";
  signal r_sevenfour_clk_n : std_logic_vector(6 downto 0) := "0011100";
  --
  signal r_cnt_clk7        : unsigned(4 downto 0)         := (others => '0');
  signal r_camlink_data_p  : std_logic_vector(3 downto 0) := (others => '0');
  --
    
  signal HBLANK : std_logic;
  signal VBLANK : std_logic;
  signal AV     : std_logic;
  signal HSYNC  : std_logic;
  signal VSYNC  : std_logic;
  signal DOUT   : std_logic_vector(C_BITS-1 downto 0);
  --
  signal r_data_in_to_device      : std_logic_vector(27 downto 0);
  --
  signal r_red                  : std_logic_vector(7 downto 0)  := (others => '0');
  signal r_green                : std_logic_vector(7 downto 0)  := (others => '0');
  signal r_blue                 : std_logic_vector(7 downto 0)  := (others => '0');
  --
  signal r_cnt_px : unsigned(15 downto 0) := (others => '0'); 


  --


begin

  process
  begin
    clk_7x <= '0';
    wait for C_BITCLK/2;
    clk_7x <= '1';
    wait for C_BITCLK/2;
  end process;

  process
  begin
    clk_1x <= '0';
    wait for (C_BITCLK/2)*7;
    clk_1x <= '1';
    wait for (C_BITCLK/2)*7;
  end process;
  
  
  -----------------------------------------------------------------------------
  -- Instancia del TPG
  -----------------------------------------------------------------------------
  inst_test_pattern_generator : test_pattern_generator
    generic map (
      G_BITS => C_BITS,
      G_PPC  => 2
      )
    port map (
      CLK    => clk_1x,
      RST    => RST,
      HBLANK => HBLANK,
      VBLANK => VBLANK,
      AV     => AV,
      HSYNC  => HSYNC,
      VSYNC  => VSYNC,
      DOUT   => DOUT
      );
      
      
    -- El reloj diferencial del Cameralink Transmiter se usa para generar
  -- uno single ended que controla la generación del pulso 7/4 necesario
  -- para que el otro extremo de la comunicación sea capaz de decodificar
  -- los datos que desde aquí se envían.  
  
  process(clk_1x)
  begin
    if rising_edge(clk_1x) then
      if HBLANK = '1' then
        r_cnt_px <= (others => '0');
      else
        r_cnt_px <= r_cnt_px + 1;
      end if;
     end if;
   end process;

  process(clk_7x)
  begin
    if rising_edge(clk_7x) then
      if RST = '1' then
      --
       r_sevenfour_clk_p <= "1100011";
       --      
       r_cnt_clk7 <= to_unsigned(6, r_cnt_clk7'length); -- (others => '0');
       --
       generate_reset_data : for i in 0 to 3 loop
        r_camlink_data_p(i) <= '0';
       end loop;
      else
        r_sevenfour_clk_p <= r_sevenfour_clk_p(5 downto 0) & r_sevenfour_clk_p(6);
        r_cnt_clk7 <= r_cnt_clk7 - 1;
        generate_link_data : for i in 6 downto 0 loop
        if r_cnt_clk7 = i then
          r_camlink_data_p(0) <= r_data_in_to_device(i);
          r_camlink_data_p(1) <= r_data_in_to_device(i+7);
          r_camlink_data_p(2) <= r_data_in_to_device(i+7*2);
          r_camlink_data_p(3) <= r_data_in_to_device(i+7*3);
          if r_sevenfour_clk_p = "1100011" then
            r_cnt_clk7 <= to_unsigned(6, r_cnt_clk7'length);
          end if;
        end if;
        end loop;
      end if; -- RST
    end if; -- CLK
end process;

  r_sevenfour_clk_n <= not r_sevenfour_clk_p;

  r_red   <= DOUT(23 downto 16);
  r_green <= DOUT(15 downto 8);
  r_blue  <= DOUT(7 downto 0);
  
  r_data_in_to_device(27)  <=  '0';
  
  r_data_in_to_device(20)  <=  (not VBLANK) and (not HBLANK) ;
  r_data_in_to_device(19)  <=  not VBLANK;
  r_data_in_to_device(18)  <=  not HBLANK;
                                          
  r_data_in_to_device(26)  <=  r_blue(7)  ;
  r_data_in_to_device(25)  <=  r_blue(6)  ;
  r_data_in_to_device(17)  <=  r_blue(5)  ;
  r_data_in_to_device(16)  <=  r_blue(4)  ;
  r_data_in_to_device(15)  <=  r_blue(3)  ;
  r_data_in_to_device(14)  <=  r_blue(2)  ;
  r_data_in_to_device(13)  <=  r_blue(1)  ;
  r_data_in_to_device(12)  <=  r_blue(0)  ;
                                             
  r_data_in_to_device(24)  <=  r_green(7) ;
  r_data_in_to_device(23)  <=  r_green(6) ;
  r_data_in_to_device(11)  <=  r_green(5) ;
  r_data_in_to_device(10)  <=  r_green(4) ;
  r_data_in_to_device(9)   <=  r_green(3) ;
  r_data_in_to_device(8)   <=  r_green(2) ;
  r_data_in_to_device(7)   <=  r_green(1) ;
  r_data_in_to_device(6)   <=  r_green(0) ;
                                          
  r_data_in_to_device(22)  <=  r_red(7)   ;
  r_data_in_to_device(21)  <=  r_red(6)   ;
  r_data_in_to_device(5)   <=  r_red(5)   ;
  r_data_in_to_device(4)   <=  r_red(4)   ;
  r_data_in_to_device(3)   <=  r_red(3)   ;
  r_data_in_to_device(2)   <=  r_red(2)   ;
  r_data_in_to_device(1)   <=  r_red(1)   ;
  r_data_in_to_device(0)   <=  r_red(0)   ;

  




  
  XCLK_CAMLINK_P <= r_sevenfour_clk_p(1);
  XCLK_CAMLINK_N <= r_sevenfour_clk_n(1);

  CAMLINK_DATA_P(0) <= r_camlink_data_p(0);
  CAMLINK_DATA_P(1) <= r_camlink_data_p(1);
  CAMLINK_DATA_P(2) <= r_camlink_data_p(2);
  CAMLINK_DATA_P(3) <= r_camlink_data_p(3);

  CAMLINK_DATA_N <= not r_camlink_data_p;
  
  CAMLINK_TFG_P <= '1';
  CAMLINK_TFG_N <= '0';


  end Behavioral;



