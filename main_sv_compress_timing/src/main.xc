#define PRINT_TIMING_RESULTS            1
#define PLOT_TIMING_SIGNALS             0
#define PLOT_TIMING_SIGNALS_DETAILED    0
#define PLOT_TIMING_SIGNALS_FINAL       0
#define PLOT_WAVEFORM                   0
#define VALIDATE_DECODING               1

#include <xs1.h>
#include <xclib.h>
#include <print.h>
#include <platform.h>
#include <stdlib.h>
#include "otp_board_info.h"
#include "ethernet.h"
#include "ethernet_board_support.h"
#include <xscope.h>
#include "ethernet_conf.h"
#include "mac_custom_filter.h"
#include "debug_print.h"
//#include "random.h"

#include "rapid61850_proxy.h"

#pragma unsafe arrays

on ETHERNET_DEFAULT_TILE: otp_ports_t otp_ports = OTP_PORTS_INITIALIZER;

smi_interface_t smi1 = ETHERNET_DEFAULT_SMI_INIT;

// Circle slot
mii_interface_t mii1 = ETHERNET_DEFAULT_MII_INIT;

// Square slot
on tile[1]: mii_interface_t mii2 = {
        XS1_CLKBLK_3,
        XS1_CLKBLK_4,
        XS1_PORT_1B,
        XS1_PORT_4D,
        XS1_PORT_4A,
        XS1_PORT_1C,
        XS1_PORT_1G,
        XS1_PORT_1F,
        XS1_PORT_4B
};


#define SV_DELAY_FLAG_PERIODIC_TIME_14400_HZ (6944)      // approx. 14400 Hz (14400.92166 Hz)
//#define SV_DELAY_FLAG_PERIODIC_TIME (1666667)      // approx. 6 Hz
#define SV_DELAY_FLAG_PERIODIC_TIME_REMAINDER_OF_CYCLE (1631944)      // 16.319 ms

#define MAX_DELAY_MESG_LENGTH   1024
#define MAX_BUF_LENGTH  16

#define INTERFACE_TX    0

#define GET_SHARED_GLOBAL(x, g) asm volatile("ldw %0, dp[" #g "]":"=r"(x)::"memory")
#define SET_SHARED_GLOBAL(g, v) asm volatile("stw %0, dp[" #g "]"::"r"(v):"memory")

extern void set_global_t0(unsigned write_val);
extern unsigned get_global_t0(void);


typedef struct delay_buf {
    unsigned int buf[MAX_DELAY_MESG_LENGTH / 4];
    //    unsigned char buf[MAX_DELAY_MESG_LENGTH];
    unsigned len;
    unsigned rx_ts;
    unsigned src_port;
    unsigned to_send;
    unsigned delay_counter;
    unsigned delay_packet_order;
} delay_buf_t;

typedef enum _SV_Mode {
    NO_COMPRESSION = 0,
    COMPRESSION = 1
} SV_Mode;


SV_Mode sv_mode = NO_COMPRESSION;
SV_Mode sv_mode_recv = NO_COMPRESSION;

unsigned int send_buf[1024 / 4] = {0};
delay_buf_t delay_buffer[MAX_BUF_LENGTH];

unsigned int next_free_buf = 0;

timer sv_timer;
timer sv_timer_recv;
unsigned ASDU = 0;
unsigned t0 = 0;
unsigned td = 0;
unsigned t0_for_recv = 0;

unsigned ASDU_encode_time[6] = {0};


unsigned get_local_time() {
    unsigned t;
    sv_timer :> t;
    return t;
}

unsigned get_local_time_recv() {
    unsigned t;
    sv_timer_recv :> t;
    return t;
}

void plot_int(unsigned char id, unsigned int data) {
#if PLOT_TIMING_SIGNALS == 1
    xscope_int(id, data);
#endif
}

