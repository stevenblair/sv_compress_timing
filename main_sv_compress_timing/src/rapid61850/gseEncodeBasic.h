/**
 * Rapid-prototyping protection schemes with IEC 61850
 *
 * Copyright (c) 2012 Steven Blair
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

#ifndef GSE_ENCODE_BASIC_H
#define GSE_ENCODE_BASIC_H

#ifdef __cplusplus /* If this is a C++ compiler, use C linkage */
extern "C" {
#endif

#include "datatypes.h"
#include "encodePacket.h"

int BER_ENCODE_CTYPE_FLOAT32(unsigned char *buf, CTYPE_FLOAT32 *value);
int BER_ENCODE_CTYPE_FLOAT64(unsigned char *buf, CTYPE_FLOAT64 *value);
int BER_ENCODE_CTYPE_QUALITY(unsigned char *buf, CTYPE_QUALITY *value);
int BER_ENCODE_CTYPE_TIMESTAMP(unsigned char *buf, CTYPE_TIMESTAMP *value);
int BER_ENCODE_CTYPE_ENUM(unsigned char *buf, CTYPE_ENUM *value);
int BER_ENCODE_CTYPE_INT8(unsigned char *buf, CTYPE_INT8 *value);
int BER_ENCODE_CTYPE_INT16(unsigned char *buf, CTYPE_INT16 *value);
int BER_ENCODE_CTYPE_INT32(unsigned char *buf, CTYPE_INT32 *value);
int BER_ENCODE_CTYPE_INT16U(unsigned char *buf, CTYPE_INT16U *value);
int BER_ENCODE_CTYPE_INT32U(unsigned char *buf, CTYPE_INT32U *value);
int BER_ENCODE_CTYPE_VISSTRING255(unsigned char *buf, CTYPE_VISSTRING255 *value);
int BER_ENCODE_CTYPE_BOOLEAN(unsigned char *buf, CTYPE_BOOLEAN *value);
int BER_ENCODE_CTYPE_DBPOS(unsigned char *buf, CTYPE_DBPOS *value);

#ifdef __cplusplus /* If this is a C++ compiler, end C linkage */
}
#endif

#endif

