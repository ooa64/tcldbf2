#!/bin/sh
# the next line restarts using tclsh \
exec wish8.6 "$0" "$@"

package require Tk 8.6-
package require tcldbf 2.1-

wm title . "DBF View"
wm withdraw .

array set state {}
array set option {
    -filename ""
    -encoding ""
    -theme ""
    -scale ""
    -font ""
    -fixed false
    -width 100
    -height 30
    -limit 10000
    -bulk 100
    -debug 0
}

package require Tk

proc appInit {argc argv} {
    global state option

    if {$argc % 2 == 0} {
        array set option $argv  
    } else {
        array set option [linsert $argv end-1 "-filename"]
    }
    if {![string is integer -strict $option(-width)] || $option(-width) < 50 ||
            ![string is integer -strict $option(-height)] || $option(-height) < 10} {
        error "invalid width/height option"
    }
    if {![string is integer -strict $option(-limit)] ||
            ![string is integer -strict $option(-bulk)]} {
        error "invalid bulk/limit option"
    }
    if {$option(-theme) ne ""} {
        if {$option(-theme) eq "dark"} {
            appThemeDark
        }
        ::ttk::setTheme $option(-theme) 
        option add *Toplevel*foreground [ttk::style lookup . -foreground]
        option add *Toplevel*background [ttk::style lookup . -background]
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
        ttk::style configure Treeview -font TkFixedFont
    } elseif {$option(-font) ne ""} {
        ttk::style configure Treeview -font [font create TkCustomFont -family $option(-font)]
    }
    set font [ttk::style lookup Treeview -font]
    if {$font eq ""} {
        set font TkDefaultFont
    }
    set state(font:width) [expr {[font measure $font "X"] + 1}]
    set state(font:height) [expr {[font metrics $font -linespace] + 2}]

    ttk::style configure Treeview -rowheight $state(font:height)

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
    bind Treeview <<SelectPrevLine>> {
        if {[set i [%W prev [%W focus]]] ne ""} {
           %W selection add [list $i]; %W focus $i; %W see $i
        }
    }
    bind Treeview <<SelectNextLine>> {
        if {[set i [%W next [%W focus]]] ne ""} {
           %W selection add [list $i]; %W focus $i; %W see $i
        }
    }
    bind Treeview <<SelectAll>> {%W selection set [%W children {}]}
    bind Treeview <<SelectNone>> {%W selection remove [%W selection]}

    bind TButton <Left>        {focus [tk_focusPrev %W]}
    bind TButton <Right>       {focus [tk_focusNext %W]}
    bind TButton <Up>          {focus [tk_focusPrev %W]}
    bind TButton <Down>        {focus [tk_focusNext %W]}
    bind TButton <Return>      {%W invoke; break}

    option add *Menu*TearOff off

    if {$option(-debug)} {
        catch {console show}
        catch {package require tkcon; bind all <F9> {tkcon show}}
    }
}

proc appAbout {} {
    tk_messageBox -type "ok" -title "About" -message "DBF View 1.1" -detail "\n\
            Tcl [package require Tcl]\n\
            Tk [package require Tk]\n\
            Tcldbf [package require tcldbf]\n"
}

