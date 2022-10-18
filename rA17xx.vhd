--*****************************************************************************
--
--  Title   : Rockwell A17xx ROM RAM and IO chip
--
--  File    : rA17xx.vhd
--
--  Author  : bontango
--
--  a simplified design for implementing Rockwell 10788 chip
--
--
-- Notes
-- only IO section implemented
-- v02 io_data is set to full feedback (4bits)
-- v03 io_data adjusted
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rA17xx is
  port( 
		  clk     : in  std_logic;
        reset   : in  std_logic;		
        device_id    : in  std_logic_vector( 3 downto 0); -- chip select
		  w_io   : in  std_logic;
		  		  
		  io_data : out  std_logic_vector( 3 downto 0); -- data from IO device 
		  
		  io_device    : in std_logic_vector( 3 downto 0); -- ID of current active IO device -> I2(7 downto 4)
		  io_cmd    : in std_logic_vector( 3 downto 0); --  command -> I2(3 downto 0)
		  io_accu    : in std_logic_vector( 3 downto 0); -- accu for input to IO device
		  io_port    : in std_logic_vector( 3 downto 0); -- port of IO device (BL)

		  io_port_in   : in  std_logic_vector( 15 downto 0); 
		  io_port_out   : out  std_logic_vector( 15 downto 0) 		
        );
end rA17xx;

architecture fsm of rA17xx is
    --   FSM states
  type state_t is ( wait_cs, assign, wait_io_finish );
  signal state : state_t;

	signal io_port_out_enable : std_logic_vector( 15 downto 0);
	
begin  
  
  fsm_proc : process ( reset, clk)
  begin  
		
		if ( reset = '0') then -- Asynchronous reset
		   --   output and variable initialisation		
			io_port_out     <= ( others => '0');
			io_port_out_enable     <= ( others => '0');					
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
					-- four commands
					if (io_cmd(0)='0') and (io_accu(3)='1') then -- SES 1 - select enable status, enable all outputs
						io_data <= io_port_in( to_integer(unsigned(io_port))) & "111";
						--for cnt_val in 0 to 15 loop
							--io_port_out(cnt_val) <= io_port_out_enable(cnt_val);
						--end loop;
					elsif (io_cmd(0)='0') and (io_accu(3)='0') then -- SES 0 - select enable status, disable all outputs
						--for cnt_val in 0 to 15 loop
							--io_port_out(cnt_val) <= '0'; --RTH is this correct?
						--end loop;
						io_data <= io_port_in( to_integer(unsigned(io_port))) & "111";
					elsif (io_cmd(0)='1') and (io_accu(3)='1') then -- SOS 1 - select output status, port->1
						io_port_out_enable( to_integer(unsigned(io_port))) <= '1';
						io_port_out( to_integer(unsigned(io_port))) <= '1';						
						--io_data(3) <= io_port_in( to_integer(unsigned(io_port)));
						--io_data <= "1000"; 
						io_data <= io_accu;
					elsif (io_cmd(0)='1') and (io_accu(3)='0') then -- SOS 1 - select output status, port->0
						io_port_out_enable( to_integer(unsigned(io_port))) <= '0';
						io_port_out( to_integer(unsigned(io_port))) <= '0';									
						--io_data(3) <= io_port_in( to_integer(unsigned(io_port)));
						--io_data <= "0000"; 
						io_data <= io_accu;
					end if;
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
