#!/bin/sh
# the next line restarts using tclsh \
exec tclsh8.6 "$0" "$@"

if {$argc < 1 || $argc > 2} {
    puts stderr "Usage: [file tail $argv0] <csv-file> ?<dbf-file>?"
    exit 1
}

variable csvencoding ""
variable csvdelimiter ","
variable csvquote "\""

proc splitCsv {str {sepChar ,}} {
    set line [string map [list $sepChar \0$sepChar\0 \" \0\"\0] $str]
    set line [string map [list \0\0 \0] $line]
    regsub "^\0" $line {} line
    regsub "\0$" $line {} line

    set val ""
    set res ""
    set state base
    foreach token [::split $line \0] {
        switch -exact -- $state {
            base {
                if {[string equal $token "\""]} {
                    set state qvalue
                    continue
                }
                if {[string equal $token $sepChar]} {
                    lappend res $val
                    set val ""
                    continue
                }
                append val $token
            }
            qvalue {
                if {[string equal $token "\""]} {
                    set state endordouble
                    continue
                }
                append val $token
            }
            endordouble {
                if {[string equal $token "\""]} {
                    append val \"
                    set state qvalue
                    continue
                }
                if {[string is space $token] && ![string equal $token $sepChar]} {
                    continue
                }
                lappend res $val
                set val ""
                set state base
                if {[string equal $token $sepChar]} {
                    continue
                }
                set state qvalue
            }
            default {
                return -code error "Internal error, illegal parsing state"
            }
        }
    }
    lappend res $val
    return $res
}

proc createByDescription {description dbfname} {
    if {[regexp {\mSTRUCT\s([^/]+)\s/STRUCT\M} $description => struct]} {
        set columns {}
        foreach c [split $struct ,] {
            if {[regexp {^ *(\w+) +([CNDL]) +(\d+)( +(\d+))? *$} $c => name type width - dec]} {
                lappend columns [list $name $type $width [expr {$dec ne "" ? $dec : 0}]]
            } else {
                error "invalid dbf structure specified in header"
            }
        }
        if {[regexp {\mLDID\s+(\d+)\M} $description => ldid]} {
            dbf d -create $dbfname -codepage [format "LDID/%d" $ldid]
        } else {
            dbf d -create $dbfname
        }
        foreach c $columns {
            $d add {*}$c
        }
        return $d
    }
    return ""
}

proc createBySniff {chan dbfname} {
    if {0 && ![catch {package present tclcsv}]} {
        set sniff [::tclcsv::sniff $chan]
        set ::csvdelimiter [dict get $sniff -delimiter]
        set ::csvquote [dict get $sniff -quote]
    }
    return ""
}

proc createByScan {chan dbfname} {
    if {1 && ![catch {package require csv}]} {
        set cmd [list apply { {line} {::csv::split -alternate $line $::csvdelimiter $::csvquote} }]
    } else {
        set cmd [list apply { {line} {splitCsv $line $::csvdelimiter} }]
    }
    set fields {}
    set count 0
    set checklines 100
    while {[gets $chan line] >= 0 && $count < $checklines} {
        set line [string trim $line]
        if {$line ne "" && [string index $line 0] ne ""} {
            set l {}
            foreach f $fields v [{*}$cmd $line] {
                lappend l [expr {max( ($f == "" ? 0 : $f), [string length $v] )}]
            }
            set fields $l
        }
        incr count
    }
    seek $chan 0
    if {[llength $fields] > 0} {
        dbf d -create $dbfname
        set i 0
        foreach f $fields {
            $d add F[incr i] C [expr {$f > 0 ?$f : 1}]
        }
        return $d
    }
    return ""
}

try {
    package require tcldbf

    set csvname [file normalize [lindex $argv 0]]
    set dbfname [file normalize [lindex $argv 1]]

    set c [open $csvname]

    if {$dbfname ne "" && [file exists $dbfname]} {
        dbf d -open $dbfname
    } else {
        set d ""
        set s [gets $c]
        if {[regexp {^#\s*DBF\s+([^\s]+)} $s => dbfname]} {
            if {[file exists $dbfname]} {
                error "dbf file $dbfname from header already exists"
            } else {
                set d [createByDescription $s $dbfname]
            }
            if {$d eq ""} {
                seek $c 0
            }
        }
        if {$dbfname eq ""} {
            error "dbf file name missing"
        }
        if {$d eq ""} {
            set d [createBySniff $c $dbfname]
        }
        if {$d eq ""} {
            set d [createByScan $c $dbfname]
        }
        if {$d eq ""} {
            error "error detecting dbf structure"
        }
        puts "created $dbfname"
    }
    set count 0
    if {1 && ![catch {package require tclcsv}]} {
        fconfigure $c -blocking false
        set r [::tclcsv::reader new -delimiter $::csvdelimiter -quote $::csvquote -comment "#" $c]
        try {
            while {true} {
                set values [$r next]
                if {[llength $values]} {
                    $d insert end {*}$values
                    incr count
                } elseif {[$r eof]} {
                    break
                }
            }
        } finally {
            $r destroy
        }
    } else {
        if {1 && ![catch {package require csv}]} {
            set cmd [list apply { {line} {::csv::split -alternate $line $::csvdelimiter $::csvquote} }]
        } else {
            set cmd [list apply { {line} {splitCsv $line $::csvdelimiter} }]
        }
        while {[gets $c line] >= 0} {
            set line [string trim $line]
            if {[string length $line] && [string index $line 0] ne "#"} {
                $d insert end [{*}$cmd $line]
                incr count
            }
        }
    }
    puts "imported $count rows"
    $d close
    close $c
} on error message {
    #puts stderr $message
    puts stderr $::errorInfo
    catch {$d close}
    catch {close $c}
    exit 1
}
