#include "wsn_message.h"

#define MAX_SENSORS 5

module ReadDataP{
	provides interface ReadData;
	uses{
		interface Logger;
		interface Read<uint16_t> as Humidity;
		interface Read<uint16_t> as Temperature;
		interface Read<uint16_t> as Vref;
		interface Read<uint16_t> as Photo;
		interface Read<uint16_t> as Radiation;
	}
}
implementation{
	data_pkg_msg_t data;
	uint8_t numsensors = 0;

	event void Humidity.readDone(error_t result, uint16_t val){
		call Logger.log("Reading Humidity!", log_lvl_dbg);
		data.humidity = val;
		if (++numsensors == MAX_SENSORS) {
			signal ReadData.readDone(SUCCESS, &data);
			numsensors = 0;
		}
	}

	event void Temperature.readDone(error_t result, uint16_t val){
		call Logger.log("Reading Temperature!", log_lvl_dbg);
		data.temperature = val;
		if(++numsensors == MAX_SENSORS) {
			signal ReadData.readDone(SUCCESS, &data);
			numsensors = 0;
		}
	}

	event void Vref.readDone(error_t result, uint16_t val){
		call Logger.log("Reading Vref!", log_lvl_dbg);
		data.vref = val;
		if(++numsensors ==  MAX_SENSORS) {
			signal ReadData.readDone(SUCCESS, &data);
			numsensors = 0;
		}
	}

	event void Photo.readDone(error_t result, uint16_t val){
		call Logger.log("Reading Photo!", log_lvl_dbg);
		data.photo = val;
		if(++numsensors == MAX_SENSORS) {
			signal ReadData.readDone(SUCCESS, &data);
			numsensors = 0;
		}
	}

	event void Radiation.readDone(error_t result, uint16_t val){
		call Logger.log("Reading Radiation!", log_lvl_dbg);
		data.radiation = val;
		if(++numsensors == MAX_SENSORS){
			signal ReadData.readDone(SUCCESS, &data);
			numsensors = 0;
		}
	}	

	command error_t ReadData.read(){
		call Photo.read();
		call Vref.read();
		call Radiation.read();
		call Temperature.read();
		call Humidity.read();
		return SUCCESS;
	}
	
	command void ReadData.readMsg(data_pkg_msg_t* msg) {
		call Logger.logValue("Temperature", msg->temperature, TRUE, log_lvl_dat);
		call Logger.logValue("Humidity", msg->humidity, TRUE, log_lvl_dat);
		call Logger.logValue("Radio", msg->radiation, TRUE, log_lvl_dat);
		call Logger.logValue("Photo", msg->photo, TRUE, log_lvl_dat);
		call Logger.logValue("vRef", msg->vref, TRUE, log_lvl_dat);
	}
}