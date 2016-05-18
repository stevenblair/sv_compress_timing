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
#include "random.h"

#include "rapid61850_proxy.h"

#pragma unsafe arrays

//unsafe {
//#include "iec61850.h"
//}

//void xscope_user_init(void) {
//
//#if 0
//  xscope_register(3, XSCOPE_CONTINUOUS, "local_egress_ts", XSCOPE_UINT, "Value",
//    XSCOPE_CONTINUOUS, "received_sync_ts", XSCOPE_INT, "Value",
//    XSCOPE_CONTINUOUS, "residence", XSCOPE_INT, "Value");
///*
//  xscope_register(4, XSCOPE_CONTINUOUS, "rdptr", XSCOPE_UINT, "Value",
//    XSCOPE_CONTINUOUS, "wrptr", XSCOPE_UINT, "Value",
//    XSCOPE_CONTINUOUS, "hdr", XSCOPE_UINT, "Value",
//    XSCOPE_CONTINUOUS, "hdr->next", XSCOPE_INT, "Value");
//*/
///*
//  xscope_register(2, XSCOPE_CONTINUOUS, "commit", XSCOPE_UINT, "Value",
//    XSCOPE_CONTINUOUS, "buf", XSCOPE_INT, "Value");
//*/
//    // XSCOPE_CONTINUOUS, "buf", XSCOPE_INT, "Value");
//    // XSCOPE_CONTINUOUS, "fwdbuf", XSCOPE_INT, "Value");
//#else
//  xscope_register(0);
//#endif
//  xscope_config_io(XSCOPE_IO_BASIC);
//}

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

#define NORMAL_PORT     0   // rx on this port is tx'd normally
#define DELAYED_PORT    1   // rx on this port is tx'd with delay


//#define PTP_PERIODIC_TIME           (10000)      // every 100 us
//#define DELAY_FLAG_PERIODIC_TIME    (100000000) // every 1 s
#define SV_DELAY_FLAG_PERIODIC_TIME_14400_HZ (6944)      // approx. 14400 Hz (14400.92166 Hz)
//#define SV_DELAY_FLAG_PERIODIC_TIME (1666667)      // approx. 6 Hz
#define SV_DELAY_FLAG_PERIODIC_TIME_REMAINDER_OF_CYCLE (1631944)      // 16.319 ms

#define MAX_DELAY_MESG_LENGTH   1024        // TODO define max packet size
#define MAX_BUF_LENGTH  16




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

unsigned int send_buf[1024 / 4] = {0};
delay_buf_t delay_buffer[MAX_BUF_LENGTH];

unsigned int next_free_buf = 0;
//unsigned int start_replay = 0;
//unsigned int next_emptiable_buf = 0;

unsigned sv_delay_flag = 0;
timer sv_timer;
unsigned sv_send_ts = 0;
unsigned sv_recv_ts = 0;
unsigned sv_encode_ts = 0;
unsigned sv_ASDU_5_ts = 0;
unsigned sv_prev_ASDU_ts = 0;

unsigned ASDU = 0;
unsigned t0 = 0;
unsigned td = 0;

unsigned get_local_time() {
    unsigned t;
    sv_timer :> t;
    return t;
}

//int is_multicast_or_broadcast(unsigned int *buf) {
//    unsigned char *buf_bytes = (unsigned char *) buf;
//    int result = 0;
//
//    if ((buf_bytes[0] & 0x1) || // Broadcast
//      (buf_bytes[0] != mac[0] || buf_bytes[1] != mac[1])) // Not unicast
//    {
//        result = 1;
//    }
//
//    return result;
//}

