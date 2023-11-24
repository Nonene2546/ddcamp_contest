----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Filename     UserRdDdr.vhd
-- Title        Top
--
-- Company      Design Gateway Co., Ltd.
-- Project      DDCamp
-- PJ No.       
-- Syntax       VHDL
-- Note         

-- Version      1.00
-- Author       B.Attapon
-- Date         2017/12/20
-- Remark       New Creation
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

Entity UserRdDdr Is
    Port
    (
        RstB            : in    std_logic;                          -- use push button Key0 (active low)
        Clk             : in    std_logic;                          -- clock input 100 MHz

        DipSwitch       : in    std_logic_vector( 1 downto 0 );     -- Input dip switch for setting address

        -- HDMICtrl I/F
        HDMIReq         : out   std_logic;                         
        HDMIBusy        : in    std_logic;                          

        -- RdCtrl I/F
        MemInitDone     : in    std_logic;                         
        MtDdrRdReq      : out   std_logic;                          -- DDR read request ('1' when you want to request reading)
        MtDdrRdBusy     : in    std_logic;                          -- input from ddr indicate that it has accept request if '1' or ready for new request if '0'
        MtDdrRdAddr     : out   std_logic_vector( 28 downto 7 );    -- DDR read address (address you want to read)

        -- D2URdFf I/F
        D2URdFfWrEn     : in    std_logic;                         
        D2URdFfWrData   : in    std_logic_vector( 63 downto 0 );    
        D2URdFfWrCnt    : out   std_logic_vector( 15 downto 0 );    

        -- URd2HFf I/F
        URd2HFfWrEn     : out   std_logic;                          
        URd2HFfWrData   : out   std_logic_vector( 63 downto 0 );    
        URd2HFfWrCnt    : in    std_logic_vector( 15 downto 0 )     
    );
End Entity UserRdDdr;

Architecture rtl Of UserRdDdr Is

----------------------------------------------------------------------------------
-- Component declaration
----------------------------------------------------------------------------------
    -- No components declared for this architecture

----------------------------------------------------------------------------------
-- Signal declaration
----------------------------------------------------------------------------------
    
    signal  rMemInitDone    : std_logic_vector( 1 downto 0 );         
    signal  rHDMIReq        : std_logic;                             
    
    signal  rMtDdrRdReq     : std_logic;                            -- Memory read request signal
    signal  rMtDdrRdAddr    : std_logic_vector(28 downto 7);        -- Memory read address signal
    
    type SerStateType is 
                    (
                        stInit,  -- Initialization state
                        stReq,   -- Request state (Request read then wait for ddr to accept request -> MtDdrRdBusy = '1')
                        stAddr,  -- Changing the address
                        stEnd    -- End state (wait ddr to be ready for a new request)
                    );
                        
    signal rState      : SerStateType;                              -- State variable

Begin

----------------------------------------------------------------------------------
-- Output assignment
----------------------------------------------------------------------------------

    HDMIReq         <= rHDMIReq;                                     
    
    URd2HFfWrEn     <= D2URdFfWrEn;                               
    URd2HFfWrData   <= D2URdFfWrData;                           
    D2URdFfWrCnt    <= URd2HFfWrCnt;                          
    
    MtDdrRdReq      <= rMtDdrRdReq;                             
    MtDdrRdAddr(28 downto 7)     <= rMtDdrRdAddr(28 downto 7);                              
    
----------------------------------------------------------------------------------
-- DFF 
----------------------------------------------------------------------------------

    u_rMemInitDone : Process (Clk) Is
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rMemInitDone    <= "00";                                
            else
                -- Use rMemInitDone(1) in your design
                rMemInitDone    <= rMemInitDone(0) & MemInitDone;       
            end if;
        end if;
    End Process u_rMemInitDone;

    u_rHDMIReq : Process (Clk) Is
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rHDMIReq    <= '0';                                     
            else
                if (HDMIBusy = '0' and rMemInitDone(1) = '1') then
                    rHDMIReq    <= '1';                                 
                elsif (HDMIBusy = '1')  then
                    rHDMIReq    <= '0';                                 
                else
                    rHDMIReq    <= rHDMIReq;
                end if;
            end if;
        end if;
    End Process u_rHDMIReq;
    
    u_rState : Process(Clk) Is
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rState <= stInit;                                       -- Reset state machine on active-low reset
            else
                case (rState) Is
                    when stInit =>
                        if (rMemInitDone(1) = '1') then
                            rState <= stReq;                           -- Transition to idle state after memory initialization
                        else
                            rState <= stInit;                           -- Stay in initialization state otherwise
                        end if;
                    
                    when stReq =>
                        if (MtDdrRdBusy = '1') then
                            rState <= stAddr;                           -- Transition to address state if MtDdrWrBusy = '1' (ddr has accept request)
                        else
                            rState <= stReq;                           -- Stay in idle state otherwise
                        end if;
                    
                    when stAddr =>
                        rState <= stEnd;                                
                        
                    when stEnd =>
                        if (MtDdrRdBusy = '0') then
                            rState <= stReq;                          -- Transition back to idle state when ddr read is ready for a new request
                        else
                            rState <= stEnd;                           -- Stay in end state otherwise
                        end if;
                        
                end case;
            end if;
        end if;
    end process;
    
    u_rMtDdrRdReq : process(Clk) Is
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rMtDdrRdReq <= '0';                                     -- Clear memory read request on active-low reset
            elsif (rState = stReq) then
                rMtDdrRdReq <= '1';                                     -- Set memory read request in request state
            else
                rMtDdrRdReq <= '0';                                     -- Clear memory read request otherwise
            end if;
        end if;
    end process;
    
    u_rMtDdrRdAddr : Process(Clk) Is
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rMtDdrRdAddr(28 downto 7) <= (others => '0');           -- Reset memory read address on active-low reset
            elsif (rState = stAddr) then
                if (rMtDdrRdAddr(26 downto 7) = "101" & x"FFF") then
                    rMtDdrRdAddr(28 downto 7) <= (others => '0');                   -- Reset memory read address when reaching the maximum value
                else
                    rMtDdrRdAddr(26 downto 7) <= rMtDdrRdAddr(26 downto 7) + 1;  -- If not, Increment memory read address
                end if;
            elsif (rState = stReq) then
                rMtDdrRdAddr(28 downto 27) <= DipSwitch(1 downto 0);    -- On state request, set first 2 bits (picture no.) based on dip switch
            end if;
        end if;
    end process;
    
End Architecture rtl;
