#ifndef _LIB_IO_H
#define _LIB_IO_H
#include "stdint.h"
//向端口写入一个字节
static inline void outb(uint16_t port,uint8_t data){
    //对端口指定 N 表示1－255
    //%b0 表示对应al %W1 表示对应 dx
    //b0表示第一个操作数的低1字节，这里就是eax寄存器的低1字节，也就是al
    //w1表示第二个操作数的低2字节，这里就是edx寄存器的低2字节，也就是dx
    asm volatile ("outb %b0,%w1"::"a" (data),"Nd" (port));
}

//将addr 处的起始的word_cnt个字写入端口port

static inline void outsw(uint16_t port,const void* addr,uint32_t word_cnt){
    //+表示此限制即做输入 也做输出
    //outsw 是把ds:esi处的16位内容写入port端口
    //outsw将    DS:esi中的字输出到　dl指向的端口
    asm volatile("cld;rep outsw":"+S"(addr),"+c"(word_cnt):"d"(port));
}

//将从端口port读入的一个字节返回

static inline uint8_t inb(uint16_t port){
    //b0表示第一个操作数的低1字节，这里就是eax寄存器的低1字节，也就是al
    //w1表示第二个操作数的低2字节，这里就是edx寄存器的低2字节，也就是dx
    //Nd表示立即数约束，表示0 - 255，这里也就是最多１字节的内容
    uint8_t data;
    asm volatile("inb %w1,%b0":"=a"(data):"Nd"(port));
    return data;
}

//将从端口 port 读入的 word_cnt 个字写入 addr 
static inline void insw(uint16_t port,void* addr,uint32_t word_cnt){
    //insw 是将从端口port处读入的16位内容写入es：edi指向的内存，
    //我们在设置段描述符时，已经将ds，es，ss段的选择子都设置为相同的值了
    asm volatile("cld;rep insw":"+D"(addr),"+c"(word_cnt):"d"(port):"memory");
}

#endif