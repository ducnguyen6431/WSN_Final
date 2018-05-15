module LoggerP{
	provides interface Logger;
}
implementation{
	
	command void Logger.log(unsigned char *msg, log_level_t lvl){
		switch (lvl) {
			case log_lvl_info:
				#ifdef DBG_INFO
				printf("[INFO] %s\n", msg);
				printfflush();
				#endif
				break;
			case log_lvl_dbg:
				#ifdef DBG_DBG
				printf("[DBG] %s\n", msg);
				printfflush();
				#endif
				break;
			case log_lvl_err:
				#ifdef DBG_ERR
				printf("[ERR] %s\n", msg);
				printfflush();
				#endif
				break;
			case log_lvl_dat:
				#ifdef DBG_DATA
				printf("[DAT] %s\n", msg);
				printfflush();
				#endif
			default:
				#ifdef UNKNOWN_PRINT
				printf("[UKN] %s\n", msg);
				printfflush();
				#endif
				break;
		}
	}
	
	command void Logger.logValue(unsigned char *msg, uint32_t value, bool to_hex, log_level_t lvl) {
		switch (lvl) {
			case log_lvl_info:
				#ifdef DBG_INFO
				if(to_hex) {
					printf("[INFO] %s: 0x%08x\n", msg, value);
					printfflush();
				} else {
					printf("[INFO] %s: %d\n", msg, value);
					printfflush();
				}
				#endif
				break;
			case log_lvl_dbg:
				#ifdef DBG_DBG
				if(to_hex) {
					printf("[DBG] %s: 0x%08x\n", msg, value);
					printfflush();
				} else {
					printf("[DBG] %s: %d\n", msg, value);
					printfflush();
				}
				#endif
				break;
			case log_lvl_err:
				#ifdef DBG_ERR
				if(to_hex) {
					printf("[ERR] %s: 0x%08x\n", msg, value);
					printfflush();
				} else {
					printf("[ERR] %s: %d\n", msg, value);
					printfflush();
				}
				#endif
				break;
			case log_lvl_dat:
				#ifdef DBG_DATA
				if(to_hex) {
					printf("[DAT] %s: 0x%08x\n", msg, value);
					printfflush();
				} else {
					printf("[DAT] %s: %d\n", msg, value);
					printfflush();
				}
				#endif
			default:
				#ifdef UNKNOWN_PRINT
				if(to_hex) {
					printf("[UKN] %s: 0x%08x\n", msg, value);
					printfflush();
				} else {
					printf("[UKN] %s: %d\n", msg, value);
					printfflush();
				}
				#endif
				break;
		}
	}
}
