;---------------loader和kernel   ----------

LOADER_BASE_ADDR equ 0x900
LOADER_START_SECTOR equ 0x2

;--------------   gdt描述符属性  -------------
DESC_G_4K   equ	  1_00000000000000000000000b   	;G在段描述符第23位,将这里设为1,就是使用4K的密度
DESC_D_32   equ	   1_0000000000000000000000b	;D在段描述符第22位,将这里设为1,表示操作数使用32位
DESC_L	    equ	    0_000000000000000000000b	;L:段是否64位模式  64位代码标记，此处标记为0便可。
DESC_AVL    equ	     0_00000000000000000000b	;  cpu不用此位，暂置为0  
DESC_LIMIT_CODE2  equ 1111_0000000000000000b	;段界限,段的长度 limit
DESC_LIMIT_DATA2  equ DESC_LIMIT_CODE2		;
DESC_LIMIT_VIDEO2  equ 0000_000000000000000b	;段界限,设为0
DESC_P	    equ		  1_000000000000000b	;p:是否在内存中
DESC_DPL_0  equ		   00_0000000000000b	;DPL,为0的权限
DESC_DPL_1  equ		   01_0000000000000b
DESC_DPL_2  equ		   10_0000000000000b
DESC_DPL_3  equ		   11_0000000000000b
DESC_S_CODE equ		     1_000000000000b	;代码段
DESC_S_DATA equ	  DESC_S_CODE			;数据段,都是1,表示非系统段
DESC_S_sys  equ		     0_000000000000b
DESC_TYPE_CODE  equ	      1000_00000000b	;x=1,c=0,r=0,a=0 代码段是可执行的,非依从的,不可读的,已访问位a清0.  
DESC_TYPE_DATA  equ	      0010_00000000b	;x=0,e=0,w=1,a=0 数据段是不可执行的,向上扩展的,可写的,已访问位a清0.

DESC_CODE_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + DESC_P + DESC_DPL_0 + DESC_S_CODE + DESC_TYPE_CODE + 0x00				     ;代码段的平坦模型
DESC_DATA_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x00
DESC_VIDEO_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x0b

;--------------   选择子属性  ---------------
RPL0  equ   00b					;访问权限
RPL1  equ   01b
RPL2  equ   10b
RPL3  equ   11b
TI_GDT	 equ   000b				;访问GDT
TI_LDT	 equ   100b				;访问LDT

