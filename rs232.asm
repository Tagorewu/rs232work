 ;定义位变量 1602的控制口
RS		BIT		P1.2	
RW		BIT		P1.1
E		BIT		P1.0
;1602指令定义
CLR_SCREEN	EQU	01H		  	;清屏指令01H
CURSOR_ENTER	EQU	02H			;回车
DISPLAY_SET	EQU	38H 			;显示设定，显示2行，5*7点阵
SHOW_CURSOR	EQU	0FH			;打开显示和光标，光标闪烁
CURSOR_UNBLINK	EQU	0EH
CURSOR_RIGHT	EQU	14H			;光标向右移动一位
CURSOR_LEFT	EQU	10H			 ;光标向左移动一位
RIGHT_CURSOR	EQU	06H			 ;显示方向向右
LEFT_CURSOR	EQU	04H			 ;显示方向向左
CURSOR_FL	EQU	80H			;光标回到第一行开头
CURSOR_SL	EQU	0C0H			;光标回到第二行开头
;变量，缓存区设置
TIME_T0		EQU	20H	   	;存放T0次数
KEY_BUF		EQU	21H		;记录键值
TIME_KEY	EQU	22H		;记录1秒内按键次数
ORDER		EQU	23H		;指向当前字符缓存地址=#WORD_BUF+偏移量
INPUT_METHOD	EQU	24H		;存放输入法键状态	
WORD_BUF	EQU	50H		;存放ASCII语句
;---------------------------------------------------------------------------
	ORG	0000H
	AJMP	MAIN
	ORG	0003H
	AJMP	INT_0
	ORG	000BH
	AJMP	INT_T0
	ORG	0023H
	AJMP	INT_S
	ORG	00100H
MAIN:	MOV	SP,#60H
;串口，定时器初始化	   
	MOV	SCON,#50H	;串口方式1，REN=1
	MOV	TMOD,#21H     ;定时器1，方式2;定时器0，方式1，做1s定时
	MOV	TH0,#3CH
	MOV	TL0,#0AFH	;19*
	MOV	TIME_T0,#19H	  ;
	MOV	TH1,#0FDH	;晶振11.0592M,波特率19200
	SETB	ET0
	SETB	IT0		   ;IT0=1,边沿触发
	SETB	TR1
	ORL	PCON,#80H	   ;波特率加倍	
	SETB	ES
	SETB	EX0
;1602初始化
	MOV		P0,#01H			;清屏指令01H
	CALL	LOADC
	MOV		P0,#38H			;显示设定，显示2行，5*7点阵
	CALL	LOADC
	MOV		P0,#0FH			;打开显示和光标，光标闪烁
	CALL	LOADC
	MOV		P0,#06H			;光标向右移动
	CALL	LOADC
	MOV		P0,#80H			;光标回到第一行开头
	CALL	LOADC	
;变量初始化		
	MOV	KEY_BUF,#0FFH
	MOV	TIME_KEY,#00H
	MOV	ORDER,#WORD_BUF
	MOV	INPUT_METHOD,#00H		   
	SETB	EA
;循环		
LOOP:	ACALL	DELAY
	ACALL	KEY_IN		   
	SJMP	LOOP

;-----------INT_S;串口中断---------
INT_S:	 	JNB	RI,SEND
		ACALL	S_R_OK
		SJMP	EXIT
SEND:		ACALL	S_T_OK
EXIT:		RETI
;-------------S_T-------
S_T:		MOV	SBUF,P1
		JNB	TI,$	
		RET	
;------------SEND_BUF;发送WORD_BUF缓存区内容------
SEND_BUF:	
		MOV	R1,#WORD_BUF
LOOP_SEND:	MOV	SBUF,@R1
		JNB	TI,$
		CLR	TI
		CALL	DELAY
		CALL	DELAY
		INC	R1
		MOV	A,@R1		  
		JNZ	LOOP_SEND	  ;空字符停止发送
		RET		
;----------S_T_OK-----------
S_T_OK:		CLR	TI
		RET
;------------S_R--------
S_R:		CLR	RI
		RET
;----------S_R_OK---------
S_R_OK:		CLR	RI
		MOV	WORD_BUF,SBUF	;只显示接收内容不存入内存	
		MOV	P0,WORD_BUF
		CALL	DISPLAY
		RET
