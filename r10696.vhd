--*****************************************************************************
--
--  Title   : Rockwell r10696 General Purpose INPUT/OUTPUT GP I/O Device
--
--  File    : r10696.vhd
--
--  Author  : bontango
--
--  a simplified design for implementing Rockwell 10696 chip
--
--
--REGISTER DESCRIPTION

--    HEX    Address   Select     Names
--    -------------------------------------------------------
--    A      x x x x   1 0 1 0    Read Group A
--    9      x x x x   1 0 0 1    Read Group B
--    3      x x x x   0 0 1 1    Read Group C
--    0      x x x x   0 0 0 0    Read Groups A | B | C
--    1      x x x x   0 0 0 1    Read Groups B | C
--    2      x x x x   0 0 1 0    Read Groups A | C
--    8      x x x x   1 0 0 0    Read Groups A | B

--    E      x x x x   1 1 1 0    Set Group A
--    D      x x x x   1 1 0 1    Set Group B
--    7      x x x x   0 1 1 1    Set Group C
--    4      x x x x   0 1 0 0    Set Groups A, B and C
--    5      x x x x   0 1 0 1    Set Groups B and C
--    6      x x x x   0 1 1 0    Set Groups A and C
--    C      x x x x   1 1 0 0    Set Groups A and B
--

-- Notes
-- only IO section implemented
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity r10696 is
  port( 
		  clk     : in  std_logic;
        reset   : in  std_logic;		
        device_id    : in  std_logic_vector( 3 downto 0); -- chip select
		  w_io   : in  std_logic;
		  		  
		  io_data : out  std_logic_vector( 3 downto 0); -- data from IO device 
		  
		  io_device    : in std_logic_vector( 3 downto 0); -- ID of current active IO device -> I2(7 downto 4)
		  io_cmd    : in std_logic_vector( 3 downto 0); --  command -> I2(3 downto 0)
		  io_accu    : in std_logic_vector( 3 downto 0); -- accu for input to IO device		  

		  group_A_in   : in  std_logic_vector( 3 downto 0); 
		  group_B_in   : in  std_logic_vector( 3 downto 0); 
		  group_C_in   : in  std_logic_vector( 3 downto 0); 
		
		  group_A_out   : out  std_logic_vector( 3 downto 0); 
		  group_B_out   : out  std_logic_vector( 3 downto 0); 
		  group_C_out   : out  std_logic_vector( 3 downto 0)
        );
end r10696;

architecture fsm of r10696 is

    --   FSM states
  type state_t is ( wait_cs, assign, wait_io_finish );
  signal state : state_t;
  		
begin  
  
  fsm_proc : process ( reset, clk)
  begin  

		if ( reset = '0') then -- Asynchronous reset
		   --   output and variable initialisation			
			group_A_out     <= ( others => '0');
			group_B_out     <= ( others => '0');
			group_C_out     <= ( others => '0');
			state <= wait_cs;
		elsif rising_edge( clk) then  -- Synchronous FSM
		   	 case state is
			    ---- State 1 wait for chip select ---
				 when wait_cs =>
				 if (device_id = io_device) and ( w_io = '1' ) then
					state <= assign;
				 end if;	
				 
				 ---- State 2 assign values to out and read in (depends on cmd)
				 when assign =>
					-- possible commands
					case to_integer(unsigned(io_cmd)) is
						when 16#0A# => -- Read Group A
							io_data <= not group_A_in;
						when 16#09# => -- Read Group B
							io_data <= not group_B_in;
						when 16#03# => -- Read Group C
							io_data <= not group_C_in;
						when 16#00# => -- // Read Groups A | B | C
							io_data <= not ( group_A_in or group_B_in or group_C_in);
						when 16#01# => -- // Read Groups B | C
							io_data <= not ( group_B_in or group_C_in);
						when 16#02# => -- // Read Groups A | C
							io_data <= not ( group_A_in or group_C_in);
						when 16#08# => -- // Read Groups A | B
							io_data <= not ( group_A_in or group_B_in);
						when 16#0E# => --  Set Group A
							group_A_out <= not io_accu;
						when 16#0D# => -- Set Group B
							group_B_out <= not io_accu;
						when 16#07# => -- Set Group C
							group_C_out <= not io_accu;
						when 16#04# => -- Set Groups A, B and C
							group_A_out <= not io_accu;
							group_B_out <= not io_accu;
							group_C_out <= not io_accu;
						when 16#05# => -- Set Groups B and C
							group_B_out <= not io_accu;
							group_C_out <= not io_accu;
						when 16#06# => -- et Groups A and C
							group_A_out <= not io_accu;
							group_C_out <= not io_accu;
						when 16#0C# => -- Set Groups A and B
							group_A_out <= not io_accu;
							group_B_out <= not io_accu;
						when others =>
							-- nop
					end case; -- cmd
					state <= wait_io_finish;
					
				 when wait_io_finish =>
				 ---- State 3 wait for current iio cycle to be finished
				 if ( w_io = '0' ) then 
					state <= wait_cs;
				 end if;	
			end case;  --  state
		end if; -- rising_edge(clk)
  end process fsm_proc;
end fsm;
