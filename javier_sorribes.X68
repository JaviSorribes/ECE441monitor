*-----------------------------------------------------------
* Title      : Monitor Design Project
* Written by : Javier Sorribes
* Date       : 4/2/17
* Description: Some crazy, crazy stuff
*-----------------------------------------------------------
*** MEMORY INITIALIZATION ***
    ORG     $1000       ; stack and other memory
; $A is newline, $D carriage return, $20 whitespace
WELCOME     DC.B    'WELCOME TO MONITOR441! - BY JAVIER SORRIBES',0
PROMPT_STR  DC.B    $A,$D,'MONITOR441>',0 ; might want to add one space
INVALID_MSG DC.B    'INVALID COMMAND',$A,$D
            DC.B    'Type HELP for command usage',0

COM_TABL    DC.B    '4HELP',0   ; Command names table
            DC.B    '4MDSP',$20  ; number specifies length of word 
            DC.B    '2MM',0       ; used for SEARCH (not input)
            DC.B    '4EXIT',0
            
COM_ADDR    DC.W    HELP        ; Command addresses table
            DC.W    MDSP
            DC.W    MM
            DC.W    EXIT
            
HELP_MSG    DC.B    'HELP: Displays this message',$A,$A,$D
            DC.B    'MDSP: Outputs Address And Memory Contents',$A,$D
            DC.B    'Default address2: address1 + 16',$A,$D
            DC.B    'MDSP <address1>[ <address2>] eg: MDSP $908 $904<CR>',$A,$A,$D
            DC.B    'MM: Modifies Data In Memory',$A,$D
            DC.B    'Default: Displays one byte',$A,$D
            DC.B    ';W: Displays One Word',$A,$D
            DC.B    ';L: Displays One Long Word',$A,$D
            DC.B    'MM <address>[;size]',$A,$A,$D
            ** Add all others as I go
            DC.B    'EXIT: Exit the monitor program eg: EXIT<CR>',0
            
*** RUNNING PROGRAM ***
    ORG     $1200
START:                  ; first instruction of program

MAX_IN_LEN  EQU 80  ; to ensure input won't overflow stack
STACK       EQU $3000
        LEA     STACK,A7
        MOVEM.L D0-D7/A0-A6,-(A7)   ; store all registers in stack. Want to be able to display them

        **Populate exception vector table
        
*** MAIN: Prompt, execute and repeat ***
        LEA     WELCOME,A1
        MOVE.B  #13,D0
        TRAP    #15
PROMPT  LEA     PROMPT_STR,A1  
        MOVE.B  #14,D0
        TRAP    #15     ; print out prompt
        SUBA.L  #MAX_IN_LEN,A7  ; open space in stack for input -- COULD GO BEFORE PROMPT (REF #1)
        MOVEA.L A7,A1   ; input will go in stack
        MOVE.B  #2,D0
        TRAP    #15     ; read user input, length stored in D1
        
        LEA     COM_TABL,A4 ; beginning of command table
        LEA     COM_ADDR,A5 ; end of command table
        CLR.L   D3      ; will be the count of where the command is
SEARCH  CLR.L   D2
        MOVE.B  (A4)+,D2   ; length of next command string
        SUBI.B  #$30,D2 ; convert ascii num to hex
        MOVEA.L A1,A6   ; pointer to input string
CMP_B   CMPM.B  (A4)+,(A6)+ ; compare byte to byte with command names
        DBNE    D2,CMP_B    ; keep comparing characters until length is over
        TST.W   D2
        BLT     EXEC    ; loop was exhausted and all chars were equal
        ADDA.L  D2,A4   ; go to end of command
        ADDQ.L  #2,D3   ; else, increment offset by word size
        CMPA.L  A4,A5 ; end of COM_TABL
        BGE     SEARCH  ; keep on searching
        
        BSR     INVALID ; print invalid command message
        BRA     ENDLOOP ; prompt again
        
EXEC    ADDA.L  D3,A5   ; add offset to COM_ADDR start
        MOVEA.L #0,A3   ; clear A3, used for subroutine call
        MOVEA.W (A5),A3 ; move that command's address to register
        JSR     (A3)    ; jump to that command's subroutine (below)

ENDLOOP ADDA.L  #MAX_IN_LEN,A7  ; move stack back to position prior to reading input -- COULD GO IN EXIT SUBROUTINE (REF #1)
        BRA     PROMPT  ; prompt again

*** DEBUGGING COMMANDS ***
HELP    MOVEM.L D0/A1,-(A7) ; store used registers in stack
        LEA     HELP_MSG,A1  
        MOVE.B  #13,D0
        TRAP    #15     ; print help message
        MOVEM.L (A7)+,D0/A1 ; restore registers from stack
        RTS
        
