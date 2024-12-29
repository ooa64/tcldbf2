#include <string.h>
#include "tcldbfobjectcmd.hpp"

#include "dbffield.c"
#include "codepages.c"

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

  $d insert $rowid|end value [value ...]
        inserts the specified values into the given record

  $d update $rowid|end field value [field value ...]
        replaces the specified values of a single field in the record

  $d deleted $rowid [true|false]
        returns or sets the deleted flag for the given rowid

  $d forget
        closes dbase file
*/

static void TclDbfError(const char *message, void *pvUserData)
{
  DEBUGLOG("TclDbfError " << message << " " << pvUserData);
  if (pvUserData) {
    ((TclDbfObjectCmd *)pvUserData)->SetLastError(message);
  }
}

TclDbfObjectCmd::TclDbfObjectCmd(Tcl_Interp * interp, const char * name, TclCmd * parent,
    DBFHandle handle): TclCmd(interp, name, parent) {
  Tcl_DStringInit(&dstring);
  Tcl_DStringInit(&message);
  encoding = Tcl_GetEncoding(NULL, codepage_encoding(handle->pszCodePage));    
  handle->sHooks.Error = TclDbfError; 
  handle->sHooks.pvUserData = this;
  dbf = handle;
} 

TclDbfObjectCmd::~TclDbfObjectCmd() {
  dbf->sHooks.pvUserData = NULL;
  DBFClose(dbf);
  Tcl_FreeEncoding(encoding);
  Tcl_DStringFree(&message);
  Tcl_DStringFree(&dstring);
};

int TclDbfObjectCmd::Command(int objc, Tcl_Obj * const objv[]) {
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
      Tcl_SetObjResult(tclInterp, Tcl_NewStringObj(DBFGetCodePage(dbf), -1));
    }
    break;

  case cmAdd:

    if (objc < 5 || objc > 6) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> add <label> type|nativetype <width> ?prec?");
      return TCL_ERROR;
    } else {
      return AddField(objv[2], objv[3], objv[4], objc > 5 ? objv[5] : NULL);
    }
    break;

  case cmFields:

    if (objc > 3) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> fields ?field?");
      return TCL_ERROR;
    } else if (objc == 3) {

      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      const char * field = Tcl_GetString(objv[2]);
      int i = DBFGetFieldIndex(dbf, field);
      if (i < 0) {
        Tcl_AppendResult(tclInterp, "unknown field ", field, NULL);
        return TCL_ERROR;
      }
      GetField(result, i);

    } else {

      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      int count = DBFGetFieldCount(dbf);
      for (int i = 0; i < count; i++) {
        Tcl_Obj * field = Tcl_NewObj();
        if (GetField(field, i) == TCL_ERROR) {
          return TCL_ERROR;
        } 
        Tcl_ListObjAppendElement(tclInterp, result, field);
      }
    }
    break;

  case cmValues:
    break;

  case cmRecord:

    if (objc != 3) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> record <rowid>");
      return TCL_ERROR;
    } else {

      int rowid;
      if (GetRowid(objv[2], &rowid) == TCL_ERROR) {
        return TCL_ERROR;
      }
      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      int count = DBFGetFieldCount(dbf);
      for (int i = 0; i < count; i++) {
        Tcl_Obj * value = NULL;
        if (GetFieldValue(rowid, i, &value) == TCL_ERROR) {
          return TCL_ERROR;
        }
        Tcl_ListObjAppendElement(tclInterp, result, value);
      }
    }
    break;

  case cmInsert:

    if (objc < 3) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> insert <rowid>|end ?<value>? ?<value> ...?");
      return TCL_ERROR;
    } else {

      int fcount = DBFGetFieldCount(dbf);
      if (objc > (fcount + 3)) {
        Tcl_SetResult(tclInterp, (char *)"too many values", NULL);
        return TCL_ERROR;
      }
      int rowid;
      if (GetRowid(objv[2], &rowid) == TCL_ERROR) {
        return TCL_ERROR;
      }
      for (int i = 3; i < objc; i++) {
        if (SetFieldValue(rowid, i - 3, objv[i]) == TCL_ERROR) {
          return TCL_ERROR;
        }
      }
      DBFUpdateHeader(dbf);
      if (CheckLastError() == TCL_ERROR) {
        return TCL_ERROR;
      }
      Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(rowid));
    }
    break;

  case cmUpdate:

    if (objc < 3 || (objc - 3) % 2 != 0) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> update <rowid>|end ?<field> <value>? ?<field> <value> ...?");
      return TCL_ERROR;
    } else {

      int rowid;
      if (GetRowid(objv[2], &rowid) == TCL_ERROR) {
        return TCL_ERROR;
      }
      for (int i = 3; i < objc; i += 2) {
        char * field = Tcl_GetString(objv[i]);
        index = DBFGetFieldIndex(dbf, field);
        if (index < 0) {
          Tcl_AppendResult(tclInterp, "unknown field ", field, NULL);
          return TCL_ERROR;
        }
        if (SetFieldValue(rowid, index, objv[i+1]) == TCL_ERROR) {
          return TCL_ERROR;
        }
      }
      Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(rowid));
    }  
    break;

  case cmDeleted:

    if (objc < 3 || objc > 4) {
      Tcl_WrongNumArgs(tclInterp, 0, objv, "<object> deleted rowid ?mark?");
      return TCL_ERROR;
    } else {
      
      int rowid;
      if (GetRowid(objv[2], &rowid) == TCL_ERROR) {
        return TCL_ERROR;
      }
      if (objc == 4) {
        int deleted;
        if (Tcl_GetBooleanFromObj(tclInterp, objv[3], &deleted) == TCL_ERROR) {
          return TCL_ERROR;
        }
        if (!DBFMarkRecordDeleted(dbf, rowid, deleted)) {
          return TCL_ERROR;
          if (CheckLastError() != TCL_ERROR) { 
            Tcl_SetResult(tclInterp, (char *)"failed to change deleted mark", NULL);
          }
          return TCL_ERROR;
        }
      }
			Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(DBFIsRecordDeleted(dbf, rowid)));
    }
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

