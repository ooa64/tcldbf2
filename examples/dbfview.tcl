package require Tk
package require tcldbf

wm title . "DBF View"

array set state {}
array set option {
    -filename ""
    -encoding ""
    -fixed false
    -bulk 1000
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

    option add *TearOff off

    bind Button <Left>        {focus [tk_focusPrev %W]}
    bind Button <Right>       {focus [tk_focusNext %W]}
    bind Button <Up>          {focus [tk_focusPrev %W]}
    bind Button <Down>        {focus [tk_focusNext %W]}
    bind Button <Return>      {%W invoke; break}

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

    # NOTE: fixup treeview row height
    ttk::style configure Treeview -rowheight $state(font:height)

    set state(find:string) ""
    set state(find:regexp) 0
    set state(find:nocase) 0

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

    menu $w.menu
    menu $w.menu.file
    menu $w.menu.view
    $w.menu add cascade -menu $w.menu.file -label "File"   
    $w.menu add cascade -menu $w.menu.view -label "View"   
    $w.menu.file add command -command {fileOpen} -label "Open" -accelerator "Ctrl-O"
    $w.menu.file add separator
    $w.menu.file add command -command {windowClose} -label "Quit" -accelerator "Ctrl-Q" 
    $w.menu.view add command -command {infoCreate} -label "Info" -accelerator "Ctrl-I"
    $w.menu.view add separator
    $w.menu.view add command -command {findCreate} -label "Find" -accelerator "Ctrl-F"
    $w.menu.view add command -command {findNext 1} -label "Find Next" -accelerator "F3"
    $w.menu.view add command -command {findNext 0} -label "Find Prev" -accelerator "Shift-F3"
    $toplevel configure -menu $w.menu

    sheetCreate 50 10

    foreach {k c} {o fileOpen q windowClose i infoCreate f findCreate} {
        bind $toplevel <Control-$k> [list $c]
        bind $toplevel <Control-[string toupper $k]> [list $c]
    }
    bind $toplevel <F3> {findNext 1}
    bind $toplevel <Shift-F3> {findNext 0}

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
    set x $state(font:width)

    ttk::treeview $w.tree -height $height \
            -yscroll "$w.vbar set" -yscroll "$w.vbar set" -xscroll "$w.hbar set"
    ttk::scrollbar $w.vbar -orient vertical -command "$w.tree yview"
    ttk::scrollbar $w.hbar -orient horizontal -command "$w.tree xview"
    ttk::label $w.status 
    grid $w.tree $w.vbar -sticky "news"
    grid $w.hbar "x" -sticky "we"
    grid $w.status - -sticky "w"

    grid columnconfigure [winfo parent $w.tree] 0 -weight 1
    grid rowconfigure [winfo parent $w.tree] 0 -weight 1

    bind $w.tree <<TreeviewSelect>> {+recordLoad focus}
    bind $w.tree <Return> {+recordCreate}
    bind $w.tree <Double-1> {+recordCreate}
    bind $w.tree <Down> {+fileLoadContinue focus}
    bind $w.tree <Next> {+fileLoadContinue focus}
    bind $w.vbar <ButtonRelease-1> {+fileLoadContinue bar %x %y}
}

proc sheetDestroy {} {
    global state
    set w $state(window)

    if {[winfo exists $w.tree]} {
        destroy $w.tree $w.vbar $w.hbar $w.status
    }
}

