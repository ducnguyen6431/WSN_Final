#include "radio_info.h"
configuration TDMAControllerC{
	provides interface TDMAController;
}
implementation{
	components TDMAControllerP as TDMA;
	TDMA = TDMAController;
	
	components LoggerC;
	TDMA.Logger			->	LoggerC.Logger;
	
	components ActiveMessageC;
	TDMA.AMPacket		->	ActiveMessageC.AMPacket;
	TDMA.RadioControl	->	ActiveMessageC.SplitControl;
	
	components CC2420TimeSyncMessageC as TimeSync;
	TDMA.TSPacket		->	TimeSync.TimeSyncPacketMilli;
	TDMA.TSSend			->	TimeSync.TimeSyncAMSendMilli[RADIO_TIMESYNC_MSG];
	TDMA.TSReceive		->	TimeSync.Receive[RADIO_TIMESYNC_MSG];
	
	components new AMSenderC(RADIO_JOIN_REQ_MSG) as JoinReqSender;
	TDMA.JoinReqSend	->	JoinReqSender.AMSend;
	components new AMReceiverC(RADIO_JOIN_REQ_MSG) as JoinReqReceiver;
	TDMA.JoinReqReceive	->	JoinReqReceiver.Receive;
	
	components new AMSenderC(RADIO_JOIN_ANS_MSG) as JoinAnsSender;
	TDMA.JoinAnsSend	->	JoinAnsSender.AMSend;
	components new AMReceiverC(RADIO_JOIN_ANS_MSG) as JoinAnsReceiver;
	TDMA.JoinAnsReceive	->	JoinAnsReceiver.Receive;
	
	components new AMSenderC(RADIO_DATA_PKG_MSG) as DataPkgSender;
	TDMA.DataPkgSend	->	DataPkgSender.AMSend;
	components new AMReceiverC(RADIO_DATA_PKG_MSG) as DataPkgReceiver;
	TDMA.DataPkgReceive	->	DataPkgReceiver.Receive;
	
	components new SlotSchedulerC() as LocalScheduler;
	TDMA.LocalScheduler	->	LocalScheduler.SlotScheduler;
	components new SlotSchedulerC() as SystemScheduler;
	TDMA.SystemScheduler->	SystemScheduler.SlotScheduler;
	
	components SettingsC;
	TDMA.Settings		->	SettingsC.Settings;

	components ReadDataC;
	TDMA.ReadData 		->	ReadDataC.ReadData;
}