int TclDbfObjectCmd::GetFieldValue(int rowid, int index, Tcl_Obj ** valueObj) {
  char label [XBASE_FLDNAME_LEN_READ+1];
  DBFFieldType type = DBFGetFieldInfo(dbf, index, label, NULL, NULL);

  if (DBFIsAttributeNULL(dbf, rowid, index)) {
    *valueObj = Tcl_NewStringObj("", -1);
  } else if (type == FTString) {
    *valueObj = Tcl_NewStringObj(EncodeTclString(DBFReadStringAttribute(dbf, rowid, index)), -1);
  } else if (type == FTDouble) {
    *valueObj = Tcl_NewDoubleObj(DBFReadDoubleAttribute(dbf, rowid, index));
  } else if (type == FTInteger) {
    *valueObj = Tcl_NewIntObj(DBFReadIntegerAttribute(dbf, rowid, index));
  } else if (type == FTDate) {
    // NOTE: skip double conversion
    // SHPDate date = DBFReadDateAttribute(dbf, rowid, index);
    // char value[9]; /* "yyyyMMdd\0" */
    // snprintf(value, sizeof(value), "%04d%02d%02d", date->year, date->month, date->day);
    *valueObj = Tcl_NewStringObj(DBFReadStringAttribute(dbf, rowid, index), -1);
  } else if (type == FTLogical) {
    *valueObj = Tcl_NewStringObj(DBFReadLogicalAttribute(dbf, rowid, index), -1);
  } else {
    // valueObj = Tcl_NewStringObj(DBFReadStringAttribute(dbf, rowid, index), -1);
    Tcl_AppendResult(tclInterp, "invalid data type, field ", label, NULL);
    return TCL_ERROR;
  }
  return TCL_OK;
}