proc fileOpen {{filename ""}} {
    global state option
    set w $state(window)
    set x $state(font:width)

    if {$filename eq ""} {
        set filename [tk_getOpenFile -filetypes {{"DBF files" {.dbf .DBF}} {"All files" *}}]
    }
    if {$filename eq ""} {
        return
    }

    fileClose

    try {
        dbf state(dbf:handle) -open $filename -readonly
        if {$option(-encoding) ne ""} {
            $state(dbf:handle) encoding $option(-encoding)
        }
    } on error {message} {
        tk_messageBox -icon "error" -title "Error" -message $message
        return
    }

    set state(dbf:name) [file normalize $filename]
    set state(dbf:limit) [expr {min( [$state(dbf:handle) info records], $option(-limit) )}]
    set state(dbf:loading) ""
    set state(dbf:count) 0

    set fields [$state(dbf:handle) fields]
    set columns [dict create]

    # NOTE: using digital column names to avoid duplicated names
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

    set rows [$w.tree children {}]
    set state(find:first) [lindex $rows 0]
    set state(find:last) ""
    set state(find:item) ""
    set state(find:field) ""

    foreach row $rows {
        foreach c [dict keys $columns] v [$w.tree item $row -values] {
            dict set columns $c [expr {max( [dict get $columns $c], [string length $v] )}]
        }
    }
    foreach c [dict keys $columns] {
        $w.tree column $c -width [expr {min( [dict get $columns $c], 50 ) * $x + 8}]
    }

    wm title [winfo toplevel $w.tree] \
            [string cat "DBF View - " [file nativename $state(dbf:name)]]
}

proc fileClose {} {
    global state

    if {![info exists state(dbf:handle)]} {
        return
    }
    
    after cancel $state(dbf:loading)
    
    recordDestroy
    sheetDestroy
    $state(dbf:handle) forget

    array unset state dbf:*

    sheetCreate 50 10
}

proc fileReload {} {
    global state option
    set w $state(window)

    if {![info exists state(dbf:handle)]} {
        return
    }

    $w.tree delete [$w.tree children {}]

    set state(dbf:limit) \
            [expr {min( [$state(dbf:handle) info records], $option(-limit) )}]
    set state(dbf:loading) ""
    set state(dbf:count) 0

    fileLoadRows

    set state(find:first) [lindex [$w.tree children {}] 0]
    set state(find:last) ""
    set state(find:item) ""
    set state(find:field) ""
}

proc fileLoadRows {{update ""}} {
    global state option
    set w $state(window)

    set row $state(dbf:count)
    set maxrow [expr {min( $row + $option(-bulk), $state(dbf:limit) )}]
    while {$row < $maxrow} {
        set deleted [expr {[$state(dbf:handle) deleted $row] ? "*" : " "}]
        $w.tree insert {} end \
                -text [format "%1s%6d " $deleted [expr {$row+1}]] \
                -values [$state(dbf:handle) record $row]
        incr row
    }
    set state(dbf:count) $row

    $w.status configure -text "$row/[$state(dbf:handle) info records] rows loaded"

    if {$update ne ""} {
        update
    }
    if {$state(dbf:count) < $state(dbf:limit)} {
        set state(dbf:loading) [after idle {fileLoadRows "update"}]
    }
}

proc fileLoadContinue {what args} {
    global state option
    set w $state(window)

    if {$state(dbf:count) < $state(dbf:limit)} {
        return
    }
    if {$state(dbf:count) >= [$state(dbf:handle) info records]} {
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
            2 "Yes, $option(-limit) rows" "Yes, all rows" "Cancel"] {
        0 {
            set state(dbf:limit) [expr {min( $state(dbf:limit) + $option(-limit),
                    [$state(dbf:handle) info records] )}]
        }
        1 {
            set state(dbf:limit) [$state(dbf:handle) info records]
        }
        default {
            return
        }
    }
    fileLoadRows "update"
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
    # wm attributes $w.record -topmost yes
    wm transient $w.record $w

    tk::PlaceWindow $w.record "widget" $w

    recordLoad "focus"
}

