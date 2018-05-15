typedef enum {
	log_lvl_err 	= 0,
	log_lvl_info 	= 1,
	log_lvl_dbg		= 2,
	log_lvl_dat		= 3
} log_level_t;

interface Logger {
	command void log(unsigned char* msg, log_level_t lvl);
	command void logValue(unsigned char* msg, uint32_t value, bool to_hex, log_level_t lvl);	
}