unsigned sv_send_frame(chanend c_tx, int tile_timer_offset) {
    unsigned next_delay = SV_DELAY_FLAG_PERIODIC_TIME_14400_HZ;

    if (ASDU == 0) {
        t0 = get_local_time();
        set_global_t0(t0);
        //        SET_SHARED_GLOBAL(t0_for_recv, t0);
    }

    int len = 0;

    set_values(ASDU);
    if (sv_mode == NO_COMPRESSION) {
        len = proxy_sv_update_LE_IED_MUnn_MSVCB01((send_buf, unsigned char[]));
    }
    else {
        len = proxy_sv_update_LE_IED_MUnn_MSVCB01_compress((send_buf, unsigned char[]));
    }

    ASDU_encode_time[ASDU] = (get_local_time() - t0) / 100;

#if PLOT_TIMING_SIGNALS_DETAILED == 1
    switch (ASDU) {
    case 0:
        plot_int(ASDU_0_ENCODE_TIME, ASDU_encode_time[ASDU]);
        break;
    case 1:
        plot_int(ASDU_1_ENCODE_TIME, ASDU_encode_time[ASDU]);
        break;
    case 2:
        plot_int(ASDU_2_ENCODE_TIME, ASDU_encode_time[ASDU]);
        break;
    case 3:
        plot_int(ASDU_3_ENCODE_TIME, ASDU_encode_time[ASDU]);
        break;
    case 4:
        plot_int(ASDU_4_ENCODE_TIME, ASDU_encode_time[ASDU]);
        break;
    case 5:
        plot_int(ASDU_5_ENCODE_TIME, ASDU_encode_time[ASDU]);
        break;
    }
#endif

    if (len > 0) {
        mac_tx_timed(c_tx, send_buf, len, td, INTERFACE_TX);
        //        debug_printf("sent %d bytes on port %d, ts: %d\n", len, 0, td);

#if PLOT_TIMING_SIGNALS_DETAILED == 1
        plot_int(FRAME_DELAY, ((td - tile_timer_offset) - (t0)) / 100);
#endif
    }

    ASDU++;
    if (ASDU > 5) {
        ASDU = 0;

        next_delay = SV_DELAY_FLAG_PERIODIC_TIME_REMAINDER_OF_CYCLE;

        if (sv_mode == NO_COMPRESSION) {
            sv_mode = COMPRESSION;
        }
        else {
            sv_mode = NO_COMPRESSION;
        }

#if PRINT_TIMING_RESULTS == 1
        debug_printf("ASDU0 ASDU1 ASDU2 ASDU3 ASDU4 ASDU5 Send\n");
        debug_printf("%d %d %d %d %d %d %d\n",
                ASDU_encode_time[0],
                ASDU_encode_time[1],
                ASDU_encode_time[2],
                ASDU_encode_time[3],
                ASDU_encode_time[4],
                ASDU_encode_time[5],
                ((td - tile_timer_offset) - t0) / 100);
#endif
    }

    return next_delay;
}

#pragma select handler
void sv_recv_and_process_packet(chanend c_rx, int tile_timer_offset) {
    unsigned local_t0 = get_global_t0();
    unsigned recv_time = 0;
    unsigned ready_to_decode_time = 0;
    unsigned decode_time = 0;

    safe_mac_rx_timed(c_rx,
            (delay_buffer[next_free_buf].buf, unsigned char[]),
            delay_buffer[next_free_buf].len,
            delay_buffer[next_free_buf].rx_ts,
            delay_buffer[next_free_buf].src_port,
            MAX_DELAY_MESG_LENGTH);

    //      debug_printf("recv %d bytes on port %d, ts: %d\n", delay_buffer[next_free_buf].len, delay_buffer[next_free_buf].src_port, sv_recv_ts);

    //          GET_SHARED_GLOBAL(local_t0_for_recv, t0_for_recv);
    recv_time = (delay_buffer[next_free_buf].rx_ts - (local_t0 + tile_timer_offset)) / 100;

    ready_to_decode_time = (get_local_time_recv() - local_t0) / 100;

#if PLOT_TIMING_SIGNALS_DETAILED == 1
    plot_int(RECV_FLAG, recv_time);
#endif
    //      debug_printf("sv_recv_ts: %d, local_t0_for_recv: %d, tile_timer_offset: %d\n", sv_recv_ts, local_t0_for_recv, tile_timer_offset);
    //      debug_printf("  get_global(): %d\n", get_global());

    if (sv_mode_recv == COMPRESSION) {
        proxy_svDecode_compress((delay_buffer[next_free_buf].buf, unsigned char[]), delay_buffer[next_free_buf].len);
    }
    else {
        proxy_svDecode((delay_buffer[next_free_buf].buf, unsigned char[]), delay_buffer[next_free_buf].len);
    }

    decode_time = (get_local_time_recv() - local_t0) / 100;

#if PLOT_TIMING_SIGNALS_FINAL == 1
    plot_int(DECODE_TIME, decode_time);
#endif

#if PLOT_WAVEFORM == 1
//    plot_int(DECODED_WAVEFORM, proxy_get_decoded_value(0));
//    plot_int(DECODED_WAVEFORM, proxy_get_decoded_value(1));
//    plot_int(DECODED_WAVEFORM, proxy_get_decoded_value(2));
//    plot_int(DECODED_WAVEFORM, proxy_get_decoded_value(3));
//    plot_int(DECODED_WAVEFORM, proxy_get_decoded_value(4));
//    plot_int(DECODED_WAVEFORM, proxy_get_decoded_value(5));

//    debug_printf("%d %d %d %d %d %d\n",
//            proxy_get_decoded_value(0),
//            proxy_get_decoded_value(1),
//            proxy_get_decoded_value(2),
//            proxy_get_decoded_value(3),
//            proxy_get_decoded_value(4),
//            proxy_get_decoded_value(5));
#endif

#if VALIDATE_DECODING == 1
    if (proxy_test_decoded_values() != 1) {
        debug_printf("validation failed (mode %d)\n", sv_mode_recv);
    }
#endif

    if (sv_mode_recv == COMPRESSION) {
        sv_mode_recv = NO_COMPRESSION;
    }
    else {
        sv_mode_recv = COMPRESSION;
    }

    next_free_buf++;
    if (next_free_buf >= MAX_BUF_LENGTH) {
        next_free_buf = 0;
    }

#if PRINT_TIMING_RESULTS == 1
    debug_printf("Recv, Ready to decode, Decode\n");
    debug_printf("%d,  %d,             %d\n",
            recv_time,
            ready_to_decode_time,
            decode_time);
#endif

    proxy_clear_decoded_values();
}

