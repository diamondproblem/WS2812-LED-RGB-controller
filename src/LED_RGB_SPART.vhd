library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_unsigned.all;
use IEEE.NUMERIC_STD.all; 
use IEEE.STD_LOGIC_arith;

----------------------------------------------------------
-- Generation of valid signal for the WS2812 led stripe
-- Mode for manual control of a rgb led color
-- Color value can be changed by units, tens or hundreds 
-- Color value can not be greater than 252
----------------------------------------------------------


entity LED_RGB is
	port(
		RESET  : in STD_LOGIC; -- reset signal, also enables pulse generation mechanism
		CLK  : in STD_LOGIC; -- clock signal 12 MHz	
		UNITY, DOZENS, HUNDREDS : in STD_LOGIC;	-- push buttons adding values to color value
		MINUS_UNITY, MINUS_DOZENS, MINUS_HUNDREDS : in STD_LOGIC;  -- push buttons subtracting values from color value
		SELECT_R, SELECT_G, SELECT_B : in STD_LOGIC; -- preview of color value
		R, G, B	 : in STD_LOGIC; -- enable of elementary RGB colors
		LED : out STD_LOGIC := '0'; -- output of WS2812 control signal
		COLOR_OUT : out STD_LOGIC_VECTOR(7 downto 0); -- output of current value of selected color
		SELECT_R_OUT, SELECT_G_OUT, SELECT_B_OUT : out STD_LOGIC -- preview of color value (transfered to SEVEN_SEG)
		);
end LED_RGB;


architecture LED_RGB of LED_RGB is	 

signal CYCLE_CNTR : STD_LOGIC_VECTOR(6 downto 0); -- duration time of one pulse (TH + TL)
signal BIT_CNTR : STD_LOGIC_VECTOR(4 downto 0); -- number of transfered bit (there should be 24 in one bit pack)
signal RGB : STD_LOGIC_VECTOR(0 to 23);	-- 24-bit value consist of red, green and blue color values
signal RGB_bit : STD_LOGIC;	-- current bit 'converted' to pulses				
signal RESET_CNTR : STD_LOGIC_VECTOR(36 downto 0) := (others => '0'); -- duration time of reset code ( >= 50 us) 
signal BIT_PACK : STD_LOGIC_VECTOR(2 downto 0);	-- current bit pack (there should be eight bit pack to light up eight diodes)
signal RESET_FLAG : STD_LOGIC := '0';  -- reset switch has been toggled
signal TO_BLUE : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');  -- current blue color value
signal TO_RED : STD_LOGIC_VECTOR(7 downto 0) := (others => '0') ; -- current red color value
signal TO_GREEN : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); -- current green color value		
signal DB_PUSHBUTTONS_PREVIOUS_UNITY, DB_PUSHBUTTONS_PREVIOUS_DOZENS, DB_PUSHBUTTONS_PREVIOUS_HUNDREDS : STD_LOGIC; 
-- previous state of addition buttons (for debouncing and falling edge detection)
signal DB_PUSHBUTTONS_PREVIOUS_MINUS_UNITY, DB_PUSHBUTTONS_PREVIOUS_MINUS_DOZENS, DB_PUSHBUTTONS_PREVIOUS_MINUS_HUNDREDS : STD_LOGIC;
-- previous state of subtraction buttons (for debouncing and falling edge detection)

begin  
	
-- Dependent upon which color switches were toggled, show color consist of suitable red, green and blue component 
 
RGB <= TO_GREEN & TO_RED & TO_BLUE when (R = '1' and G = '1' and B = '1' and TO_RED < 252 and TO_BLUE < 252 and TO_GREEN < 252) else 
	TO_GREEN & "00000000" & TO_BLUE	when((R = '0' and B = '1' and G = '1') or ((TO_RED >= 252 or  TO_RED < 0) and R = '1' and G = '1' and B = '1')) else
	TO_GREEN & TO_RED & "00000000"  when ((G = '1' and R = '1' and B = '0') or ((TO_GREEN >= 252 or TO_GREEN < 0) and R = '1' and G = '1' and B = '1')) else
	"00000000" & TO_RED & TO_BLUE  when ((B = '1' and R = '1' and G = '0') or ((TO_BLUE >= 252 or TO_BLUE < 0) and R = '1' and G = '1' and B = '1')) else	 
	"00000000" & "00000000" & TO_BLUE	when((R = '0' and B = '1' and G = '0') or (((TO_RED >= 252 and TO_BLUE >= 252) or (TO_RED < 0 and TO_BLUE < 0)) and R = '1' and G = '1' and B = '1')) else
	TO_GREEN & "00000000" & "00000000"  when ((G = '1' and R = '0' and B = '0') or (((TO_GREEN >= 252 or TO_RED >= 252) or (TO_RED < 0 and TO_GREEN < 0)) and R = '1' and G = '1' and B = '1')) else
	"00000000" & TO_RED & "00000000" when ((B = '0' and R = '1' and G = '0') or (((TO_BLUE >= 252 or TO_GREEN >= 252) or (TO_BLUE < 0 and TO_GREEN < 0)) and R = '1' and G = '1' and B = '1')) else
	(others => '0');
	
