总结，bochs安装最重要的四步：

一、配置bochsrc.disk文件

二、创建硬盘（或软盘，看你想以硬盘启动还是软盘启动了）

三、创建一个bin文件

四、把bin文件放到创建好的硬盘中，写一个run脚本来启动bochs即可

硬盘           https://www.jianshu.com/p/c57c4e688da6
LBA28的寄存器  https://blog.csdn.net/weixin_43751461/article/details/125216050
              
            https://jadeshu.blog.csdn.net/article/details/89072512?spm=1001.2101.3001.6661.1&utm_medium=distribute.pc_relevant_t0.none-task-blog-2%7Edefault%7EOPENSEARCH%7ERate-1-89072512-blog-128116999.pc_relevant_3mothn_strategy_recovery&depth_1-utm_source=distribute.pc_relevant_t0.none-task-blog-2%7Edefault%7EOPENSEARCH%7ERate-1-89072512-blog-128116999.pc_relevant_3mothn_strategy_recovery&utm_relevant_index=1
            https://blog.csdn.net/Destiny_159/article/details/120764425

当我们的系统开机时，cpu首先工作在实模式下完成一些工作，之后跳入保护模式

https://zhuanlan.zhihu.com/p/27401519

    保护模式的偏移地址和实模式下的是相同的，只不过是32位
    在保护模式下，地址仍然采用“段地址:偏移地址”的方式来表示

1. 寻址时，先找到gdtr寄存器，从中得到GDT的基址
2. 有了GDT的基址，又有段寄存器中保存的索引，可以得到段寄存器“所指”的那个表项，既所指的那个描述符
3. 得到了描述符，就可以从描述符中得到该描述符所描述的那个段的起始地址
4. 有了段的起始地址，将偏移地址拿过来与之相加，便能得到最后的线性地址
5. 有了线性地址（虚拟地址），经过变换，即可得到相应的物理地址          

实模式如下：

* 16位寄存器

* 20位地址线，可访问1MB内存

* 通过CS/DS寄存器左移4位+IP寄存器的值生成20位访问地址

https://www.cnblogs.com/chengxuyuancc/p/3474623.html

typedef struct elf32_phdr{
  Elf32_Word    p_type;  //段的类型，LOAD，DYNAMIC等
  Elf32_Off    p_offset;  //段在文件中的偏移量
  Elf32_Addr    p_vaddr;  //段的物理地址
  Elf32_Addr    p_paddr;  //段的虚拟地址
  Elf32_Word    p_filesz;  //段在文件中的大小
  Elf32_Word    p_memsz;  //段在内存中的大小
  Elf32_Word    p_flags;  //读写执行标记
  Elf32_Word    p_align;  //段的对齐
} Elf32_Phdr;

