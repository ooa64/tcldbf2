#
# Usage:
#     wish90s dbfview-make-executable.tcl 
#

package require Tk 9
package require tcldbf

# Make sure we are running a static wish
set exe_path [zipfs mount //zipfs:/app]
if {$exe_path eq ""} {
    pack [ttk::label .e -text "Please use a static wish to make single-file exes!"]
    pack [ttk::button .b -text Exit -command exit]
    return
}
# Make sure we have tcldbf
set dll_path [lindex [lsearch -inline -index 1 [info loaded] Tcldbf] 0]
if {$dll_path eq ""} {
    pack [ttk::label .e -text "Tcldbf shared library not found!"]
    pack [ttk::button .b -text Exit -command exit]
    return
}
pack [ttk::label .l -text "Building dbfview single file exe. Please wait ..."]
tk::PlaceWindow .
update
file delete -force dbfview.vfs
file mkdir dbfview.vfs
file copy $tcl_library [file join dbfview.vfs tcl_library]
file copy $tk_library [file join dbfview.vfs tk_library]
file delete -force [file join dbfview.vfs tk_library demos]
file delete -force [file join dbfview.vfs tk_library images]
file copy $dll_path dbfview.vfs/tcldbf[info sharedlib]
file copy dbfview.tcl dbfview.vfs/dbfview.tcl
writeFile [file join dbfview.vfs main.tcl] {
    load //zipfs:/app/tcldbf[info sharedlib]
    source //zipfs:/app/dbfview.tcl
}
zipfs mkimg dbfview[file extension $exe_path] dbfview.vfs dbfview.vfs "" $exe_path
.l configure -text "Done."
pack [ttk::button .b -text Exit -command exit]
