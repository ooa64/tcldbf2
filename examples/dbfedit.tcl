#!/bin/sh
# the next line restarts using tclsh \
exec wish8.6 "$0" "$@"

package require Tk 8.6-
package require Tktable 2.10-
package require tcldbf 2.1-

wm title . "DBF Edit"
wm withdraw .

array set state {}
array set option {
    -filename ""
    -encoding ""
    -scale ""
    -font ""
    -width 100
    -height 30
    -maxcolwidth 50
    -edit false
    -debug false
}

proc appAbout {} {
    tk_messageBox -type "ok" -title "About" -message "DBF Edit 0.1" -detail "\n\
            Tcl [package require Tcl]\n\
            Tk [package require Tk]\n\
            Tktable [package require Tktable]\n\
            Tcldbf [package require tcldbf]\n"
}

proc appInit {argc argv} {
    global state option

    if {$argc % 2 == 0} {
        array set option $argv  
    } else {
        array set option [linsert $argv end-1 "-filename"]
    }
    if {![string is boolean -strict $option(-debug)]} {
        error "invalid debug option"
    }
    if {![string is boolean -strict $option(-edit)]} {
        error "invalid edit option"
    }
    if {
        ![string is integer -strict $option(-width)] || $option(-width) < 50 ||
        ![string is integer -strict $option(-height)] || $option(-height) < 10 ||
        ![string is integer -strict $option(-maxcolwidth)] || $option(-maxcolwidth) < 1
    } {
        error "invalid width/height option"
    }
    if {[string is double -strict $option(-scale)]} {
        set scale [expr {min( max( $option(-scale), 0.2 ), 5.0 )}]
        if {[tk windowingsystem] eq "win32"} {
            tk scaling $scale
        } else {
            foreach font {Default Text Fixed Heading Caption Tooltip Icon Menu} {
                set size [font configure Tk${font}Font -size]
                font configure Tk${font}Font -size [expr {int($scale*$size)}]
            }
        }
    }
    if {$option(-font) eq "fixed"} {
        set font TkFixedFont
    } elseif {$option(-font) eq ""} {
        set font TkDefaultFont
    } else {
        set font TkCustomFont
        font create $font -family $option(-font)
    }
    set state(font:width) [expr {[font measure $font "X"] + 1}]
    set state(font:height) [expr {[font metrics $font -linespace] + 2}]
    option add *Table*Font $font widgetDefault
    option add *Menu*TearOff off widgetDefault
    option add *Button*Width 10 widgetDefault
    option add *Entry*Relief "solid" widgetDefault
    option add *Listbox*Relief "solid" widgetDefault
    bind Button <Left>        {focus [tk_focusPrev %W]}
    bind Button <Right>       {focus [tk_focusNext %W]}
    bind Button <Up>          {focus [tk_focusPrev %W]}
    bind Button <Down>        {focus [tk_focusNext %W]}
    bind Button <Return>      {%W invoke; break}

    if {$option(-debug)} {
        catch {console show}
        catch {package require tkcon; bind all <F9> {tkcon show}}
    }
    appLog {startup option: [array get option]}
}

proc appToplevelCreate {toplevel} {
    if {[winfo exists $toplevel]} {
        wm deiconify $toplevel
        return 0
    }
    toplevel $toplevel -height 1
    $toplevel configure -width [winfo width [winfo parent $toplevel]]
    return 1
}

# NOTE: appToplevelPlace is a replacement for
# tk::PlaceWindow $toplevel "widget" [winfo parent $toplevel]
# tk::SetFocusGrab $tolevel $grabfocus
proc appToplevelPlace {toplevel title {grabfocus {}}} {
    global state
    set x $state(font:width)
    set y $state(font:height)

    set rootx [winfo rootx [winfo parent $toplevel]]
    set rooty [winfo rooty [winfo parent $toplevel]]
    wm geometry $toplevel +[expr {$rootx+8*$x+$x}]+[expr {$rooty+$y+4}]
    wm title $toplevel $title
    wm deiconify $toplevel
    update idletasks
    if {$grabfocus ne ""} {
        grab $toplevel
        focus $grabfocus
    }
    update
}

proc appToplevelBindings {toplevel} {
    if {[tk windowingsystem] eq "win32"} {
        bind $toplevel <Control-Key> {+appWindowsCopyPasteFix %W %K %k}
    }
}

