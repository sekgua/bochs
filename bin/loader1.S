	%include "boot.inc"
	section loader vstart=LOADER_BASE_ADDR
	LOADER_STACK_TOP equ LOADER_BASE_ADDR	;保护模式下的栈
	;jmp loader_start

;构建 gdt 及其内部的描述符
	GDT_BASE: dd 0x00000000		;GDT的第0个段不可用
		  dd 0x00000000
	; 定义了三个有用的段描述符
	CODE_DESC: dd 0x0000FFFF	;段描述符的低4字节,其中的低2字节是段长度 FFFF,高2字节是段基址 0000,
		  dd DESC_CODE_HIGH4	;代码段的高四节,已经定义好了

	DATA_STACK_DESC: dd 0x0000FFFF	;数据段和栈段的段描述符
			 dd DESC_DATA_HIGH4
;显存段描述符,0xb8000~0xbffff是用于文本模式的显示内存,段基址:0x8000 长度 0007
VIDEO_DESC:	  dd 0x80000007		;limit=(0xbffff-0xb8000)/4k = 0x7	4k是段粒度
		  dd DESC_VIDEO_HIGH4	;此时dpl为0

	GDT_SIZE equ $ - GDT_BASE	;19~20 获取GDT的大小,为加载GDT做准备
	GDT_LIMIT equ GDT_SIZE - 1
	times 60 dq 0			;此处预留60个描述符的空位,为了将来往GDT中添加其它描述符,提前保留空间
	;jmp_align times 254 db 0     ;254+jmp_2bite=256B
	total_mem_bytes dd 0    ;0xb00
	SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0	;相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0,构建代码段的段选择子,段描述符+TI+PRL
	SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0	;同上
	SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	;同上

	;以下是gdt的指针,前2字节是gdt界限,后四字节是gdt起始地址

	gdt_ptr dw GDT_LIMIT		;定义GDT的指针.前16位,是GDT以字节为单位的长度,也就是GDT大小减1
		dd GDT_BASE		;GDT的起始位置
    ards_buf times 227 db 0 ;244-17
	ards_nr dw 0
	loadermsg db '2 loader in real.' ;17B
	
	loader_start:

;--------------------------------------------------
;INT 0x10 功能号:0x13 功能描述:打印字符串
;--------------------------------------------------
;输入
;AH 子功能号=13H
;BH = 页码
;BL = 属性(若AL=00H或01H)
;CX = 字符串的长度
;(DH,DL) = 坐标(行,列)
;ES:BP=字符串的地址
;AL=显示输出方式
;	0--字符串中只含显示字符,其显示属性在BL中,显示后,光标位置不变
;	1--字符串中只含显示字符,其显示属性在BL中,显示后,光标位置改变
;	2--字符串中含显示字符和显示属性.显示后,光标位置不变
;	3--字符串中含显示字符和显示休息,显示后,光标位置改变
;无返回值
	mov sp,LOADER_BASE_ADDR
	mov bp,loadermsg		;ES:BP = 字符串地址
	mov cx,17			;字符串长度
	mov ax,0x1301			;AH = 13,AL=01h
	mov bx,0x001f			;页号为0(BH = 0) 蓝底粉红字(BL = 1fh)
	mov dx,0x1800			;dh=18h=24行,dl=0,最后一行的行首
	int 0x10			;10h 号中断


