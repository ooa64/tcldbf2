#!/bin/sh
# the next line restarts using tclsh \
exec tclsh8.6 "$0" "$@"

if {$argc != 1} {
    puts stderr "Usage: [file tail $argv0] <dbf-file>"
    exit 1
}

try {
    package require tcldbf

    set dbfname [file normalize [lindex $argv 0]]

    dbf d -open $dbfname -readonly

    puts dbfname:\t[file tail $dbfname]
    puts Codepage:\t[$d codepage]
    puts Filesize:\t[file size $dbfname]
    puts Records:\t[$d info records]
    puts Fields:
    foreach f [$d fields] {
        puts [format "\t%-10s\t%-7s %s %s %s" {*}$f]
    }
    if {[$d info records] > 0} {
        # FIXME: skip deleted
        set row [expr {int([$d info records]/2)}]
        puts Sample\ #$row:
        foreach f [$d fields] v [$d record $row] {
            puts [format "\t%-10s\t%s" [lindex $f 0] $v]
        }
    }
    $d close
} on error message {
    puts stderr $message
    catch {$d close}
    exit 1
}
