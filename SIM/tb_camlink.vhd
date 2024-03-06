

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_camlink is
end tb_camlink;

architecture Behavioral of tb_camlink is

  constant XCLK_period_P : time := 7.142 ns;
  constant XCLK_period_N : time := 5.358 ns;
  

  component cameralink_interface is
--    generic (
--      G_CAMLINK_DATA_WIDTH  : integer;
--      G_CLK_SYSTEM_FREQ     : integer;
--      G_CLK_CAMERALINK_FREQ : integer);
    port (
      RST                  : in  std_logic;
      CAMLINK_XCLK_P       : in  std_logic;
      CAMLINK_XCLK_N       : in  std_logic;
      CAMLINK_X_P          : in  std_logic_vector(3 downto 0);
      CAMLINK_X_N          : in  std_logic_vector(3 downto 0);
      CAMLINK_CC_P         : out std_logic_vector(4 downto 1);
      CAMLINK_CC_N         : out std_logic_vector(4 downto 1);
      CAMLINK_TFG_P        : in  std_logic;
      CAMLINK_TFG_N        : in  std_logic;
      CAMLINK_TC_P         : out std_logic;
      CAMLINK_TC_N         : out std_logic;
            --
      AV                   : out std_logic;
      HBLANK               : out std_logic;
      VBLANK               : out std_logic;
      DATA_OUT             : out std_logic_vector(15 downto 0);
      CLK_OUT              : out std_logic;  -- synced with data
      -- CLK_1080P            : out std_logic;
      --
      UART_TX              : in  std_logic;  -- Processor controlled uart
      UART_RX              : out std_logic
      );
  end component cameralink_interface;

  component photonfocus_sim is
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
  end component photonfocus_sim;


  signal ready                : std_logic;
  signal RST                  : std_logic := '1';
  signal RST_pf               : std_logic := '1';
  signal CAMLINK_XCLK_P       : std_logic;
  signal CAMLINK_XCLK_N       : std_logic;
  signal CAMLINK_X_P          : std_logic_vector(3 downto 0);
  signal CAMLINK_X_N          : std_logic_vector(3 downto 0);
  signal CAMLINK_CC_P         : std_logic_vector(4 downto 1);
  signal CAMLINK_CC_N         : std_logic_vector(4 downto 1);
  signal CAMLINK_TFG_P        : std_logic;
  signal CAMLINK_TFG_N        : std_logic;
  signal CAMLINK_TC_P         : std_logic;
  signal CAMLINK_TC_N         : std_logic;
  signal LED                  : std_logic_vector(3 downto 0);
  signal FMC_HPC0_CAMLINK_LED : std_logic_vector(3 downto 0);
  signal USER_SI570_P         : std_logic;
  signal USER_SI570_N         : std_logic;
  --
  signal AV         : std_logic;
  signal HBLANK         : std_logic;
  signal VBLANK         : std_logic;
  signal CLK_OUT         : std_logic;

  
  signal xclk_p : std_logic;
  signal xclk_n : std_logic;


begin

  inst_photonfocus_simulator : photonfocus_sim
    port map (
      RST            => RST_pf,
      CAMLINK_DATA_N => CAMLINK_X_N,
      CAMLINK_DATA_P => CAMLINK_X_P,
      XCLK_CAMLINK_N => CAMLINK_XCLK_N,
      XCLK_CAMLINK_P => CAMLINK_XCLK_P,
      CAMLINK_TFG_P  => CAMLINK_TFG_P,
      CAMLINK_TFG_N  => CAMLINK_TFG_N,
      CAMLINK_TC_P   => CAMLINK_TC_P,
      CAMLINK_TC_N   => CAMLINK_TC_N
      );


  UUT_CAMERALINK_INTERFACE : cameralink_interface
--    generic map (
--      G_CAMLINK_DATA_WIDTH  => 24,
--      G_CLK_SYSTEM_FREQ     => 100000000,
--      G_CLK_CAMERALINK_FREQ => 80000000)
    port map (
      RST                  => RST,
      CAMLINK_XCLK_P       => CAMLINK_XCLK_P,
      CAMLINK_XCLK_N       => CAMLINK_XCLK_N,
      CAMLINK_X_P          => CAMLINK_X_P,
      CAMLINK_X_N          => CAMLINK_X_N,
      CAMLINK_CC_P         => CAMLINK_CC_P,
      CAMLINK_CC_N         => CAMLINK_CC_N,
      CAMLINK_TFG_P        => CAMLINK_TFG_P,
      CAMLINK_TFG_N        => CAMLINK_TFG_N,
      CAMLINK_TC_P         => CAMLINK_TC_P,
      CAMLINK_TC_N         => CAMLINK_TC_N,
      --
      AV                   => AV,
      HBLANK               => HBLANK,
      VBLANK               => VBLANK,
      DATA_OUT             => open,
      CLK_OUT              => CLK_OUT,  -- synced with data
      -- CLK_1080P            : out std_logic;
      --
      UART_TX              => '1',  -- Processor controlled uart
      UART_RX              => open
      );



  
  TB_PROC : process
  begin
    wait for 100 ns;
    RST <= '1';
    RST_pf <= '1';
    wait for 4.5 ns;
    RST <= '0';
    RST_pf <= '0';
    wait until ready = '1';
   -- assert false report "READY" severity note;
    wait for 500 ns;
    wait;
  end process;
  
  Photonfocus_RST :process
  begin
   wait for 1.5 ns;
   ready <= '1';
   wait;
  end process;


end Behavioral;




