--*****************************************************************************
--
--  Title   : Rockwell PPS4_2 CPU
--
--  File    : pps4_2.vhd
--
--  Author  : bontango
--
--
--  Notes:
--  need to be clocked faster ( 4 times ?) the the original CPU because of used statemaschine model
--  256 half-byte ram included address range (via B Register) 
--  should be 0x0..0xFF and 0x800 .. 0x8FF
--  we map it to 0x0FF and 0x100..0x1FF via B(11 downto 4)
--
-- v0.2 adjusted memory handling
-- v0.3 ADSK implemented according datasheet
-- v0.4 LB corrected
-- v0.5 SAG added (according to pps4.cpp from mame)
-- v0.6 IOL corrected, now we exchange negated accu
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pps4 is
  port( clk     : in  std_logic;
        reset   : in  std_logic;
        w_io    : out  std_logic; -- write command and IO enable	
		  io_cmd  : out  std_logic_vector( 3 downto 0); -- cmd to IO device
		  io_data : in  std_logic_vector( 3 downto 0); -- data from IO device
		  io_device    : out std_logic_vector( 3 downto 0); -- ID of IO device
		  io_accu    : out std_logic_vector( 3 downto 0); -- accu for input to IO device
		  io_port    : out std_logic_vector( 3 downto 0); -- port of IO device (BL)
        d_in    : in  std_logic_vector( 7 downto 0); -- Instruction/Data Bus		  
        addr    : out std_logic_vector( 11 downto 0); -- program counter (ROM address)		  
        di_a    : in std_logic_vector( 3 downto 0); -- discrete Input Group A
		  di_b    : in std_logic_vector( 3 downto 0); -- discrete Input Group B
        do_a	 : out std_logic_vector( 3 downto 0); -- discrete output ( DOA <- A)
        do_b	 : out std_logic_vector( 3 downto 0);  -- discrete output ( DOB <- X )
		  accu_debug : out std_logic_vector( 3 downto 0)
        );
end pps4;

