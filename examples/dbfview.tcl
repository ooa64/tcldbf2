#!/bin/sh
# the next line restarts using tclsh \
exec wish8.6 "$0" "$@"

package require Tk 8.6-
package require tcldbf 2.1-

wm title . "DBF View"

array set state {}
array set option {
    -filename ""
    -encoding ""
    -fixed false
    -bulk 100
    -limit 10000
    -scale ""
    -debug 0
}

proc appInit {argc argv} {
    global state option

    if {$argc % 2 == 0} {
        array set option $argv  
    } else {
        array set option [linsert $argv end-1 "-filename"]
    }

    if {[string is double -strict $option(-scale)]} {
        set scale [expr {min( max( $option(-scale), 0.2 ), 5.0 )}]
        if {$::tcl_platform(platform) eq "unix"} {
            foreach font {Default Text Fixed Heading Caption Tooltip Icon Menu} {
                set size [font configure Tk${font}Font -size]
                font configure Tk${font}Font -size [expr {int($scale*$size)}]
            }
        } else {
            tk scaling $scale
        }
    }

    if {$option(-fixed)} {
        ttk::style configure Treeview -font TkFixedFont
    }
    set font [ttk::style lookup Treeview -font]
    if {$font eq ""} {
        set font TkDefaultFont
    }
    set state(font:width) [expr {[font measure $font "X"] + 1}]
    set state(font:height) [expr {[font metrics $font -linespace] + 2}]

    ttk::style configure Treeview -rowheight $state(font:height)

    # bind Treeview <Prior>     {%W yview scroll -1 page; puts ID:[%W identify row 0 0]}
    # bind Treeview <Next>      {%W yview scroll 1 page; puts ID:[%W identify row 0 0]}
    bind Treeview <Home>      {%W xview moveto 0}
    bind Treeview <End>       {%W xview moveto 1}
    bind Treeview <Left>      {%W xview scroll -$::state(font:width) unit}
    bind Treeview <Right>     {%W xview scroll $::state(font:width) unit}
    bind Treeview <<Copy>> {
        clipboard clear -displayof %W
        foreach i [%W selection] {
            clipboard append -displayof %W [join [%W item $i -values] \t]\n
        }
    }

    bind Button <Left>        {focus [tk_focusPrev %W]}
    bind Button <Right>       {focus [tk_focusNext %W]}
    bind Button <Up>          {focus [tk_focusPrev %W]}
    bind Button <Down>        {focus [tk_focusNext %W]}
    bind Button <Return>      {%W invoke; break}

    if {$option(-debug)} {
        catch {console show}
        catch {package require tkcon; bind all <F9> {tkcon show}}
    }
}

proc windowCreate {toplevel} {
    global state option

    set state(window) [expr {$toplevel eq "." ? "" : $toplevel}]

    set x $state(font:width)
    set y $state(font:height)
    set w $state(window)

    menu $w.menu -tearoff off
    menu $w.menu.file -tearoff off
    menu $w.menu.view -tearoff off
    # menu $w.menu.help
    $w.menu add cascade -menu $w.menu.file -label "File"   
    $w.menu add cascade -menu $w.menu.view -label "View"   
    $w.menu.file add command -command {fileOpen} -label "Open" -accelerator "Ctrl-O"
    $w.menu.file add separator
    $w.menu.file add command -command {windowClose} -label "Quit" -accelerator "Ctrl-Q" 
    $w.menu.view add command -command {infoCreate} -label "Info" -accelerator "Ctrl-I"
    # $w.menu.view add command -command {recordCreate} -label "Record" -accelerator "Enter"
    $w.menu.view add separator
    $w.menu.view add command -command {findCreate} -label "Find" -accelerator "Ctrl-F"
    $w.menu.view add command -command {findNext 1} -label "Find Next" -accelerator "F3"
    $w.menu.view add command -command {findNext 0} -label "Find Prev" -accelerator "Shift-F3"
    $toplevel configure -menu $w.menu -takefocus 0

    sheetCreate 50 10

    # NOTE: use keycode bindings to ignore keyboard language mode on windows
    bind $toplevel <Control-Key> {switch %k 79 fileOpen 81 windowClose 73 infoCreate 70 findCreate}
    # 67 {event generate %W <<Copy>>}
    # 86 {event generate %W <<Paste>>}
    # 88 {event generate %W <<Cut>>; puts gen:%W}
    bind $toplevel <F3> {findNext 1}
    bind $toplevel <Shift-F3> {findNext 0}

    bind All <<Cut>> {puts cut:%W}

    wm protocol $toplevel WM_DELETE_WINDOW {windowClose}
    wm minsize $toplevel [expr {50*$x}] [expr {10*$y}]
    wm geometry $toplevel [expr {100*$x}]x[expr {20*$y}]

    tk::PlaceWindow $toplevel
}

