/*
 * rapid61850_proxy.h
 *
 *  Created on: 17 May 2016
 *      Author: nau03113
 */

#ifndef RAPID61850_PROXY_H_
#define RAPID61850_PROXY_H_

void proxy_initialise_iec61850();
void set_values(int ASDU);
int proxy_sv_update_LE_IED_MUnn_MSVCB01(unsigned char bufOut[]);
int proxy_sv_update_LE_IED_MUnn_MSVCB01_compress(unsigned char bufOut[]);

#endif /* RAPID61850_PROXY_H_ */
