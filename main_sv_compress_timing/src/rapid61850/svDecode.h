/**
 * Rapid-prototyping protection schemes with IEC 61850
 *
 * Copyright (c) 2014 Steven Blair
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#ifndef SV_DECODE_H
#define SV_DECODE_H

#ifdef __cplusplus /* If this is a C++ compiler, use C linkage */
extern "C" {
#endif

#include "svPacketData.h"




int decode_LE_IED_MUnn_PhsMeas1(unsigned char *buf, CTYPE_INT16U smpCnt, struct LE_IED_MUnn_PhsMeas1 *LE_IED_MUnn_PhsMeas1);
int decode_LE_IED_MUnn_PhsMeas2(unsigned char *buf, CTYPE_INT16U smpCnt, struct LE_IED_MUnn_PhsMeas2 *LE_IED_MUnn_PhsMeas2);

void svDecodeDataset(unsigned char *dataset, int datasetLength, int ASDU, unsigned char *svID, int svIDLength, CTYPE_INT16U smpCnt);



#ifdef __cplusplus /* If this is a C++ compiler, end C linkage */
}
#endif

#endif

