	component clk_gen is
		port (
			clk_clk       : in  std_logic := 'X'; -- clk
			clk_100m_clk  : out std_logic;        -- clk
			reset_reset_n : in  std_logic := 'X'; -- reset_n
			clk_25m_clk   : out std_logic         -- clk
		);
	end component clk_gen;

	u0 : component clk_gen
		port map (
			clk_clk       => CONNECTED_TO_clk_clk,       --      clk.clk
			clk_100m_clk  => CONNECTED_TO_clk_100m_clk,  -- clk_100m.clk
			reset_reset_n => CONNECTED_TO_reset_reset_n, --    reset.reset_n
			clk_25m_clk   => CONNECTED_TO_clk_25m_clk    --  clk_25m.clk
		);

