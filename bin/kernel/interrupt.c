#include "interrupt.h"
#include "stdint.h"
#include "global.h"
#include "io.h"
#include "print.h"

/** PIC主从片端口 **/
#define PIC_M_CTRL 0x20
#define PIC_M_DATA 0x21
#define PIC_S_CTRL 0xa0
#define PIC_S_DATA 0xa1

#define IDT_DESC_CNT 0x21

/**-----初始化主从PIC，一般家用电脑是两块8259A芯片-----**/

static void pic_init(void) {
    //主片初始化
    outb(PIC_M_CTRL,0x11); //ICW1
    outb(PIC_M_DATA,0x20); //ICW2

    outb(PIC_M_DATA,0x04);
    outb(PIC_M_DATA,0x01);

    //初始化从片
    outb(PIC_S_CTRL,0x11);
    outb(PIC_S_DATA,0x28);

    outb(PIC_S_DATA,0x02);
    outb(PIC_S_DATA,0x01);

   //打开主片上的IR0，也就是目前只接受时钟产生的中断
   outb(PIC_M_DATA,0xfe);
   outb(PIC_S_DATA,0xff);
   put_str(" pic_init done\n");
}
// 中断门描述符结构体

struct gate_desc{
    uint16_t func_offset_low_word;
    uint16_t selector;
    uint8_t dcount;
    uint8_t attribute;
    uint16_t func_offset_high_word;
};

// 静态函数声明，非必须

static void make_idt_desc(struct gate_desc* p_gdesc,uint8_t attr,intr_handler function);
static struct gate_desc idt[IDT_DESC_CNT];

extern intr_handler intr_entry_table[IDT_DESC_CNT];

// 创建中断门描述符

static void make_idt_desc(struct gate_desc* p_gdesc,uint8_t attr,intr_handler function){
    p_gdesc->func_offset_low_word=(uint32_t)function & 0x0000FFFF;
    p_gdesc->selector=SELECTOR_K_CODE;
    p_gdesc->dcount=0;
    p_gdesc->attribute=attr;
    p_gdesc->func_offset_high_word=((uint32_t)function& 0xFFFF0000)>>16;
}

//  初始化中断描述符表

static void idt_desc_init(void){
    int i;
    for(i=0;i<IDT_DESC_CNT;i++){
        make_idt_desc(&idt[i],IDT_DESC_ATTR_DPL0,intr_entry_table[i]);
    }
    put_str("  idt_desc_init done\n");
}

// 完成有关中断的所有初始化工作

void idt_init(){
    put_str("idt_init start\n");
    idt_desc_init();
    pic_init();
    // 加载idt
    uint64_t idt_operand= ((sizeof(idt)-1) | (uint64_t)((uint32_t)idt<<16));
    asm volatile("lidt %0"::"m"(idt_operand));
    put_str("idt_init done\n");
}
