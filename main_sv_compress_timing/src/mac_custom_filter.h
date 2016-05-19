//
//#define MAC_FILTER_1722  0x1
//#define MAC_FILTER_PTP   0x2
//#define MAC_FILTER_ARPIP 0x4
//#define MAC_FILTER_AVB_CONTROL  0x8
//
#include "debug_print.h"

#define MII_FILTER_FORWARD_TO_OTHER_PORTS (0x80000000)
//
inline int mac_custom_filter(unsigned int buf[], unsigned int mac[2])
{
  int result = 0;
  unsigned short etype = (unsigned short) buf[3];
  int qhdr = (etype == 0x0081);

  if (qhdr) {
    // has a 802.1q tag - read etype from next word
    etype = (unsigned short) buf[4];
  }


//  debug_printf("etype: %x\n", etype);

  switch (etype) {
//      case 0xf788:
//        result |= 0x4000;
//        break;
//      case 0x4788://0xBA88://
//        result |= 0x1000;
//        break;
//      case 0x4888:
//        result |= 0x0001;
//        break;
      case 0xBA88:
          // SV
//          debug_printf("SV etype: %x\n", etype);
        result |= 0x0001;
        break;
    default:
//      if ((buf[0] & 0x1) || // Broadcast
//          (buf[0] != mac[0] || buf[1] != mac[1])) // Not unicast
//      {
//        result |= MII_FILTER_FORWARD_TO_OTHER_PORTS;
//      }
      break;
  }

  return result;
}

//inline int mac_custom_filter(unsigned int buf[], unsigned int mac[2])
//{
//      int result = 1;
//      unsigned short etype = (unsigned short) buf[3];
//      int qhdr = (etype == 0x0081);
//
//      if (qhdr) {
//        // has a 802.1q tag - read etype from next word
//        etype = (unsigned short) buf[4];
//      }
//
//      switch (etype) {
////        case 0xf788:
////          result = MAC_FILTER_PTP;
////          break;
//        default:
//          if ((buf[0] & 0x1) || // Broadcast
//              (buf[0] != mac[0] || buf[1] != mac[1])) // Not unicast
//          {
//            result |= MII_FILTER_FORWARD_TO_OTHER_PORTS;
//          }
//          break;
//      }
//
//      return result;
//}
