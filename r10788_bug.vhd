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
-- not fully implemented yet
-- strobe output is 4bit for an input to 74hct138 on GottFA PCB
-- original chip has here 8bit output combined with 'DBS' signal (display bank select 8->16 strobes)
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
		  		  
		  --io_data : out  std_logic_vector( 3 downto 0); -- data from IO device 
		  
		  io_device    : in std_logic_vector( 3 downto 0); -- ID of current active IO device -> I2(7 downto 4)
		  io_cmd    : in std_logic_vector( 3 downto 0); --  command -> I2(3 downto 0)
		  io_accu    : in std_logic_vector( 3 downto 0); -- accu for input to IO device		  

		  group_A   : out  std_logic_vector( 3 downto 0); -- Digit data Group A
		  group_B   : out  std_logic_vector( 3 downto 0); -- Digit data Group B
		  strobes   : out  std_logic_vector( 3 downto 0) 
        );
end r10788;

architecture fsm of r10788 is

      --   FSM states
  type state_t is ( wait_cs, assign, wait_io_finish );
  signal state : state_t;

  signal count : integer range 0 to 25000 := 0;
  signal digit : integer range 0 to 15 := 0;
  signal reg_A_count : integer range 0 to 15 := 0;
  signal reg_B_count : integer range 0 to 15 := 0;

  -- internal buffer display regs
  type DISP_REG_TYPE is array (1 to 16) of std_logic_vector(3 downto 0);
  signal DISP_REG_A            : DISP_REG_TYPE;	
  signal DISP_REG_B            : DISP_REG_TYPE;		
	
begin  --  fsm 


  
  fsm_proc : process ( clk, reset)
  begin  --  process fsm_proc 

		if ( reset = '0') then  -- Asynchronous reset
			--   output and variable initialisation
			state <= wait_cs;
			for cnt_val in 1 to 16 loop
				DISP_REG_A(cnt_val) <= "0000";
				DISP_REG_B(cnt_val) <= "0000";
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
						when "1110" => --  load display register A 16 times each, need to count)
						   reg_A_count <= reg_A_count +1;
							DISP_REG_A(reg_A_count + 1) <= io_accu;
							if (reg_A_count = 15) then
								reg_A_count <= 0;
							end if;
							
						when "1101" => --  load display register B 16 times, need to count)
						   reg_B_count <= reg_B_count +1;
							DISP_REG_B(reg_B_count + 1) <= io_accu;
							if (reg_B_count = 15) then
								reg_B_count <= 0;
							end if;														
							
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
			if ( reset = '0') then  -- Asynchronous reset
				--   output and variable initialisation
				strobes <= "0000";
				group_A <= "0000";
				group_B <= "0000";	 
			elsif rising_edge(clk) then
				-- inc count for next round
				count <= count +1;
				if ( count >= 25000) then -- 50MHz input we have a clk each 20ns
					digit <= digit +1;     -- new refresh after 0,5ms, which is a count of 25.000
					strobes <= std_logic_vector( to_unsigned((digit +1),4));
					count <= 0;
					-- overflow?
					if ( digit = 15) then
						digit <= 0;
						strobes <= "0000";
					end if;	
				end if;
				
				case digit is 				
				when 0 to 5 => 					
					group_A <= DISP_REG_A(digit +3); -- player 1
					group_B <= DISP_REG_B(digit +3); -- player 3					
				when 6 =>
					group_A <= DISP_REG_A(1); -- status 0										
				when 7 =>
					group_A <= DISP_REG_A(2); -- status 1
				when 8 to 13 => 					
					group_A <= DISP_REG_A(digit +3); -- player 2
					group_B <= DISP_REG_B(digit +3); -- player 4					
				when 14 =>
					group_A <= DISP_REG_A(9); -- status 2
				when 15 =>
					group_A <= DISP_REG_A(10); -- status 3
					
				--when OTHERS =>
				end case;
			end if; --rising edge		
		end process;

end fsm;
		