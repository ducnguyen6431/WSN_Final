generic configuration SlotSchedulerC() {
	provides interface SlotScheduler;
}
implementation {
	components new SlotSchedulerP();
	SlotScheduler = SlotSchedulerP;

	components new TimerMilliC() as SlotTimer;
	SlotSchedulerP.SlotTimer	-> SlotTimer;

	components new TimerMilliC() as SystemTimer;
	SlotSchedulerP.SystemTimer	-> SystemTimer;
	
	components SerialActiveMessageC;
	
	components LoggerC;
	SlotSchedulerP.Logger		-> LoggerC.Logger;
}