;------------INT_0;发送按键ISP----------
INT_0: 		CLR	EX0
		CLR	IE0	
		ACALL 	SEND_BUF		
		MOV	ORDER,#WORD_BUF	     ;发送完指针指向基址，并不清除缓存
		SETB	EX0
		RETI
;--------GET_KEY;键盘处理程序-------------
;扫描是否有键
KEY_IN:    MOV  	P2,#0F0H    ;高四位作为输入  置行线为高电平 , 列线为低电平
           MOV  	A,P2
           ANL  	A,#0F0H		;屏蔽低四位
           MOV  	B,A
           MOV  	P2,#0FH     ;低四位作为输入  ;置列线为高电平，行线为低电平
           MOV  	A,P2
           ANL  	A,#0FH
           ORL  	A,B               ;高四位与低四位重新组合
	   MOV		R0,A
           CJNE  	A,#0FFH,KEY_S  ;不等表示有键，延时继续查消除抖动;0FFH为未按键
           RET 
;有键消抖动
KEY_S:	   ACALL	DELAY
	   MOV	  	P2,#0F0H    ;高四位作为输入  置行线为高电平 , 列线为低电平
           MOV  	A,P2
           ANL  	A,#0F0H		;屏蔽低四位
           MOV  	B,A
           MOV  	P2,#0FH     ;低四位作为输入  ;置列线为高电平，行线为低电平
           MOV  	A,P2
           ANL  	A,#0FH
           ORL  	A,B               ;高四位与低四位重新组合	
           CJNE  A,00H,RET_KEY  ;00H表示R0,未按键跳至返回
	   ACALL	KEY_IN1
RET_KEY:	RET
;确实有键，查表取序号	   
KEY_IN1:   
	   MOV  B,A	      ;扫描到的键码存B内
           MOV  DPTR,#KEYTABLE		     ;查键码序号
           MOV  R3,#0FFH
KEY_IN2:   INC  R3
           MOV  A,R3
           MOVC  A,@A+DPTR
           CJNE  A,B,KEY_IN3
	   SJMP	 GET_KEY_ORDER	       ;查到序号R3,跳转
KEY_IN3:   CJNE  A,#00H,KEY_IN2         ;00H为结束码
           RET  
;查到顺序码
GET_KEY_ORDER:	  
 	   CJNE	R3,#09,KEY_CLR_SCR	   
 ;是左移键
	   MOV	P0,#CURSOR_LEFT
	   CALL	LOADC
	   DEC	ORDER	  
	   RET                  
;判断清屏键
 KEY_CLR_SCR:	CJNE	R3,#10,KEY_INPUT_METHOD
 		MOV	P0,#CLR_SCREEN	      ;调用清屏命令
		CALL	LOADC
		;循环清除缓存区
		MOV	R0,ORDER	    ;ORDER指向了当前缓存地址
		MOV	@R0,#00H
C_LOOP_KEY_CLR:	CJNE	A,#50H,LOOP_KEY_CLR
		JMP	RET_KEY_SCR
LOOP_KEY_CLR:	DEC	ORDER
		MOV	R0,ORDER
		MOV	@R0,#00H
		MOV	A,ORDER
		JMP    C_LOOP_KEY_CLR				
RET_KEY_SCR:		RET
;输入法选择键
KEY_INPUT_METHOD:	CJNE	R3,#11,OTHER_KEY
			INC	INPUT_METHOD
			RET

;其他非功能键
OTHER_KEY:     	MOV  A,R3            	;取顺序码	   
	    
	    	JNB	TR0,NEW_KEY		;是否有计时								
	   	;还在1S内
	   	CJNE		A,KEY_BUF,DIR_NEW_KEY	   ;与之前值比较。否，跳至确认旧键完成，保存新键
	;还是原键 未超过1S，按键次数加1
	 	;重新计1S
		MOV	TIME_T0,#19
	   	INC	TIME_KEY
		;显示	
		CALL	WORD_TRAN
		MOV	R0,ORDER	  ;ORDER为当前缓存区指针
		MOV	P0,@R0
		CALL	DISPLAY
		MOV	P0,#CURSOR_LEFT
		CALL	LOADC 		   	
		RET