proc windowClose {} {
    global state

    if {[info exists state(dbf:handle)]} {
        catch {$state(dbf:handle) forget}
    }
    exit
}

proc sheetCreate {width height} {
    global state
    set w $state(window)

    set state(find:first) ""
    set state(find:last) ""
    set state(find:item) ""
    set state(find:string) ""
    set state(find:field) "all"
    set state(find:nocase) "0"
    set state(find:regexp) "0"

    ttk::treeview $w.tree -height $height \
            -yscrollcommand "$w.vbar set" -xscrollcommand "$w.hbar set"
    ttk::scrollbar $w.vbar -orient vertical -command "$w.tree yview"
    ttk::scrollbar $w.hbar -orient horizontal -command "$w.tree xview"
    ttk::label $w.status 
    grid $w.tree $w.vbar -sticky "news"
    grid $w.hbar "x" -sticky "we"
    grid $w.status - -sticky "w"

    grid columnconfigure [winfo parent $w.tree] 0 -weight 1
    grid rowconfigure [winfo parent $w.tree] 0 -weight 1

}

proc sheetDestroy {} {
    global state
    set w $state(window)

    if {[winfo exists $w.tree]} {
        destroy $w.tree $w.vbar $w.hbar $w.status
    }
}

proc sheetBind {} {
    global state
    set w $state(window)
    set x $state(font:width)

    bind $w.tree <Return> {+recordCreate}
    bind $w.tree <Double-1> {+recordCreate}
    bind $w.tree <<TreeviewSelect>> {+recordLoad focus}

    bind $w.tree <Control-Home> {sheetSelect $::state(find:first)}
    bind $w.tree <Control-End> {sheetSelect $::state(find:last)}

    bind $w.tree <Down> {+fileLoadContinue focus}
    bind $w.tree <Next> {+fileLoadContinue focus}
    bind $w.vbar <ButtonRelease-1> {+fileLoadContinue bar %x %y}
}

proc sheetSelect {item} {
    global state option
    set w $state(window)

    if {$item ne ""} {
        $w.tree see $item
        $w.tree focus $item
        $w.tree selection set [list $item]
    }
}

proc sheetRecordNo {item} {
    global state option
    set w $state(window)

    regsub -all {[^\d]*} [$w.tree "item" $item -text] ""
}

