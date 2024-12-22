#include <string.h>
#include "tcldbfobjectcmd.hpp"

#include "dbffield.c"

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

  switch ((enum commands)(index)) {

  case cmInfo:
    break; 
  case cmCodepage:
    break; 

  case cmAdd:

    if (objc < 5 || objc > 6) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> <label> type|nativetype <width> ?prec?");
      return TCL_ERROR;
    } else {

      char *field_name = Tcl_GetString(objv[2]);    
      if (!valid_name(field_name)) {
        Tcl_SetResult(tclInterp, "add: field name must be 10 characters or less, and contain only letters, numbers, or underscore", NULL);
        return TCL_ERROR;
      }

      DBFFieldType field_type = get_type(Tcl_GetString(objv[3]));
      if (field_type == FTInvalid) {
        Tcl_SetResult(tclInterp, "add: type of field must be String, Integer, Logical, Date, or Double", NULL);
        return TCL_ERROR;
      }

      int field_width = 0;
      if (Tcl_GetIntFromObj(tclInterp, objv[4], &field_width) == TCL_ERROR) {
        Tcl_SetResult(tclInterp, "add: cannot interpret the width of the field", NULL);
        return TCL_ERROR;
      }
      if (field_width < 1 || field_width > 255) {
        Tcl_SetResult(tclInterp,"add: field width must be greater than zero and less than 256", NULL);
        return TCL_ERROR;
      }

      int field_prec  = 0;
      if (field_type == FTDouble && objc > 5) {
        if (Tcl_GetIntFromObj(tclInterp, objv[5], &field_prec) == TCL_ERROR) {
          Tcl_SetResult(tclInterp, "add: cannot interpret the precision of the field", NULL);
          return TCL_ERROR;
        }
        if (field_prec > field_width) {
          Tcl_SetResult(tclInterp, "add: field prec must not be greater than field width", NULL);
          return TCL_ERROR;
        }
      }

      int rc = DBFAddField(dbf, field_name, field_type, field_width, field_prec);
      if (rc < 0) {
        Tcl_SetResult(tclInterp, "add: field could not be added.  Fields can be added only after creating the file and before adding any records.", NULL);
        return TCL_ERROR;
      }

      Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(rc));
    }
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
    } else {
      // v.1 compatibility
      Tcl_SetResult(tclInterp, (char *)"1", NULL);
      delete this;
    }
    break;
  }

  return TCL_OK;
};

void TclDbfObjectCmd::Cleanup() {
  DEBUGLOG("TclDbfObjectCmd::Cleanup *" << this);
};