proc appThemeDark {} {
    array set colors {
        -background #33393b
        -foreground #ffffff
        -selectbackground #215d9c 
        -selectforeground #ffffff
        -fieldbackground #191c1d
        -bordercolor #000000
        -insertcolor #ffffff
        -troughcolor #191c1d
        -focuscolor #215d9c
        -lightcolor #5c6062
        -darkcolor #232829
    }
    ttk::style theme create dark -parent clam -settings {
        ttk::style configure . {*}[array get colors]
        ttk::style configure TCheckbutton -indicatormargin {1 1 4 1} \
                -indicatorbackground $colors(-fieldbackground) \
                -indicatorforeground $colors(-foreground)
        ttk::style configure TButton \
                -anchor center -width -11 -padding 5 -relief raised
        ttk::style map TEntry \
                -bordercolor [list focus $colors(-selectbackground)]
        ttk::style map TCombobox \
                -bordercolor [list focus $colors(-selectbackground)]
        ttk::style configure ComboboxPopdownFrame \
                -relief solid -borderwidth 1
        ttk::style configure Heading \
                -font TkHeadingFont -relief raised
        ttk::style configure Treeview \
                -background $colors(-fieldbackground)
        ttk::style map Treeview \
                -background [list selected $colors(-selectbackground)] \
                -foreground [list selected $colors(-selectforeground)] \
                -bordercolor [list focus $colors(-selectbackground)]
    }
    option add *TCombobox*Listbox.foreground $colors(-foreground)
    option add *TCombobox*Listbox.background $colors(-fieldbackground)
    option add *TCombobox*Listbox.selectForeground $colors(-selectforeground)
    option add *TCombobox*Listbox.selectBackground $colors(-selectbackground)
    option add *Canvas.background $colors(-background)
    option add *Canvas.highlightColor $colors(-selectbackground)
    option add *Canvas.highlightBackground $colors(-background)
    option add *Canvas.highlightThickness 2
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

proc appToplevelCreate {toplevel} {
    if {[winfo exists $toplevel]} {
        wm deiconify $toplevel
        return 0
    }
    toplevel $toplevel -height 1
    $toplevel configure -width [winfo width [winfo parent $toplevel]]
    return 1
}

proc appToplevelPlace {toplevel {grabfocus {}}} {
    # NOTE: avoid ui splash on update idletasks, replacement for
    # tk::PlaceWindow $toplevel "widget" [winfo parent $toplevel]
    # tk::SetFocusGrab $tolevel $grabfocus
    global state
    set x $state(font:width)
    set y $state(font:height)
    set rootx [winfo rootx [winfo parent $toplevel]]
    set rooty [winfo rooty [winfo parent $toplevel]]
    wm geometry $toplevel +[expr {$rootx+8*$x+$x}]+[expr {$rooty+$y+4}]
    wm deiconify $toplevel
    update idletasks
    if {$grabfocus ne ""} {
        grab $toplevel
        focus $grabfocus
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
    menu $w.menu.help
    $w.menu add cascade -menu $w.menu.file -label "File"
    $w.menu add cascade -menu $w.menu.view -label "View"
    $w.menu add cascade -menu $w.menu.help -label "Help"
    $w.menu.file add command -command {fileOpen} -label "Open" -accelerator "Ctrl-O"
    $w.menu.file add separator
    $w.menu.file add command -command {windowClose} -label "Quit" -accelerator "Ctrl-Q" 
    $w.menu.view add command -command {infoCreate} -label "Info" -accelerator "Ctrl-I"
    $w.menu.view add command -command {recordCreate} -label "Record" -accelerator "Enter"
    $w.menu.view add separator
    $w.menu.view add command -command {findCreate} -label "Find" -accelerator "Ctrl-F"
    $w.menu.view add command -command {findNext 0} -label "Find Prev" -accelerator "Shift-F3"
    $w.menu.view add command -command {findNext 1} -label "Find Next" -accelerator "F3"
    $w.menu.help add command -command {appAbout} -label "About"
    $toplevel configure -menu $w.menu -takefocus 0 -bg [ttk::style lookup . -background]

    sheetCreate 50 10

    wm protocol $toplevel WM_DELETE_WINDOW {windowClose}
    wm minsize $toplevel [expr {50*$x}] [expr {10*$y}]
    wm maxsize $toplevel [winfo vrootwidth $toplevel] [winfo vrootheight $toplevel]
    wm geometry $toplevel [format "%dx%d+%d+%d" \
            [expr {$option(-width)*$x}] [expr {$option(-height)*$y}] \
            [expr {max(([winfo screenwidth $toplevel]-$option(-width)*$x)/2,0)}] \
            [expr {max(([winfo screenheight $toplevel]-$option(-height)*$y)/2,0)}]]
    appToplevelBindings $toplevel
    windowToplevelBindings $toplevel
    wm deiconify $toplevel
    raise $toplevel
    focus $toplevel
}

proc windowClose {} {
    global state

    if {[info exists state(dbf:handle)]} {
        catch {$state(dbf:handle) forget}
    }
    exit
}

proc windowToplevelBindings {toplevel} {
    if {[tk windowingsystem] eq "win32"} {
        # NOTE: use keycode bindings to ignore keyboard mode on windows
        bind $toplevel <Control-Key> \
                {+switch %k 79 fileOpen 81 windowClose 73 infoCreate 70 findCreate}
    } else {
        foreach {k c} {o fileOpen q windowClose i infoCreate f findCreate} {
            bind $toplevel <Control-$k> [list $c]
            bind $toplevel <Control-[string toupper $k]> [list $c]
        }
    }
    bind $toplevel <F3> {findNext 1}
    bind $toplevel <Shift-F3> {findNext 0}
}

proc sheetCreate {width height} {
    global state
    set w $state(window)

    set state(item:base) ""
    set state(item:first) ""
    set state(item:last) ""
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

    after 1 [list focus -force $w.tree]
}

proc sheetDestroy {} {
    global state
    set w $state(window)

    if {[winfo exists $w.tree]} {
        destroy $w.tree $w.vbar $w.hbar $w.status
    }
}

proc sheetBindings {} {
    global state
    set w $state(window)
    set x $state(font:width)

    bind $w.tree <Return> {+recordCreate}
    bind $w.tree <Double-1> {+recordCreate}
    bind $w.tree <<TreeviewSelect>> {+recordLoad focus}

    bind $w.tree <Control-Home> {sheetSelect $::state(item:first); break}
    bind $w.tree <Control-End> {sheetSelect $::state(item:last); break}

    bind $w.tree <Prior> {after idle {sheetSelect [%W identify item {*}$::state(item:base)]}}
    bind $w.tree <Next> {after idle {sheetSelect [%W identify item {*}$::state(item:base)]}}

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
        tk_messageBox -parent [winfo toplevel $w.tree] \
                -icon "error" -title "Error" -message $message
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

    sheetBindings
    sheetSelect $state(item:first)
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
    set state(item:base) ""
    set state(item:first) ""
    set state(item:last) ""

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
        set state(item:first) [lindex [$w.tree children {}] 0]
        set state(item:base) [lmap i [lrange [$w.tree bbox $state(item:first)] 0 1] {incr i}]
    }
    set state(item:last) $item
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
    if {![appToplevelCreate $w.record]} {
        return
    }
    wm withdraw $w.record

    canvas $w.record.c -height 1 -width 1 -yscrollcommand "$w.record.v set"
    ttk::scrollbar $w.record.v -command "$w.record.c yview"
    ttk::frame $w.record.c.f -padding 4
    foreach c [lrange [$w.tree cget -columns] 0 end-1] {
        ttk::label $w.record.c.f.l$c -text [$w.tree heading $c -text] -anchor "e"
        ttk::entry $w.record.c.f.e$c -width 50 -state readonly
        grid $w.record.c.f.l$c $w.record.c.f.e$c - - -sticky "we" -padx 4 -pady 2
    }
    grid columnconfigure $w.record.c.f 1 -weight 1

    ttk::frame $w.record.f
    ttk::button $w.record.f.b1 -text "Prev" -command {recordLoad "prev"}
    ttk::button $w.record.f.b2 -text "Next" -command {recordLoad "next"}
    ttk::button $w.record.f.b3 -text "Close" -command [list destroy $w.record]
    pack $w.record.f.b3 $w.record.f.b2 $w.record.f.b1 -side "right" -padx 4 -pady 4
    grid $w.record.c $w.record.v -sticky "news"
    grid $w.record.f - -sticky "we"
    grid columnconfigure $w.record 0 -weight 1
    grid rowconfigure $w.record 0 -weight 1

    update idletasks
    $w.record.c.f configure -width [winfo reqwidth $w.record.c.f] -height [winfo reqheight $w.record.c.f]
    $w.record.c create window 0 0 -anchor nw -window $w.record.c.f
    $w.record.c configure -scrollregion [$w.record.c bbox all] \
            -height [expr {20*$y}] -width [winfo reqwidth $w.record.c.f]

    bind $w.record <Escape> [list destroy $w.record]

    wm title $w.record "DBF Record"
    wm transient $w.record [winfo parent $w.record]

    windowToplevelBindings $w.record
    appToplevelBindings $w.record
    appToplevelPlace $w.record

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
        "first" {set item $state(item:first)}
        "last" {set item $state(item:last)}
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
    # set c 0
    # foreach f [$h fields] {
    #     incr c
    #     if {[$w.record.c.f.e$c get] ne ""} {
    #         $w.record.c.f.e$c configure -state normal
    #         $w.record.c.f.e$c delete 0 end
    #         $w.record.c.f.e$c configure -state readonly
    #     }
    # }
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
        if {[$w.record.c.f.e$c get] ne $c} {
            $w.record.c.f.e$c configure -state normal
            $w.record.c.f.e$c delete 0 end
            $w.record.c.f.e$c insert end $v
            $w.record.c.f.e$c configure -state readonly
        }
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
    set w $state(window)
    set x $state(font:width)
    set h $state(dbf:handle)

    if {![info exists state(dbf:handle)]} {
        return
    }
    if {![appToplevelCreate $w.info]} {
        return
    }

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

    update
    appToplevelPlace $w.info $w.info.ok
    appToplevelBindings $w.info
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
    if {![appToplevelCreate $w.find]} {
        return
    }

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

    update
    appToplevelPlace $w.find $w.find.string
    appToplevelBindings $w.find
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
        set nextitem [expr {$forward ? $state(item:first) : $state(item:last)}]
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
            tk_messageBox -parent [winfo toplevel $w.tree] \
                    -icon "info" -title "Find" -message "Not found"
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

try {
    appInit $argc $argv
} on error {message} {
    tk_messageBox -icon "error" -title "Startup error" -message $message
    exit 1
}

windowCreate .

after 0 [list fileOpen $option(-filename)]