proc appWindowsCopyPasteFix {W K k} {
    switch $k {
        67 {if {"$K" ni {"C" "c"}} {event generate $W <<Copy>>}}
        86 {if {"$K" ni {"V" "v"}} {event generate $W <<Paste>>}}
        88 {if {"$K" ni {"X" "x"}} {event generate $W <<Cut>>}}
    }
}

proc appError {title message} {
    global state
    if {[info exists state(window)] && [winfo exists $state(window).table]} {
        set w [winfo parent $state(window).table]
    } else {
        set w .
    }
    appLog $title:\ $message
    tk_messageBox -parent $w -icon "error" -title "Error" -message $title -detail $message
}

proc appLog {message} {
    if {$::option(-debug)} {
        catch {
            tclLog [concat \
                    [uplevel 1 namespace current] \
                    [lindex [::info level -1] 0]: \
                    [uplevel 1 subst [list $message]]]
        }
    }
}

proc windowCreate {toplevel} {
    global state option

    set state(window) [expr {$toplevel eq "." ? "" : $toplevel}]
    set x $state(font:width)
    set y $state(font:height)
    set w $state(window)

    set Alt [expr {$::tcl_platform(os) eq "Darwin" ? "Option" : "Alt"}]
    set Ctrl [expr {$::tcl_platform(os) eq "Darwin" ? "Command" : "Ctrl"}]
    menu $w.menu
    menu $w.menu.file
    menu $w.menu.edit
    menu $w.menu.view
    menu $w.menu.help
    $w.menu add cascade -menu $w.menu.file -label "File"
    $w.menu add cascade -menu $w.menu.edit -label "Edit"
    $w.menu add cascade -menu $w.menu.view -label "View"
    $w.menu add cascade -menu $w.menu.help -label "Help"
    $w.menu.file add command -command {windowFileNew} -label "New"
    $w.menu.file add command -command {windowFileOpen} -label "Open" -accelerator "$Ctrl-O"
    $w.menu.file add command -command {windowFileClose} -label "Close"
    $w.menu.file add command -command {windowFileClone} -label "Clone"
    $w.menu.file add command -command {windowFilePack} -label "Pack"
    $w.menu.file add separator
    $w.menu.file add command -command {windowQuit} -label "Quit" -accelerator "$Ctrl-Q" 
    $w.menu.edit add command -command {event generate [focus] <<Cut>>} -label "Cut" -accelerator "$Ctrl-X"
    $w.menu.edit add command -command {event generate [focus] <<Copy>>} -label "Copy" -accelerator "$Ctrl-C"
    $w.menu.edit add command -command {event generate [focus] <<Paste>>} -label "Paste" -accelerator "$Ctrl-V"
    $w.menu.edit add separator
    $w.menu.edit add checkbutton -command {windowEditable check} -label "Editable" -variable ::option(-edit)
    $w.menu.edit add command -command {windowRecordDeleted} -label "Mark Record Deleted" -accelerator "$Alt-D"
    $w.menu.edit add command -command {windowRecordAppend} -label "Append Record" -accelerator "$Alt-A"
    $w.menu.view add command -command {infoCreate} -label "Info" -accelerator "$Ctrl-I"
    $w.menu.view add command -command {recordCreate} -label "Record" -accelerator "$Ctrl-R"
    $w.menu.view add separator
    $w.menu.view add command -command {findCreate} -label "Find" -accelerator "$Ctrl-F"
    if {$::tcl_platform(os) eq "Darwin"} {
        $w.menu.view add command -command {findNext 1} -label "Find Next" -accelerator "$Ctrl-G"
        $w.menu.view add command -command {findNext 0} -label "Find Prev" -accelerator "$Ctrl-Shift-G"
    } else {
        $w.menu.view add command -command {findNext 0} -label "Find Prev" -accelerator "Shift-F3"
        $w.menu.view add command -command {findNext 1} -label "Find Next" -accelerator "F3"
    }
    $w.menu.help add command -command {appAbout} -label "About"
    $toplevel configure -menu $w.menu -takefocus 0

    table $w.table -cols 0 -rows 0 \
        -titlecols 1 -titlerows 1 -colorigin -1 -roworigin -1 \
        -xscrollcommand "$w.hbar set" -yscrollcommand "$w.vbar set" \
        -validatecommand {windowValidate %c %S} -validate 1 \
        -command {windowCell %i %r %c %s} -cache 1 \
        -selectmode extended -state disabled \
        -rowseparator \n -colseparator \t \
        -drawmode single -borderwidth 1 -padx 2 \
        -cursor arrow -bordercursor cross
    scrollbar $w.hbar -orient horizontal -command "$w.table xview"
    scrollbar $w.vbar -orient vertical -command "$w.table yview"

    label $w.status 
    grid $w.table $w.vbar -sticky "news"
    grid $w.hbar "x" -sticky "we"
    grid $w.status - -sticky "w"

    windowFileClose
    windowToplevelBindings $toplevel
    appToplevelBindings $toplevel

    grid columnconfigure [winfo parent $w.table] 0 -weight 1
    grid rowconfigure [winfo parent $w.table] 0 -weight 1
    wm protocol $toplevel WM_DELETE_WINDOW {windowQuit}
    wm minsize $toplevel [expr {50*$x}] [expr {10*$y}]
    wm maxsize $toplevel [winfo vrootwidth $toplevel] [winfo vrootheight $toplevel]
    wm geometry $toplevel [format "%dx%d+%d+%d" \
            [expr {$option(-width)*$x}] [expr {$option(-height)*$y}] \
            [expr {max(([winfo screenwidth $toplevel]-$option(-width)*$x)/2,0)}] \
            [expr {max(([winfo screenheight $toplevel]-$option(-height)*$y)/2,0)}]]

    wm deiconify $toplevel
    raise $toplevel
    focus -force $w.table
}