proc fileOpen {{filename ""}} {
    global state option
    set w $state(window)
    set x $state(font:width)

    if {$filename eq ""} {
        set filename [tk_getOpenFile -parent [winfo parent $w.tree] \
                -filetypes {{"DBF files" {.dbf .DBF}} {"All files" *}}]
    }
    if {$filename eq ""} {
        return
    }

    fileClose

    $w.status configure -text "Opening $filename"
    update idletasks

    try {
        dbf h -open $filename -readonly
        if {$option(-encoding) ne ""} {
            $h encoding $option(-encoding)
        }
    } on error {message} {
        tk_messageBox -icon "error" -title "Error" -message $message
        return
    } finally {
        $w.status configure -text ""
    }

    wm title [winfo toplevel $w.tree] \
            [string cat "DBF View - " [file nativename [file normalize $filename]]]

    set state(dbf:handle) $h
    set state(dbf:name) [file normalize $filename]
    set state(dbf:limit) [expr {min( [$h info records], $option(-limit) )}]
    set state(dbf:loading) ""
    set state(dbf:count) 0

    set fields [$h fields]
    set columns [dict create]

    # NOTE: use synthetic column names (1,2,...) to avoid duplicated names

    set c 0
    $w.tree configure -columns [concat [lmap f $fields {incr c}] [list \#end]]
    $w.tree column \#0 -width [expr {8*$x+$x}] -minwidth [expr {8*$x+$x}] -stretch 0 -anchor "e"
    $w.tree column \#end -minwidth 0 -width 0 -stretch 1

    set c 0
    foreach f $fields {
        incr c
        lassign $f n - t s
        $w.tree heading $c -text $n
        $w.tree column $c -stretch 0 -anchor [expr {$t in {F M L N} ? "e" : "w"}]
        dict set columns $c [string length $n]
    }

    fileLoadRows

    foreach row [$w.tree children {}] {
        foreach c [dict keys $columns] v [$w.tree item $row -values] {
            dict set columns $c [expr {max( [dict get $columns $c], [string length $v] )}]
        }
    }
    foreach c [dict keys $columns] {
        $w.tree column $c -width [expr {min( [dict get $columns $c], 50 ) * $x + 8}]
    }

    after idle [list focus $w.tree]

    sheetBind
    sheetSelect $state(find:first)
}

proc fileClose {} {
    global state

    if {![info exists state(dbf:handle)]} {
        return
    }

    wm title [winfo toplevel $state(window).tree] "DBF View"

    after cancel $state(dbf:loading)
    
    recordDestroy
    sheetDestroy
    $state(dbf:handle) forget

    array unset state dbf:*

    sheetCreate 50 10
}

proc fileReload {} {
    global state option

    if {![info exists state(dbf:handle)]} {
        return
    }
    set w $state(window)
    set h $state(dbf:handle)

    $w.tree delete [$w.tree children {}]

    set state(dbf:limit) [expr {min( [$h info records], $option(-limit) )}]
    set state(dbf:loading) ""
    set state(dbf:count) 0
    set state(find:first) ""
    set state(find:last) ""
    set state(find:item) ""

    fileLoadRows
}

proc fileLoadRows {{update ""}} {
    global state option
    set w $state(window)
    set h $state(dbf:handle)

    set item ""
    set row $state(dbf:count)
    set maxrow [expr {min( $row + $option(-bulk), $state(dbf:limit) )}]
    while {$row < $maxrow} {
        set item [$w.tree insert {} end \
                -text [format "%1s%6d " \
                        [expr {[$h deleted $row] ? "*" : " "}] \
                        [expr {$row+1}]] \
                -values [$h record $row]]
        incr row
    }
    if {$state(dbf:count) == 0} {
        set state(find:first) [lindex [$w.tree children {}] 0]
    }
    set state(find:last) $item
    set state(dbf:count) $row

    $w.status configure -text "$row/[$h info records] rows loaded"

    if {$update ne ""} {
        update
    }
    if {$state(dbf:count) < $state(dbf:limit)} {
        set state(dbf:loading) [after 1 {fileLoadRows "update"}]
    }
}

proc fileLoadContinue {what args} {
    global state option
    set w $state(window)
    set h $state(dbf:handle)

    if {$state(dbf:count) < $state(dbf:limit)} {
        return
    }
    if {$state(dbf:count) >= [$h info records]} {
        return
    }
    switch -- $what {
        "bar" {
            if {[lindex [$w.vbar get] 1] < 1.0} {
                return
            }
        }
        "focus" {
            if {[$w.tree next [$w.tree focus]] ne {}} {
                return
            }
        }
        default {}
    }
    switch -- [tk_dialog $w.dialog "Question" "Load more rows?" "" \
            2 "Yes, $option(-limit) rows" "Yes, all rows" "   Cancel   "] {
        0 {
            set state(dbf:limit) \
                [expr {min( $state(dbf:limit) + $option(-limit), [$h info records] )}]
        }
        1 {
            set state(dbf:limit) [$h info records]
        }
        default {
            return
        }
    }
    set state(dbf:loading) [after 1 {fileLoadRows "update"}]
}

proc recordCreate {} {
    global state
    set w $state(window)
    set x $state(font:width)
    set y $state(font:height)

    if {![info exists state(dbf:handle)]} {
        return
    }
    if {[winfo exists $w.record]} {
        wm deiconify $w.record
        return
    }
    toplevel $w.record
    wm withdraw $w.record

    canvas $w.record.c -height [expr {20*$y}] -yscrollcommand "$w.record.v set"
    ttk::scrollbar $w.record.v -command "$w.record.c yview"
    ttk::frame $w.record.c.f
    foreach c [lrange [$w.tree cget -columns] 0 end-1] {
        ttk::label $w.record.c.f.l$c -text [$w.tree heading $c -text] -anchor "e"
        ttk::entry $w.record.c.f.e$c -width 50 -state readonly
        grid $w.record.c.f.l$c $w.record.c.f.e$c - - -sticky "we" -padx 4 -pady 2
    }
    grid columnconfigure $w.record.c.f 1 -weight 1

    update idletasks
    $w.record.c configure -width [winfo reqwidth $w.record.c.f]
    $w.record.c.f configure -width [winfo reqwidth $w.record.c.f] -height [winfo reqheight $w.record.c.f]

    ttk::button $w.record.b1 -text "Prev" -command {recordLoad "prev"}
    ttk::button $w.record.b2 -text "Next" -command {recordLoad "next"}
    ttk::button $w.record.b3 -text "Close" -command [list destroy $w.record]

    $w.record.c create window 0 0 -anchor nw -window $w.record.c.f
    $w.record.c configure -scrollregion [$w.record.c bbox all]

    grid $w.record.c - - - $w.record.v -sticky "news"
    grid "x" $w.record.b1 $w.record.b2 $w.record.b3 "x" -sticky "e" -padx 4 -pady 2
    grid columnconfigure $w.record 0 -weight 1
    grid rowconfigure $w.record 0 -weight 1

    bind $w.record <Escape> [list destroy $w.record]

    wm title $w.record "DBF Record"
    wm transient $w.record [winfo parent $w.record]

    tk::PlaceWindow $w.record "widget" [winfo parent $w.record]

    recordLoad "focus"
}

proc recordLoad {position} {
    global state
    set w $state(window)
    set h $state(dbf:handle)

    if {![winfo exists $w.record]} {
        return
    }

    set item [$w.tree focus]
    if {$item eq ""} {
        destroy $w.record
    }
    switch -- $position {
        "first" {set item $state(find:first)}
        "last" {set item $state(find:last)}
        "next" {set item [$w.tree next $item]}
        "prev" {set item [$w.tree prev $item]}
    }
    if {$item eq ""} {
        fileLoadContinue "focus"
        return
    }
    if {$position ne "focus"} {
        sheetSelect $item
        update
        return
    }

    set r [sheetRecordNo $item]
    set c 0
    foreach f [$h fields] {
        incr c
        $w.record.c.f.e$c configure -state normal
        $w.record.c.f.e$c delete 0 end
        $w.record.c.f.e$c configure -state readonly
    }
    set c 0
    foreach f [$h fields] v [$w.tree "item" $item -values] {
        update
        if {![winfo exists $w.record] || $item ne [$w.tree focus]} {
            return
        }
        incr c
        lassign $f n - t
        switch -- $t {
            "D" {
                if {[regexp {\d{6}} $v]} {
                    catch {clock format [clock scan $v] -format "%d/%m/%Y"} v
                }
            }
            "M" {
                if {[string is integer -strict $r]} {
                    catch {encoding convertfrom [$h encoding] [$h memo $r $n]} v
                }
            }
        }
        $w.record.c.f.e$c configure -state normal
        $w.record.c.f.e$c delete 0 end
        $w.record.c.f.e$c insert end $v
        $w.record.c.f.e$c configure -state readonly
    }

    wm title $w.record "DBF Record - $r"
}

proc recordDestroy {} {
    global state
    set w $state(window)

    if {[winfo exists $w.record]} {
        destroy $w.record
    }
}

proc infoCreate {} {
    global state

    if {![info exists state(dbf:handle)]} {
        return
    }
    set w $state(window)
    set x $state(font:width)
    set h $state(dbf:handle)

    if {[winfo exists $w.info]} {
        wm deiconify $w.info
        return
    }
    toplevel $w.info

    set i 0
    foreach {n v} [list \
        "Filename" [file tail $state(dbf:name)] \
        "Filesize" [file size $state(dbf:name)] \
        "Records" [$h info records] \
        "Codepage" [$h codepage] \
    ] {
        ttk::label $w.info.l$i -text $n -anchor "e"
        ttk::entry $w.info.e$i
        grid $w.info.l$i $w.info.e$i -sticky "we" -padx 4 -pady 2
        $w.info.e$i insert end $v
        $w.info.e$i configure -state readonly
        incr i
    }

    ttk::label $w.info.l$i -text "Encoding" -anchor "e"
    ttk::combobox $w.info.encoding -values [lsort -dictionary [encoding names]]
    grid $w.info.l$i $w.info.encoding -sticky "we" -padx 4 -pady 2

    $w.info.encoding insert end [$h encoding]
    $w.info.encoding configure -state readonly
    set columns [dict create \
            field [expr {10*$x}] \
            type  [expr {4*$x}] \
            size  [expr {4*$x}] \
            prec  [expr {4*$x}]] 
    ttk::treeview $w.info.t -show {headings} -columns [dict keys $columns] \
            -yscrollcommand "$w.info.v set"
    ttk::scrollbar $w.info.v -orient vertical -command "$w.info.t yview"
    grid $w.info.t - $w.info.v -sticky "news"

    ttk::button $w.info.ok -text "OK" -command {infoOk}
    grid "x" $w.info.ok -sticky "e" -padx 4 -pady 2

    grid columnconfigure $w.info 1 -weight 1
    grid rowconfigure $w.info 5 -weight 1

    foreach n [dict keys $columns] {
        $w.info.t heading $n -text $n
        $w.info.t column $n -width [dict get $columns $n] -anchor "e"
    }
    foreach f [$h fields] {
        $w.info.t insert {} end -values [lreplace $f 1 1]
    }

    bind $w.info <Escape> [list destroy $w.info]

    wm title $w.info "DBF Info"

    tk::PlaceWindow $w.info "widget" [winfo parent $w.info]
    tk::SetFocusGrab $w.info $w.info.ok
}

proc infoOk {} {
    global state
    set w $state(window)
    set h $state(dbf:handle)

    if {![winfo exists $w.info]} {
        return
    }

    set e [$w.info.encoding get]
    if {$e ne [$h encoding]} {
        after cancel $state(dbf:loading)
        $h encoding $e
        fileReload
        recordLoad "focus"
    } 
    destroy $w.info
}

proc findCreate {} {
    global state
    set w $state(window)

    if {![info exists state(dbf:handle)]} {
        return
    }

    if {[winfo exists $w.find]} {
        wm deiconify $w.find
        return
    }
    toplevel $w.find

    ttk::label $w.find.l1 -text "Find" -anchor "e"
    ttk::entry $w.find.string -textvariable ::state(find:string) -width 50
    grid $w.find.l1 $w.find.string - - - -sticky "we" -padx 4 -pady 2

    ttk::label $w.find.l2 -text "Field" -anchor "e"
    ttk::combobox $w.find.field -state readonly -textvariable ::state(find:field) \
            -values [concat [list "all"] [lmap f [$state(dbf:handle) fields] {lindex $f 0}]]

    grid $w.find.l2 $w.find.field -sticky "we" -padx 4 -pady 2

    ttk::checkbutton $w.find.nocase -variable ::state(find:nocase) -text "ignore case"
    grid x $w.find.nocase -sticky "w" -padx 4 -pady 2

    ttk::checkbutton $w.find.regexp -variable ::state(find:regexp) -text "regular expression"
    grid x $w.find.regexp -sticky "w" -padx 4 -pady 2

    ttk::label $w.find.status
    ttk::button $w.find.b1 -text "Prev" -command [list findNext 0]
    ttk::button $w.find.b2 -text "Next" -command [list findNext 1]
    ttk::button $w.find.b3 -text "Close" -command [list destroy $w.find]
    grid $w.find.status - $w.find.b1 $w.find.b2 $w.find.b3 -sticky "e" -padx 4 -pady 2
    grid configure $w.find.status -sticky "w"

    bind $w.find.string <Return> [list findNext 1]
    bind $w.find <Escape> [list destroy $w.find]

    wm title $w.find "DBF Find"
    wm transient $w.find [winfo parent $w.find]
    wm withdraw $w.find

    tk::PlaceWindow $w.find "widget" [winfo parent $w.find]
    tk::SetFocusGrab $w.find $w.find.string
}

proc findNext {forward} {
    global state
    set w $state(window)

    if {![info exists state(dbf:handle)]} {
        return
    }
    if {![winfo exists $w.find]} {
        after idle findCreate
    }
    if {$state(find:string) eq ""} {
        return
    }

    set i [lsearch -index 0 [$state(dbf:handle) fields] $state(find:field)]
    if {$i >= 0} {
        set columns [expr {$i + 1}]
    } else {
        set columns [lrange [$w.tree cget -columns] 0 end-1]
    }

    set item [$w.tree focus]
    if {$item ne ""} {
        set nextitem [expr {$forward ? [$w.tree next $item] : [$w.tree prev $item]}]
    } else {
        set nextitem [expr {$forward ? $state(find:first) : $state(find:last)}]
    }

    while {true} {
        update

        if {![winfo exists $w.find]} {
            return
        }
        if {$forward && $nextitem eq ""} {
            fileLoadContinue "anyway"
            set nextitem [$w.tree next $item]
            if {$nextitem eq "" && $state(dbf:count) < $state(dbf:limit)} {
                continue
            }
        }
        if {$nextitem eq ""} {
            destroy $w.find
            tk_messageBox -icon "info" -title "Find" -message "Not found"
            break
        }
        set item $nextitem

        $w.find.status configure -text [string cat "Row " [sheetRecordNo $item]]

        foreach c $columns {
            set s [$w.tree set $item $c]
            if {$state(find:regexp)} {
                if {$state(find:nocase)} {
                    set result [regexp -nocase $state(find:string) $s]
                } else {
                    set result [regexp $state(find:string) $s]
                }
            } else {
                if {$state(find:nocase)} {
                    set result [string first [string toupper $state(find:string)] [string toupper $s]]
                } else {
                    set result [string first $state(find:string) $s]
                }
                incr result
            }
            if {$result} {
                destroy $w.find
                sheetSelect $item
                return
            }
        }
        set nextitem [expr {$forward ? [$w.tree next $item] : [$w.tree prev $item]}]
    }
}

appInit $argc $argv

windowCreate .

after 0 [list fileOpen $option(-filename)]
