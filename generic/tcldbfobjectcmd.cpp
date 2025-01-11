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
        returns a list of cell values for the given row

  $d get $rowid ?field?
        returns a cell value for the given row or dictionary of cells

  $d insert $rowid|end value [value ...]
        inserts the specified values into the given record

  $d update $rowid|end field value [field value ...]
        replaces the specified values of a single field in the record

  $d deleted $rowid [true|false]
        returns or sets the deleted flag for the given rowid

  $d forget
        closes dbase file
*/

static void TclDbfError (const char *message, void *pvUserData)
{
  DEBUGLOG("TclDbfError " << message << " " << pvUserData);
  if (pvUserData) {
    ((TclDbfObjectCmd *)pvUserData)->SetLastError(message);
  }
}

TclDbfObjectCmd::TclDbfObjectCmd (Tcl_Interp * interp, const char * name, TclCmd * parent,
    DBFHandle handle, bool v1compatible): TclCmd(interp, name, parent) {
  DEBUGLOG("TclDbfObjectCmd construct *" << this << " " << name << "" << handle <<" " << v1compatible);
  Tcl_DStringInit(&dstring);
  Tcl_DStringInit(&message);
  compatible = v1compatible;
  encoding = Tcl_GetEncoding(NULL, codepage_encoding(handle->pszCodePage));    
  handle->sHooks.Error = TclDbfError; 
  handle->sHooks.pvUserData = this;
  dbf = handle;
} 

TclDbfObjectCmd::~TclDbfObjectCmd () {
  DEBUGLOG("TclDbfObjectCmd destruct *" << this);
  dbf->sHooks.pvUserData = NULL;
  DBFClose(dbf);
  Tcl_FreeEncoding(encoding);
  Tcl_DStringFree(&message);
  Tcl_DStringFree(&dstring);
};

