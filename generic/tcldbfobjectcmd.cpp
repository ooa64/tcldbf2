#include <string.h>
#include "tcldbfobjectcmd.hpp"

#if defined(TCLDBFOBJECTCMD_DEBUG)
#   include <iostream>
#   define DEBUGLOG(_x_) (std::cerr << "DEBUG: " << _x_ << "\n")
#else
#   define DEBUGLOG(_x_)
#endif

/*
  $d info																
 		returns {record_count field_count}								
 																		
  $d codepage															
 		returns database codepage										
 																		
  $d add label typenativetype width [prec]										
 		adds field specified to the dbf, if created and empty			
 																		
  $d fields															
 		returns a list of lists, each of which consists of				
 		{name type native-type width prec}								
 																		
  $d values $name														
 		returns a list of values of the field $name						
 																		
  $d record $rowid														
 		returns a list of cell values (as strings) for the given row	
 																		
  $d insert $rowid  end value0 [... value1 value2 ...]				
 		inserts the specified values into the given record 				
 																		
  $d update $rowid $field $value										
 		replaces the specified values of a single field in the record 	
 																		
  $d deleted $rowid [truefalse]										
 		returns or sets the deleted flag for the given rowid			
 																		
  $d forget															
 		closes dbase file												
*/


int TclDbfObjectCmd::Command(int objc, Tcl_Obj * const objv[]) {
  DEBUGLOG("TclDbfObjectCmd::Command *" << this);

  static const char *commands[] = {
    "info", "codepage", "add", "fields", "values", "record",														
    "insert", "update", "deleted", "forget", "close", 0L
  };
  enum commands {
    cmInfo, cmCodepage, cmAdd, cmFields, cmValues, cmRecord,														
    cmInsert, cmUpdate, cmDeleted, cmForget, cmClose
  };
  int index;

  if (objc < 2) {
    Tcl_WrongNumArgs(tclInterp, 1, objv, "command");
    return TCL_ERROR;
  }
  
  if (Tcl_GetIndexFromObj(tclInterp, objv[1], 
      (const char **)commands, "command", 0, &index) != TCL_OK) {
    return TCL_ERROR;
  }

DEBUGLOG("TclDbfObjectCmd::Command index" << index);

  switch ((enum commands)(index)) {

  case cmInfo:
    break; 
  case cmCodepage:
    break; 
  case cmAdd:
    break;
  case cmFields:
    break; 
  case cmValues:
    break; 
  case cmRecord:
    break;														
  case cmInsert:
    break; 
  case cmUpdate:
    break; 
  case cmDeleted:
    break;

  case cmClose:
  case cmForget:

    if (objc > 2) {
      Tcl_WrongNumArgs(tclInterp, 2, objv, NULL);
      return TCL_ERROR;
    }

    // v.1 compatibility
    Tcl_SetResult(tclInterp, (char *)"1", NULL);

    delete this;

    break;
  }

  return TCL_OK;
};

void TclDbfObjectCmd::Cleanup() {
  DEBUGLOG("TclDbfObjectCmd::Cleanup *" << this);
};
