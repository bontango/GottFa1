---------------------------------------------------------------
-- SN7448 7 segment decoder
-- sapecial Gottlieb version
-- including 'h segment'
---------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

	entity sn7448_wh is
		port(                			
				 Din		  : in std_logic_vector (3 downto 0);
				 Dout		  : out std_logic_vector (1 to 8)
            );
    end sn7448_wh;


  architecture Behavioral of sn7448_wh is
    begin
		process (Din)
			begin
		    case Din is 
				 when "0000"=>Dout<="11111100"; 
				 --when "0001"=>Dout<="0110000"; 
				 when "0001"=>Dout<="00000001"; -- only '1' on Gottlieb display show 'h' segment
				 when "0010"=>Dout<="11011010"; 
				 when "0011"=>Dout<="11110010"; 
				 when "0100"=>Dout<="01100110"; 
				 when "0101"=>Dout<="10110110"; 
				 when "0110"=>Dout<="00111110"; 
				 when "0111"=>Dout<="11100000"; 
				 when "1000"=>Dout<="11111110"; 
				 when "1001"=>Dout<="11100110"; 
				 when "1010"=>Dout<="00011010"; 
				 when "1011"=>Dout<="00110010"; 
				 when "1100"=>Dout<="01000110"; 
				 when "1101"=>Dout<="10010110"; 
				 when "1110"=>Dout<="00011110"; 
				 when "1111"=>Dout<="00000000"; 
				 when others=>Dout<="00000000"; 
			end case;	 
		end process;
   end Behavioral;					