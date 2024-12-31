@echo off

set TCLLIBPATH=../win
set TCLDBF1=..\..\tcldbf

call tclsh -encoding utf-8 %TCLDBF1%\test.tcl
call tclsh -encoding utf-8 %TCLDBF1%\test2.tcl
call tclsh -encoding utf-8 %TCLDBF1%\test3.tcl
call tclsh -encoding utf-8 %TCLDBF1%\test4.tcl
call tclsh -encoding utf-8 %TCLDBF1%\test5.tcl
call tclsh -encoding utf-8 %TCLDBF1%\test6.tcl
call tclsh -encoding utf-8 %TCLDBF1%\test7.tcl
call tclsh -encoding utf-8 %TCLDBF1%\test8.tcl

call tclsh -encoding utf-8 %TCLDBF1%\dbf.test -verbose bpse