---------------------------------------------------------------
-- ds decoder for GottFA1
-- SYS1_74154 in fact a 74154 with 10 outputs 0..9
-- in order to spare a 138er decoder
-- bontango January 2022
---------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

	entity SYS1_74154 is
		port(                			
				 ds_in		  : in std_logic_vector (3 downto 0);
				
				 ds0		  : out std_logic;				
				 ds_out		  : out std_logic_vector (3 downto 0); -- ds_in 74138 -> ds1 .. ds8				 
				 ds9		  : out std_logic
            );
    end SYS1_74154;


  architecture Behavioral of SYS1_74154 is
    begin
		process (ds_in)
			begin
			-- active low!
		    case ds_in is 
				 when "0000" =>
					ds0  <= '1';    -- "0" -- we need DS0/ and have an inverter
					ds_out <= "1111"; -- deactivate 74138 ds(3) == 1
					ds9  <= '1';
				 when "0001" =>
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "0000"; -- "1"
					ds9  <= '1';				 
				 when "0010" =>
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "0001"; -- "2"
					ds9  <= '1';				 
				 when "0011" =>
					ds0  <= '0'; -- we need DS0/ and have an inverterds0  <= '1';
					ds_out <= "0010"; -- "3"
					ds9  <= '1';				 
				 when "0100" =>
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "0011"; -- "4"
					ds9  <= '1';				 
				 when "0101" =>
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "0100"; -- "5"
					ds9  <= '1';				 
				 when "0110" =>
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "0101"; -- "6"
					ds9  <= '1';				 
				 when "0111" =>
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "0110"; -- "7"
					ds9  <= '1';				 
				 when "1000" =>
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "0111"; -- "8"
					ds9  <= '1';				 
				 when "1001" =>			
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "1111"; -- deactivate 74138 ds(3) == 1
					ds9  <= '0';	-- "9"
				 when others =>
					ds0  <= '0'; -- we need DS0/ and have an inverter
					ds_out <= "1111"; -- deactivate 74138 ds(3) == 1
					ds9  <= '1';
			end case;	 
		end process;
   end Behavioral;					