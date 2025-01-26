#include <shapefil.h>
#include <ctype.h>

//
// Adapted code from original tcldbf, see README
//

static const char *type_of (DBFFieldType field_type) {
	switch (field_type) {
	case FTString:  return "String";
	case FTInteger: return "Integer";
	case FTDouble:  return "Double";
	case FTLogical: return "Logical";
	case FTDate:    return "Date";
	case FTInvalid: return "Invalid";
	// default: return "Unknown";
	}
	return "Unknown";
}

static DBFFieldType get_type (const char *type_name, int width, int prec) {
	if (type_name && *type_name) {
		if (type_name[1] == '\0') {
			switch (type_name[0]) {  
			case 'C': return FTString;
			case 'N':
			case 'F': return (prec > 0 || width >= 10) ? FTDouble : FTInteger;
			case 'L': return FTLogical;
			case 'D': return FTDate;
			}
		} else {
			if (strcmp(type_name,"String" ) == 0) return FTString;
			if (strcmp(type_name,"Integer") == 0) return FTInteger;
			if (strcmp(type_name,"Double" ) == 0) return FTDouble;
			if (strcmp(type_name,"Logical") == 0) return FTLogical;
			if (strcmp(type_name,"Date") == 0)    return FTDate;
		}
	}
	return FTInvalid;
}

static int valid_name (const char *field_name) {
	if (strlen(field_name) > 10)
		return 0;
	for (const char *s = field_name; *s; s++)
		if (!(isalnum(*s) || *s == '_'))
			return 0;
	return 1;
}

static int format_number(const char * value, int width, char * buffer, int buffer_size) {
    const char *s = value;
    int i = 0;
    if (s[i] == '-')
        i++;
    while (i < width && isdigit(s[i]))
    	i++;
    if (s[i])
        return 0;
    memset(buffer, ' ', width - i);
    memcpy(&buffer[width - i], value, i);
	return 1;
}

static int format_decimal(const char * value, int width, int prec, char * buffer, int buffer_size) {
    memset(&buffer[0], ' ', width - prec - 2);
    memset(&buffer[width - prec - 2], '0', prec + 2);
    buffer[width - prec - 1] = '.';
    const char *s = value;
    int i = 0;
    if (s[i] == '-')
    	i++;
    while (i < width && isdigit(s[i]))
        i++;
    if (i + prec + 1 > width) 
		return 0;
    int pointi = i;
    if (s[i] == '.') {
    	i++;
    	while (isdigit(s[i]))
			i++;
		if (s[i])
			return 0;
		if (i > pointi + prec + 1)
			i = pointi + prec + 1	;
	} else if (s[i])
		return 0;
    memcpy(&buffer[width - prec - 1 - pointi], value, i);
	return 1;
}

static int format_numeric(const char * value, int width, int prec, char * buffer, int buffer_size) {
	if (width >= buffer_size)
		return 0;
	if (width - prec < 2) 
		return 0;
	if (prec)
        return format_decimal(value, width, prec, buffer, buffer_size);
	else
		return format_number(value, width, buffer, buffer_size);
}