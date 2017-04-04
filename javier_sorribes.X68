*-----------------------------------------------------------
* Title      : Monitor Design Project
* Written by : Javier Sorribes
* Date       : 4/2/17
* Description: Some crazy, crazy stuff
*-----------------------------------------------------------
    ORG     $1000       ; stack and other memory
PROMPT_STR  DC.B    'MONITOR441>',0 ; might want to add one space
INVALID     DC.B    'INVALID COMMAND',0

COM_TABL    DC.B    '4HELP',0   ; Command names table
            DC.B    '4MDSP',0  ; number specifies length of word 
            DC.B    '4MTST',0       ; used for SEARCH (not input)
            DC.B    '4EXIT',0
            
COM_ADDR    DC.W    HELP        ; Command addresses table
            DC.W    MDSP
            DC.W    MTST
            DC.W    EXIT

    ORG     $1200
START:                  ; first instruction of program

MAX_IN_LEN  EQU 80  ; to ensure input won't overflow stack
STACK       EQU $3000
        LEA     STACK,A7

        **Populate exception vector table
        
*** MAIN: Prompt, execute and repeat ***
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
        
        LEA     INVALID,A1  ; command was invalid
        MOVE.B  #13,D0
        TRAP    #15     ; output invalid command
        BRA     ENDLOOP ; prompt again
        
EXEC    ADDA.L  D3,A5   ; add offset to COM_ADDR start
        MOVEA.L #0,A6   ; clear A6
        MOVEA.W (A5),A6 ; move that command's address register
        JSR     (A6)    ; jump to that command's subroutine (below)

ENDLOOP ADDA.L  #MAX_IN_LEN,A7  ; move stack back to position prior to reading input -- COULD GO IN EXIT SUBROUTINE (REF #1)
        BRA     PROMPT  ; prompt again

*** DEBUGGING COMMANDS ***
HELP    
        RTS
        
MDSP    
        RTS

MTST    
        RTS

EXIT    MOVE.B  #9, D0
        TRAP    #15     ; exit program

    END     START        ; last line of source












*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
