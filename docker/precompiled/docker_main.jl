using Pluto
Pluto.run("0.0.0.0", 1234;
	configuration=Pluto.ServerConfiguration(launch_browser=false),
	security=Pluto.ServerSecurity(false),
	)