#pragma select handler
void sv_recv_and_process_packet(chanend c_rx) {
    xscope_int(RECV_FLAG, 1);

      safe_mac_rx_timed(c_rx,
                       (delay_buffer[next_free_buf].buf, unsigned char[]),
                       delay_buffer[next_free_buf].len,
                       delay_buffer[next_free_buf].rx_ts,
                       delay_buffer[next_free_buf].src_port,
                       MAX_DELAY_MESG_LENGTH);

      sv_recv_ts = delay_buffer[next_free_buf].rx_ts;

//      debug_printf("recv %d bytes on port %d, ts: %d\n", delay_buffer[next_free_buf].len, delay_buffer[next_free_buf].src_port, sv_recv_ts);
//      debug_printf("  ts diff: %d us\n", (sv_recv_ts - sv_send_ts) / 100);

//      xscope_int(TIME_DIFF_SEND_RECV, (sv_recv_ts - sv_send_ts) / 100);

      next_free_buf++;
      if (next_free_buf >= MAX_BUF_LENGTH) {
          next_free_buf = 0;
      }

      xscope_int(RECV_FLAG, 0);

//      if (delay_flag) {
//          xscope_int(DELAY_FLAG, 0);
//          delay_buffer[next_free_buf].to_send = 1;
//          delay_buffer[next_free_buf].delay_counter = DELAY_ITERATIONS;
//      }
//      else {
//          unsigned buf_to_forward = next_free_buf;
//          unsigned int sentTime;
//          mac_tx_timed(c_tx, delay_buffer[buf_to_forward].buf, delay_buffer[buf_to_forward].len, sentTime, NORMAL_PORT);
//          delay_buffer[buf_to_forward].to_send = 0;
//          delay_buffer[buf_to_forward].delay_counter = 0;
//
//          int duration_us = (sentTime - delay_buffer[buf_to_forward].rx_ts) / 100;
//          xscope_int(FRAME_DELAY, duration_us);
//      }
}

unsigned sv_send_frame(chanend c_tx, int tile_timer_offset) {
    unsigned next_delay = SV_DELAY_FLAG_PERIODIC_TIME_14400_HZ;


    if (ASDU == 0) {
        t0 = get_local_time();
    }
//    else if (ASDU == 5) {
//    }
    xscope_int(ASDU_5_TIME, (get_local_time() - sv_prev_ASDU_ts) / 100);

    sv_prev_ASDU_ts = get_local_time();

//    unsigned int sentTime;
    int len = 0;

    // TODO precompute waveform
//    set_values();
//    if (ASDU == 5) {
//        sv_encode_ts = get_local_time();
//    }
    len = proxy_sv_update_LE_IED_MUnn_MSVCB01_compress((send_buf, unsigned char[]));
//    if (ASDU == 5) {
//        sv_encode_ts = get_local_time() - sv_encode_ts;
//        xscope_int(SV_ENCODE_TIME, sv_encode_ts / 100);
//    }

    ASDU++;

//    debug_printf("len: %d bytes\n", len);
//    if (len > 0) {
//        debug_printf("len > 0 bytes\n");
//    }
//    else {
//        debug_printf("len == 0 bytes\n");
//    }

    if (len > 0) {
        mac_tx_timed(c_tx, send_buf, len, sv_send_ts, 0);                 // TODO check interface number
        td = sv_send_ts;

//        debug_printf("sent %d bytes on port %d, ts: %d\n", len, 0, sv_send_ts);

        xscope_int(FRAME_DELAY, (td - (t0 + tile_timer_offset)) / 100);

    }

    if (ASDU >= 5) {
        ASDU = 0;
        next_delay = SV_DELAY_FLAG_PERIODIC_TIME_REMAINDER_OF_CYCLE;
    }

    return next_delay;
}

void sv_timing_tx(chanend c_tx, chanend share_tile_timer_offset) {
  timer sv_delay_flag_timer;
  unsigned int sv_delay_flag_timeout;
  static int tile_timer_offset = -79802;

  proxy_initialise_iec61850();

  while (1) {
    [[ordered]]
    select {
        case sv_delay_flag_timer when timerafter(sv_delay_flag_timeout) :> void:
            xscope_int(DELAY_FLAG, 1);
            unsigned next_delay = sv_send_frame(c_tx, tile_timer_offset);
//            sv_delay_flag = 1;
//            xscope_int(DELAY_FLAG, 1);
            sv_delay_flag_timeout += next_delay;
            xscope_int(DELAY_FLAG, 0);
            break;
        case share_tile_timer_offset :> tile_timer_offset:
//            sv_delay_flag_timeout = i;
            debug_printf("got tile_timer_offset: %d\n", tile_timer_offset);
//            printintln(i);
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
        case sv_recv_and_process_packet(c_rx):
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

    on stdcore[1]: sv_timing_tx(c_mac_tx[0], share_tile_timer_offset);
//    on stdcore[0]: sv_timing_rx(c_mac_rx[0], share_tile_timer_offset);
//    on tile[1]: sv_timing(c_mac_rx[0], c_mac_tx[0]);
  }

  return 0;
}