proc windowToplevelBindings {toplevel} {
    # bind $toplevel <Return> {+recordCreate; break}
    # bind $toplevel <Double-1> {+recordCreate}
    if {$::tcl_platform(os) eq "Darwin"} {
        # NOTE: use keycode bindings to ignore keyboard mode on mac
        ##nagelfar ignore String argument to switch is constant
        bind $toplevel <Command-Key> {+switch %k\
                520093807 windowFileOpen\
                570425449 infoCreate\
                50331750  findCreate\
                83886183  {findNext 1}\
                88080487  {findNext 0}\
                88080455  {findNext 0}}
        # TODO: Bind Option keys for Delete/Append
    } else {
        if {[tk windowingsystem] eq "win32"} {
            # NOTE: use keycode bindings to ignore keyboard mode on windows
            ##nagelfar ignore String argument to switch is constant
            bind $toplevel <Control-Key> {+switch %k\
                    79 windowFileOpen\
                    81 windowQuit\
                    73 infoCreate\
                    70 findCreate\
                    82 recordCreate}
            ##nagelfar ignore String argument to switch is constant
            bind $toplevel <Alt-Key> {+switch %k\
                    68 windowRecordDeleted\
                    65 windowRecordAppend}
        } else {
            foreach {k c} {
                o windowFileOpen
                q windowQuit
                i infoCreate
                f findCreate
                r recordCreate
            } {
                bind $toplevel <Control-$k> [list $c]
                bind $toplevel <Control-[string toupper $k]> [list $c]
            }
            foreach {k c} {
                d windowRecordDeleted
                a windowRecordAppend
            } {
                bind $toplevel <Alt-$k> [list $c]
                bind $toplevel <Alt-[string toupper $k]> [list $c]
            }
        }
        bind $toplevel <F3> {findNext 1}
        bind $toplevel <Shift-F3> {findNext 0}
    }
}

proc windowQuit {} {
    windowFileClose
    exit
}

proc windowStatus {message} {
    global state
    set w $state(window)

    $w.status configure -text $message
    update idletasks
}

proc windowActivate {cell} {
    global state
    set w $state(window)

    $w.table activate $cell
    $w.table selection clear origin end
    $w.table selection set $cell
    $w.table see active
}

proc windowValidate {col val} {
    global state

    lassign [lindex $state(file:fields) $col] - - t s d
    switch -- $t {
        "F" -
        "N" {expr {$d > 0 ? [string is double $val] :  [string is integer $val]}}
        "D" {expr {[string is digit $val] && ![catch {clock scan $val}]}}
        "L" {expr {$val in {"T" "F" ""}}}
        "C" {expr {[string length $val] <= $s}}
        "M" {expr 0}
        default {expr 0}
    }
}

