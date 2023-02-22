#include "timer.h"
#include "io.h"
#include "print.h"
#include "stdint.h"

#define IRQ0_FREQUENCE 100
#define INPUT_FREQUENCE 1193180
#define COUNTER0_VALUE INPUT_FREQUENCE/IRQ0_FREQUENCE
#define COUNTER0_PORT 0x40
#define COUNTER0_NO 0
#define COUNTER0_MODE 2
#define READ_WRITE_LATCH 3
#define PIT_CONTROL_PORT 0x43

static void frequence_set(uint8_t counter_port,uint8_t counter_no,uint8_t rwl,uint8_t counter_mode,uint16_t counter_value){
    //往控制字寄存器端口0x43中写入控制字
    outb(PIT_CONTROL_PORT,(uint8_t)(counter_no<<6 | rwl<<4 | counter_mode<<1));
    //先写入counter_value的低8位
    outb(counter_port,(uint8_t)counter_value);
    //再写入counter_value的高8位
    outb(counter_port,(uint8_t)counter_value>>8);
}

//初始化PIT8253
void timer_init(){
    put_str("timer_init start\n");
    frequence_set(COUNTER0_PORT,COUNTER0_NO,READ_WRITE_LATCH,COUNTER0_MODE,COUNTER0_VALUE);
    put_str("timer_init done\n");
}