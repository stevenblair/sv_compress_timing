/*
 * rapid61850_interface.c
 *
 *  Created on: 17 May 2016
 *      Author: nau03113
 */


//unsafe {
#include <math.h>
#include "iec61850.h"
#include "compress.h"
#include "rapid61850_proxy.h"
//}

#define TWO_PI              6.283185307179586476925286766559
#define TWO_PI_OVER_THREE   2.0943951023931954923084289221863
#define MAGNITUDE           326598.632371                       // 400 kV * sqrt(2) / sqrt(3)
#define CURRENT_MAGNITUDE   5656.8542                           // 4 kA * sqrt(2)
//#define MAGNITUDE           814040.75977137578661740084290745
//#define INCREMENT           0.07853981633974483096156608458199  // 2 * pi / 80
#define INCREMENT           0.02181661564992911971154613460611  // 2 * pi / 288 (50 Hz)
//#define INCREMENT           0.02617993877991494365385536152733  // 2 * pi / 240 (60 Hz)
//#define ERROR               (1.0 + (rand() % 6) / 100.0)    // 0.00-0.05 pu error factor
#define ERROR               (1.0)    // 0.00-0.05 pu error factor

float phase = 0.0;
float offset = 0.0;


CTYPE_INT32 value[8][6] = {{0}};

void precompute_values() {
    int ASDU = 0;
    for (ASDU = 0; ASDU < 6; ASDU++) {
        value[0][ASDU] = (CTYPE_INT32) CURRENT_MAGNITUDE * sin(phase + offset - 0.1) * ERROR;
        value[1][ASDU] = (CTYPE_INT32) CURRENT_MAGNITUDE * sin(phase + offset - TWO_PI_OVER_THREE - 0.1) * ERROR;
        value[2][ASDU] = (CTYPE_INT32) CURRENT_MAGNITUDE * sin(phase + offset + TWO_PI_OVER_THREE - 0.1) * ERROR;
        value[3][ASDU] = value[0][ASDU] + value[1][ASDU] + value[2][ASDU];

        value[4][ASDU] = (CTYPE_INT32) MAGNITUDE * sin(phase + offset) * ERROR;
        value[5][ASDU] = (CTYPE_INT32) MAGNITUDE * sin(phase + offset - TWO_PI_OVER_THREE) * ERROR;
        value[6][ASDU] = (CTYPE_INT32) MAGNITUDE * sin(phase + offset + TWO_PI_OVER_THREE) * ERROR;
        value[7][ASDU] = value[4][ASDU] + value[5][ASDU] + value[6][ASDU];

//        debug_printf("ASDU %d: %d %d %d %d %d %d %d %d\n",
//                ASDU,
//                value[0][ASDU],
//                value[1][ASDU],
//                value[2][ASDU],
//                value[3][ASDU],
//                value[4][ASDU],
//                value[5][ASDU],
//                value[6][ASDU],
//                value[7][ASDU]);

        phase += INCREMENT;
        if (phase > TWO_PI) {
            phase = phase - TWO_PI;
        }
    }
}

int get_value(int v, int ASDU) {
    return value[v][ASDU];
}

void set_values(int ASDU) {
    // generate voltage and current waveforms
    LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_1.Amp.instMag.i = value[0][ASDU];
    LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_2.Amp.instMag.i = value[1][ASDU];
    LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_3.Amp.instMag.i = value[2][ASDU];
    LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_4.Amp.instMag.i = value[3][ASDU];
    LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_1.Vol.instMag.i = value[4][ASDU];
    LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_2.Vol.instMag.i = value[5][ASDU];
    LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_3.Vol.instMag.i = value[6][ASDU];
    LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_4.Vol.instMag.i = value[7][ASDU];
}

void proxy_initialise_iec61850() {
    initialise_iec61850();
    precompute_values();
}

