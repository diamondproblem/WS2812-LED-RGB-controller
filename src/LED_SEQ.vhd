 library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_unsigned.all;
use IEEE.NUMERIC_STD.all; 
use IEEE.STD_LOGIC_arith; 

----------------------------------------------------------
-- Generation of valid signal for the WS2812 led stripe
-- Mode for making a light sequence
----------------------------------------------------------

entity LED_SEQ is
	port(
		CLK  : in STD_LOGIC; -- clock 12 MHz	
		RESET : in STD_LOGIC; -- reset signal to enable a generation algorithm	  
		LED : out STD_LOGIC := '0' -- output of the WS2812 control signal 
		);
end LED_SEQ;  



architecture LED_SEQ of LED_SEQ is	
	
signal CYCLE_CNTR : STD_LOGIC_VECTOR(6 downto 0); -- duration time of a single pulse (TH + TL)
signal BIT_CNTR : STD_LOGIC_VECTOR(4 downto 0); -- number of the transfered bit (there should be 24 in a single bit pack)
signal RGB : STD_LOGIC_VECTOR(0 to 23); -- 24-bit value consist of red, green and blue color values	
signal RGB_bit : STD_LOGIC; -- current bit 'converted' to pulses					
signal RESET_CNTR : STD_LOGIC_VECTOR(36 downto 0) := (others => '0'); -- duration time of the reset code ( >= 50 us)  
signal BIT_PACK : STD_LOGIC_VECTOR(2 downto 0); -- current bit pack (there should be eight bit packs to light up eight diodes)
signal RESET_FLAG : STD_LOGIC := '0';  -- indicator to showing if reset switch has been toggled
signal TO_BLUE : STD_LOGIC_VECTOR(7 downto 0) := "11010101"; -- current blue color value
signal TO_RED : STD_LOGIC_VECTOR(7 downto 0) := "10110001";	-- current red color value
signal TO_GREEN : STD_LOGIC_VECTOR(7 downto 0) := "01010101"; -- current green color value		
signal MAX_DIODE : STD_LOGIC_VECTOR(3 downto 0) := "0001"; -- first there is a single diode lighted up, then two and so on to eight lighted up diodes
signal COLOR_NOW : STD_LOGIC := '0'; -- current color

begin

-- This process set color in a sequence (blue-purple and pink)

process(COLOR_NOW)
begin 
	    if COLOR_NOW = '0' then
			TO_RED <= "10000000";
			TO_GREEN <= "00100111";
			TO_BLUE <= "10100000";
		else 
			TO_RED <= "10111010";
			TO_GREEN <= "00011000";
			TO_BLUE <= "01110101";
		end if;
end process;

-- Show color consist of suitable red, green and blue component 

RGB <= TO_GREEN & TO_RED & TO_BLUE;

-- Transfer following bits of 24-bit number

RGB_bit <= RGB(to_integer(unsigned(BIT_CNTR)));

-- This process generates valid pulses for the WS2812 led strip
-- Works sequentially with the clock rising edge
	
process (CLK)  
begin 
	if CLK'event and CLK = '1' then
		if RESET = '1' or BIT_PACK > 7 then -- toggling of reset switch starts process of pulses generation
			CYCLE_CNTR <= (others => '0');
			BIT_CNTR <= (others => '0'); 
			BIT_PACK <= (others => '0'); 
			RESET_FLAG <= '1'; 
			LED <= '0'; -- when the reset switch is in high state no pulses are generated	 

		else	 
			if RESET_FLAG = '1' then  -- when reset switch was toggled it means that single pulse should be generated all over again
				CYCLE_CNTR <= (others => '0');
				RESET_FLAG <= '0';
				LED <= '1'; -- every data pulse, which represents '0' or '1' starts with high state
			else
				CYCLE_CNTR <= CYCLE_CNTR + 1;
			end if;
			
			if RGB_bit = '1' then
				if CYCLE_CNTR = 7 then	   -- generation of valid sequence for '1'
					LED <= '0';
				end if;
			else
				if CYCLE_CNTR = 3 then	 -- generation of valid sequence for '0'
					LED <= '0';
				end if;
			end if;
			
			if CYCLE_CNTR = 13 then -- at the end of the sequence (pulse) duration time
				LED <= '1';
				if BIT_CNTR = 23 and BIT_PACK = (MAX_DIODE-1) then -- case when sequence duration time has elapsed and the pulse was last pulse in variable-length bit pack  
					LED <= '0';		
					RESET_CNTR <= RESET_CNTR + 1; -- generation of >= 50 us reset code
					if RESET_CNTR = 10000 then -- end of reset code, pulse generation process starts all over again
						CYCLE_CNTR <= (others => '0');
						BIT_CNTR <= (others => '0'); 
						BIT_PACK <= (others => '0');
						RESET_CNTR <= (others => '0');
						LED <= '1';
						if MAX_DIODE < 8 then
							MAX_DIODE <= MAX_DIODE + 1;	 -- light up following diodes (first one, second two)
						else
							MAX_DIODE <= "0001"; 	  -- if all eight diodes are lighted up, change color
							COLOR_NOW <= not COLOR_NOW;
						end if;
					end if;
				elsif BIT_CNTR < 23 and BIT_PACK <= (MAX_DIODE-1) then -- case when sequence duration time has elapsed and the pulse was not the last in bit pack
					BIT_CNTR <= BIT_CNTR + 1;	 
					CYCLE_CNTR <= (others => '0');
				elsif BIT_CNTR = 23 and BIT_PACK < (MAX_DIODE-1) then -- case when sequence duration time has elapsed and the pulse was the last in bit pack (not last bit pack)
					BIT_CNTR <= (others => '0'); 
					CYCLE_CNTR <= (others => '0');	
					BIT_PACK <= BIT_PACK + 1;  
					LED <= '1';
				end if;
			end if;
		end if;
	end if;

end process; 


	
end LED_SEQ;