architecture fsm of pps4 is
	  --   op-codes
  constant LBL : integer := 0;
  constant TML_from : integer := 16#01#;
  constant TML_to : integer := 16#03#;    
  constant LBUA : integer := 16#04#;
  constant RTN : integer := 16#05#;
  constant XS : integer := 16#06#;
  constant RTNSK : integer := 16#07#;
  constant ADCSK : integer := 16#08#;    
  constant ADSK : integer := 16#09#;    
  constant  ADC : integer := 16#0A#;    
  constant AD : integer := 16#0B#;
  constant EOR : integer := 16#0C#;    
  constant PPS4_AND : integer := 16#0D#;    
  constant COMP : integer := 16#0E#;    
  constant PPS4_OR : integer := 16#0F#;    
  
  constant LBMX : integer := 16#10#;
  constant LABL : integer := 16#11#;
  constant LAX : integer := 16#12#;
  constant SAG : integer := 16#13#;
  constant SKF2 : integer := 16#14#;
  constant SKC : integer := 16#15#;
  constant SKF1 : integer := 16#16#;
  constant INCB : integer := 16#17#;
  constant XBMX : integer := 16#18#;
  constant XABL : integer := 16#19#;
  constant XAX : integer := 16#1A#;
  constant LXA : integer := 16#1B#;
  constant IOL : integer := 16#1C#;
  constant DOA : integer := 16#1D#;
  constant SKZ : integer := 16#1E#;
  constant DECB : integer := 16#1F#;
  
  
  constant SC : integer := 16#20#;
  constant SF2 : integer := 16#21#;
  constant SF1 : integer := 16#22#;
  constant DIB : integer := 16#23#;
  constant RC : integer := 16#24#;
  constant RF2 : integer := 16#25#;
  constant RF1 : integer := 16#26#;
  constant DIA : integer := 16#27#;
  constant EXD_from : integer := 16#28#;
  constant EXD_to : integer := 16#2F#;
  
  constant LD_from : integer := 16#30#;
  constant LD_to : integer := 16#37#;
  constant EX_from : integer := 16#38#;
  constant EX_to : integer := 16#3F#;   
  
  constant SKBI_from : integer := 16#40#;
  constant SKBI_to : integer := 16#4F#;    
  
  constant TL_from : integer := 16#50#;
  constant TL_to : integer := 16#5F#;    
  
  constant ADI_1_from : integer := 16#60#;
  constant ADI_1_to : integer := 16#64#;    
  constant DC : integer := 16#65#;
  constant ADI_2_from : integer := 16#66#;
  constant ADI_2_to : integer := 16#6E#;    
  constant CYS : integer := 16#6F#;    
  
  constant LDI_from : integer := 16#70#;
  constant LDI_to : integer := 16#7F#;    
  
  constant T_from : integer := 16#80#;
  constant T_to : integer := 16#BF#;    
  
  constant LB_from : integer := 16#C0#;
  constant LB_to : integer := 16#CF#;    
  
  constant TM_from : integer := 16#D0#;
  constant TM_to : integer := 16#FF#;          
  
  -- internal RAM   
	type RAMTYPE is array (255 downto 0) of std_logic_vector(3 downto 0);
   signal RAM             : RAMTYPE;	
	--attribute ramstyle : string;
	--attribute ramstyle of RAM : signal is "no_rw_check, MLAB";
	-- to prevent Warning (276020): Inferred RAM node "pps4:U1|RAM_rtl_0" from synchronous design logic.  
	-- Pass-through logic has been added to match the read-during-write behavior of the original design.

  -- CPU registers
  signal accu    : std_logic_vector( 3 downto 0); -- Accumulator
  signal xreg    : std_logic_vector( 3 downto 0); --Secondary Accumulator Register		
  signal PC      : std_logic_vector( 11 downto 0); -- Program counter needed
  
  signal SA      : std_logic_vector( 11 downto 0); --Save Registers, SA
  signal SB      : std_logic_vector( 11 downto 0); --Save Registers, SB
  signal B      : std_logic_vector( 11 downto 0); --RAM Address Register ( BU, BM, BL)
  
  signal carry : std_logic;
  signal ff1 : std_logic;
  signal ff2 : std_logic;
  
  -- internal signals, flags and help vars
  signal wasLB : integer range 0 to 2;
  signal wasLDI : integer range 0 to 2;
  signal skip : std_logic;  
  signal I      : std_logic_vector( 7 downto 0); -- current Instruction
  -- 
  signal op_code     : integer range 0 to 255; -- current opcode
  
  signal m_SAG      : std_logic_vector( 11 downto 0); -- Special address generation mask
  
    --   FSM states
  type state_t is ( load_opcode, execution, sec_cycle, finish_sec_cycle, skip_it );
  signal state : state_t;    
  