* For this subroutine and others, A6 contains the start of the command's parameters
* eg: MDSP $1230 $1890 <- A6 points to the first '$'
MDSP    MOVEM.L D0-D3/A1-A3,-(A7)
        MOVE.B  (A6)+,D1    ; first '$'
        CMPI.B  #$24,D1
        BNE     MDSPINV ; wrong command usage
        BSR     MEM2HEX ; D1 has 1st address in hex
        MOVEA.L #0,A2   ; CLR.L A2 (not allowed)
        MOVEA.W D1,A2
        MOVE.B  (A6)+,D1    ; space in between addresses
        TST.B   D1  ; if null, no 2nd address, so address2 = address1 + 16
        BNE     MDSPADDR2
        MOVEA.L A2,A3
        ADDA.L  #16,A3  ; A3 = A2 +16
        BRA     MDSPLOOP
MDSPADDR2   MOVE.B  (A6)+,D1    ; second '$'
        CMPI.B  #$24,D1
        BNE     MDSPINV
        BSR     MEM2HEX ; D1 has 2nd address in hex
        MOVEA.L D1,A3
MDSPLOOP    MOVEA.L A7,A1
        SUBA.L  #$40,A1 ; move A1 far from A7 to avoid collision in subroutines
        MOVE.B  #$00,-(A1) ; null terminator
        MOVE.B  #$20,-(A1)  ; space
        MOVE.B  #$3E,-(A1)  ; '<' for nicer output
        MOVE.L  A2,D1
        BSR     HEX2MEM ; puts digits of D1 into -8(A1) in ascii
        MOVE.B  #$24,-(A1)  ; '$' for nicer output
        MOVE.B  #14,D0
        TRAP    #15     ; print current memory address
        ;MOVEA.L A7,A1   ; write on top to leverage memory usage
        MOVE.B  #$00,-(A1) ; null terminator
        MOVE.B  #$20,-(A1)  ; space
        MOVE.L  (A2)+,D1
        BSR     HEX2MEM ; puts digits of D1 into -8(A1) in ascii
        MOVE.B  #13,D0
        TRAP    #15
        CMPA.L  A2,A3
        BGT     MDSPLOOP
        BRA     MDSPDONE
MDSPINV BSR     INVALID ; print invalid command message
MDSPDONE    MOVEM.L (A7)+,D0-D3/A1-A3
        RTS

MM    
        RTS

EXIT    MOVE.B  #9, D0
        TRAP    #15     ; exit program

*** HELPERS ***
* Print INVALID message:
INVALID MOVEM.L D0/A1,-(A7)
        LEA     INVALID_MSG,A1  ; command was invalid
        MOVE.B  #13,D0
        TRAP    #15     ; output invalid command
        MOVEM.L (A7)+,D0/A1
        RTS

* Takes 4 digits from (A6) in ascii and puts them in D1 as hex: -- COULD MAKE IT TAKE X DIGITS (REF #2)
MEM2HEX MOVEM.L D0/D7,-(A7)    ; store in stack
        MOVE.L  #4,D0   ; number of digits
        CLR.L   D1
M2HNEXT MOVE.B (A6)+,D7    ; read in next byte
        BSR     BYTE2HEX    ; byte to hex digit, in D7
        ADD.B   D7,D1
        SUBQ.L  #1,D0   ; decrement counter
        BEQ     MEM2HEXDONE ; done
        ASL.L   #4,D1   ; skip this the last time
        BRA     M2HNEXT ; loop again because not done
MEM2HEXDONE  MOVEM.L (A7)+,D0/D7    ; restore from stack
        RTS

* Takes byte in ascii in D7 and converts it to hex in D7:
* Assumes 0-9 or A-F
BYTE2HEX CMPI.B #$40,D7
        BLT B2HSKIPPY
        SUBQ.B  #$7,D7   ; only for A-F
B2HSKIPPY   SUB.B   #$30,D7
        RTS
        
* Takes 8 digits from D1 in hex and puts them into -8(A1) in ascii:
HEX2MEM MOVEM.L D0/D2/D7,-(A7)    ; store in stack
        CLR.L   D0   ; counter
H2MNEXT MOVE.L  D1,D7
        ;MOVE.L  D0,D2
;H2MLEFT LSL.L   #4,D7    ; move by corresponding amount so at top
 ;       SUBQ.W  #1,D2
  ;      BGT     H2MLEFT
        MOVE.L D0,D2
H2MRIGHT    SUBQ.W  #1,D2
        BLT     H2MDONE
        LSR.L   #4,D7   ; that upper byte to lowest by -> only one left
        BRA     H2MRIGHT
H2MDONE BSR     HEX2BYTE ; convert to ascii in D7
        MOVE.B  D7,-(A1)
        ADDQ.W  #1,D0
        CMPI.W  #8,D0
        BLT     H2MNEXT
        MOVEM.L (A7)+,D0/D2/D7
        RTS

* Takes hex digit in D7 and converts it to ascii byte in D7:
* Assumes 0-9 or A-F
HEX2BYTE AND.L  #$0F,D7 ; mask and take only smallest hex digit
        CMPI.B  #$A,D7
        BLT H2BSKIPPY
        ADDQ.B  #$7,D7   ; only for A-F
H2BSKIPPY   ADD.B   #$30,D7
        RTS

    END     START        ; last line of source














*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
