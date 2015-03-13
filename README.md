# CoreOS/fleet watchdog

This script will arrange for all services that end up in the "failed"
state to be restarted properly.  They will be restarted through, first
unloading them from the cluster, and then starting them (again).  The
script is able to only restart part of the services.
