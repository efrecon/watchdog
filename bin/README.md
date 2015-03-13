# Binaries

The defaults for the program supposes that this directory contains the
fleetctl binary for your platform.  Binaries are available from the
most relevant platforms at the following location [1].  For example,
to place the 0.9.1 binary for linux 64bits here, you could run:

    wget -q -O - https://github.com/coreos/fleet/releases/download/v0.9.1/fleet-v0.9.1-linux-amd64.tar.gz|tar zxf - --wildcards -O */fleetctl > ./fleetctl
    chmod a+x ./fleetctl

  [1]: https://github.com/coreos/fleet/releases