proc windowEditable {{check {}}} {
    global state option
    set w $state(window)

    if {$option(-edit) && [info exists state(file:handle)]} {
        set s "normal"
        bind $w.table <Return> {}
        bind $w.table <Double-1> {}
    } else {
        set s "disabled"
        bind $w.table <Return> {+recordCreate}
        bind $w.table <Double-1> {+recordCreate}
    }
    $w.table configure -state $s
    $w.menu.edit entryconfigure "*Deleted*" -state $s
    $w.menu.edit entryconfigure "*Append*" -state $s
    $w.menu.file entryconfigure "*Pack*" -state $s

    if {$check ne {} && [info exists state(file:handle)]} {
        if {$option(-edit) != $state(file:edit)} {
            windowFileReload
        }
    }
}

proc windowCell {set row col val} {
    global state
    set w $state(window)

    if {$set} {
        if {$row == -1 || $col == -1} {
            appLog "Invalid update for $row,$col = $val"
            return
        }
        try {
            fileCell $row $col $val
        } on error {message} {
            appError "Writing cell $row,$col" $message
        }
        after idle [list $w.table clear cache $row,$col]
        return
    }

    if {$row == -1 && $col == -1} {
        return ""
    }
    if {$row == -1 && $col != -1} {
        return [lindex [lindex $state(file:fields) $col] 0]
    }
    if {$row != -1 && $col == -1} {
        try {
            set deleted [fileRowDeleted $row]
        } on error {message} {
            appError [string cat [expr {$deleted ? "Deleting" : "Undeleting"}] " row $row"] $message
            return [format "%s %d" "?" [expr {$row+1}]]
        }
        if {$deleted} {
            $w.table tag rowtag "*" $row
        } else {
            $w.table tag rowtag {} $row
        }
        return [format "%s %d" [expr {$deleted ? "*" : " "}] [expr {$row+1}]]
    }
    try {
        return [fileCell $row $col]
    } on error {message} {
        appError "Reading cell $row,$col" $message
        return "?"
    }
}

proc windowFileOpen {{filename ""}} {
    global state option
    set w $state(window)

    if {$filename eq ""} {
        set filename [tk_getOpenFile -title "Open DBF File" -parent [winfo parent $w.table] \
                -filetypes {{"DBF files" {.dbf .DBF}} {"All files" *}}]
        if {$filename eq ""} {
            return
        }
    }
    windowFileClose
    windowStatus "Opening $filename"
    try {
        fileOpen $filename $option(-encoding) $option(-edit)
    } on error {message} {
        windowStatus ""
        appError "Opening $filename" $message
        return
    }

    wm title [winfo toplevel $w.table] \
         [string cat "DBF Edit - " [file nativename $state(file:name)]]
    $w.menu.file entryconfigure "*Close*" -state "normal"
    $w.menu.file entryconfigure "*Clone*" -state "normal"

    $w.table configure \
            -cols [expr {[llength $state(file:fields)]+1}] \
            -rows [expr {$state(file:size)+1}]
    set c 0
    foreach f $state(file:fields) {
        lassign $f n - t s
        $w.table width $c [expr {min(max(round([string length $n]*1.1), $s), $option(-maxcolwidth))}]
        $w.table tag coltag $t $c
        incr c
    }

    windowEditable
    windowStatus ""
}

proc windowFileClose {} {
    global state
    set w $state(window)

    set state(find:string) ""
    set state(find:field) "all"
    set state(find:nocase) "0"
    set state(find:regexp) "0"

    $w.table clear all
    $w.table configure -rows 0 -cols 0
    $w.table tag configure "F" -anchor "e"
    $w.table tag configure "M" -anchor "e"
    $w.table tag configure "L" -anchor "e"
    $w.table tag configure "N" -anchor "e"
    $w.table tag configure "C" -anchor "w"
    $w.table tag configure "*" -state disabled -fg [.menu cget -disabledforeground]
    $w.table tag coltag "N" -1
    $w.table width -1 8

    findDestroy
    recordDestroy
    if {[info exists state(file:handle)]} {
        fileClose
    }

    wm title [winfo toplevel $w.table] "DBF Edit"
    $w.menu.file entryconfigure "*Close*" -state "disabled"
    $w.menu.file entryconfigure "*Clone*" -state "disabled"

    windowEditable
}