//void set_values() {
//    // generate voltage and current waveforms
//    LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_1.Vol.instMag.i = (CTYPE_INT32) MAGNITUDE * sin(phase + offset) * ERROR;
//    LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_2.Vol.instMag.i = (CTYPE_INT32) MAGNITUDE * sin(phase + offset - TWO_PI_OVER_THREE) * ERROR;
//    LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_3.Vol.instMag.i = (CTYPE_INT32) MAGNITUDE * sin(phase + offset + TWO_PI_OVER_THREE) * ERROR;
//    LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_4.Vol.instMag.i = LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_1.Vol.instMag.i + LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_2.Vol.instMag.i + LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_3.Vol.instMag.i;
////        LE_IED.S1.MUnn.IEC_61850_9_2LETVTR_4.Vol.instMag.i = 0;
//    LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_1.Amp.instMag.i = (CTYPE_INT32) MAGNITUDE * sin(phase + offset - 0.1) * ERROR;
//    LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_2.Amp.instMag.i = (CTYPE_INT32) MAGNITUDE * sin(phase + offset - TWO_PI_OVER_THREE - 0.1) * ERROR;
//    LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_3.Amp.instMag.i = (CTYPE_INT32) MAGNITUDE * sin(phase + offset + TWO_PI_OVER_THREE - 0.1) * ERROR;
//    LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_4.Amp.instMag.i = LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_1.Amp.instMag.i + LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_2.Amp.instMag.i + LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_3.Amp.instMag.i;
////        LE_IED.S1.MUnn.IEC_61850_9_2LETCTR_4.Amp.instMag.i = 0;
//
//    phase += INCREMENT;
//    if (phase > TWO_PI) {
//        phase = phase - TWO_PI;
//    }
//}

int proxy_sv_update_LE_IED_MUnn_MSVCB01_compress(unsigned char bufOut[]) {
    return sv_update_LE_IED_MUnn_MSVCB01_compress(bufOut);
}

int proxy_sv_update_LE_IED_MUnn_MSVCB01(unsigned char bufOut[]) {
    return sv_update_LE_IED_MUnn_MSVCB01(bufOut);
}

void proxy_svDecode_compress(unsigned char bufOut[], int lenOut) {
    svDecode_compress(bufOut, lenOut);
}

void proxy_svDecode(unsigned char bufOut[], int lenOut) {
    svDecode(bufOut, lenOut);
}

int proxy_get_decoded_value(unsigned char ASDU) {
    return LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_1_Amp_instMag.i;
}

int proxy_test_decoded_values() {
    int ASDU = 0;
    for (ASDU = 0; ASDU < 6; ASDU++) {
        if (value[0][ASDU] != LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_1_Amp_instMag.i) return 0;
        if (value[1][ASDU] != LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_2_Amp_instMag.i) return 0;
        if (value[2][ASDU] != LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_3_Amp_instMag.i) return 0;
        if (value[3][ASDU] != LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_4_Amp_instMag.i) return 0;
        if (value[4][ASDU] != LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TVTR_1_Vol_instMag.i) return 0;
        if (value[5][ASDU] != LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TVTR_2_Vol_instMag.i) return 0;
        if (value[6][ASDU] != LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TVTR_3_Vol_instMag.i) return 0;
        if (value[7][ASDU] != LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TVTR_4_Vol_instMag.i) return 0;
    }

    return 1;
}

void proxy_clear_decoded_values() {
    int ASDU = 0;
    for (ASDU = 0; ASDU < 6; ASDU++) {
        LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_1_Amp_instMag.i = 0;
        LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_2_Amp_instMag.i = 0;
        LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_3_Amp_instMag.i = 0;
        LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TCTR_4_Amp_instMag.i = 0;
        LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TVTR_1_Vol_instMag.i = 0;
        LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TVTR_2_Vol_instMag.i = 0;
        LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TVTR_3_Vol_instMag.i = 0;
        LE_IED_RECV.S1.MUnn.IEC_61850_9_2LETCTR_1.sv_inputs_MSVCB01.LE_IED_MUnn_PhsMeas1[ASDU].MUnn_TVTR_4_Vol_instMag.i = 0;
    }
}
