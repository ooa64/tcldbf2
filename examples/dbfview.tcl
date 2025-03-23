package require Tk
package require tcldbf
eval {package require tkcon; bind all <F9> {tkcon show}}

wm withdraw .
wm title . "DBF View"

array set state {}
array set option {
    -filename ""
    -encoding ""
    -scale 1.0
}

proc dbf:init {argc argv} {
    global option
    if {$argc % 2 == 0} {
        array set option $argv  
    } else {
        array set option [linsert $argv end-1 "-filename"]
    }

    option add *TearOff off

    set scale [expr {min(max($option(-scale),0.2),5.0)}]
    foreach font {Default Text Fixed Heading Caption Tooltip Icon Menu} {
        set size [font configure Tk${font}Font -size]
        font configure Tk${font}Font -size [expr {int($scale*$size)}]
    }
}

proc dbf:open {{filename ""}} {
    global state
    if {$filename eq ""} {
        set filename [tk_getOpenFile \
                -filetypes {{"DBF files" {.dbf .DBF}} {"All files" *}}]
    }
    if {$filename eq ""} {
        return
    }
    dbf:close
    try {
        dbf state(dbfhandle) -open $filename -readonly
    } on error {message} {
        tk_messageBox -icon "error" -title "Error" -message $message
        return
    }
    set state(dbfname) [file normalize $filename]
    set fields [$state(dbfhandle) fields]

    set w $state(window)
    set x $state(fontwidth)
    set c 0
    $w.t configure -columns [concat [lmap f $fields {incr c}] [list \#end]]
    $w.t column \#0 -width [expr {6*$x}] -minwidth [expr {6*$x}] -stretch 0 -anchor "e"
    $w.t column \#end -minwidth 0 -width 0 -stretch 1
    set z [dict create]
    set c 0
    foreach f $fields {
        incr c
        lassign $f n - t s
        $w.t heading $c -text $n
        $w.t column $c -stretch 0 -anchor [expr {$t in {F M L N} ? "e" : "w"}]
        dict set z $c [string length $n]    
    }
    for {set i 0} {$i < [$state(dbfhandle) info records]} {incr i} {
        set d [expr {[$state(dbfhandle) deleted $i] ? "*" : " "}]
        $w.t insert {} end -text [format "%1s%5d" $d [expr {$i+1}]] \
            -values [$state(dbfhandle) record $i]
        foreach c [dict keys $z] v [$state(dbfhandle) record $i] {
            dict set z $c [expr {max([dict get $z $c],[string length $v])}]
        }
    }
    foreach c [dict keys $z] {
        $w.t column $c -width [expr {min([dict get $z $c],100)*$x+4}]
    }
    wm title [winfo toplevel $w.t] $state(dbfname) 
}

proc dbf:load {} {
    global state
    if {![info exists state(dbfhandle)]} {
        return
    }
    set w $state(window)
    $w.t delete [$w.t children {}]
    for {set i 0} {$i < [$state(dbfhandle) info records]} {incr i} {
        set d [expr {[$state(dbfhandle) deleted $i] ? "*" : " "}]
        $w.t insert {} end -text [format "%1s%5d" $d [expr {$i+1}]] \
            -values [$state(dbfhandle) record $i]
    }    
}

proc dbf:close {} {
    global state
    if {![info exists state(dbfhandle)]} {
        return
    }
    $state(dbfhandle) close
    unset state(dbfhandle)
    unset state(dbfname)
    dbf:recreate:treeview t v h
}

proc dbf:info {} {
    global state
    if {![info exists state(dbfhandle)]} {
        return
    }
    set i 0
    set w [toplevel $state(window).info]
    set x $state(fontwidth)
    foreach {n v} [list \
        "Filename" [file tail $state(dbfname)] \
        "Filesize" [file size $state(dbfname)] \
        "Records" [$state(dbfhandle) info records] \
        "Codepage" [$state(dbfhandle) codepage] \
    ] {
        ttk::label $w.l$i -text $n -anchor "e"
        ttk::entry $w.e$i
        grid $w.l$i $w.e$i -sticky "we" -padx 2m -pady 1m
        $w.e$i insert end $v
        $w.e$i configure -state readonly        
        incr i
    }
    ttk::label $w.l$i -text "Encoding" -anchor "e"
    ttk::combobox $w.c1 -values [lsort -dictionary [encoding names]]
    grid $w.l$i $w.c1 -sticky "we" -padx 2m -pady 1m
    $w.c1 insert end [$state(dbfhandle) encoding]

    set columns [dict create \
        field [expr {10*$x}] \
        type  [expr {4*$x}] \
        size  [expr {4*$x}] \
        prec  [expr {4*$x}]] 
    ttk::treeview $w.t -show {headings} -columns [dict keys $columns] -yscroll "$w.v set"
    ttk::scrollbar $w.v -orient vertical -command "$w.t yview"
    grid $w.t - $w.v -sticky "news"
    foreach n [dict keys $columns] {
        $w.t heading $n -text $n
        $w.t column $n -width [dict get $columns $n] -anchor e
    }
    foreach f [$state(dbfhandle) fields] {
        $w.t insert {} end -values [lreplace $f 1 1]
    }
    ttk::button $w.b -text "OK" -command [list dbf:info:close $w $w.c1]
    grid x $w.b -sticky "e" -padx 2m -pady 1m

    grid columnconfigure $w 1 -weight 1
    grid rowconfigure $w 5 -weight 1

    bind $w <Escape> [list $w.b invoke]

    tk::PlaceWindow $w "widget" $state(window)
    tk::SetFocusGrab $w $w.b
}

proc dbf:info:close {w c} {
    global state
    set e [$c get]
    if {$e ne [$state(dbfhandle) encoding]} {
        $state(dbfhandle) encoding $e
        dbf:load                        
    } 
    destroy $w
}

proc dbf:create {toplevel} {
    global state option
    set state(window) [expr {$toplevel eq "." ? "" : $toplevel}]
    set state(fontwidth) [font measure TkDefaultFont "X"]
    set state(fontheight) [expr {[font metrics TkDefaultFont -ascent] + [font metrics TkDefaultFont -descent]}] ;# -linespace ?

    set w $state(window)
    set x $state(fontwidth)
    set y $state(fontheight)
    menu $w.m
    menu $w.m.file
    menu $w.m.view
    $w.m add cascade -menu $w.m.file -label "File"   
    $w.m add cascade -menu $w.m.view -label "View"   
    $w.m.file add command -command {dbf:open} -label "Open" -accelerator "Ctrl-O"
    $w.m.file add separator
    $w.m.file add command -command {dbf:quit} -label "Quit" -accelerator "Ctrl-Q" 
    $w.m.view add command -command {dbf:info} -label "Info" -accelerator "Ctrl-I"
    # $w.m.view add command -command {dbf:search} -label "Search"
    $toplevel configure -menu $w.m

    dbf:recreate:treeview t v h

    bind $toplevel <Control-KeyPress-o> {dbf:open}
    bind $toplevel <Control-KeyPress-q> {dbf:quit}
    bind $toplevel <Control-KeyPress-i> {dbf:info}

    wm minsize $toplevel [expr {100*$x}] [expr {30*$y}]
    tk::PlaceWindow $toplevel
    after 0 [list dbf:open $option(-filename)]
}

proc dbf:recreate:treeview {t v h} {
    global state
    set w $state(window)
    set x $state(fontwidth)
    if {[winfo exists $w.$t]} {
        destroy $w.$t $w.$v $w.$h
    }
    ttk::treeview $w.$t -height 30 -yscroll "$w.$v set" -yscroll "$w.$v set" -xscroll "$w.$h set"
    ttk::scrollbar $w.$v -orient vertical -command "$w.$t yview"
    ttk::scrollbar $w.$h -orient horizontal -command "$w.$t xview"
    grid $w.$t $w.$v -sticky "news"
    grid $w.$h -sticky "we"
    # NOTE: set initial treeview width
    $w.$t column \#0 -stretch 1 -width [expr {100*$x}] -minwidth [expr {100*$x}]

    grid columnconfigure [winfo parent $w.$t] 0 -weight 1
    grid rowconfigure [winfo parent $w.$t] 0 -weight 1
}

proc dbf:quit {} {
    exit
}

dbf:init $argc $argv
after idle {
    dbf:create .
}