proc windowFileClone {{filename {}} {fields {}} {codepage {}}} {
    global state
    set w $state(window)

    if {$codepage eq {} && [info exists state(file:codepage)]} {
        set codepage $state(file:codepage)
    }
    if {$fields eq {} && [info exists state(file:fields)]} {
        set fields $state(file:fields)
    }
    if {$fields eq {}} {
        return
    }
    if {$filename eq {}} {
        set filename [tk_getSaveFile -title "New DBF File" -parent [winfo parent $w.table] \
                -filetypes {{"DBF files" {.dbf .DBF}} {"All files" *}}]
        if {$filename eq {}} {
            return
        }
        if {[string index "." [file tail $filename]] < 0} {
            append filename ".dbf"
        }
    }
    windowStatus "Creating $filename"
    try {
        fileCreate $filename $fields $codepage
    } on error {message} {
        windowStatus ""
        appError "Creating $filename" $message
        return
    }
    windowFileOpen $filename
}

proc windowFilePack {} {
    global state

    set filename $state(file:name)

    windowStatus "Packing $filename"
    try {
        filePack $filename.pak
        fileClose
        file rename -force $filename $filename.bak
        file rename -force $filename.pak $filename
    } on error {message} {
        if {![file exists $filename] && [file exists $filename.bak]} {
            catch {file rename $filename.bak $filename}
        }
        windowStatus ""
        appError "Packing $filename" $message
        return
    }
    windowFileOpen $filename
}

proc windowFileReload {} {
    global state

    if {[info exists state(file:name)]} {
        # TODO: save/restore selection, active cell, find window, record window etc 
        windowFileOpen $state(file:name)
    }
}

proc windowFileNew {} {
    puts "windowFileNew: to be done"
    # set l [codepages]; set c 0; for {set i 0} {$i < 256} {incr i} {if {$i in $l} {set c [expr {$c | 1 << $i}]}}; set c
    # 1766847064828199408955326209275605677338875325268013602910910426818539294
    # windowFileClone $filename $fields $codepage
}

proc windowRecordDeleted {} {
    global state
    set w $state(window)

    if {![info exists state(file:handle)]} {
        return
    }
    if {!$state(file:edit)} {
        return
    }
    if {[catch {scan [$w.table index active] %d} row] || $row < 0} {
        return
    }
    fileRowDeleted $row "toggle"
    after idle [list $state(window).table clear cache $row,-1]
}

proc windowRecordAppend {} {
    global state
    set w $state(window)

    if {![info exists state(file:handle)]} {
        return
    }
    if {!$state(file:edit)} {
        return
    }
    try {
        fileAppend
    } on error {message} {
        appError "Append record" $message
        return
    }
    $w.table configure -rows [expr {$state(file:size)+1}]

    windowActivate [expr {$state(file:size)-1}],0
}

proc recordCreate {} {
    global state
    set w $state(window)
    set x $state(font:width)
    set y $state(font:height)

    if {![info exists state(file:handle)]} {
        return
    }
    if {[catch {scan [$w.table index active] %d} row] || $row < 0} {
        return
    }
    if {![appToplevelCreate $w.record]} {
        return
    }
    wm withdraw $w.record

    canvas $w.record.c -height 1 -width 1 -yscrollcommand "$w.record.v set"
    scrollbar $w.record.v -command "$w.record.c yview"
    frame $w.record.c.f
    for {set c 0} {$c < [llength $state(file:fields)]} {incr c} {
        label $w.record.c.f.l$c -text [$w.table get -1,$c] -anchor "e"
        entry $w.record.c.f.e$c -width 50 -state readonly -vcmd [list windowValidate $c %P]
        grid $w.record.c.f.l$c $w.record.c.f.e$c - - -sticky "we" -padx 4 -pady 2
        bind $w.record.c.f.e$c <FocusIn> [list recordActivate $c]
        bind $w.record.c.f.e$c <FocusOut> [list recordSave $c]
    }
    grid columnconfigure $w.record.c.f 1 -weight 1

    frame $w.record.f
    button $w.record.f.b1 -text "Prev" -command {recordLoad "prev"}
    button $w.record.f.b2 -text "Next" -command {recordLoad "next"}
    button $w.record.f.b3 -text "Close" -command [list destroy $w.record]
    pack $w.record.f.b3 $w.record.f.b2 $w.record.f.b1 -side "right" -padx 4 -pady 4
    grid $w.record.c $w.record.v -sticky "news"
    grid $w.record.f - -sticky "we"
    grid columnconfigure $w.record 0 -weight 1
    grid rowconfigure $w.record 0 -weight 1

    update idletasks
    $w.record.c.f configure -width [winfo reqwidth $w.record.c.f] -height [winfo reqheight $w.record.c.f]
    $w.record.c create window 0 0 -anchor "nw" -window $w.record.c.f
    $w.record.c configure -scrollregion [$w.record.c bbox all] \
            -height [expr {20*$y}] -width [winfo reqwidth $w.record.c.f]

    bind $w.record <Escape> recordDestroy

    appToplevelPlace $w.record "DBF Record" $w.record.f.b2
    appToplevelBindings $w.record
    wm maxsize $w.record [winfo width $w.record] [lindex [wm maxsize $w.record] 1]
    wm transient $w.record [winfo parent $w.record]

    recordLoad "active"
}

