package require Tcl 8.5-
package require tcltest 2.2

::tcltest::configure \
	-testdir [file dirname [file normalize [info script]]] \
	{*}$argv

puts "Tests auto_path:  $auto_path"
puts "Tests encoding system:  [encoding system]"
puts "Tests package version:  [package require tcltest]"
puts "Tests interpreter version:  [info patchlevel]"

::tcltest::runAllTests
