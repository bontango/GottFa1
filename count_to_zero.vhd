---------------------------------------------------------------
-- count clocks, set output to high if count is zero
---------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

	entity count_to_zero is
		port(        
					 Clock : in std_logic;	      -- system clock
					 count :  std_logic_vector(7 downto 0);
					 d_in  : in std_logic;	      -- rising edge
					 d_out : out std_logic;		  -- output indicator
					 clear  : in std_logic
            );
    end count_to_zero;

  architecture Behavioral of count_to_zero is
	signal reg1 :std_logic;
   signal reg2 :std_logic;
	signal int_count :  std_logic_vector(7 downto 0);
    
	begin
	 process ( Clock, count, clear )
		begin
		if (clear = '0') then
			int_count <= count;
			d_out <= '0';
		elsif rising_edge(Clock) then
			reg1  <= d_in;
			reg2  <= reg1;
			if (reg1 and (not reg2)) = '1' then
				if ( int_count > 0) then
					int_count <= int_count - 1;
					d_out <= '0';
				else 
					d_out <= '1';	 
				end if;
			end if;	
		end if;
	end process;
  end Behavioral;				
		