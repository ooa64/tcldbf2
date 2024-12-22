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

  $d add label type|nativetype width [prec]
        adds field specified to the dbf, if created and empty

  $d fields ?name?
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

  $d deleted $rowid [true|false]
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

    if (objc > 2) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> info");
      return TCL_ERROR;
    } else {
      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      Tcl_ListObjAppendElement(tclInterp, result, Tcl_NewIntObj(DBFGetRecordCount(dbf)));
      Tcl_ListObjAppendElement(tclInterp, result, Tcl_NewIntObj(DBFGetFieldCount(dbf)));
    }

    break;

  case cmCodepage:

    if (objc > 2) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> codepage");
      return TCL_ERROR;
    } else {
      Tcl_SetObjResult (tclInterp, Tcl_NewStringObj(DBFGetCodePage(dbf), -1));
    }

    break;

  case cmAdd:

    if (objc < 5 || objc > 6) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> <label> type|nativetype <width> ?prec?");
      return TCL_ERROR;
    } else {
      return AddField(objv[2], objv[3], objv[4], objc > 5 ? objv[5] : NULL);
    }
    break;

  case cmFields:

    if (objc < 2 || objc > 3) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> fields ?name?");
      return TCL_ERROR;
    } else if (objc == 3) {
      const char * name = Tcl_GetString(objv[2]);
      int i = DBFGetFieldIndex(dbf, name);
      if (i < 0) {
        Tcl_AppendResult(tclInterp, "fields ", name, " does not match a field name in this dbf file", name);
      }
      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      GetField(result, i);
    } else {
      int count = DBFGetFieldCount(dbf);
      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      for (int i = 0; i < count; i++) {
        Tcl_Obj * field = Tcl_NewObj();
        GetField(field, i); 
        Tcl_ListObjAppendElement(tclInterp, result, field);
      }
    }
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

int TclDbfObjectCmd::AddField(Tcl_Obj * labelObj, Tcl_Obj * typeObj, Tcl_Obj * widthObj, Tcl_Obj * precObj) {
  char *label = Tcl_GetString(labelObj);
  if (!valid_name(label)) {
    Tcl_SetResult(tclInterp, (char *)"add: field name must be 10 characters or less, and contain only letters, numbers, or underscore", NULL);
    return TCL_ERROR;
  }

  DBFFieldType type = get_type(Tcl_GetString(typeObj));
  if (type == FTInvalid) {
    Tcl_SetResult(tclInterp, (char *)"add: type of field must be String, Integer, Logical, Date, or Double", NULL);
    return TCL_ERROR;
  }

  int width = 0;
  if (Tcl_GetIntFromObj(tclInterp, widthObj, &width) == TCL_ERROR) {
    Tcl_SetResult(tclInterp, (char *)"add: cannot interpret the width of the field", NULL);
    return TCL_ERROR;
  }
  if (width < 1 || width > 255) {
    Tcl_SetResult(tclInterp, (char *)"add: field width must be greater than zero and less than 256", NULL);
    return TCL_ERROR;
  }

  int prec  = 0;
  if (precObj) {
    if (Tcl_GetIntFromObj(tclInterp, precObj, &prec) == TCL_ERROR) {
      Tcl_SetResult(tclInterp, (char *)"add: cannot interpret the precision of the field", NULL);
      return TCL_ERROR;
    }
    if (prec > width) {
      Tcl_SetResult(tclInterp, (char *)"add: field prec must not be greater than field width", NULL);
      return TCL_ERROR;
    }
  }

  int i = DBFAddField(dbf, label, type, width, prec);
  if (i < 0) {
    Tcl_SetResult(tclInterp, (char *)"add: field could not be added.  Fields can be added only after creating the file and before adding any records.", NULL);
    return TCL_ERROR;
  }

  Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(i));
  return TCL_OK;
}

int TclDbfObjectCmd::GetField(Tcl_Obj * fieldObj, int index) {
  int width, prec;
  char label [XBASE_FLDNAME_LEN_READ+1];
  char nativetype = DBFGetNativeFieldType(dbf, index);
  DBFFieldType type = DBFGetFieldInfo(dbf, index, label, &width, &prec);

  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewStringObj(EncodeTclString(label), -1));
  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewStringObj(type_of(type), -11));
  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewStringObj(&nativetype, 1));
  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewIntObj(width));
  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewIntObj(prec));
  return TCL_OK;
}

void TclDbfObjectCmd::Cleanup() {
  DEBUGLOG("TclDbfObjectCmd::Cleanup *" << this);
};
