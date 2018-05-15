configuration SettingsC {
	provides interface Settings;
}
implementation {
	components SettingsP;
	SettingsP	= Settings;
}