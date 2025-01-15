#!/bin/sh
# the next line restarts using tclsh \
exec tclsh8.6 "$0" "$@"

if {$argc < 1 || $argc > 2} {
    puts stderr "Usage: [file tail $argv0] <dbf-file> ?<csv-file>?"
    exit 1
}

variable csvencoding ""
variable csvdelimiter ","
variable csvquote "\""

proc joinCsv {values {sepChar ,}} {
    set str ""
    set sep {}
    foreach val $values {
        if { [string match "*\[\"$sepChar \]*" $val] } {
            append str $sep\"[string map [list \" \"\"] $val]\"
        } else {
            append str $sep$val
        }
        set sep $sepChar
    }
    return $str
}

try {
    package require tcldbf

    set dbfname [file normalize [lindex $argv 0]]
    set csvname [file normalize [lindex $argv 1]]

    dbf d -open $dbfname -readonly

    if {$csvname ne ""} {
        set c [open $csvname {CREAT EXCL WRONLY APPEND}]
    } else {
        set c stdout
    }

    set s "# DBF"
    append s " " [file tail $dbfname]
    if {[$d codepage] ne ""} {
        append s " LDID " [lindex [split [$d codepage] "/"] 1]
    }
    append s " STRUCT " [join [lmap f [$d fields] {lreplace $f 1 1}] ", "] " /STRUCT"
    puts $c $s
    set count 0
    for {set i 0} {$i < [$d info records]} {incr i} {
        if {![$d deleted $i]} {
            puts $c [joinCsv [$d record $i] $::csvdelimiter]
            incr count
        }
    }
    $d close
    if {$c ne "stdout"} {
        close $c
    }
    puts stderr "exported $count rows"
} on error message {
    puts stderr $message
    catch {$d close}
    catch {close $c}
    exit 1
}
