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
	mov eax,KERNEL_START_SECTOR
	mov ebx,KERNEL_BIN_BASE_ADDR
	mov ecx,200
	call rd_disk_m_32

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
enter_kernel:
	call kernel_init
	mov esp, 0xc009f000

	mov byte [gs:160], 'V'
	jmp KERNEL_ENTRY_POINT
	
kernel_init:
	xor eax,eax
	xor ebx,ebx
	xor ecx,ecx
	xor edx,edx

	mov dx,[KERNEL_BIN_BASE_ADDR+42]  ;program header 大小
	mov ebx,[KERNEL_BIN_BASE_ADDR+28] ;第1个 program header 在文件中的偏移量
	add ebx,KERNEL_BIN_BASE_ADDR      ;第1个 program header在内存的地址
	mov cx,[KERNEL_BIN_BASE_ADDR+44]  ;表示有几个 program header
each_segment:
	cmp byte [ebx],PT_NULL
	je PTNULL
	push dword [ebx+16]  ;  program header 中偏移 16 字节的地方是 p_filesz
	mov eax,[ebx+4]      ;  距程序头偏移量为 4 字节的位置是 p_offset
	add eax,KERNEL_BIN_BASE_ADDR ;eax 为该段在内存的地址
	push eax              
	push dword [ebx+8]   ;偏移程序头 8 字节的位置是 p_vaddr,段的物理地址
	call mem_cpy
	add esp, 12
PTNULL:
	add ebx,edx
	loop each_segment
	ret

mem_cpy:
	cld
	push ebp
	mov ebp, esp
	push ecx
	mov edi, [ebp + 8] ; dst   p_vaddr
	mov esi, [ebp+12]  ; src
	mov ecx, [ebp+16]  ; size
    rep movsb
	
	pop ecx
	pop ebp
	ret

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

rd_disk_m_32:
;-------------------------------------------------------------------------------------
;eax=LBA扇区号
;bx=将数据写入的内存地址
;cx=读入的扇区数
	mov esi,eax			;备份eax,因为al在out命令中会使用,会影响到eax的低8位
	mov di,cx			;备份cx,cx在读数据的时候会使用到
;读写硬盘
;第一步:设置要读取的扇区数
	mov dx,0x1f2			;虚拟硬盘属于ata0,是Primary通道,所以sector count 是由0x1f2访问
	mov al,cl			;cl是cx的低8位,就读一个扇区,这样就能传过去了
	out dx,al			;读取的扇区数,sector count 记录要读取的扇盘数量

	mov eax,esi			;恢复eax,现在eax存的是其实扇区lba的地址,0x2,第二个扇区

;第二步:将LBA地址存入 0x1f3 ~ 0x1f6

	;LBA地址 7~0 位写入端口 0x1f3
	mov dx,0x1f3			;LBA low
	out dx,al			;eax的第8位,就是al

	;LBA地址 15~8 位写入端口 0x1f4
	mov cl,8
	shr eax,cl			;eax右移8位,让al的数,变为eax中8位
	mov dx,0x1f4			;LBA mid
	out dx,al

	;LBA地址 23~16 位写入端口 0x1f5
	shr eax,cl			;再右移8位
	mov dx,0x1f5			;LBA high
	out dx,al

	shr eax,cl			;这样al为0000
	and al,0x0f			;lba第24~27位
	or al,0xe0			;设置7~4位为1110,表示lba模式
	mov dx,0x1f6			;就是拼凑出device寄存器的值
	out dx,al

;第3步:向0x1f7端口写入读命令,0x20
	mov dx,0x1f7
	mov al,0x20
	out dx,al			;command:0x1f7,写入命令,写入的命令是读命令

;第四步:检测硬盘状态
 .not_ready:
	;同一端口,写时表示写入命令字,读时表示写入硬盘的状态,所以不需要更换dx的值
	nop				;减少打扰硬盘的工作
	in al,dx			;将Status的寄存器的值读入到al中
	and al,0x88			;第四位为1表示硬盘控制器已准备好数据传输,第七位为1表示硬盘忙,保存第4位和第7位
	cmp al,0x08			;若第4位为1,表示数据已经准备好了,若第7位为1,表示硬盘处于忙
	jnz .not_ready			;若未准备好,继续等,判断结果是否为0

;第5步,从0x1f0端口读数据
	mov ax,di			;这个时候di存的是上面备份的cx,及时要读取的扇区的数量
	mov dx,256			;每次in操作只读取两个字节,根据读入的数据总量(扇区数*512字节)
	mul dx				;dx*ax就是总数量/2,然后将值送到cx中,cx就是要in的次数
	mov cx,ax			;di为要读取的扇区数,一个扇区有512个字节,每次读入一个字,共需要di*512/2次,所以di*256

	mov dx,0x1f0
 .go_on_read:
	in ax,dx			;读入到ax中
	mov [ebx],ax			;读入到ebx指向的内存
	add ebx,2			;每次读入2个字节
	loop .go_on_read		;cx是循环的次数
	ret










