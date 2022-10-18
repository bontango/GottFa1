-- detect switch
-- input strobe and return 
-- input is cpu clock
-- output
-- shortpush when switch is pushed >=100ms
-- longpush when switch is pushed >=1,8s
-- Gottlieb version
-- bontango 21.01.2021
-- 400KHz version for SYS1

Library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity detect_sw is 
   port(
	   clk     : in std_logic; -- clock is cpuclk 400KHz, 2,5uS cycle
		sw_strobe : in std_logic; -- strobe line of switch (active high)
		sw_return : in std_logic; -- return line of switch (active high)		
		short_push :out  std_logic;    -- will go high if switch is pushed >50ms
		long_push :out  std_logic;    -- will go high if switch is pushed >1500ms		
		rst 		: in  STD_LOGIC --reset_l or game running
   );
end detect_sw;
architecture Behavioral of detect_sw is  
		  type STATE_T is ( Idle, counting, delay); 
		signal state : STATE_T;        --State			
		signal is_closed : std_logic;
		signal check_counter : integer range 0 to 20000000 := 0;
		signal closed_counter : integer range 0 to 20000000 := 0;
begin 

 is_closed <= sw_strobe and sw_return;
 
 process(clk, rst)
		begin
			if rst = '0' then --Reset condidition (reset_l)
				 short_push <= '0';
				 long_push <= '0';
				 check_counter <= 0;
				 closed_counter <= 0;
				 state <= Idle;    
			elsif rising_edge(clk)then
				case state is
					when Idle =>
						if is_closed = '1' then 
							state <= counting;	-- start counting
						end if;
					----------------------------------	
					-- we count 2 seconds which is 800.000 cycles at 400KHz
					when counting => 						
							check_counter <= check_counter +1;
							if ( is_closed = '1') then 								
								closed_counter <= closed_counter +1;
							end if;		
							
							if (check_counter > 800000) then -- end checking phase
								if ( closed_counter > 80000) then
									long_push <= '1';
								else	
									long_push <= '0';
								end if;		
								
								if ( closed_counter > 8000) then
									short_push <= '1';
								else	
									short_push <= '0';
								end if;		
								
								-- new state			
								check_counter <= 0;
								closed_counter <= 0;
								state <= delay;
							end if;								  
					----------------------------------	
					when delay =>
						check_counter <= check_counter +1;												
						if (check_counter > 40000) then -- 100ms signals active							
							short_push <= '0';
							long_push <= '0';
							check_counter <= 0;
							closed_counter <= 0;
							state <= Idle;				
						end if;
				end case;
			end if;
		end process;
    end Behavioral;				
