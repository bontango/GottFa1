-- boot message on Gottlieb Display
-- alphanumeric version
-- part of  GottFA1
-- bontango 05.2021
--
-- v 1.0
-- 200KHz input clock

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

    entity boot_message is        
        port(
            clk  : in std_logic;             
				reset   : in  std_logic;		
				-- input (display data)
			   display1			: in  string (1 to 6);
				display2			: in  string (1 to 6);
				display3			: in  string (1 to 6);
				display4			: in  string (1 to 6);
				status_d			: in  string (1 to 4);		
				--output (display control)
			  group_A   : out  std_logic_vector( 1 to 8); -- Digit data Group A
			  group_B   : out  std_logic_vector( 1 to 8); -- Digit data Group B
			  strobes   : out  std_logic_vector( 3 downto 0) 				
            );
    end boot_message;
    ---------------------------------------------------
    architecture Behavioral of boot_message is
		signal count : integer range 0 to 50001 := 0;
		signal digit : integer range 0 to 15 := 0;
		type RomGottFA1 is array (32 to 90) of std_logic_vector (7 downto 0);
			constant GTB_Char : RomGottFA1 := ( 
				"00000000",--SPACE32
				"00000001",--!33
				"01000100",--"34
				"01101110",--#35
				"10110110",--$36
				"01101110",--%37
				"11110110",--&38
				"01000000",--39
				"10011100",--(40
				"11110000",--)41
				"00000011",--*42
				"00000011",--+43
				"00100000",--,44
				"00000010",---45
				"00010000",--_46
				"00000001",--47
				"11111100",--048
				"00000001",--149
				"11011010",--250
				"11110010",--351
				"01100110",--452
				"10110110",--553
				"10111110",--654
				"11100000",--755
				"11111110",--856
				"11110110",--957
				"01100000",--:58
				"00110000",--;59
				"00011010",--<60
				"00010010",--=61
				"00110010",-->62
				"11011010",--?63
				"11011110",--@64
				"11101110",--A65
				"00111110",--B66
				"10011100",--C67
				"01111010",--D68
				"10011110",--E69
				"10001110",--F70
				"11100110",--G71
				"01101110",--H72
				"00000001",--I73
				"01111000",--J74
				"00001111",--K75
				"00011100",--L76
				"11101101",--M77
				"00101010",--N78
				"11111100",--O79
				"11001110",--P80
				"11111100",--Q81
				"00001010",--R82
				"10110110",--S83
				"10000001",--T84
				"01111100",--U85
				"00111000",--V86
				"01111101",--W87
				"00000011",--X88
				"01000111",--Y89
				"11011010" --Z90
			);		  
		  
begin	
  boot_message: process (clk, reset)
    begin
			if ( reset = '0') then  -- Asynchronous reset
				--   output and variable initialisation
				strobes <= "0000";
				group_A <= "00000000";
				group_B <= "00000000";	 
				count <= 0;
				digit <= 0;

			elsif rising_edge(clk) then
				-- inc count for next round
				-- 50MHz input we have a clk each 20ns
				-- new refresh after 1ms, which is a count of 50.000
				count <= count +1;
				if ( count = 50000) then 					     
					strobes <= std_logic_vector( to_unsigned((digit +1),4));
					count <= 0;
					-- overflow?
					if ( digit = 15) then
						digit <= 0;
						strobes <= "0000";
					else
						digit <= digit +1;
					end if;	
				end if;
				
				case digit is 		
				when 0 to 5 => 										
					group_A <= GTB_Char( character'pos(display1( 6 - digit)) ); -- player 1 ( digits 6 ...1 reverse order )
					group_B <= GTB_Char( character'pos(display3( 6 - digit)) ); -- player 3
				when 6 =>
					group_A <= GTB_Char( character'pos(status_d(1))); -- status 0										
				when 7 =>
					group_A <= GTB_Char( character'pos(status_d(2))); -- status 1
				when 8 to 13 => 					
					group_A <= GTB_Char( character'pos(display2( 14 - digit )) ); -- player 2 ( digits 6 ...1 reverse order )
					group_B <= GTB_Char( character'pos(display4( 14 - digit )) ); -- player 4	
				when 14 =>
					group_A <= GTB_Char( character'pos(status_d(3))); -- status 2
				when 15 =>
					group_A <= GTB_Char( character'pos(status_d(4))); -- status 3
					
				--when OTHERS =>
				end case;
			end if; --rising edge		
		end process;
    end Behavioral;