begin  --  fsm 
  
  --debug
  accu_debug <= accu;
  
  fsm_proc : process ( clk, reset)
  
  variable Temp   : std_logic_vector( 4 downto 0); -- for calculations with carry bit  
  variable accu_save   : std_logic_vector( 3 downto 0); -- Accumulator save help
  
  begin  --  process fsm_proc 

		if ( reset = '0') then  -- Asynchronous reset
			--   output and variable initialisation
			w_io     <= '0';
			--d_out    <= ( others => '0');
			B       <= ( others => '0');
			PC       <= ( others => '0');
			addr      <= ( others => '0');
			accu     <= ( others => '0');
			PC       <= ( others => '0');
			do_a     <= ( others => '0');
			do_b     <= ( others => '0');
			m_SAG    <= x"FFF";
			wasLB   <= 0;
			wasLDI   <= 0;
			skip <= '0';
			carry <= '0';
			ff1 <= '0';
			ff2 <= '0';
			state <= load_opcode;

		elsif rising_edge( clk) then  -- Synchronous FSM

			case state is
			  --------------------------------
			  ---- State 1 load the opcode ---
			  --------------------------------			  
			  when load_opcode =>
			    I <= d_in; -- assign instruction for later use
				 op_code <= to_integer(unsigned(d_in)); -- Load the op-code				 
				 PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter			
				 -- check LB and LBI flags
				 if (wasLB >0) then wasLB <= wasLB -1; end if;
				 if (wasLDI >0) then wasLDI <= wasLDI -1; end if;
				 -- check if we need to skip next instruction
				 if ( skip = '1') then
					state <= skip_it;
				 else
					state <= execution;
				 end if;	
				 
			  --------------------------------				 
			  -- State 2 Execution			 
			  --------------------------------				
				when execution =>
				 -- opcode decoder
				 case op_code is
				   -- ####################################
				   -- ARITHMETIC INSTRUCTIONS
					-- ####################################
					--------------------------------
					-- 0x0B - 'AD' Add C,A <- A + M
					--------------------------------
					when AD =>  					   
						Temp := std_logic_vector( unsigned('0' & accu) + unsigned( RAM( to_integer(unsigned(B(11 downto 0) and m_SAG)))) );
					   accu    <= Temp(3 downto 0);
						carry   <= Temp(4);
						addr <= PC;
						m_SAG <= x"FFF";
						state <= load_opcode; 	-- next instruction
					--------------------------------
					-- 0x0A - 'ADC' Add with carry-in C,A <- A + M + c
					--------------------------------
					when ADC =>  						
						if ( carry = '1') then
						 Temp := std_logic_vector( unsigned('0' & accu) + unsigned( RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)))) + 1);
						else 
						 Temp := std_logic_vector( unsigned('0' & accu) + unsigned( RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)))));
						end if; 
					   accu    <= Temp(3 downto 0);
						carry   <= Temp(4);
						addr <= PC;
						m_SAG <= x"FFF";
						state <= load_opcode; 	-- next instruction
					--------------------------------
					-- 0x09 - 'ADSK' Add and skip on carry out C,A <- A + M Skip if C = 1
					--------------------------------
					when ADSK =>  					   
						--Temp := std_logic_vector( unsigned('0' & accu) + unsigned( RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)))) );
						-- same as ADCSK??? see hint in gts1.c in pinmame
						if ( carry = '1') then
						 Temp := std_logic_vector( unsigned('0' & accu) + unsigned( RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)))) + 1);
						else 
						 Temp := std_logic_vector( unsigned('0' & accu) + unsigned( RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)))));
						end if; 												
					   accu    <= Temp(3 downto 0);
						carry   <= Temp(4);
						skip   <= Temp(4);
						addr <= PC;
						m_SAG <= x"FFF";
						state <= load_opcode; 	-- next instruction
					--------------------------------
					-- 0x08 - 'ADCSK' Add with carry-in and skip on carry out C,A <- A + M + C Skip if C = 1
					--------------------------------
					when ADCSK =>  
						if ( carry = '1') then
						 Temp := std_logic_vector( unsigned('0' & accu) + unsigned( RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)))) + 1);
						else 
						 Temp := std_logic_vector( unsigned('0' & accu) + unsigned( RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)))));
						end if; 						
					   accu    <= Temp(3 downto 0);
						carry   <= Temp(4);
						skip   <= Temp(4);
						addr <= PC;					
						m_SAG <= x"FFF";		
						state <= load_opcode; 	-- next instruction				
					--------------------------------
					-- 0x60 to 0x64 - 'ADI' Part1 add immidiate and skip on carry out ( complementary value on bus!) no change of carry bit
					--------------------------------
					when ADI_1_from to ADI_1_to =>  
					   Temp := std_logic_vector( unsigned('0' & accu) + unsigned(not I(3 downto 0))); -- I inverted
					   accu    <= Temp(3 downto 0);
						skip   <= Temp(4);
						addr <= PC;											
						state <= load_opcode; 	-- next instruction				
					--------------------------------
					-- 0x65 - 'DC' Decimal correction,no use or change carry bit or skip
					--------------------------------
					when DC =>  
						Temp := std_logic_vector( unsigned('0' & accu) + 10);
					   accu    <= Temp(3 downto 0);
						addr <= PC;											
						state <= load_opcode; 	-- next instruction				
					--------------------------------
					-- 0x66 to 0x6E - 'ADI' Part2 add immidiate and skip on carry out ( complementary value on bus!) no change of carry bit
					--------------------------------
					when ADI_2_from to ADI_2_to =>  
					   Temp := std_logic_vector( unsigned('0' & accu) + unsigned(not I(3 downto 0))); -- I inverted
					   accu    <= Temp(3 downto 0);
						skip   <= Temp(4);
						addr <= PC;											
						state <= load_opcode; 	-- next instruction				
					
				-- ####################################	
				   -- LOGICAL INSTRUCTIONS
					-- ####################################
					--------------------------------
					-- 0x0D - 'AND' logical AND
					--------------------------------
					when PPS4_AND =>  
						accu <= accu and RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)));
						addr <= PC;		
						m_SAG <= x"FFF";		
						state <= load_opcode; 	-- next instruction										
					--------------------------------
					-- 0x0F - 'OR' logical OR
					--------------------------------
					when PPS4_OR =>  					   
						accu <= accu or RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)));
						addr <= PC;			
						m_SAG <= x"FFF";		
						state <= load_opcode; 	-- next instruction	
					--------------------------------
					-- 0x0C - 'EOR' exclusive OR
					--------------------------------
					when EOR =>  					   
						accu <= accu xor RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)));
						addr <= PC;	
						m_SAG <= x"FFF";				
						state <= load_opcode; 	-- next instruction	
					--------------------------------
					-- 0x0E - 'COMP' complement
					--------------------------------
					when COMP =>
						accu <= not accu;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction	
					-- ####################################							
					-- DATA TRANSFER INSTRUCTIONS
					-- ####################################
					--------------------------------											
					-- 0x20 - 'SC' set carry flip-flop
					--------------------------------
					when SC =>  	
						carry <= '1';
						addr <= PC;			
						state <= load_opcode; 	-- next instruction	
					--------------------------------											
					-- 0x24 - 'RC' reset carry flip-flop
					--------------------------------
					when RC =>  	
						carry <= '0';
						addr <= PC;			
						state <= load_opcode; 	-- next instruction	
					--------------------------------											
					-- 0x22 - 'SF1' set FF1
					--------------------------------
					when SF1 =>  	
						ff1 <= '1';
						addr <= PC;			
						state <= load_opcode; 	-- next instruction	
					--------------------------------											
					-- 0x26 - 'RF1' reset FF1
					--------------------------------
					when RF1 =>  	
						ff1 <= '0';
						addr <= PC;			
						state <= load_opcode; 	-- next instruction	

					--------------------------------											
					-- 0x21 - 'SF2' set FF2
					--------------------------------
					when SF2 =>  	
						ff2 <= '1';
						addr <= PC;			
						state <= load_opcode; 	-- next instruction	
					--------------------------------											
					-- 0x25 - 'RF2' reset FF2
					--------------------------------
					when RF2 =>  	
						ff2 <= '0';
						addr <= PC;			
						state <= load_opcode; 	-- next instruction	
					--------------------------------											
					-- 'LD' Load Accumulator from memory
					--------------------------------						
					when LD_from to LD_to =>    						
						accu <= RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)));
						B(6 downto 4) <= B(6 downto 4) xor ( not I(2 downto 0)); --I inverted						
						addr <= PC;			
						m_SAG <= x"FFF";		
						state <= load_opcode; 	-- next instruction	
					--------------------------------											
					-- 'EX' Exchange Accumulator and memory
					--------------------------------						
					when EX_from to EX_to =>    
					   accu_save := accu; -- preserve accu because Quartus adds some intelligence for ram
						accu <= RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)));						
						RAM( to_integer(unsigned(B(11 downto 0)and m_SAG))) <= accu_save;
						B(6 downto 4) <= B(6 downto 4) xor not(I(2 downto 0)); -- I inverted						
						addr <= PC;			
						m_SAG <= x"FFF";		
						state <= load_opcode; 	-- next instruction	
					--------------------------------											
					-- 'EXD' Exchange Accumulator and memory and decrement BL, skip on BL=1111
					--------------------------------						
					when EXD_from to EXD_to =>    	
						accu_save := accu; -- preserve accu because Quartus adds some intelligence for ram					
						accu <= RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)));
						RAM( to_integer(unsigned(B(11 downto 0)and m_SAG))) <= accu_save;						
						B(6 downto 4) <= B(6 downto 4) xor not (I(2 downto 0)); -- I inverted
						B(3 downto 0) <= std_logic_vector( unsigned(B(3 downto 0)) - 1 );	-- decrement BL						
						if B(3 downto 0) = "0000" then skip <= '1'; end if; -- we check against 0 as dec is done at end of process						
						addr <= PC;			
						m_SAG <= x"FFF";		
						state <= load_opcode; 	-- next instruction					
					--------------------------------											
					-- 'LDI' Load Accumulator Immediate 
					--------------------------------						
					when LDI_from to LDI_to =>    
						if ( wasLDI = 0) then
							accu    <= not d_in(3 downto 0);   -- inverted in this case
						end if;
					   wasLDI <= 2;	
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'LAX' Load Accumulator from X register
					--------------------------------						
					when LAX =>    
					   accu <= xreg;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'LXA' Load X register from Accumulator
					--------------------------------						
					when LXA =>    
					   xreg <= accu;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'LABL' Load Accumulator with BL
					--------------------------------						
					when LABL =>    
					   accu <= B(3 downto 0);
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'LBMX' Load BM with X register
					--------------------------------						
					when LBMX =>    
					   B(7 downto 4) <= xreg;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'LBUA' Load BU with Accumulator, also contents of currently addressed RAM are transferred to accu
					--------------------------------						
					when LBUA =>    
					   B(11 downto 8) <= accu;
						accu <= RAM( to_integer(unsigned(B(11 downto 0)and m_SAG)));
						addr <= PC;			
						m_SAG <= x"FFF";		
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'XABL' Exchange Accumulator and BL
					--------------------------------						
					when XABL =>    
					   B(3 downto 0) <= accu;
						accu <= B(3 downto 0);
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'XBMX' Exchange BM and X
					--------------------------------						
					when XBMX =>    
					   B(7 downto 4) <= xreg;
						xreg <= B(7 downto 4);
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'XAX' Exchange Accumulator and X
					--------------------------------						
					when XAX =>    
					   accu <= xreg;
						xreg <= accu;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'XS' Exchange SA and SB
					--------------------------------						
					when XS =>    
					   SA <= SB;
						SB <= SA;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'CYS' cycle SA register and Accumulator
					--------------------------------						
					when CYS =>    
					   accu <= not SA(3 downto 0);
						SA(3 downto 0) <= SA(7 downto 4);
						SA(7 downto 4) <= SA(11 downto 8);
						SA(11 downto 8) <= not accu;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction						
					--------------------------------											
					-- 'LB' Load B indirect (2 cycles, but one rom word! )
					--------------------------------						
					when LB_from to LB_to =>    
						if ( wasLB = 0) then
							SB <= SA;
							SA <= PC;	-- already advanced here							
							PC(11 downto 4) <= "00001100";
							PC(3 downto 0) <= I(3 downto 0);
							addr(11 downto 4) <= "00001100";
							addr(3 downto 0) <= I(3 downto 0);						
							state <= sec_cycle; -- second cycle								
						else
							-- last cmd was LB or LBL -> to be ignored
							addr <= PC;			
							state <= load_opcode; 	-- next instruction						
						end if;																	
					   wasLB <= 2;							
					--------------------------------											
					-- 0x00 - 'LBL' Load B Long (2 cycles)
					--------------------------------
					when LBL =>  								
					   addr <= PC;	-- set address	(PC already incremented, so pointing to argument)						
						state <= sec_cycle; -- second cycle												
					--------------------------------											
					-- 'INCB' BL=BL+1 increment BL, skip on BL=0000
					--------------------------------						
					when INCB =>    
						B(3 downto 0) <= std_logic_vector( unsigned(B(3 downto 0)) + 1 );	-- increment BL
						if B(3 downto 0) = "1111" then skip <= '1'; end if; -- we check against 0xF as inc is done at end of process											   
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------											
					-- 'DECB' BL=BL-1 decrement BL, skip on BL=1111
					--------------------------------						
					when DECB =>    
						B(3 downto 0) <= std_logic_vector( unsigned(B(3 downto 0)) - 1 );	-- decrement BL
						if B(3 downto 0) = "0000" then skip <= '1'; end if; -- we check against 0 as dec is done at end of process											   
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
						
					-- ####################################								
					-- SPECIAL
					-- ####################################							
					--------------------------------																	
					-- 'SAG'  special address generation
					--------------------------------											
					when SAG =>    						
						m_SAG <= "000000001111"; -- set the mask, will be unset by each memory access opcode
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
						
					-- ####################################								
					-- SPECIAL
					-- ####################################							
					--------------------------------																	
					-- 'T'  transfer
					--------------------------------											
					when T_from to T_to =>    						
						PC(5 downto 0) <= I(5 downto 0);
						addr(5 downto 0) <= I(5 downto 0);						
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'TM'  transfer and mark indirect (2 cycles, but one rom word! Second word from 'page 3'))
					--------------------------------											
					when TM_from to TM_to =>    						
						SB <= SA;							
						SA <= PC; -- already advanced here
						PC(11 downto 6) <= "000011";
						PC(5 downto 0) <= I(5 downto 0);							
						addr(11 downto 6) <= "000011";
						addr(5 downto 0) <= I(5 downto 0);							
						state <= sec_cycle; -- second cycle								
					--------------------------------																	
					-- 'TL'  transfer and mark indirect (2 cycles)
					--------------------------------											
					when TL_from to TL_to =>    					
						addr <= PC;	-- set address	(PC already incremented, so pointing to argument)						
						state <= sec_cycle; -- second cycle						
					--------------------------------																	
					-- 'TML'  transfer and mark long (2 cycles, 2 words)
					--------------------------------											
					when TML_from to TML_to =>    				
						addr <= PC;	-- set address	(PC already incremented, so pointing to argument)						
						state <= sec_cycle; -- second cycle		
					--------------------------------																	
					-- 'SKC'  skip on carry flipflop
					--------------------------------											
					when SKC  =>    						
						if carry = '1' then skip <= '1'; end if;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'SKZ'  skip on accumulator zero
					--------------------------------											
					when SKZ  =>    						
						if accu = "0000" then skip <= '1'; end if;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'SKBI'  skip if BL is equal to immediate
					--------------------------------											
					when SKBI_from to SKBI_to  =>    						
						if B(3 downto 0) = I(3 downto 0) then skip <= '1'; end if;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'SKF1'  skip if FF1 equals 1
					--------------------------------											
					when SKF1  =>    						
						if ff1 = '1' then skip <= '1'; end if;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'SKF2'  skip if FF2 equals 1
					--------------------------------											
					when SKF2  =>    						
						if ff2 = '1' then skip <= '1'; end if;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'RTN'  return
					--------------------------------											
					when RTN  =>    						
						PC <= SA;
						addr <= SA;
						SA <= SB;
						SB <= SA;
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'RTNSK'  return and skip
					--------------------------------											
					when RTNSK  =>    
					   -- datasheet says PC=PC+1 but we need to 'skip' in case of 2cycle cmd after RTN
						-- ( thx for the hint in gts1.c from pinmame)
						PC <= SA;						
						addr <= SA;						
						SA <= SB;
						SB <= SA;
						skip <= '1';
						state <= load_opcode; 	-- next instruction		
					
					-- ####################################								
					-- INPUT / OUTPUT TRANSFER INSTRUCTIONS
					-- ####################################							
					--------------------------------																	
					-- 'IOL'  Input / Output Long (2 cycles)
					--------------------------------											
					when IOL =>    					   
						addr <= PC;	-- set address	(PC already incremented, so pointing to argument)
						--PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter															
						state <= sec_cycle; -- second cycle			
					--------------------------------																	
					-- 'DIA'  discrete input Group A
					--------------------------------											
					when DIA  =>    						
						accu <= di_a;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'DIB'  discrete input Group B
					--------------------------------											
					when DIB  =>    						
						accu <= di_b;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction
					--------------------------------																	
					-- 'DOA'  discrete output
					--------------------------------											
					when DOA  =>    						
						do_a <= accu;
						do_B <= xreg;
						addr <= PC;			
						state <= load_opcode; 	-- next instruction								
						
					when others =>
						-- nop
						addr <= PC;
						state <= load_opcode; 	-- next instruction
				  end case;  --  opcode	             				   												 
				  
			  --------------------------------				 
			  -- State 3 second cycle
			  --------------------------------				
				when sec_cycle =>
				 -- opcode decoder (again, but 2cycle codes only)
				 case op_code is		
				 	when LB_from to LB_to =>    
						B(11 downto 8) <= "0000";
						B(7 downto 0) <= not d_in;	-- inverted in this case						
						PC <= SA; 
						SA <= SB;
						SB <= SA;
					
					when LBL =>  
					if ( wasLB = 0) then
						B(11 downto 8) <= "0000";
						B(7 downto 0) <= not d_in;		-- inverted in this case
					end if;
						wasLB <= 2;
						PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter				 				 
						
					when TM_from to TM_to =>    						
						PC(11 downto 8) <= "0001";
						PC(7 downto 0) <= d_in;
						
					when TL_from to TL_to =>    						
						PC(11 downto 8) <= I(3 downto 0);
						PC(7 downto 0) <= d_in;

					when TML_from to TML_to =>    						
						SB <= SA;
						SA <= std_logic_vector( unsigned(PC) + 1 ); -- +1 because it has 2 words
						PC(11 downto 8) <= I(3 downto 0);
						PC(7 downto 0) <= d_in;
					
					when IOL =>  						
						io_device <= d_in(7 downto 4);
						io_cmd <= d_in(3 downto 0);
						
						io_port <= B(3 downto 0); --io port is BL
						io_accu <= not accu; -- negated!
						
						w_io <= '1';
						PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter				 				 
						
					when others =>
						-- nop
						PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter				 				 

				 end case;  --  opcode	             	
				 
				 state <= finish_sec_cycle; 
				 
			  --------------------------------				 
			  -- State 4 finish second cycle
			  --------------------------------				
			  when finish_sec_cycle =>
			  	 case op_code is				 	
					 when IOL =>  
						accu <= not io_data; -- negated!
						w_io <= '0';
						addr <= PC; -- assign program counter to addressbus
						state <= load_opcode; 	-- next instruction
						
					 when others =>
						addr <= PC; -- assign program counter to addressbus
						state <= load_opcode; 	-- next instruction
					 end case;  --  opcode	             		
			  --------------------------------				 
			  -- special state, skip a instruction
			  --------------------------------				
			  when skip_it =>
			      -- do we need to skip second instruction only (not all 2cycle codes, only those with 2 rom codes)
				   case op_code is
						when LBL =>
							PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter				 				 
							addr <= std_logic_vector( unsigned(PC) + 1 );
						when TL_from to TL_to =>    													
							PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter				 				 
							addr <= std_logic_vector( unsigned(PC) + 1 );							
						when TML_from to TML_to =>    													
							PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter				 				 
							addr <= std_logic_vector( unsigned(PC) + 1 );							
						when IOL =>    													
							PC <= std_logic_vector( unsigned(PC) + 1 );	-- Increment the program counter				 				 
							addr <= std_logic_vector( unsigned(PC) + 1 );							
						when others =>
							addr <= PC; -- assign program counter to addressbus	
					end case;										
					skip <= '0'; -- reset skip flag
					state <= load_opcode; 	-- next instruction
					
			end case;  --  state
		end if; -- rising_edge(clk)

  end process fsm_proc;
end fsm;