int TclDbfObjectCmd::Command (int objc, Tcl_Obj * const objv[]) {
  static const char *commands[] = {
    "info", "codepage", "add", "fields", "values", "record", "get",
    "insert", "update", "deleted", "forget", "close", 0L
  };
  enum commands {
    cmInfo, cmCodepage, cmAdd, cmFields, cmValues, cmRecord, cmGet,
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

    if (objc == 2) {

      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      Tcl_ListObjAppendElement(tclInterp, result, Tcl_NewIntObj(DBFGetRecordCount(dbf)));
      Tcl_ListObjAppendElement(tclInterp, result, Tcl_NewIntObj(DBFGetFieldCount(dbf)));
    
    } else if (objc == 3 && strcmp(Tcl_GetString(objv[2]), "records") == 0) {
    
      Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(DBFGetRecordCount(dbf)));
    
    } else if (objc == 3 && strcmp(Tcl_GetString(objv[2]), "fields") == 0) {
    
      Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(DBFGetFieldCount(dbf)));
    
    } else {
    
      Tcl_WrongNumArgs(tclInterp, 2, objv, "?records|fields?");
      return TCL_ERROR;
    } 
    break;

  case cmCodepage:

    if (objc > 2) {
      Tcl_WrongNumArgs(tclInterp, 1, objv, "codepage");
      return TCL_ERROR;
    } else {
      Tcl_SetObjResult(tclInterp, Tcl_NewStringObj(DBFGetCodePage(dbf), -1));
    }
    break;

  case cmAdd:

    if (objc < 5 || objc > 6) {
      Tcl_WrongNumArgs(tclInterp, 2, objv, "<label> type|nativetype <width> ?prec?");
      return TCL_ERROR;
    } else {
      return AddField(objv[2], objv[3], objv[4], objc > 5 ? objv[5] : NULL);
    }
    break;

  case cmFields:

    if (objc > 3) {
      Tcl_WrongNumArgs(tclInterp, 3, objv, NULL);
      return TCL_ERROR;
    } else if (objc == 3) {

      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      const char * label = Tcl_GetString(objv[2]);
      int fieldid = DBFGetFieldIndex(dbf, label);
      if (fieldid < 0) {
        Tcl_AppendResult(tclInterp, "unknown field ", label, NULL);
        return TCL_ERROR;
      }
      return GetField(result, fieldid);

    } else {

      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      int fcount = DBFGetFieldCount(dbf);
      for (int fieldid = 0; fieldid < fcount; fieldid++) {
        Tcl_Obj * field = Tcl_NewObj();
        if (GetField(field, fieldid) == TCL_ERROR) {
          return TCL_ERROR;
        } 
        Tcl_ListObjAppendElement(tclInterp, result, field);
      }
    }
    break;

  case cmValues:

    if (objc != 3) {
      Tcl_WrongNumArgs(tclInterp, 2, objv, "<label>");
      return TCL_ERROR;
    } else {

      const char * label = Tcl_GetString(objv[2]);
      int fieldid = DBFGetFieldIndex(dbf, label);
      if (fieldid < 0) {
        Tcl_AppendResult(tclInterp, "unknown field ", label, NULL);
        return TCL_ERROR;
      }
      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      int rcount = DBFGetRecordCount(dbf);
      for (int rowid = 0; rowid < rcount; rowid++) {
        Tcl_Obj * value;
        if (GetFieldValue(rowid, fieldid, &value) == TCL_ERROR) {
          return TCL_ERROR;
        }
        Tcl_ListObjAppendElement(tclInterp, result, value);
      }
    }
    break;

  case cmRecord:

    if (objc != 3) {
      Tcl_WrongNumArgs(tclInterp, 2, objv, "<rowid>");
      return TCL_ERROR;
    } else {

      int rowid;
      if (GetRowid(objv[2], &rowid) == TCL_ERROR) {
        return TCL_ERROR;
      }
      Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
      int fcount = DBFGetFieldCount(dbf);
      for (int fieldid = 0; fieldid < fcount; fieldid++) {
        Tcl_Obj * value;
        if (GetFieldValue(rowid, fieldid, &value) == TCL_ERROR) {
          return TCL_ERROR;
        }
        Tcl_ListObjAppendElement(tclInterp, result, value);
      }
    }
    break;

  case cmGet:

    if (objc < 3 || objc > 4) {
      Tcl_WrongNumArgs(tclInterp, 2, objv, "<rowid> ?label?");
      return TCL_ERROR;
    } else {

      int rowid;
      if (GetRowid(objv[2], &rowid) == TCL_ERROR) {
        return TCL_ERROR;
      }

      if (objc == 4) {

        const char * label = Tcl_GetString(objv[3]);
        int fieldid = DBFGetFieldIndex(dbf, label);
        if (fieldid < 0) {
          Tcl_AppendResult(tclInterp, "unknown field ", label, NULL);
          return TCL_ERROR;
        }
        Tcl_Obj * value;
        if (GetFieldValue(rowid, fieldid, &value) == TCL_ERROR) {
          return TCL_ERROR;
        }
        Tcl_SetObjResult(tclInterp, value);

      } else {

        Tcl_Obj * result = Tcl_GetObjResult(tclInterp);
        int fcount = DBFGetFieldCount(dbf);
        for (int fieldid = 0; fieldid < fcount; fieldid++) {
          Tcl_Obj * value;
          if (GetFieldValue(rowid, fieldid, &value) == TCL_ERROR) {
            return TCL_ERROR;
          }
          char label [XBASE_FLDNAME_LEN_READ+1];
          DBFGetFieldInfo(dbf, fieldid, label, NULL, NULL);
          Tcl_ListObjAppendElement(tclInterp, result, Tcl_NewStringObj(label, -1));
          Tcl_ListObjAppendElement(tclInterp, result, value);
        }
      }
    }
    break;

  case cmInsert:

    if (objc < 3) {
      Tcl_WrongNumArgs(tclInterp, 2, objv, "<rowid>|end <list>|?<value> ...?");
      return TCL_ERROR;
    } else {

      int vobjc;
      Tcl_Obj ** vobjv;
      if (objc == 4 && objv[3]->typePtr && objv[3]->typePtr->name &&
          strcmp(objv[3]->typePtr->name, "list") == 0) {
        // NOTE: v1 compatibility
        if (Tcl_ListObjGetElements(tclInterp, objv[3], &vobjc, &vobjv) == TCL_ERROR) {
          return TCL_ERROR;
        }
      } else {
        vobjc = objc - 3;
        vobjv = (Tcl_Obj **)&objv[3];
      }

      int fcount = DBFGetFieldCount(dbf);
      if (vobjc > fcount && !compatible) {
        Tcl_SetResult(tclInterp, (char *)"too many values", NULL);
        return TCL_ERROR;
      }
      int rowid;
      if (GetRowid(objv[2], &rowid) == TCL_ERROR) {
        return TCL_ERROR;
      }
      for (int i = 0; i < vobjc && i < fcount; i++) {
        if (SetFieldValue(rowid, i, vobjv[i]) == TCL_ERROR) {
          return TCL_ERROR;
        }
      }
      if (!compatible) {
        DBFUpdateHeader(dbf);
        if (CheckLastError() == TCL_ERROR) {
          return TCL_ERROR;
        }
      }
      Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(rowid));
    }
    break;

  case cmUpdate:

    if (objc < 3 || (objc - 3) % 2 != 0) {
      Tcl_WrongNumArgs(tclInterp, 2, objv, "<rowid>|end ?<field> <value>? ?<field> <value> ...?");
      return TCL_ERROR;
    } else {

      int rowid;
      if (GetRowid(objv[2], &rowid) == TCL_ERROR) {
        return TCL_ERROR;
      }
      for (int i = 3; i < objc; i += 2) {
        char * field = Tcl_GetString(objv[i]);
        int fieldid = DBFGetFieldIndex(dbf, field);
        if (fieldid < 0) {
          Tcl_AppendResult(tclInterp, "unknown field ", field, NULL);
          return TCL_ERROR;
        }
        if (SetFieldValue(rowid, fieldid, objv[i+1]) == TCL_ERROR) {
          return TCL_ERROR;
        }
      }
      if (!compatible) {
        DBFUpdateHeader(dbf);
        if (CheckLastError() == TCL_ERROR) {
          return TCL_ERROR;
        }
      }
      Tcl_SetObjResult(tclInterp, Tcl_NewIntObj(rowid));
    }  
    break;

  case cmDeleted:

    if (objc < 3 || objc > 4) {
      Tcl_WrongNumArgs(tclInterp, 2, objv, "<rowid> ?<mark>?");
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

int TclDbfObjectCmd::GetFieldValue (int rowid, int fieldid, Tcl_Obj ** valueObj) {
  char label [XBASE_FLDNAME_LEN_READ+1];
  DBFFieldType type = DBFGetFieldInfo(dbf, fieldid, label, NULL, NULL);

  if (DBFIsAttributeNULL(dbf, rowid, fieldid)) {

    *valueObj = Tcl_NewStringObj("", -1);
  
  } else if (compatible) {
  
    *valueObj = Tcl_NewStringObj(EncodeTclString(DBFReadStringAttribute(dbf, rowid, fieldid)), -1);
  
  } else if (type == FTString) {
  
    *valueObj = Tcl_NewStringObj(EncodeTclString(DBFReadStringAttribute(dbf, rowid, fieldid)), -1);
  
  } else if (type == FTDouble) {
  
    *valueObj = Tcl_NewDoubleObj(DBFReadDoubleAttribute(dbf, rowid, fieldid));
  
  } else if (type == FTInteger) {
  
    *valueObj = Tcl_NewIntObj(DBFReadIntegerAttribute(dbf, rowid, fieldid));
  
  } else if (type == FTDate) {
  
    // NOTE: skip double conversion
    // SHPDate date = DBFReadDateAttribute(dbf, rowid, fieldid);
    // char value[9]; /* "yyyyMMdd\0" */
    // snprintf(value, sizeof(value), "%04d%02d%02d", date->year, date->month, date->day);
    *valueObj = Tcl_NewStringObj(DBFReadStringAttribute(dbf, rowid, fieldid), -1);
  
  } else if (type == FTLogical) {
  
    *valueObj = Tcl_NewStringObj(DBFReadLogicalAttribute(dbf, rowid, fieldid), -1);
  
  } else {
  
    // valueObj = Tcl_NewStringObj(DBFReadStringAttribute(dbf, rowid, fieldid), -1);
    Tcl_AppendResult(tclInterp, "invalid data type, field ", label, NULL);
    return TCL_ERROR;
  }
  return TCL_OK;
}

int TclDbfObjectCmd::SetFieldValue (int rowid, int fieldid, Tcl_Obj * valueObj) {
  int result = false;
  char * value = Tcl_GetString(valueObj);

  int width;
  char label [XBASE_FLDNAME_LEN_READ+1];
  DBFFieldType type = DBFGetFieldInfo(dbf, fieldid, label, &width, NULL);

  if (strcmp(value, "") == 0) {

    result = DBFWriteNULLAttribute(dbf, rowid, fieldid);

  } else if (type == FTString) {

    // FIXME: check for valid encoding and truncation
    Tcl_DString s;
    Tcl_DStringInit(&s);
    Tcl_UtfToExternalDString(encoding, value, -1, &s);
    // fprintf(stderr,"encoding:%s,input:%zd,output:%zd\n", Tcl_GetEncodingName(encoding),strlen(value),strlen(Tcl_DStringValue(&s)));
    if (Tcl_DStringLength(&s) > width) {
      if (compatible) {
        // Tcl_DStringSetLength(&s, width);
      } else {
        Tcl_AppendResult(tclInterp, "too long value, field ", label, " row ", NULL);
        Tcl_AppendObjToObj(Tcl_GetObjResult(tclInterp), Tcl_NewIntObj(rowid));
        return TCL_ERROR;
      }
    }
    result = DBFWriteStringAttribute(dbf, rowid, fieldid, Tcl_DStringValue(&s));
    Tcl_DStringFree(&s);

  } else if (type == FTDouble) {

    double d;
    if (Tcl_GetDoubleFromObj(tclInterp, valueObj, &d) == TCL_ERROR) {
      Tcl_AppendResult(tclInterp, ", field ", label, " row ", NULL);
      Tcl_AppendObjToObj(Tcl_GetObjResult(tclInterp), Tcl_NewIntObj(rowid));
      return TCL_ERROR;
    }
    result = DBFWriteDoubleAttribute (dbf, rowid, fieldid, d);

  } else if (type == FTInteger) {

    int i;
    if (Tcl_GetIntFromObj(tclInterp, valueObj, &i) == TCL_ERROR) {
      Tcl_AppendResult(tclInterp, ", field ", label, " row ", NULL);
      Tcl_AppendObjToObj(Tcl_GetObjResult(tclInterp), Tcl_NewIntObj(rowid));
      return TCL_ERROR;
    }
    result = DBFWriteIntegerAttribute (dbf, rowid, fieldid, i);

  } else if (type == FTDate) {

    SHPDate date;
    if (3 != sscanf(value, "%4d%2d%2d", &date.year, &date.month, &date.day)) {
      Tcl_AppendResult(tclInterp, "expected date as YYYYMMDD but got \"", value, "\", field ", label, " row ", NULL);
      Tcl_AppendObjToObj(Tcl_GetObjResult(tclInterp), Tcl_NewIntObj(rowid));
      return TCL_ERROR;
    }
    // FIXME: more checks (via mktime or "clock scan")
    if (date.month < 1 || date.month > 12 || date.day < 1 || date.day > 31) {
      Tcl_AppendResult(tclInterp, "invalid date, field ", label, " row ", NULL);
      Tcl_AppendObjToObj(Tcl_GetObjResult(tclInterp), Tcl_NewIntObj(rowid));
      return TCL_ERROR;
    }

    result = DBFWriteDateAttribute (dbf, rowid, fieldid, &date);

  } else if (type == FTLogical) {

    if (strlen(value) > 1) {
      Tcl_AppendResult(tclInterp, "too long value, field ", label, " row ", NULL);
      Tcl_AppendObjToObj(Tcl_GetObjResult(tclInterp), Tcl_NewIntObj(rowid));
      return TCL_ERROR;
    }
    result = DBFWriteLogicalAttribute (dbf, rowid, fieldid, *value);

  } else {

    Tcl_AppendResult(tclInterp, "invalid data type, field ", label, NULL);
    return TCL_ERROR;
  }

  if (!result && !compatible) {
    Tcl_AppendResult(tclInterp, "update error, field ", label, " row ", NULL);
    Tcl_AppendObjToObj(Tcl_GetObjResult(tclInterp), Tcl_NewIntObj(rowid));
    return TCL_ERROR;
  }
  return TCL_OK;
}

int TclDbfObjectCmd::GetRowid (Tcl_Obj * rowidObj, int * rowid) {
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

int TclDbfObjectCmd::AddField (Tcl_Obj * labelObj, Tcl_Obj * typeObj, Tcl_Obj * widthObj, Tcl_Obj * precObj) {
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

int TclDbfObjectCmd::GetField (Tcl_Obj * fieldObj, int fieldid) {
  int width, prec;
  char label [XBASE_FLDNAME_LEN_READ+1];
  char nativetype = DBFGetNativeFieldType(dbf, fieldid);
  DBFFieldType type = DBFGetFieldInfo(dbf, fieldid, label, &width, &prec);

  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewStringObj(EncodeTclString(label), -1));
  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewStringObj(type_of(type), -1));
  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewStringObj(&nativetype, 1));
  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewIntObj(width));
  Tcl_ListObjAppendElement(NULL, fieldObj, Tcl_NewIntObj(prec));

  return TCL_OK;
}