-- Transfer following bits of 24-bit number

RGB_bit <= RGB(to_integer(unsigned(BIT_CNTR)));

-- Number which is shown on seven segment display is dependent upon state of suitable switches

COLOR_OUT <= TO_RED when (SELECT_R = '1' and SELECT_G = '0' and SELECT_B = '0') else
	TO_GREEN when (SELECT_R = '0' and SELECT_G = '1' and SELECT_B = '0') else
	TO_BLUE when (SELECT_R = '0' and SELECT_G = '0' and SELECT_B = '1') else
	(others => '0'); 
	
	
-- This process sets value of RGB components
-- Only one component value can be set at a time
-- Works sequentially with clock rising edge

process(CLK, SELECT_R, SELECT_G, SELECT_B, UNITY, DOZENS, HUNDREDS)
begin 
	
	if rising_edge(CLK) then
		if SELECT_R = '1' then
			-- the same procedure is used for setting other colors values
			-- color value can not be greater than 252
				if TO_RED >= 252 then
					TO_RED <= (others => '0');
				elsif TO_RED < 0 then
					TO_RED <= (others => '0');
				end if;
				
				-- previous states of push buttons
				
				DB_PUSHBUTTONS_PREVIOUS_UNITY <= UNITY;
				DB_PUSHBUTTONS_PREVIOUS_DOZENS <= DOZENS;
				DB_PUSHBUTTONS_PREVIOUS_HUNDREDS <= HUNDREDS; 
			
				DB_PUSHBUTTONS_PREVIOUS_MINUS_UNITY <= MINUS_UNITY;
				DB_PUSHBUTTONS_PREVIOUS_MINUS_DOZENS <= MINUS_DOZENS;
				DB_PUSHBUTTONS_PREVIOUS_MINUS_HUNDREDS <= MINUS_HUNDREDS;
				
				-- previous state is compared with current state
				-- if current state is '0' and previous is '1' it means that button was pressed so suitable value should be 
			    -- added/subtracted to/from color value
				
				if UNITY = '0' and DB_PUSHBUTTONS_PREVIOUS_UNITY = '1' then
					TO_RED <= TO_RED + 1; 
				elsif DOZENS = '0' and DB_PUSHBUTTONS_PREVIOUS_DOZENS = '1' then						 
					TO_RED <= TO_RED + 10;
				elsif HUNDREDS = '0' and DB_PUSHBUTTONS_PREVIOUS_HUNDREDS = '1' then
					TO_RED <= TO_RED + 100;		
				elsif MINUS_UNITY = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_UNITY = '1' then
					TO_RED <= TO_RED - 1; 
				elsif MINUS_DOZENS = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_DOZENS = '1' then						 
					TO_RED <= TO_RED - 10;
				elsif MINUS_HUNDREDS = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_HUNDREDS = '1' then
					TO_RED <= TO_RED - 100;
				end if;	
		 elsif SELECT_G = '1' then
				if TO_GREEN >= 252 then
					TO_GREEN <= (others => '0'); 
				elsif TO_GREEN < 0 then
					TO_GREEN <= (others => '0');
				end if;	
				
				DB_PUSHBUTTONS_PREVIOUS_UNITY <= UNITY;
				DB_PUSHBUTTONS_PREVIOUS_DOZENS <= DOZENS;
				DB_PUSHBUTTONS_PREVIOUS_HUNDREDS <= HUNDREDS;
				
				DB_PUSHBUTTONS_PREVIOUS_MINUS_UNITY <= MINUS_UNITY;
				DB_PUSHBUTTONS_PREVIOUS_MINUS_DOZENS <= MINUS_DOZENS;
				DB_PUSHBUTTONS_PREVIOUS_MINUS_HUNDREDS <= MINUS_HUNDREDS;
				
				if UNITY = '0' and DB_PUSHBUTTONS_PREVIOUS_UNITY = '1' then
					TO_GREEN <= TO_GREEN + 1;
				elsif DOZENS = '0' and DB_PUSHBUTTONS_PREVIOUS_DOZENS = '1' then
					TO_GREEN <= TO_GREEN + 10;
				elsif HUNDREDS = '0' and DB_PUSHBUTTONS_PREVIOUS_HUNDREDS = '1' then
					TO_GREEN <= TO_GREEN + 100;
				elsif MINUS_UNITY = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_UNITY = '1' then
					TO_GREEN <= TO_GREEN - 1; 
				elsif MINUS_DOZENS = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_DOZENS = '1' then						 
					TO_GREEN <= TO_GREEN - 10;
				elsif MINUS_HUNDREDS = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_HUNDREDS = '1' then
					TO_GREEN <= TO_GREEN - 100;
				end if;
		elsif SELECT_B = '1' then
				if TO_BLUE >= 252 then
					TO_BLUE <= (others => '0');	
				elsif TO_BLUE < 0 then
					TO_BLUE <= (others => '0');
				end if;

				DB_PUSHBUTTONS_PREVIOUS_UNITY <= UNITY;
				DB_PUSHBUTTONS_PREVIOUS_DOZENS <= DOZENS;
				DB_PUSHBUTTONS_PREVIOUS_HUNDREDS <= HUNDREDS;  
				
				DB_PUSHBUTTONS_PREVIOUS_MINUS_UNITY <= MINUS_UNITY;
				DB_PUSHBUTTONS_PREVIOUS_MINUS_DOZENS <= MINUS_DOZENS;
				DB_PUSHBUTTONS_PREVIOUS_MINUS_HUNDREDS <= MINUS_HUNDREDS;
				
				if UNITY = '0' and DB_PUSHBUTTONS_PREVIOUS_UNITY = '1' then
					TO_BLUE <= TO_BLUE + 1;
				elsif DOZENS = '0' and DB_PUSHBUTTONS_PREVIOUS_DOZENS = '1' then
					TO_BLUE <= TO_BLUE + 10;
				elsif HUNDREDS = '0' and DB_PUSHBUTTONS_PREVIOUS_HUNDREDS = '1' then
					TO_BLUE <= TO_BLUE + 100;
				elsif MINUS_UNITY = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_UNITY = '1' then
					TO_BLUE <= TO_BLUE - 1; 
				elsif MINUS_DOZENS = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_DOZENS = '1' then						 
					TO_BLUE <= TO_BLUE - 10;
				elsif MINUS_HUNDREDS = '0' and DB_PUSHBUTTONS_PREVIOUS_MINUS_HUNDREDS = '1' then
					TO_BLUE <= TO_BLUE - 100;
					
				end if;
		end if;
	end if;
		