int TclDbfObjectCmd::SetFieldValue(int rowid, int index, Tcl_Obj * valueObj) {
  int result = false;
  char * value = Tcl_GetString(valueObj);
  char label [XBASE_FLDNAME_LEN_READ+1];
  DBFFieldType type = DBFGetFieldInfo(dbf, index, label, NULL, NULL);

  if (strcmp(value, "") == 0) {

    result = DBFWriteNULLAttribute(dbf, rowid, index);

  } else if (type == FTString) {

    // FIXME: check for valid encoding
    result = DBFWriteStringAttribute(dbf, rowid, index, DecodeTclString(value));

  } else if (type == FTDouble) {

    double d;
    if (Tcl_GetDoubleFromObj(tclInterp, valueObj, &d) == TCL_ERROR) {
      Tcl_AppendResult(tclInterp, ", field ", label, NULL);
      return TCL_ERROR;
    }
    result = DBFWriteDoubleAttribute (dbf, rowid, index, d);

  } else if (type == FTInteger) {

    int i;
    if (Tcl_GetIntFromObj(tclInterp, valueObj, &i) == TCL_ERROR) {
      Tcl_AppendResult(tclInterp, ", field ", label, NULL);
      return TCL_ERROR;
    }
    result = DBFWriteIntegerAttribute (dbf, rowid, index, i);

  } else if (type == FTDate) {

    SHPDate date;
    if (3 != sscanf(value, "%4d%2d%2d", &date.year, &date.month, &date.day)) {
      Tcl_AppendResult(tclInterp, "expected date as YYYYMMDD but got \"", value, "\", field ", label, NULL);
      return TCL_ERROR;
    }
    result = DBFWriteDateAttribute (dbf, rowid, index, &date);

  } else if (type == FTLogical) {

    result = DBFWriteLogicalAttribute (dbf, rowid, index, *value);

  } else {

    Tcl_AppendResult(tclInterp, "invalid data type, field ", label, NULL);
    return TCL_ERROR;
  }

  if (!result) {
    Tcl_AppendResult(tclInterp, "update error, field ", label, NULL);
    return TCL_ERROR;
  }
  return TCL_OK;
}

int TclDbfObjectCmd::GetRowid(Tcl_Obj * rowidObj, int * rowid) {
  int rcount = DBFGetRecordCount(dbf);
  if (strcmp(Tcl_GetString(rowidObj), "end") == 0) {
    *rowid = rcount;
  } else if (Tcl_GetIntFromObj(tclInterp, rowidObj, rowid) == TCL_ERROR) {
    return TCL_ERROR;
  } else if (*rowid < 0 || *rowid > rcount) {
    Tcl_AppendResult(tclInterp, "invalid rowid ", Tcl_GetString(rowidObj), NULL);
    return TCL_ERROR;
  }
  return TCL_OK;
}

int TclDbfObjectCmd::AddField(Tcl_Obj * labelObj, Tcl_Obj * typeObj, Tcl_Obj * widthObj, Tcl_Obj * precObj) {
  char *label = Tcl_GetString(labelObj);
  if (!valid_name(label)) {
    Tcl_AppendResult(tclInterp, "invalid name, field ", label, NULL);
    return TCL_ERROR;
  }

  int width = 0;
  if (Tcl_GetIntFromObj(tclInterp, widthObj, &width) == TCL_ERROR || width < 1 || width > 255) {
    Tcl_AppendResult(tclInterp, "invalid width, field ", label, NULL);
    return TCL_ERROR;
  }

  int prec  = 0;
  if (precObj) {
    if (Tcl_GetIntFromObj(tclInterp, precObj, &prec) == TCL_ERROR || prec > width) {
      Tcl_AppendResult(tclInterp, "invalid precision, field ", label, NULL);
      return TCL_ERROR;
    }
  }

  DBFFieldType type = get_type(Tcl_GetString(typeObj), width, prec);
  if (type == FTInvalid) {
    Tcl_AppendResult(tclInterp, "invalid type, field ", label, NULL);
    return TCL_ERROR;
  }

  int i = DBFAddField(dbf, label, type, width, prec);
  if (i < 0) {
    if (CheckLastError() != TCL_ERROR) {
      Tcl_AppendResult(tclInterp, "cannot add field ", label, NULL);
    }
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
