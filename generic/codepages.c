#include <stdlib.h>

static const char * codepages[] = {
	NULL,
	"cp437", /* 1 - US MS-DOS */
	"cp850", /* 2 - International MS-DOS */
	"cp1252", /* 3 - Windows ANSI Latin I */
	"macCentEuro", /* 4 - Standard Macintosh */
	NULL,NULL,NULL,
	"cp865", /* 8 - Danish OEM */
	"cp437", /* 9 - Dutch OEM */
	"cp850", /* 10 - Dutch OEM* */
	"cp437", /* 11 - Finnish OEM */
	NULL,
	"cp437", /* 13 - French OEM */
	"cp850", /* 14 - French OEM* */
	"cp437", /* 15 - German OEM */
	"cp850", /* 16 - German OEM* */
	"cp437", /* 17 - Italian OEM */
	"cp850", /* 18 - Italian OEM* */
	"cp932", /* 19 - Japanese Shift-JIS */
	"cp850", /* 20 - Spanish OEM* */
	"cp437", /* 21 - Swedish OEM */
	"cp850", /* 22 - Swedish OEM* */
	"cp865", /* 23 - Norwegian OEM */
	"cp437", /* 24 - Spanish OEM */
	"cp437", /* 25 - English OEM (Great Britain) */
	"cp850", /* 26 - English OEM (Great Britain)* */
	"cp437", /* 27 - English OEM (US) */
	"cp863", /* 28 - French OEM (Canada) */
	"cp850", /* 29 - French OEM* */
	NULL,
	"cp852", /* 31 - Czech OEM */
	NULL,NULL,
	"cp852", /* 34 - Hungarian OEM */
	"cp852", /* 35 - Polish OEM */
	"cp860", /* 36 - Portuguese OEM */
	"cp850", /* 37 - Portuguese OEM* */
	"cp866", /* 38 - Russian OEM */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	"cp850", /* 55 - English OEM (US)* */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	"cp852", /* 64 - Romanian OEM */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	"cp936", /* 77 - Chinese GBK (PRC) */
	"cp949", /* 78 - Korean (ANSI/OEM) */
	"cp950", /* 79 - Chinese Big5 (Taiwan) */
	"cp874", /* 80 - Thai (ANSI/OEM) */
	NULL,NULL,NULL,NULL,NULL,NULL,
	NULL, /* 87 - Current ANSI CP ANSI */
	"cp1252", /* 88 - Western European ANSI */
	"cp1252", /* 89 - Spanish ANSI */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	"cp852", /* 100 - Eastern European MS-DOS */
	"cp866", /* 101 - Russian MS-DOS */
	"cp865", /* 102 - Nordic MS-DOS */
	"cp861", /* 103 - Icelandic MS-DOS */
	"cp850", /* 104 - Kamenicky (Czech) MS-DOS 895 */
	"cp850", /* 105 - Mazovia (Polish) MS-DOS 620 */
	"cp737", /* 106 - Greek MS-DOS (437G) */
	"cp857", /* 107 - Turkish MS-DOS */
	"cp863", /* 108 - French-Canadian MS-DOS */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	"cp950", /* 120 - Taiwan Big 5 */
	"cp949", /* 121 - Hangul (Wansung) */
	"cp936", /* 122 - PRC GBK */
	"cp932", /* 123 - Japanese Shift-JIS */
	"cp874", /* 124 - Thai Windows/MS–DOS */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	"cp737", /* 134 - Greek OEM */
	"cp852", /* 135 - Slovenian OEM */
	"cp857", /* 136 - Turkish OEM */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	"macCyrillic", /* 150 - Russian Macintosh */
	"macCentEuro", /* 151 - Eastern European Macintosh */
	"macGreek", /* 152 - Greek Macintosh */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	"cp1250", /* 200 - Eastern European Windows */
	"cp1251", /* 201 - Russian Windows */
	"cp1254", /* 202 - Turkish Windows */
	"cp1253", /* 203 - Greek Windows */
	"cp1257", /* 204 - Baltic Windows */
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
	NULL,NULL,NULL
};

static const char *codepage_encoding (char *codepage) {
	int result = 0; 
    if (codepage && strncmp(codepage,"LDID/",5) == 0) {
        result = atoi(codepage + 5);
        if (result < 0 || result > 255)
        	result = 0;
    };
    return codepages[result];
};