; int l5h eax = OOOOE820h ,edx = 534D4150h ('SMAP ’）获取内存布局
    xor ebx, ebx
	mov edx, 0x534d4150
	mov di, ards_buf ;es:di
	mov ax,0
	mov es,ax
.e820_mem_get_loop:
	mov eax, 0x0000e820
	mov ecx, 20
	int 0x15
	jc .e801 ;cf=0 ok
	add di, cx   ;指向下一个内存块
	inc word [ards_nr]
	cmp ebx, 0 
	jnz .e820_mem_get_loop

    mov cx, [ards_nr]
	mov ebx, ards_buf
	xor edx, edx
.find_max_mem_area:
	mov eax, [ebx+8]
	
	add ebx , 20
	cmp edx, eax
    jge .next_ards;>= 跳过
    mov edx, eax
.next_ards:
	loop .find_max_mem_area
	jmp .mem_get_ok

.e801:
	mov ax,0xe801
	int 0x15
	jc .int88
;先算出低 15MB 的内存
	mov cx,0x400  ;0x400=1k=1024
	mul cx       ;dx:ax=ax*cx
	shl edx,16
	and eax,0x0000ffff
    or edx,eax
	add edx,0x100000  ;1mb
	mov esi,edx       ;先把低 15MB 的内存容量存入 esi 寄存器备份
    
	xor eax, eax
	mov ax,bx
	mov ecx, 0x10000 ;0x10000=64k
	mul ecx          ;edx:eax=eax*ecx
	add esi,eax      ;两部分相加
	mov edx,esi
	jmp .mem_get_ok

.int88:
	mov ah, 0x88
	int 0x15
	je .error
	and eax,0x0000FFFF
	mov cx, 0x400    ;1k
    mul cx           ;dx:ax=ax*cx
	shl edx ,16
	and eax ,0x0000ffff
    or edx,eax
	add edx,0x100000  ;1mb
	jmp .mem_get_ok


.mem_get_ok:
	mov [total_mem_bytes],edx



;------------------------   准备进入保护模式	--------------------------
;1 打开A20
;2 加载gdt
;3 将cr0的pe位置1

	;----------------    打开A20	----------------------------------
	in al,0x92
	or al,0000_0010B
	out 0x92,al

	;----------------     加载GDT	----------------------------------
	lgdt [gdt_ptr]


	;----------------     cr0 第0位置1 -------------------------------
	mov eax,cr0
	or eax,0x00000001
	mov cr0,eax

	jmp dword SELECTOR_CODE:p_mode_start	;刷新流水线

.error:
	hlt

[bits 32]
p_mode_start:
	mov ax,SELECTOR_DATA	;83~89 用选择子初始化成各段寄存器
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp,LOADER_STACK_TOP
	mov ax,SELECTOR_VIDEO
	mov gs,ax

	mov byte [gs:160], 'P'

	call setup_page
	sgdt [gdt_ptr]
	mov ebx, [gdt_ptr+2]
    or dword [ebx+0x18+4], 0xc0000000
    add dword [gdt_ptr + 2], 0xc0000000
	add esp, 0xc0000000

	mov eax, PAGE_DIR_TABLE_POS
    mov cr3, eax
    mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

    lgdt [gdt_ptr]
	mov byte [gs:160], 'V'
	jmp $

setup_page:
	mov ecx,4096
	mov esi,0
.clear_page_dir:
	mov byte [PAGE_DIR_TABLE_POS+esi],0
	inc esi
	loop .clear_page_dir
.create_pde: 
	mov eax, PAGE_DIR_TABLE_POS
	add eax,0x1000
	mov ebx, eax
	or eax, PG_US_U | PG_RW_W | PG_P
	mov [PAGE_DIR_TABLE_POS+0x0], eax
	mov [PAGE_DIR_TABLE_POS+0xc00], eax
	sub eax, 0x1000
	mov [PAGE_DIR_TABLE_POS+4092], eax
	
	mov ecx, 256
	mov esi,0
	mov edx,PG_US_U | PG_RW_W | PG_P
.create_pte:
	mov [ebx+esi*4],edx
	add edx,0x1000
	inc esi
	loop .create_pte
    
	mov eax, PAGE_DIR_TABLE_POS
	add eax,0x2000
	or eax, PG_US_U | PG_RW_W | PG_P
	mov ebx,PAGE_DIR_TABLE_POS
	mov ecx, 254
	mov esi, 769
.create_kernel_pde:
	mov [ebx+esi*4],eax
	inc esi
	add eax,0x1000
	loop .create_kernel_pde
	ret






