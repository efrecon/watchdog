#! /usr/bin/env tclsh

set prg_args {
    -help     ""          "Print this help and exit"
    -verbose  4           "Verbosity level \[1-6\]"
    -endpoint ""          "etcd endpoint for fleetctl communication"
    -fleet    "%prgdir%/bin/fleetctl" "Location of fleet binary"
    -watch    "*.service" "Which services to watch and restart"
    -period   10          "Watching period, in seconds (negative for once)"
}



set dirname [file dirname [file normalize [info script]]]
set appname [file rootname [file tail [info script]]]
lappend auto_path [file join $dirname lib]

package require fleet

# Dump help based on the command-line option specification and exit.
proc ::help:dump { { hdr "" } } {
    global appname

    if { $hdr ne "" } {
	puts $hdr
	puts ""
    }
    puts "NAME:"
    puts "\t$appname - A fleet services watchdog"
    puts ""
    puts "USAGE"
    puts "\t${appname}.tcl \[options\]"
    puts ""
    puts "OPTIONS:"
    foreach { arg val dsc } $::prg_args {
	puts "\t${arg}\t$dsc (default: ${val})"
    }
    exit
}

proc ::getopt {_argv name {_var ""} {default ""}} {
    upvar $_argv argv $_var var
    set pos [lsearch -regexp $argv ^$name]
    if {$pos>=0} {
	set to $pos
	if {$_var ne ""} {
	    set var [lindex $argv [incr to]]
	}
	set argv [lreplace $argv $pos $to]
	return 1
    } else {
	# Did we provide a value to default?
	if {[llength [info level 0]] == 5} {set var $default}
	return 0
    }
}

array set WTDG {}
foreach {arg val dsc} $prg_args {
    set WTDG($arg) $val
}

if { [::getopt argv "-help"] } {
    ::help:dump
}

for {set eaten ""} {$eaten ne $argv} {} {
    set eaten $argv
    foreach opt [array names WTDG -*] {
	::getopt argv $opt WTDG($opt) $WTDG($opt)
    }
}

# Arguments remaining?? dump help and exit
if { [llength $argv] > 0 } {
    ::help:dump "$argv are unknown arguments!"
}

fleet verbosity $WTDG(-verbose)
if { $WTDG(-endpoint) ne "" } {
    set ::fleet::vars::-opts "--endpoint $WTDG(-endpoint)"
}
if { $WTDG(-fleet) ne "" } {
    set ::fleet::vars::-fleet [string map [list %prgdir% $dirname] $WTDG(-fleet)]
}


proc ::restart { unit { maxiter 20 } } {
    fleet log INFO "Restarting $unit..."
    while {$maxiter>0} {
	set res [string trim [fleet command $unit unload]]
	if { [string match -nocase "*inactive*" $res] } {
	    fleet log DEBUG "$unit properly unloaded from cluster"
	    break
	} else {
	    incr maxiter -1
	    fleet log WARN "Could not unload: $res"
	}
    }

    set ip ""
    while {$maxiter>0} {
	set res [string trim [fleet command $unit start]]
	if { [string match -nocase "*launched*" $res] } {
	    set rxip {(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])}
	    regexp $rxip $res ip
	    fleet log INFO "$unit restarted and now on host $ip"
	    break
	} else {
	    incr maxiter -1
	    fleet log WARN "Could not start $unit: $res"
	}
    }

    return $ip
}

proc ::consider { unit } {
    global WTDG

    foreach ptn $WTDG(-watch) {
	if { [string match $ptn $unit] } {
	    return 1
	}
    }
    return 0
}

proc ::check { {again -1} } {
    global WTDG

    fleet log INFO "Checking state of all units"
    foreach { unit host ip active sub } [fleet state] {
	if { [consider $unit] } {
	    fleet log DEBUG "Unit $unit is in state ${active}/${sub}\
                             at host $ip"
	    if { [string tolower $active] eq "failed" \
		     || [string tolower $sub] eq "dead" } {
		set ip [restart $unit]
		fleet log NOTICE "Restarted $unit, now on host $ip"
	    }
	}
    }
    if { $again >= 0 } {
	after $again [list ::check $again]
    }
}


if { $WTDG(-period) < 0 } {
    check
} else {
    set period [expr {$WTDG(-period)*1000}]
    check $period
    vwait forever
}