proc recordDestroy {} {
    global state
    set w $state(window)

    if {[winfo exists $w.record]} {
        array unset state record:*
        destroy $w.record
    }
}

proc recordSave {col} {
    global state option
    set w $state(window)

    set row $state(record:row)
    windowActivate $row,$col

    if {$option(-edit)} {
        $w.table set $row,$col [$w.record.c.f.e$col get]
    }
}

proc recordActivate {col} {
    global state option
    set w $state(window)

    set row $state(record:row)
    windowActivate $row,$col

    if {$option(-edit)} {
        # TODO: select entry?
    }
} 

proc recordLoad {position} {
    global state option
    set w $state(window)
 
    if {![winfo exists $w.record]} {
        return
    }
    switch -- $position {
        "first" {
            set row 0
            set col 0
            set cell $row,$col
        }
        "last" {
            scan [$w.table index end] "%d,%d" row col
            set cell $row,$col
        }
        default {
            scan [$w.table index active] "%d,%d" row col
            switch -- $position {
                "next" {incr row +1}
                "prev" {incr row -1}
                "active" {}
            }    
            set cell $row,$col
        }
    }
    if {
        $row < 0 || $row >= $state(file:size) || 
        $col < 0 || $col >= [llength $state(file:fields)]
    } {
        return
    }

    windowActivate $cell
    
    wm title $w.record "DBF Record - [expr {$row + 1}]"

    set state(record:row) $row

    try {
        set c 0
        foreach v [fileRow $row] {
            $w.record.c.f.e$c configure -state normal -validate none
            $w.record.c.f.e$c delete 0 end
            $w.record.c.f.e$c insert end $v
            if {$option(-edit)} {
                $w.record.c.f.e$c configure -validate key
            } else {
                $w.record.c.f.e$c configure -state readonly
            }
            incr c
        }
    } on error {message} {
        appError "Reading row $row" $message
        recordDestroy
    }
    if {$option(-edit) && $position eq "active"} {
        focus $w.record.c.f.e$col
    }
}

proc findCreate {} {
    global state
    set w $state(window)

    if {![info exists state(file:handle)]} {
        return
    }
    if {![appToplevelCreate $w.find]} {
        return
    }

    label $w.find.l1 -text "Find" -anchor "e"
    entry $w.find.string -textvariable state(find:string) -width 50
    grid $w.find.l1 $w.find.string - - - -sticky "we" -padx 4 -pady 2

    label $w.find.l2 -text "Field" -anchor "e"
    tk_optionMenu $w.find.field ::state(find:field) "all" {*}[lmap f $state(file:fields) {lindex $f 0}]
    $w.find.field configure -relief "solid" -anchor "w" -padx 1 -pady 1
    grid $w.find.l2 $w.find.field -sticky "we" -padx 4 -pady 2

    checkbutton $w.find.nocase -variable ::state(find:nocase) -text "ignore case"
    grid x $w.find.nocase -sticky "w" -padx 4 -pady 2

    checkbutton $w.find.regexp -variable ::state(find:regexp) -text "regular expression"
    grid x $w.find.regexp -sticky "w" -padx 4 -pady 2

    label $w.find.status
    button $w.find.b1 -text "Prev" -command [list findNext 0]
    button $w.find.b2 -text "Next" -command [list findNext 1]
    button $w.find.b3 -text "Close" -command [list findDestroy]
    grid $w.find.status - $w.find.b1 $w.find.b2 $w.find.b3 -sticky "e" -padx 4 -pady 2
    grid configure $w.find.status -sticky "w"

    bind $w.find.string <Return> [list findNext 1]
    bind $w.find <Escape> [list destroy $w.find]

    appToplevelPlace $w.find "DBF Find" $w.find.string
    appToplevelBindings $w.find
    wm maxsize $w.find [winfo width $w.find] [winfo height $w.find]
    wm transient $w.find [winfo parent $w.find]
}