end process;


	

		
-- This process generates valid pulses for the WS2812 led strip
-- Works sequentially with the clock rising edge

process (CLK)  
begin 

	
if CLK'event and CLK = '1' then
	if RESET = '1' or BIT_PACK > 7 then  -- toggling of reset switch starts process of pulses generation
		CYCLE_CNTR <= (others => '0');	
		BIT_CNTR <= (others => '0'); 
		BIT_PACK <= (others => '0'); 
		RESET_FLAG <= '1'; 
		LED <= '0';	  			   -- when reset switch is in high state no pulses are generated
	else	 
		if RESET_FLAG = '1' then	-- when reset switch was toggled it means that single pulse should be generated all over again
			CYCLE_CNTR <= (others => '0');
			RESET_FLAG <= '0';
			LED <= '1';	-- every data pulse, which represents '0' or '1' starts with high state
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
		
		if CYCLE_CNTR = 13 then -- at the end of sequence (pulse) duration time
			LED <= '1';
			if BIT_CNTR = 23 and BIT_PACK = 7 then  -- case when sequence duration time has elapsed and the pulse was the last pulse in eight bit pack 
				LED <= '0';		
				RESET_CNTR <= RESET_CNTR + 1;  -- generation of >= 50 us reset code
				if RESET_CNTR = 7	then	-- end of reset code, pulse generation process starts all over again
					CYCLE_CNTR <= (others => '0');
					BIT_CNTR <= (others => '0'); 
					BIT_PACK <= (others => '0');
					RESET_CNTR <= (others => '0');
					LED <= '1';	 
				end if;
			elsif BIT_CNTR < 23 and BIT_PACK <= 7 then	-- case when sequence duration time has elapsed and the pulse was not the last in bit pack
				BIT_CNTR <= BIT_CNTR + 1;	 
				CYCLE_CNTR <= (others => '0');
			elsif BIT_CNTR = 23 and BIT_PACK < 7 then -- case when sequence duration time has elapsed and the pulse was the last in bit pack (not eight bit pack)
				BIT_CNTR <= (others => '0'); 
				CYCLE_CNTR <= (others => '0');	
				BIT_PACK <= BIT_PACK + 1;  
				LED <= '1';
			end if;
		end if;
	end if;
end if;

end process;

-- Transfer of value from switches to seven segment block

SELECT_R_OUT <= SELECT_R;
SELECT_G_OUT <= SELECT_G;
SELECT_B_OUT <= SELECT_B; 



end LED_RGB;