proc recordLoad {position} {
    global state
    set w $state(window)

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
        $w.tree see $item
        $w.tree focus $item
        $w.tree selection set $item
        update
        return
    }

    set c 0
    foreach f [$state(dbf:handle) fields] {
        incr c
        $w.record.c.f.e$c configure -state normal
        $w.record.c.f.e$c delete 0 end
        $w.record.c.f.e$c configure -state readonly
    }
    set c 0
    foreach f [$state(dbf:handle) fields] v [$w.tree item $item -values] {
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
                set r [regsub -all {[^\d]*} [$w.tree item $item -text] ""]
                if {[string is integer -strict $r] && [string is integer -strict $v]} {
                    catch {encoding convertfrom [$state(dbf:handle) encoding] \
                            [$state(dbf:handle) memo $r $n]} v
                }
            }
        }
        $w.record.c.f.e$c configure -state normal
        $w.record.c.f.e$c delete 0 end
        $w.record.c.f.e$c insert end $v
        $w.record.c.f.e$c configure -state readonly
    }

    wm title $w.record [string cat "DBF Record - " [regsub { +} [$w.tree item $item -text] ""]]
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
    set w $state(window)
    set x $state(font:width)

    if {![info exists state(dbf:handle)]} {
        return
    }

    if {[winfo exists $w.info]} {
        wm deiconify $w.info
        return
    }
    toplevel $w.info

    set i 0
    foreach {n v} [list \
        "Filename" [file tail $state(dbf:name)] \
        "Filesize" [file size $state(dbf:name)] \
        "Records" [$state(dbf:handle) info records] \
        "Codepage" [$state(dbf:handle) codepage] \
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

    $w.info.encoding insert end [$state(dbf:handle) encoding]
    set columns [dict create \
        field [expr {10*$x}] \
        type  [expr {4*$x}] \
        size  [expr {4*$x}] \
        prec  [expr {4*$x}]] 
    ttk::treeview $w.info.t -show {headings} -columns [dict keys $columns] \
            -yscroll "$w.info.v set"
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
    foreach f [$state(dbf:handle) fields] {
        $w.info.t insert {} end -values [lreplace $f 1 1]
    }

    bind $w.info <Escape> [list destroy $w.info]

    wm title $w.info "DBF Info"

    tk::PlaceWindow $w.info "widget" $$w.tree
    tk::SetFocusGrab $w.info $w.info.ok
}

proc infoOk {} {
    global state
    set w $state(window)

    if {![winfo exists $w.info]} {
        return
    }

    set e [$w.info.encoding get]
    if {$e ne [$state(dbf:handle) encoding]} {
        after cancel $state(dbf:loading)
        $state(dbf:handle) encoding $e
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
    ttk::entry $w.find.string -textvariable state(find:string) -width 50
    grid $w.find.l1 $w.find.string - - - -sticky "we" -padx 4 -pady 2

    ttk::label $w.find.l2 -text "Field" -anchor "e"
    ttk::combobox $w.find.field -textvariable state(find:field) \
            -values [concat [list ""] [lmap f [$state(dbf:handle) fields] {lindex $f 0}]]

    grid $w.find.l2 $w.find.field -sticky "we" -padx 4 -pady 2

    ttk::checkbutton $w.find.regexp -variable state(find:regexp) -text "regular expression"
    grid x $w.find.regexp -sticky "w" -padx 4 -pady 2

    ttk::checkbutton $w.find.nocase -variable state(find:nocase) -text "ignore case"
    grid x $w.find.nocase -sticky "w" -padx 4 -pady 2

    ttk::label $w.find.status
    ttk::button $w.find.b1 -text "Prev" -command [list findNext 0]
    ttk::button $w.find.b2 -text "Next" -command [list findNext 1]
    ttk::button $w.find.b3 -text "Close" -command [list destroy $w.find]
    grid $w.find.status - $w.find.b1 $w.find.b2 $w.find.b3 -sticky "e" -padx 4 -pady 2
    grid configure $w.find.status -sticky "w"

    bind $w.find <Escape> [list destroy $w.find]

    wm title $w.find "DBF Find"

    tk::PlaceWindow $w.find "widget" $w.tree
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
        }
        if {$nextitem eq ""} {
            destroy $w.find
            tk_messageBox -icon "info" -title "Find" -message "Not found"
            break
        }
        set item $nextitem

        $w.find.status configure \
                -text [string cat "Row " [regsub -all {[^\d]*} [$w.tree item $item -text] ""]]

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
                $w.tree see $item
                $w.tree focus $item
                $w.tree selection set $item
                return
            }
        }
        set nextitem [expr {$forward ? [$w.tree next $item] : [$w.tree prev $item]}]
    }
}

appInit $argc $argv

windowCreate .

after 0 [list fileOpen $option(-filename)]
