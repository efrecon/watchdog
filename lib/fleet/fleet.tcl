namespace eval ::fleet {
    namespace eval vars {
	variable logger        ""
	variable verbose       3
	variable logd          stderr
	variable dateLogHeader "\[%Y%m%d %H%M%S\] \[%module%\] \[%level%\] "
	variable verboseTags   {1 CRITICAL 2 ERROR 3 WARN 4 NOTICE 5 INFO 6 DEBUG}
	variable -fleet        "fleetctl"
	variable -opts         "--endpoint=http://10.1.42.1:4001"
    }
    namespace export {[a-z]*}
    namespace ensemble create
}


proc ::fleet::state {} {
    set state {}

    set cmd [Command list-units]
    set fd [open $cmd]
    fconfigure $fd -buffering line
    set header 0
    while {![eof $fd]} {
	set l [gets $fd]
	if { !$header } {
	    set header 1
	} else {
	    foreach {unit machine active sub} $l break
	    foreach {host ip} [split $machine "/"] break
	    set host [string trimright $host "."]
	    lappend state $unit $host $ip $active $sub
	}
    }
    if { [catch {close $fd} err] } {
	log WARN "Error when executing fleetctl: $err"
    }
    return $state
}

proc ::fleet::command { unit command } {
    set cmd [Command "$command $unit"]
    set fd [open $cmd]
    set answer [read $fd]
    if { [catch {close $fd} err] } {
	log WARN "Error when executing fleetctl: $err"
    }
    return $answer
}

proc ::fleet::logger { {cmd ""} } {
    set vars::logger $cmd
}

proc ::fleet::verbosity { {lvl -1} } {
    if { $lvl >= 0 || $lvl ne "" } {
	set lvl [LogLevel $lvl]
	if { $lvl < 0 } { 
	    return -code error "Verbosity level $lvl not recognised"
	}
	set vars::verbose $lvl
    }
    return $vars::verbose
}

# ::fleet::log -- Conditional Log output
#
#       This procedure will output the message passed as a parameter
#       if the logging level of the module is set higher than the
#       level of the message.  The level can either be expressed as an
#       integer (preferred) or a string pattern.
#
# Arguments:
#	lvl	Log level (integer or string).
#	msg	Message
#
# Results:
#       None.
#
# Side Effects:
#       Will either callback the logger command or output on stderr
#       whenever the logging level allows.
proc ::fleet::log { lvl msg { module "" } } {
    global argv0

    # Convert to integer
    set lvl [LogLevel $lvl]
    
    # If we should output, either pass to the global logger command or
    # output a message onto stderr.
    if { [LogLevel $vars::verbose] >= $lvl } {
	if { $module eq "" } {
	    if { [catch {::info level -1} caller] } {
		# Catches all errors, but mainly when we call log from
		# toplevel of the calling stack.
		set module [file rootname [file tail $argv0]]
	    } else {
		set proc [lindex $caller 0]
		set proc [string map [list "::" "/"] $proc]
		set module [lindex [split $proc "/"] end-1]
		if { $module eq "" } {
		    set module [file rootname [file tail $argv0]]
		}
	    }
	}
	if { $vars::logger ne "" } {
	    # Be sure we didn't went into problems...
	    if { [catch {eval [linsert $vars::logger end \
				   $lvl $module $msg]} err] } {
		puts $vars::logd "Could not callback logger command: $err"
	    }
	} else {
	    # Convert the integer level to something easier to
	    # understand and output onto FLEET(logd) (which is stderr,
	    # unless this has been modified)
	    array set T $vars::verboseTags
	    if { [::info exists T($lvl)] } {
		set log [string map [list \
					 %level% $T($lvl) \
					 %module% $module] \
			     $vars::dateLogHeader]
		set log [clock format [clock seconds] -format $log]
		append log $msg
		puts $vars::logd $log
	    }
	}
    }
}

# ::fleet::LogLevel -- Convert log levels
#
#       For convenience, log levels can also be expressed using
#       human-readable strings.  This procedure will convert from this
#       format to the internal integer format.
#
# Arguments:
#	lvl	Log level (integer or string).
#
# Results:
#       Log level in integer format, -1 if it could not be converted.
#
# Side Effects:
#       None.
proc ::fleet::LogLevel { lvl } {
    if { ![string is integer $lvl] } {
	foreach {l str} $vars::verboseTags {
	    if { [string match -nocase $str $lvl] } {
		return $l
	    }
	}
	return -1
    }
    return $lvl
}

proc ::fleet::Command { arg } {
    set cmd "|"
    append cmd [auto_execok ${vars::-fleet}]
    if { ${vars::-opts} ne "" } {
	append cmd " "
	append cmd ${vars::-opts}
    }
    
    append cmd " "
    append cmd $arg

    return $cmd
}

package provide fleet 0.1