proc findDestroy {} {
    global state
    set w $state(window)

    if {[winfo exists $w.find]} {
        destroy $w.find
    }
}

proc findNext {forward {cell ""}} {
    global state
    set w $state(window)

    if {![info exists state(file:handle)]} {
        return
    }
    if {![winfo exists $w.find]} {
        findCreate
    }
    if {$state(find:string) eq ""} {
        return
    }
    $w.find.b1 configure -state disabled
    $w.find.b2 configure -state disabled
    bind $w.find.string <Return> {}

    if {$cell eq "" && [catch {$w.table index active} cell]} {
        set cell [$w.table index [expr {$forward ? "topleft" : "bottomright"}]]
    }
    scan $cell "%d,%d" row col

    set findcols [lsearch -index 0 $state(file:fields) $state(find:field)]
    if {$findcols < 0} {
        set findcols [lmap - $state(file:fields) {incr findcols}]
    } else {
        set findcols [list $findcols]
    }

    if {$forward} {
        if {[llength $findcols] > 1} {
            set cols [lrange $findcols $col+1 end]
        } elseif {[lindex $findcols 0] > $col} {
            set cols $findcols
        } else {
            set cols ""
        }
    } else {
        if {[llength $findcols] > 1} {
            set cols [lrange $findcols 0 $col-1]
        } elseif {[lindex $findcols 0] < $col} {
            set cols $findcols
        } else {
            set cols ""
        }
    }
    while {true} {
        if {$row % 1000 == 0} {
            $w.find.status configure -text "Searching row $row"
            update

            if {![winfo exists $w.find]} {
                return
            }
        }
        try {
            set filecols [fileRow $row]
        } on error {message} {
            appError "Reading row $row" $message
            findDestroy
        }
        foreach col $cols {
            set s [lindex $filecols $col]
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
                findDestroy
                windowActivate $row,$col
                return
            }
        }
        if {$forward} {
            if {[incr row +1] >= $state(file:size)} {
                break
            }
        } else {
            if {[incr row -1] < 0} {
                break
            }
        }
        set cols $findcols
    }
    tk_messageBox -parent [winfo parent $w.find] \
            -icon "info" -title "Find" -message "Not found"
    findDestroy
}

proc infoCreate {} {
    global state option
    set w $state(window)
    set x $state(font:width)

    if {![info exists state(file:handle)]} {
        return
    }
    if {![appToplevelCreate $w.info]} {
        return
    }

    set i 0
    foreach {n v} [list \
            "File name" [file tail $state(file:name)] \
            "File size" [file size $state(file:name)] \
            "Records"   $state(file:size) \
            "Codepage"  $state(file:codepage) \
    ] {
        label $w.info.l$i -text $n -anchor "e"
        entry $w.info.e$i
        grid $w.info.l$i $w.info.e$i -sticky "we" -padx 2 -pady 2
        $w.info.e$i insert end $v
        $w.info.e$i configure -state readonly
        incr i
    }
    set state(info:encoding) $state(file:encoding)
    label $w.info.le -text "Encoding" -anchor "e"
    tk_optionMenu $w.info.me ::state(info:encoding) "" {*}[lsort -dictionary [encoding names]]
    $w.info.me configure -anchor "w" -relief "solid" -padx 1 -pady 1
    grid $w.info.le $w.info.me -sticky "we" -ipadx 1 -padx 1 -pady 1
    
    set format "%-10s %4s %4s %4s"
    label $w.info.lf -anchor "e" -text "Fields"
    listbox $w.info.bf -font TkFixedFont -selectmode extended \
            -yscrollcommand "$w.info.vf set"
    scrollbar $w.info.vf -orient vertical \
            -command "$w.info.bf yview"
    grid $w.info.lf "x" "x"        -sticky  "ew"  -padx 2 -pady 2
    grid $w.info.bf "-" $w.info.vf -sticky "news" -padx 2 -pady 2
    foreach f $state(file:fields) {
        $w.info.bf insert end [format $format {*}[lreplace $f 1 1]]
    }

    button $w.info.ok -text "OK" -command {infoOk}
    grid "x" $w.info.ok -sticky "e" -padx 2 -pady 2

    grid columnconfigure $w.info 1 -weight 1
    grid rowconfigure $w.info 7 -weight 1
    bind $w.info <Escape> [list destroy $w.info]

    appToplevelPlace $w.info "File Info" $w.info.ok
    appToplevelBindings $w.info
    wm maxsize $w.info [winfo width $w.info] [lindex [wm maxsize $w.info] 1]
    wm transient $w.info [winfo parent $w.info]
}

