

## Project Description:
A modified version of USB 1.1, utilizing a transmitter, a reciever, AHB lite bus and a 64 bytes data buffer.<br/>
![TopLevelRTL](/images/Top_Level_RTL.png/)

## Contribuition:
Design by [Purdue University Elmore Family School of Electrical and Computer Engineering](https://engineering.purdue.edu/ECE) undergraduates
+ [Khoi Anh Nguyen](https://github.com/K0iNguyen)
+ [Aidan Michael McDonough](https://github.com/amcdonough11)
+ [Moe Wai Yan Myint](https://github.com/mwym2003)

## Getting Started:
Server source files for this project can be found in ~/337mg054/CDL (internal use only)
### + RTL Files:
The main components making the top level are [usb_tx_wrapper.sv](/source/usb_tx_wrapper.sv), [usb_rx.sv](/source/usb_rx.sv), [data_buffer.sv](/source/data_buffer.sv), and [ahb_lite_satellite.sv](/source/ahb_lite_satellite.sv).</br>
Submodules System Verilog files can be found in [/source/](/source/) folder.
#### /source/ 
  [ahb_usb.sv](/source/ahb_usb.sv) - top-level RTL code for the entire design
  
  [usb_rx.sv](/source/usb_rx.sv) - top-level code for USB receiver
  
  [usb_tx_wrapper.sv](/source/usb_tx_wrapper.sv) - top-level code for USB transmitter
  
  [ahb_lite_satellite.sv](/source/ahb_lite_satellite.sv) - top-level for ahb bus satellite/subordinate interface
  
  [data_buffer.sv](/source/data_buffer.sv) - top-level for the data buffer
  
  [EOP_det.sv](/source/EOP_det.sv) - module to detect an End-of-Packet 
  
  [NRZI_decoder.sv](/source/NRZI_decoder.sv) - module to decode NRZI packet
  
  [clk_div.sv](/source/clk_div.sv) - module for USB TX to sample at 12 MhZ
  
  [clk_div_rx.sv](/source/clk_div_rx.sv) - module for USB RX to sample at 12 MhZ
  
  [data_reg.sv](/source/data_reg.sv)- data register for the data buffer
  
  [flex_counter.sv](/source/flex_counter.sv) - adjustable counter used by rx and tx
  
  [flex_sr.sv](/source/flex_sr.sv) - adjustable shift register used by rx and tx
  
  [nrzi_encoder.sv](/source/nrzi_encoder.sv) - module to NRZI encode packet
  
  [rx_controller.sv](/source/rx_controller.sv) - fsm of the usb rx
  
  [sync.sv](/source/sync.sv) - synchronizer module for rx
  
  [usb_tx_fsm.sv](/source/usb_tx_fsm.sv) - fsm for the usb tx
  
### + Testbenches:
Testbenches can be found in [/testbench/](/testbench/) folder.
#### /testbench/:
  [tb_ahb_usb.sv](/testbench/tb_ahb_usb.sv) - testbench for the top-level full design 
  
  [tb_ahb_lite_satellite.sv](/testbench/tb_ahb_lite_satellite.sv) - testbench for the ahb satellite
  
  [tb_data_buffer.sv](/testbench/tb_data_buffer.sv) - testbench for the data buffer
  
  [tb_usb_tx_fsm](/testbench/tb_usb_tx_fsm) - testbench for the usb tx
  
### + Reports:
Synthesis reports can be found in [/reports/](/reports/) folder.
#### /reports/
  [ahb_usb.rep](/reports/ahb_usb.rep) - synthesis report file for top level
  
  [synth.log](/reports/synth.log) - synthesis log for the top-level of the design ahb usb
  
  [ahb_lite_satellite.rep](/reports/ahb_lite_satellite.rep) - synthesis report file for ahb satellite
  
  [data_buffer.rep](/reports/data_buffer.rep) - synthesis report file for data buffer
  
  [usb_rx.rep](/reports/usb_rx.rep) - synthesis report file for usb receiver
  
  [ubs_tx_wrapper.rep](/reports/ubs_tx_wrapper.rep) - synthesis report file for usb tx
