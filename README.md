

## Project Description:
A modified version of USB 1.1, utilizing a transmitter, a reciever, AHB lite bus and a 64 bytes data buffer.<br/>
![TopLevelRTL](/images/Top_Level_RTL.png/)

## Contribuition:
Design by [Purdue University Elmore Family School of Electrical and Computer Engineering](https://engineering.purdue.edu/ECE) undergraduates
+ [Khoi Anh Nguyen](https://github.com/K0iNguyen)
+ [Aidan Michael McDonough](https://github.com/amcdonough11)
+ [Moe Wai Yan Myint](https://github.com/mwym2003)

## What I did (Aidan McDonough)
- Designed and implmented AHB-lite Subordinate interface
- Created testbenches and verified the functionality of the Subordinate module
- Integerated USB_RX, USB_TX, Databuffer, and AHB-lite Subordinate to create complete AHB_USB top-level design
- Created testbenches and verified the functionality of the AHB_USB top-level

*More info on my section of the project is below under **Design Details***

  # Design Details 

  ## Features
  | Feature | Description |
  | --- | --- | 
  | AHB-Lite Subordinate | Standard `HSEL/HADDR/HTRANS/HSIZE/HWRITE/HWDATA/HRDATA/HRESP`; Allows for reads/writes to external USB device|
  | Data Buffer | 64 Bytes FIFO; Accessed via Data Buffer Register through AHB Interface; Holds both RX data and TX data|
  | USB RX | Receives USB Transmition via D+ and D- and converts into binary data to be stored in the Data Buffer|
  | USB TX | Transmits data from the Data Buffer over D+ and D– lines to the external USB device |

  ## Module Overview

  ## AHB-Lite Register Map

  | Address | Access | Size | Description| 
  | --- | --- | --- | --- |
  |0x0| Read/Write| 4 Bytes | Data Buffer Reg|
  |0x4| Read Only | 2 Bytes | Status Reg | 
  |0x6| Read Only | 2 Bytes | Error Reg|
  | 0x8| Read Only| 1 Byte | Buffer Occupancy Reg|
  | 0xC | Read/Write| 1 Byte | TX Packet Control Reg|
  |0xD| Read/Write| 1 Byte| Flush Buffer Control Reg|

  ## AHB-Lite Bus Signals
  
## Design Notes and Assumptions

## Verification

## Synthesis Results
