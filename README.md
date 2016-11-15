# Real-Time SV Compression Timing Measurement

This repository contains code to use the XMOS XP-SKC-L2 embedded platform to validate and accurately measure the performance of a real-time Sampled Value compression method. See the [rapid61850 project](https://github.com/stevenblair/rapid61850#real-time-compression-of-sampled-values-data) for a reference implementation of the SV compression.

The hardware required is a [xCORE General Purpose sliceKIT](https://www.xmos.com/support/boards?product=15825) with an additional [Ethernet interface](https://www.xmos.com/support/boards?product=15830). These can be obtained from Digikey or Farnell at a reasonable cost (~£130). The two Ethernet interfaces should be connected to the Circle and Square ports on the board.

This code is intended to support a paper presently under review. Some details of the compression method are available here: http://strathprints.strath.ac.uk/57710/1/Blair_etal_AMPS2016_Real_time_compression_of_IEC_61869_9_sampled_value_data.pdf
