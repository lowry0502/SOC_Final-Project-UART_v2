// This file is Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
// License: BSD

#include <csr.h>
#include <soc.h>
#include <irq_vex.h>
#include <user_uart.h>
#include <defs.h>

extern int uart_read();
extern int uart_read_num();
extern char uart_read_char();
extern char uart_write_char();
extern int uart_write();

void isr(void);

#ifdef CONFIG_CPU_HAS_INTERRUPT

#ifdef USER_PROJ_IRQ0_EN
uint32_t counter = 0xFFFF0000;
#endif

void isr(void)
{

#ifndef USER_PROJ_IRQ0_EN

    irq_setmask(0);
#else
    uint32_t irqs = irq_pending() & irq_getmask();
    int buf;
    int read_num;
    int num;
    int mask_num = 0x00FF0000;

    if ( irqs & (1 << USER_IRQ_0_INTERRUPT)) {
        user_irq_0_ev_pending_write(1); //Clear Interrupt Pending Event
        read_num = uart_read_num();
        for(int i=0; i<read_num; i++){
            buf = uart_read();
            reg_mprj_datal = buf<<16;
            uart_write(buf);
        }
        // if(read_num == 4){
        //     reg_mprj_datal = (buf>>8) & mask_num;//0xab550000;
        //     reg_mprj_datal = buf & mask_num;//0xab550000;
        //     reg_mprj_datal = (buf<<8) & mask_num;//0xab550000;
        //     reg_mprj_datal = (buf<<16) & mask_num;//0xab550000;
            
        // }
        // else if(read_num == 3){
        //     reg_mprj_datal = (buf>>8) & mask_num;//0xab550000;
        //     reg_mprj_datal = buf & mask_num;//0xab550000;
        //     reg_mprj_datal = (buf<<8) & mask_num;//0xab550000;
        // }
        // else if(read_num == 2){
        //     reg_mprj_datal = (buf>>8) & mask_num;//0xab550000;
        //     reg_mprj_datal = buf & mask_num;//0xab550000;
        // }
        // else{
        //     reg_mprj_datal = (buf>>8) & mask_num;//0xab550000;
        // }
    }
#endif

    return;
}

#else

void isr(void){};

#endif
