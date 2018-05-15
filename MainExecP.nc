#include "message.h"
#ifndef LIGHT_ON
#define LIGHT_ON
#endif
module MainExecP {
	uses {
		#ifdef LIGHT_ON
		interface Leds;
		interface Timer<TMilli> as Timer;
		#endif
		interface Logger;
		interface Boot;
		interface ReadData as DataReader;
		interface TDMAController;
	}
}
implementation {
	event void Boot.booted() {
		call Timer.startOneShot(5120);
	}
	
	event void Timer.fired() {
		call TDMAController.start();
	}
	
	event void DataReader.readDone(error_t error, data_pkg_msg_t* msg) {
		call Logger.log("Read data done", log_lvl_info);
		call TDMAController.setDataPkg(msg);
	}

	event void TDMAController.startDone(error_t err){
		// TODO Auto-generated method stub
		call Logger.log("TDMA started!", log_lvl_dbg);
	}

	event void TDMAController.newRound(tdma_round_type_t type){
		// TODO Auto-generated method stub
		if(type == TDMA_ROUND_SYSTEM && !(call TDMAController.isSink())) {
			call Logger.log("System new round", log_lvl_info);
			call DataReader.read();
		} else if(type == TDMA_ROUND_LOCAL && !(call TDMAController.isHead())) {
			call Logger.log("Local new round", log_lvl_info);
			call DataReader.read();
		}
	}

	event void TDMAController.stopDone(error_t err){
		// TODO Auto-generated method stub
		call Logger.log("TDMA Controller stopped!", log_lvl_info);
	}
}