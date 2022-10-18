--*****************************************************************************
--
--  Title   : Rockwell 10788 Keyboard and Display controller
--
--  File    : r10788.vhd
--
--  Author  : bontango
--
--  a simplified design for implementing Rockwell 10788 chip
--
--
-- Notes
-- display functions implemented only, no keyboard
-- strobe output is 4bit for an input to 74hct138 on GottFA PCB
-- original chip has here 8bit output combined with 'DBS' signal (display bank select 8->16 strobes)
--
-- v0.2
-- v0.3 digits reorder
-- v0.4 adapted to negated IO
-- v0.5 blank display (KAF & KBF ) and KDN (turn on display) implemented to prevent ghosting
-- v0.6 more ghosting prevention
-- v0.7 disabled KAF, KBF and KDN again (displays flickering during count)
-- v0.8 added switch for selection of 'gap'
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity r10788 is
  port( 
		  clk     : in  std_logic;
        reset   : in  std_logic;		
        device_id    : in  std_logic_vector( 3 downto 0); -- chip select
		  w_io   : in  std_logic;
		  		  		  		  
		  io_device    : in std_logic_vector( 3 downto 0); -- ID of current active IO device -> I2(7 downto 4)
		  io_cmd    : in std_logic_vector( 3 downto 0); --  command -> I2(3 downto 0)
		  io_accu    : in std_logic_vector( 3 downto 0); -- accu for input to IO device		  

		  group_A   : out  std_logic_vector( 3 downto 0); -- Digit data Group A
		  group_B   : out  std_logic_vector( 3 downto 0); -- Digit data Group B
		  strobes   : out  std_logic_vector( 3 downto 0);
		  
		  is_tube   : in  std_logic -- switch if we have tube displays or LEDs
        );
end r10788;

architecture fsm of r10788 is

      --   FSM states
  type state_t is ( wait_cs, assign, wait_io_finish );
  signal state : state_t;

  signal count : integer range 0 to 26000 := 0;
  signal digit : integer range 0 to 15 := 0;
  --signal display_status	: 	std_logic:= '0';
  signal blanking	: 	std_logic:= '0';
  signal reg_A_count : integer range 0 to 16 := 16; -- numbered 16 ... 1
  signal reg_B_count : integer range 0 to 16 := 16; -- we will receive reg 16 first!
  signal gap : integer range 0 to 300;

  -- internal buffer display regs
  type DISP_REG_TYPE is array (1 to 16) of std_logic_vector(3 downto 0);
  signal DISP_REG_A            : DISP_REG_TYPE;	
  signal DISP_REG_B            : DISP_REG_TYPE;		
	
begin  --  fsm 
  
  fsm_proc : process ( clk, reset)
  begin  --  process fsm_proc 

		if ( is_tube = '1') then 
			gap <= 300; -- tube (original display setting)
						--gap <= 200; -- tube (original display setting)
		else	
			gap <= 50;  --LED setting because of flickering with bigger gap
		end if;
		
		if ( reset = '0') then  -- Asynchronous reset
			--   output and variable initialisation
			state <= wait_cs;
			for cnt_val in 1 to 16 loop
				DISP_REG_A(cnt_val) <= "1111";
				DISP_REG_B(cnt_val) <= "1111";
				reg_A_count <= 16;
				reg_B_count <= 16;
			end loop;
		elsif rising_edge( clk) then  -- Synchronous FSM

		-- not fully implemented yet
		
		   	 case state is
			    ---- State 1 wait for chip select ---
				 when wait_cs =>
				 if (device_id = io_device) and ( w_io = '1' ) then
					state <= assign;
				 end if;	
				 
				 ---- State 2 assign values to out depends on cmd)
				 when assign =>
					-- possible commands
					case io_cmd is
						when "1110" => --  0xE load display register A 16 times each, need to count)						   
							DISP_REG_A(reg_A_count) <= not io_accu;
							if (reg_A_count = 1) then
								reg_A_count <= 16;
							else
								reg_A_count <= reg_A_count - 1;
							end if;
							
						when "1101" => --  0xD load display register B 16 times, need to count)
							DISP_REG_B(reg_B_count) <= not io_accu;
							if (reg_B_count = 1) then
								reg_B_count <= 16;
							else
								reg_B_count <= reg_B_count - 1;	
							end if;														
							
						--when "1011" => --  0xB Blank the displays of DA1,DA2,DA3,DA4,DB1,DB2
						--	display_status <= '0'; --RTH: we blank the complete display (0xB comes alway together with 0x7)
						
						--when "0111" => --  0x7 Blank the displays DB3,DB4
						--	display_status <= '0'; --RTH: we blank the complete display (0xB comes alway together with 0x7)
					
						--when "0011" => --  0x3 turn on display
						--	display_status <= '1';
							
						when others =>
							-- nop

							end case; -- cmd
					state <= wait_io_finish;
					
				 when wait_io_finish =>
				 ---- State 3 wait for current io cycle to be finished
				 if ( w_io = '0' ) then 
					state <= wait_cs;
				 end if;	
			end case;  --  state
		end if; -- rising_edge(clk)
  end process fsm_proc;
  
  -- structure of System1 display
  -- Reg A
  -- 1 & 2 : 'ball in play'
  -- 3 ... 8: player 1
  -- 9 & 10 : 'credits'
  -- 11 ... 16: player 2
  -- Reg B
  -- 3 ... 8: player 3
  -- 11 ... 16: player 4
  
  refresh: process (clk, reset)
    begin
			if ( reset = '0') then
			-- if ( reset = '0') or ( display_status = '0') then  -- Asynchronous reset or display off
				--   output and variable initialisation
				strobes <= "0000";
				group_A <= "1111"; -- display blank
				group_B <= "1111";	 
				count <= 0;
				digit <= 0;
			elsif rising_edge(clk) then
				-- inc count for next round
				-- 50MHz input we have a clk each 20ns
				-- new refresh after 0,5ms, which is a count of 25.000
				count <= count +1;
				--ghosting prevention, we switch off displays before switching to next digit
				if ( count = 25000 - gap) then 					     
					blanking <= '1';
				end if;
				--
				if ( count = 25000) then 					     
					strobes <= std_logic_vector( to_unsigned((digit +1),4));					
					-- overflow?
					if ( digit = 15) then
						digit <= 0;
						strobes <= "0000";
					else
						digit <= digit +1;
					end if;	
				end if;	
				--	
				if ( count = 25000 + gap) then 					     
					blanking <= '0';
					count <= 0;					
				end if;	
								
				if ( blanking = '1') then
					group_A <= "1111"; -- display blank
					group_B <= "1111";	 								
				else
					case digit is 		
					when 0 to 5 => 					
						group_A <= DISP_REG_A( 8 - digit); -- player 1 ( regs 3 ...8 reverse order )
						group_B <= DISP_REG_B( 8 - digit); -- player 3
					when 6 =>
						group_A <= DISP_REG_A(2); -- status 0										
					when 7 =>
						group_A <= DISP_REG_A(1); -- status 1
					when 8 to 13 => 					
						group_A <= DISP_REG_A( 24 - digit ); -- player 2 ( regs 11 ...16 reverse order )				
						group_B <= DISP_REG_B( 24 - digit ); -- player 4	
					when 14 =>
						group_A <= DISP_REG_A(10); -- status 2
					when 15 =>
						group_A <= DISP_REG_A(9); -- status 3					
					--when OTHERS =>
					end case;
				end if;	
			end if; --rising edge		
		end process;

end fsm;
		