void sv_timing_tx(chanend c_tx, chanend share_tile_timer_offset) {
    timer sv_delay_flag_timer;
    unsigned int sv_delay_flag_timeout;
    static int tile_timer_offset = -79802;

    proxy_initialise_iec61850();

    int ASDU = 0;
    for (ASDU = 0; ASDU < 6; ASDU++) {
        debug_printf("ASDU %d: %d %d %d %d %d %d %d %d\n",
                ASDU,
                get_value(0, ASDU),
                get_value(1, ASDU),
                get_value(2, ASDU),
                get_value(3, ASDU),
                get_value(4, ASDU),
                get_value(5, ASDU),
                get_value(6, ASDU),
                get_value(7, ASDU));
    }

    while (1) {
        [[ordered]]
         select {
         case sv_delay_flag_timer when timerafter(sv_delay_flag_timeout) :> void:
             unsigned next_delay = sv_send_frame(c_tx, tile_timer_offset);
             sv_delay_flag_timeout += next_delay;
             break;
         case share_tile_timer_offset :> tile_timer_offset:
             //            debug_printf("got tile_timer_offset: %d\n", tile_timer_offset);
             break;
        }
    }
}

void sv_timing_rx(chanend c_rx, chanend share_tile_timer_offset) {
    int tile_timer_offset = 0;

    mac_get_tile_timer_offset(c_rx, tile_timer_offset);
    share_tile_timer_offset <: tile_timer_offset;
    //  debug_printf("tile_timer_offset: %d, local time: %d\n", tile_timer_offset, get_local_time());

    mac_set_custom_filter(c_rx, 0x0001);

    while (1) {
        [[ordered]]
         select {
         case sv_recv_and_process_packet(c_rx, tile_timer_offset):
                    break;
        }
    }
}

int main()
{
    chan c_mac_rx[1], c_mac_tx[1];
    chan share_tile_timer_offset;

    par
    {
        on ETHERNET_DEFAULT_TILE:
        {
            char mac_address[6];
            otp_board_info_get_mac(otp_ports, 0, mac_address);
            smi_init(smi1);
            eth_phy_config(1, smi1);
            ethernet_server_full_two_port(mii1,
                    mii2,
                    smi1,
                    null,
                    mac_address,
                    c_mac_rx, 1,
                    c_mac_tx, 1);
        }

        on stdcore[0]: sv_timing_tx(c_mac_tx[0], share_tile_timer_offset);
        on stdcore[0]: sv_timing_rx(c_mac_rx[0], share_tile_timer_offset);
        //    on tile[1]: sv_timing(c_mac_rx[0], c_mac_tx[0]);
    }

    return 0;
}
