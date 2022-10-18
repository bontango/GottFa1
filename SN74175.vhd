---------------------------------------------------------------
-- SN74 175 four Flip-Flops with double rail outputs
---------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

	entity sn74175 is
		port(        
					 Clock : in std_logic;	      -- system clock
					 clk : in std_logic;	      -- rising edge
					 clear  : in std_logic;                
					 D		  : in std_logic_vector (3 downto 0);
					 Q		  : out std_logic_vector (3 downto 0);
					 Qn	  : out std_logic_vector (3 downto 0)
            );
    end sn74175;

architecture Behavioral of sn74175 is
	 signal reg1 :std_logic;
    signal reg2 :std_logic;
    begin
	 process ( Clock, clear)
		begin
		if (clear = '0') then
			Q <= "0000";
			Qn <= "1111";
		elsif rising_edge(Clock) then
			reg1  <= clk;
         reg2  <= reg1;
			if (reg1 and (not reg2)) = '1' then
				Q <= D;
				Qn <= not D;
			end if;	
		end if;
	end process;		
 end Behavioral;				
		