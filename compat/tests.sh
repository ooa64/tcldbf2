#!/bin/sh

export TCLLIBPATH=..

TCLDBF1=../../tcldbf

tclsh -encoding utf-8 $TCLDBF1/test.tcl
tclsh -encoding utf-8 $TCLDBF1/test2.tcl
tclsh -encoding utf-8 $TCLDBF1/test3.tcl
tclsh -encoding utf-8 $TCLDBF1/test4.tcl
tclsh -encoding utf-8 $TCLDBF1/test5.tcl
tclsh -encoding utf-8 $TCLDBF1/test6.tcl
tclsh -encoding utf-8 $TCLDBF1/test7.tcl
tclsh -encoding utf-8 $TCLDBF1/test8.tcl

tclsh -encoding utf-8 $TCLDBF1/dbf.test -verbose bpse

