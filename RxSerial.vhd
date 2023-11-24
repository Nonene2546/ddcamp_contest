library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

Entity RxSerial Is  
Port(
  RstB        : in    std_logic;                        -- Reset input
  Clk         : in    std_logic;                        -- Clock input
    
  SerDataIn   : in    std_logic;                        -- Serial data input
  
  RxFfFull    : in    std_logic;                        -- Receiver FIFO full indicator
  RxFfWrData  : out   std_logic_vector(7 downto 0);     -- Receiver FIFO write data output
  RxFfWrEn    : out   std_logic                         -- Receiver FIFO write enable output
);
End Entity RxSerial;

Architecture rtl Of RxSerial Is

----------------------------------------------------------------------------------
-- Constant declaration
----------------------------------------------------------------------------------

	constant	cBaudRate		:	integer	:=	108;

----------------------------------------------------------------------------------
-- Signal declaration
----------------------------------------------------------------------------------
	type SerStateType is
		(
			stRst	, -- Idle state (reset baud rate counter)
			stStart	, -- Start bit detection state
			stData	, -- Data bit reception state
			stStop	, -- Stop bit detection state
			stLoad    -- Load data to FIFO state
		);
	signal rState : SerStateType;                           -- State variable
	
	signal	rSerDataIn	: std_logic;                        -- Registered serial data input

	signal	rBaudCnt	: std_logic_vector(6 downto 0);     -- Baud rate counter
	signal	rBaudEnd	: std_logic;                        -- Flag indicating the end of a baud period

	signal	rDataCnt	: std_logic_vector(2 downto 0);     -- Data bit counter

	signal	rRxFfWrData	: std_logic_vector(7 downto 0);     -- Data to be written to the FIFO
	signal	rRxFfWrEn	: std_logic;                        -- FIFO write enable signal

Begin

----------------------------------------------------------------------------------
-- Output assignment
----------------------------------------------------------------------------------
	RxFfWrData(7 downto 0)	<=	rRxFfWrData(7 downto 0);
	RxFfWrEn	<=	rRxFfWrEn;


----------------------------------------------------------------------------------
-- DFF 
----------------------------------------------------------------------------------


	------------------------------
	--	Counter
	------------------------------

	u_rBaudCnt: process(Clk)
	begin
		if (rising_edge(Clk)) then
			if (RstB = '0') then
				rBaudCnt(6 downto 0)	<=	(others => '0'); 	-- Reset counter on active-low reset
			elsif (rBaudCnt(6 downto 0) = conv_std_logic_vector(cBaudRate,10)) then
				rBaudCnt(6 downto 0)	<=	(others => '0'); 	-- Reset counter at the end of a baud period
			elsif (rState = stStart and rBaudCnt(5) = '1') then
				rBaudCnt(6 downto 0)	<=	(others => '0'); 	-- Reset counter at the middle of the start bit
			elsif (rState = stRst) then
				rBaudCnt(6 downto 0)	<=	(others => '0'); 	-- Reset counter in idle state
			else
				rBaudCnt(6 downto 0)	<=	rBaudCnt(6 downto 0) + 1;		-- Increment counter otherwise
			end if;
		end if;
	end process u_rBaudCnt;

	u_rBaudEnd: process(Clk)
	begin
		if (rising_edge(Clk)) then
			if (RstB = '0') then
				rBaudEnd	<=	'0'; -- Clear flag on active-low reset
			elsif (rBaudCnt(6 downto 0) = conv_std_logic_vector(cBaudRate,10)) then
				rBaudEnd	<=	'1'; -- Set flag at the end of a baud period
			else 
				rBaudEnd	<=	'0'; -- Clear flag otherwise
			end if;
		end if;
	end process u_rBaudEnd;

	u_rDataCnt: process(Clk)
	begin
		if (rising_edge(Clk)) then
			if (RstB = '0') then
				rDataCnt(2 downto 0) <= (others => '0'); -- Reset data counter on active-low reset
			else
				if (rBaudEnd = '1') then
					if (rDataCnt(2 downto 0) = 7) then
						rDataCnt(2 downto 0) <= (others => '0'); -- Reset data counter at the end of 8 bits
					else
						rDataCnt(2 downto 0) <= rDataCnt(2 downto 0) + 1; -- Increment data counter otherwise
					end if ;
				elsif (rState = stStart) then
					rDataCnt(2 downto 0) <= (others => '0'); -- Reset data counter in the start state
				else
					rDataCnt(2 downto 0) <=	rDataCnt(2 downto 0); -- Maintain data counter otherwise
				end if;
			end if;
		end if;
	end process u_rDataCnt;

	------------------------------
	--	Shift Register
	------------------------------

	u_rSerDataIn : Process (Clk) Is
	Begin
		if (rising_edge(Clk)) then
			rSerDataIn		<= SerDataIn; -- Register the incoming serial data
		end if;
	End Process u_rSerDataIn;

	u_rRxFfWrData: process(Clk)
	begin
		if (rising_edge(Clk)) then
			if (RstB = '0') then
				rRxFfWrData(7 downto 0)	<=	(others => '0'); -- Clear FIFO write data on active-low reset
			else
				if (rBaudEnd = '1' and rState /= stStop) then	
					rRxFfWrData(7 downto 0) <= rSerDataIn & rRxFfWrData(7 downto 1); -- Shift in data
				else
					rRxFfWrData(7 downto 0) <= rRxFfWrData(7 downto 0); -- Maintain data otherwise
				end if;
			end if;
		end if;
	end process u_rRxFfWrData;

	u_rRxFfWrEn: process(Clk)
	begin
		if (rising_edge(Clk)) then
			if (RstB = '0') then
				rRxFfWrEn	<=	'0'; -- Clear FIFO write enable on active-low reset
			elsif (rState = stLoad) then
				rRxFfWrEn	<=	'1'; -- Set FIFO write enable in the load state
			else
				rRxFfWrEn	<=	'0'; -- Clear FIFO write enable otherwise
			end if;
		end if;
	end process u_rRxFfWrEn;
	------------------------------
	--	State Machine
	------------------------------

	u_rState : process(Clk)
	begin
		if rising_edge(Clk) then
			if (RstB = '0') then
				rState <= stRst; -- Reset state machine on active-low reset
			else
				case (rState) is
					when stRst =>
						if (rSerDataIn = '0') then
							rState <= stStart; -- Transition to start state on detecting a start bit
						else
							rState <= stRst; -- Stay in idle state otherwise
						end if;
					
					when stStart =>
						if (rBaudCnt(5) = '1') then
							rState <= stData; -- Transition to data state at the middle of the start bit
						else
							rState <= stStart; -- Stay in start state otherwise
						end if;
					
					when stData =>
						if (rDataCnt(2 downto 0) = 7 and rBaudEnd = '1') then
							rState <= stStop; -- Transition to stop state after receiving 8 bits of data
						else
							rState <= stData; -- Stay in data state otherwise
						end if;
					
					when stStop =>
						if (rBaudEnd = '1') then
							if (rSerDataIn = '1') then
								rState <= stLoad; -- Transition to load state on detecting a stop bit
							else
								rState <= stRst; -- Return to idle state if no stop bit is detected
							end if;
						else
							rState <= stStop; -- Stay in stop state otherwise
						end if;
					
					when stLoad	=>
						rState <= stRst; -- Transition back to idle state after loaded
					
				end case;
	
			end if;
		end if;
	end process u_rState;

End Architecture rtl;