proc infoOk {} {
    global state option
    set w $state(window)

    if {![winfo exists $w.info]} {
        return
    }
    destroy $w.info

    if {$state(info:encoding) ne $state(file:encoding)} {
        set option(-encoding) $state(info:encoding)
        unset state(info:encoding)
        windowFileReload
    } 
}

proc fileCreate {filename fields codepage} {
    dbf h -create $filename -codepage $codepage
    foreach f $fields {
        lassign $f n - t s d
        $h add $n $t $s $d
    }
    $h close

    # NOTE: shapelib feature for empty codepage 
    catch {file delete [file rootname $filename].cpg}
}

proc fileOpen {filename encoding edit} {
    global state

    set n [file normalize $filename]
    if {$edit} {
        dbf h -open $n
    } else {
        dbf h -open $n -readonly
    }
    if {$encoding ne ""} {
        $h encoding $encoding
    }
    set state(file:name) $n
    set state(file:handle) $h
    set state(file:codepage) [$h codepage]
    set state(file:encoding) [$h encoding]
    set state(file:fields) [$h fields]
    set state(file:size) [$h info records]
    set state(file:edit) $edit
    set state(file:row) -1
    set state(file:values) {}
}

proc filePack {filename} {
    global state
    set h $state(file:handle)

    dbf p -create $filename -codepage [$h codepage]
    $p encoding [$h encoding]
    foreach f [$h fields] {
        lassign $f n - t s d
        $p add $n $t $s $d
    }
    for {set i 0} {$i < [$h info records]} {incr i} {
        if {![$h deleted $i]} {
            $p insert end [$h record $i]
        }
    }
    $p close

    ;# NOTE: shapelib feature for empty codepage 
    catch {file delete [file rootname $filename].cpg}
}

proc fileClose {} {
    global state
    set h $state(file:handle)

    array unset state file:*
    $h close
}

proc fileRowDeleted {row args} {
    global state
    set h $state(file:handle)

    if {[llength $args]} {
        set a [lindex $args 0]
        if {[string is boolean -strict $a]} {
            $h deleted $row $a
        } else {
            $h deleted $row [expr {![$h deleted $row]}]
        }
    }
    return [$h deleted $row]
}

proc fileRow {row} {
    global state
    set h $state(file:handle)

    if {$state(file:row) != $row} {
        set state(file:values) [$h record $row]
        set state(file:row) $row
    }
    return $state(file:values)
}

proc fileCell {row col args} {
    global state
    set h $state(file:handle)

    if {[llength $args]} {
        set state(file:row) -1
        set state(file:values) {}
        $h update $row \
                [lindex [lindex $state(file:fields) $col] 0] \
                [lindex $args 0]
    }
    return [lindex [fileRow $row] $col]
}

proc fileAppend {} {
    global state
    set h $state(file:handle)

    set state(file:size) [$h insert end {}]
    set state(file:size) [$h info records]
}    

proc bgerror {message {flag 1}} {
    if {$::option(-debug)} {
        catch {puts stderr "$message\nTRACE: $::errorInfo"}
        tailcall tk::dialog::error::bgerror $message $flag
    } else {
        catch {puts stderr "$message"}
        tk_messageBox -parent . -icon "error" -title "Error" -message $message
        return ""
    }
}

proc tkerror {message} {
    bgerror $message
}

try {
    appInit $argc $argv
    windowCreate .
} on error {message} {
    bgerror $message
    exit 1
}

if {$tcl_platform(os) eq "Darwin"} {
    namespace eval ::tk::mac {
        proc OpenDocument {args} {
            windowFileOpen [lindex $args 0]
        }
    }
}

if {$tcl_platform(os) ne "Darwin" || $argc != 0} {
    after idle {
        windowFileOpen $option(-filename)
    }
}