;1S未过就有新键
DIR_NEW_KEY:	
		;重新计时		
		MOV	TIME_T0,#19
		SETB	TR0
		;直接保存旧值

		CALL	WORD_TRAN
		INC	ORDER		;缓存区指针加1
		MOV	R0,ORDER
		MOV	P0,@R0
		MOV	P0,#CURSOR_RIGHT       ;光标强制右移
		CALL	LOADC
		

		;记录新值
		MOV	KEY_BUF,R3 
		MOV	TIME_KEY,#0
		;显示新值	
		CALL	WORD_TRAN
		MOV	R0,ORDER
		MOV	P0,@R0
		CALL	DISPLAY
		MOV	P0,#CURSOR_LEFT
		CALL	LOADC 
//		MOV	P0,#RIGHT_CURSOR
//		CALL	LOADC			
		RET
;1s过后的新键	  		   
NEW_KEY:	SETB	TR0	 ;开始1S计时 
		;保存新键		
		MOV	KEY_BUF,R3
		MOV	TIME_KEY,#00H

		;显示新键
		CALL	WORD_TRAN
		MOV	R0,ORDER
		MOV	P0,@R0
		CALL	DISPLAY	
		MOV	P0,#CURSOR_LEFT
		CALL	LOADC	   	  	   	  
          	RET	           	
;--------- INT_T0---------
INT_T0: 						
		;重新装载
		MOV	TH0,#3CH
		MOV	TL0,#0AFH	;19*
		
		DJNZ	TIME_T0,RET_T0	   ;是否到1S
		;1S到
       		MOV	TIME_T0,#19	 ;1秒到，关闭定时器0 
		CLR	TR0		
		CALL	WORD_TRAN
		INC	ORDER
		MOV	P0,#CURSOR_RIGHT
		CALL	LOADC	
		
RET_T0:		RETI
;----------WORD_TARN;根据键值与次数转换成ASCII存入缓存------------
WORD_TRAN:	;查询当前输入法键值，根据不同输入法查不同表
		MOV	A,INPUT_METHOD
		MOV	B,#03H
		DIV	AB
		MOV	A,B
		CJNE	A,#00H,NEXT_INPUT1
		MOV	DPTR,#WORD_KEY_TABLE0
		JMP	INPUT_LOAD
NEXT_INPUT1:	CJNE	A,#01H,NEXT_INPUT2
		MOV	DPTR,#WORD_KEY_TABLE1
		JMP	INPUT_LOAD
NEXT_INPUT2:	MOV	 DPTR,#WORD_KEY_TABLE2
INPUT_LOAD:	MOV	A,KEY_BUF
		;查表
		MOVC	A,@A+DPTR	;ASCII值放A
		ADD	A,TIME_KEY	;加上次数
		;将ASCII放入ORDER所指的缓存
		MOV	R0,ORDER
		MOV	@R0,A		      	
		RET	
;-------DELAY-----		  
DELAY:	MOV	R6,#050H
AA1:	MOV	R7,#0FFH
AA:		NOP
		DJNZ	R7,AA
		DJNZ	R6,AA1
		RET
;---------1602子程序---------------------
;---------          ------------------
LOADC:	//控制命令装载子程序
	CLR		RS				;RS=0，写命令
	CLR		RW				;RW=0，写入
	CLR		E				;一个下降沿，DB0~DB7口数据被读入

	CALL	DELAY_1602
	SETB	E				;屏蔽DB口数据
	RET

DISPLAY://数据显示子程序
	SETB		RS		;RS=1，数据
	CLR		RW		;写入
	CLR		E		;数据被读入

	CALL	DELAY_1602
	SETB	E			;屏蔽DB口数据
	RET

DELAY_1602:
	MOV		R6,#200
D1:
	MOV		R7,#248
D2:
	DJNZ	R7,D2
	DJNZ	R6,D1

	RET
		
;-----------------------------------------------------
//;	   0   1	2	   3	 4	 5	   6	 7	   8	 9	10    11	结束标示  
KEYTABLE:	DB	0EEH,0DEH,0BEH
		DB	0EDH,0DDH,0BDH
		DB	0EBH,0DBH,0BBH
		DB	0E7H,0D7H,0B7H
		DB	00H
WORD_KEY_TABLE0:	DB	' ','A','D','G','J','M','P','T','W'
WORD_KEY_TABLE1:	DB	' ','a','d','g','j','m','p','t','w'
WORD_KEY_TABLE2:	DB	'0','2','3','4','5','6','7','8','9'	
	END