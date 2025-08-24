

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
- AHB Subordinate Interface –> handles AMBA AHB-Lite transactions with the SoC.

- USB RX module –> receives and validates incoming packets.

- USB TX module -> transmits endpoint responses.
  
- Data Buffer –> stores transaction data.

  ## AHB-Lite Register Map

  | Address | Access | Size | Description| 
  | --- | --- | --- | --- |
  |0x0| Read/Write| 4 Bytes | Data Buffer Reg: <br> - Pushes bytes on a write <br> - Pops bytes on a read|
  |0x4| Read Only | 2 Bytes | Status Reg:<br>Bit 0 -> New data available in buffer<br>Bit 1 -> IN token received from Host <br> Bit 2 -> OUT token received from Host<br>Bit 3 -> ACK received from Host<br> Bit 4 -> DATA0 packet received from Host <br> Bit 5 -> DATA1 packet received from Host <br> Bit 8 -> Actively receiving packet from Host<br> Bit 9 -> Actively sending  packet to Host| 
  |0x6| Read Only | 2 Bytes | Error Reg:<br> Bit 0 -> Error during reception <br> Bit 1 -> Error during transmission|
  | 0x8| Read Only| 1 Byte | Buffer Occupancy Reg: Displays Number of Bytes in Data Buffer|
  | 0xC | Read/Write| 1 Byte | TX Packet Control Reg: <br>Value == 1 -> Send a DATA0 packet<br>Value == 2 -> Send a DATA1 packet<br>Value == 3 -> Send an ACK<br>Value == 4 -> Send a NAK<br>Value == 5 -> Send a STALL|
  |0xD| Read/Write| 1 Byte| Flush Buffer Control Reg: Write a 1 to clear the Data Buffer |

  ## AHB-Lite Bus Signals

| Signal         | Description |
|----------------|-------------|
| `HCLK` | Bus clock (`clk`). |
| `HRESETn` | Active-low reset (`n_rst`). |
| `HSEL`         | Subordinate (slave) select. High when this peripheral is selected. |
| `HADDR[3:0]`   | Address bus (4 bits). |
| `HSIZE[2:0]`   | Transfer size: `000` = 8-bit, `001` = 16-bit. Others treated as invalid (error). |
| `HTRANS[1:0]`  | Transfer type. <br>`SEQ` = sequential (3) <br> `NONSEQ` = single transfer (2) <br> `BUSY` = busy (1)<br> `IDLE` = idle (0). |
| `HWRITE`       | Transfer direction: `0` = Read, `1` = Write. |
| `HBURST[2:0]`  | Burst type indicator: <br> 000 = SINGLE (single transfer)<br> 001 = INCR (incrementing, variable length)<br> 010 = WRAP4 (4-beat wrap-around)<br> 011 = INCR4 (4-beat incrementing)<br> 100 = WRAP8 (8-beat wrap-around)<br> 101 = INCR8 (8-beat incrementing)<br> 110 = WRAP16 (16-beat wrap-around)<br> 111 = INCR16 (16-beat incrementing). |
| `HWDATA[31:0]` | Write data bus. |
| `HREADY`       | Ready/Wait signal. Low = stall bus, High = ready. |
| `HRDATA[31:0]` | Read data bus. |
| `HRESP`        | Transfer response: `0` = OKAY, `1` = ERROR (invalid address/size). |
| `HPROT` | Not used. No protection control implemented|

  
## Design Notes and Assumptions
- Read-After-Write (RAW) hazard is prevented by stalling bus (`HREADY` == 0) for 1 cycle
- Attempting to reading a byte size bigger then the register size will full value stored in the on `HRDATA` with higher-order bits as 0 (Exception for `0xC` which will display `0xD` in higher-order bits)
- This design supports USB 1.1 Full-Speed (12 Mbps) operation, with Bulk Transfers as the only supported transfer type (no Control, Interrupt, or Isochronous transfers)
- Design assumes 100 MHz system clk and 12 MHz signaling on USB differential pair
- Little-endian format

## Verification

## Synthesis Results
