-- detect switch trigger
-- delay will be start again when retriggered
-- Gottlieb SYS1 version
-- bontango 04.02.2022

Library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity detect_sw_trigger is 
   port(
	   clk     : in std_logic; -- clock is cpuclk 400KHz, 2,5uS cycle
		sw_strobe : in std_logic; -- strobe line of switch (active high)
		sw_return : in std_logic; -- return line of switch (active high)
		trigger :out  std_logic;    -- trigger output, will change with each trigger detected		
		rst 		: in  STD_LOGIC --reset_l or game running
   );
end detect_sw_trigger;
architecture Behavioral of detect_sw_trigger is  
		  type STATE_T is ( Idle, wait_open, counting); 
		signal state : STATE_T;        --State			
		signal is_closed : std_logic;
		signal counter : integer range 0 to 50000000 := 0;		
		signal old_trigger : std_logic :='0';
begin 

 is_closed <= sw_strobe and sw_return;
 
 process(clk, rst)
		begin
			if rst = '0' then --Reset condidition (reset_l)
				 trigger <= '0';				 				 
				 old_trigger <= '0';				 				 
				 counter <= 0;
				 state <= Idle;    
			elsif rising_edge(clk)then
				case state is
					when Idle =>
						if is_closed = '1' then 
							state <= wait_open;	-- start counting
						end if;
					----------------------------------	
					when wait_open => 						
						if is_closed = '0' then 
							state <= counting;	-- start counting
						end if;
					
					----------------------------------	
					-- we count 5 seconds which is 2.500.000 cycles at 400KHz
					when counting => 						
							counter <= counter +1;
							if ( is_closed = '1') then 			-- retriggerd!			
								counter <= 0;
								state <= wait_open;										
							end if;		
							
							if (counter > 2500000) then -- end waiting, do trigger
								-- new state			
								counter <= 0;
								trigger <= not old_trigger;
								old_trigger <= not old_trigger;
								state <= Idle;
							end if;								  
				end case;
			end if;
		end process;
    end Behavioral;				
