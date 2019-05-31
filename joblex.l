 /* Count pages in print jobs. Urs Jakob Ruetschi 2008 */
%{
#include <ctype.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SUCCESS  0    // exit code if successful
#define FAILSOFT 111  // exit code for temporary failure
#define FAILHARD 127  // exit code for permanent failure
#define MAX(a,b) ((a)>(b)?(a):(b))

const char *me;
long vpages = 0;  // assumption
long copies = 1;  // assumption
long lineno = 1;
int duplex = 0;   // assumption (0=simplex)
int verbose = 0;

char lang[32], *langptr = lang;
const char *langend = lang + sizeof(lang) - 1;

int atend = 0;  // set to 1 on %%Pages: (atend)
int gotit = 0;  // set to 1 if pages determined

char first;     // parametrized char of a PCL seq
char group;     // group char of a PCL param seq
long value;     // value of a PCL param seq

static void addlang(char l);
static void skip(long nbytes);
static void dopcl(int first, int group, long value, int param);
static void pjlvar(const char *text);
static int getbool(const char *s, size_t len);
static void debug(const char *fmt, ...);
%}

ESC     \x1B
FF      \x0C
WS      [ \t]
UEL     {ESC}%-12345X
NUMBER  [[:digit:]]+
ATEND   "(atend)"
ENTER   @PJL{WS}+ENTER{WS}+LANGUAGE{WS}*={WS}*
SET     @PJL{WS}+SET{WS}+

 /*
  * PCL character ranges: two-charachter escape sequences TC,
  * parametrized character PC, group character GC, parameter
  * character zC, and termination character ZC.
  */

TC      [\x30-\x7E]
PC      [\x21-\x2F]
GC      [\x60-\x7E]
zC      [\x60-\x7E]
ZC      [\x40-\x5E]
PCLNUM  [-+]?([[:digit:]]{0,5}\.)?[[:digit:]]{1,5}

%s PJL PJL_ENTER PJL_SET
%s PS PS_PAGES PS_PAGE
%s PCL PCL_PARAM PCL_HPGL
%s PCLXL

%%

 /*
  * Switching between languages: PJL, PS, PCL, and PCLXL.
  */

{UEL}                { BEGIN(INITIAL); addlang('U');
                       debug("saw plain UEL, enter INITIAL"); }
{UEL}/@PJL           { BEGIN(PJL); addlang('U'); addlang('J');
                       debug("saw UEL@PJL, enter PJL"); }
<INITIAL>^%!         { BEGIN(PS); addlang('P');
                       debug("saw %!, enter PS"); }
<INITIAL>^@PJL       { BEGIN(PJL); addlang('J');
                       debug("saw ^@PJL, enter PJL"); }
<INITIAL>{ESC}       { BEGIN(PCL); addlang('5');
                       debug("saw plain ESC, enter PCL"); }

 /*
  * Rules for PostScript: look for %%Pages comments and %%[Page: N]%%
  * messages (Windows PS drivers often include code that generates
  * these but omit DSC %%Pages comments).
  *
  * Looking for /#copies is dangerous without a full PostScript
  * interpreter: many drivers push the result of a calculation
  * on the stack and then define /#copies. Same for /NumCopies.
  * The %%Requirements: comment has a numcopies(N) option, but
  * I've never seen it in practice...
  */

<PS>%%Pages:{WS}*    { if (!gotit) BEGIN(PS_PAGES); }
<PS_PAGES>{ATEND}    { atend = 1; debug("saw %%%%Pages: (atend)"); }
<PS_PAGES>{NUMBER}   { long n = atol(yytext);
                       if (vpages < n) vpages = n;
                       if (!atend) gotit = 1;
                       debug("saw %%%%Pages: %d", n); }
<PS_PAGES>.|\n       { BEGIN(PS); }

<PS>\(%%\[Page:{WS}*{NUMBER}\]%%\) { if (!gotit) {
                       atend = 1; BEGIN PS_PAGE; yyless(9); }}
<PS_PAGE>{WS}*{NUMBER} { long n = atol(yytext);
                       if (vpages < n) vpages = n;
                       debug("saw (%%%%[Page: %d]%%%%)" ,n); }
<PS_PAGE>.|\n        { BEGIN PS; }
                    
 /*
  * In PJL mode, we look for @PJL ENTER LANGUAGE
  * and interesting @PJL SET name = value stuff
  */

<PJL>{ENTER}         { BEGIN(PJL_ENTER); }
<PJL_ENTER>POSTSCRIPT{WS}*$  { BEGIN(PS); addlang('P');
                       debug("saw PJL ENTER, enter PS"); }
<PJL_ENTER>PCL{WS}*\r?$ { BEGIN(PCL); addlang('5');
                       debug("saw PJL ENTER, enter PCL"); }
<PJL_ENTER>PCLXL{WS}*\r?$  { BEGIN(PCLXL); addlang('6');
                       debug("saw @PJL ENTER, enter PCLXL"); }
<PJL_ENTER>.*        { BEGIN(INITIAL); addlang('?');
                       debug("saw @PJL ENTER LANGUAGE = %s", yytext); }
<PJL>{SET}           { BEGIN(PJL_SET); }
<PJL_SET>.*\r?       { BEGIN(PJL); pjlvar(yytext); }

 /*
  * In PCL mode, we completely parse the PCL stuff, assign values
  * and parameter names to global variables, and invoke dopcl()
  * for all parametrised PCL commands. The patterns that just
  * increment magic I've found in pclcount by Oliveira & Manin,
  * but cannot find any reference in the PCL specification...
  */

<PCL>{FF}            { ++vpages; debug("PCL FF ends page %ld", vpages); }

<PCL>{ESC}%-1B       { debug("Stand-alone plotter mode (?)"); }
<PCL>{ESC}%[0-9]*B   { BEGIN(PCL_HPGL); debug("enter HPGL mode"); }
<PCL_HPGL>.|\n       { /* ignore HP-GL/2 */ }
<PCL_HPGL>{ESC}%[0-9]*A { BEGIN(PCL); debug("enter PCL mode (after HPGL)"); }
<PCL>{ESC}%[0-9]*A   { debug("enter PCL mode (w/o previous HPGL mode)"); }

<PCL>{ESC}           { debug("unexpected ESC at top level"); }
<PCL>{ESC}{TC}       { /* ignore PCL two-char command */
                       if (verbose > 1) debug("{ESC %c}", yytext[1]); }
<PCL>{ESC}{PC}{GC}   { first = yytext[1];
                       group = yytext[2];
                       value = 0; // default
                       BEGIN(PCL_PARAM); }
<PCL_PARAM>{PCLNUM}  { const char *p = yytext;
                       if ((*p == '-') || (*p == '+')) ++p;
                       value = atol(p); /* trunc float */ }
<PCL_PARAM>{zC}      { dopcl(first, group, value, yytext[0]); }
<PCL_PARAM>{ZC}      { dopcl(first, group, value, yytext[0]);
                       BEGIN(PCL); }
<PCL_PARAM>{ESC}     { yyless(0); BEGIN(PCL); debug("early ESC in param"); }
<PCL_PARAM>.         { /* ignore anything else */ }
<PCL>.               { /* ignore anything else */ }
 /*<PCL>{ESC}\*p{NUMBER}[XY]\x80{FF} { ++magic; }*/
 /*<PCL>{ESC}\*p{NUMBER}x{NUMBER}[XY]\x80{FF} { ++magic; }*/

 /* I've no idea about PCL6 (aka PCLXL) so just skip it! */

<PCLXL>.             { /* ignore PCLXL */ }

 /* Maintain lineno and ignore anything else */

\n                   { ++lineno; }
.                    { /* ignore */ }

%%

int
main(int argc, char **argv)
{
   if (argv && *argv) me = *argv++;
   else return FAILHARD; // no arg0?

   while (*argv && **argv == '-') {
     const char *arg = *argv++;
     if (!strcmp(arg, "--")) break;
     if (!strcmp(arg, "-v")) verbose++;
     // else silently ignore
   }

   if (*argv) {
      const char *fn = *argv++;
      if (!(yyin = fopen(fn, "r"))) {
         fprintf(stderr, "%s: open %s: %s\n", me, fn, strerror(errno));
         return FAILSOFT;
      }
   }
   else yyin = stdin;

   if (*argv) {
      fprintf(stderr, "Usage: %s [-v] [jobfile]\n", me);
      fprintf(stderr, "Read stdin if no jobfile; -v increases verbosity\n");
      return FAILHARD;
   }

   //yyout = fopen("/dev/null", "w");
   yylex();
   addlang(0); // terminate!

   if (verbose) fprintf(stderr, "\n");
   printf("%ld vpages=%ld copies=%ld duplex=%d struct=%s\n",
          vpages*copies, vpages, copies, duplex, lang);

   return SUCCESS;
}

int
yywrap(void)
{
   return 1; // cause scanner to report end-of-file
}

static void
addlang(char l)
{
   if (l) { // append language code
      if (langptr < langend) *langptr++ = l;
      else if (langptr > lang) langptr[-1] = '!'; // too long
   }
   else *langptr = '\0'; // terminate
}

#define PCLCODE(x,y,z) (65536*(x&255) + 256*(y&255) + (z&255))

static void
dopcl(int first, int group, long value, int param)
{
   if (verbose > 1)
      debug("{ESC %c %c %ld %c}", first, group, value, param);

   //if (0x60 <= param && param <= 0x7E) param -= 0x20;
   switch (PCLCODE(first,group,param)) {
   case PCLCODE('&','b','W'): // i/o config data
   case PCLCODE('&','p','X'): // transparent data
   case PCLCODE('&','n','W'): // string data
   case PCLCODE('(','f','W'): // symbol set definition
   case PCLCODE(')','s','W'): // font descriptor data
   case PCLCODE('(','s','W'): // character/descriptor data
   case PCLCODE('*','c','W'): // pattern data
   case PCLCODE('*','b','V'): // raster data (a plane)
   case PCLCODE('*','b','W'): // raster data (a row)
   case PCLCODE('*','v','W'): // CID (Configure Image Data)
   case PCLCODE('*','m','W'): // dither matrix data
   case PCLCODE('*','l','W'): // color lookup table data
   case PCLCODE('*','i','W'): // viewing illuminant data
      if (verbose > 1)
         debug("skipping %ld bytes of %c%c#%c data",
               value, first&255, group&255, param&255);
      skip(value);
      break;
   case PCLCODE('&','l','X'):
      copies = value;
      debug("set PCL copies = %ld", copies);
      break;
   case PCLCODE('&','l','S'):
      switch (value) {
      case 0: // simplex
      case 1: // duplex, long edge binding
      case 2: // duplex, short edge binding
         duplex = (int) value;
         debug("set PCL duplex = %ld", value);
         break;
      default: // ignore all other values
         break;
      }
      break;
   default: // ignore
      break;
   }
}

static void
pjlvar(const char *text)
{
   // Format of text: "name{WS}*={WS}*value{WS*}\r?"
   // Look for these PJL environment variables:
   // COPIES       1..999   num of uncollated copies (each page)
   // DUPLEX       ON|OFF   default duplex mode (job may override)
   // PAPER        A4|LETTER|CUSTOM|etc.  physical media size
   // PLANESINUSE  1|3      1=monochrome, 3=color
   // QTY          1..999   num of collated copies (entire job)
   // Hint: BITSPERPIXEL is for PCL6 bitmaps, don't use here

   register const char *p;
   const char *name, *value;
   size_t nlen, vlen, tlen;

   while (isspace(*text)) text++; // skip leading white space
   name = text;
   p = strchr(text, '=');
   if (!p) return; // ignore invalid PJL SET command
   p--; // just before the '='
   while (p >= name && isspace(*p)) p--; // skip trailing white space
   nlen = p - name + 1;
   p = strchr(p, '=') + 1; // just past the '='
   while (isspace(*p)) p++; // skip leading white space
   value = p;
   p = value + strlen(value) - 1;
   while (p >= value && isspace(*p)) p--; // skip trailing white space
   vlen = p - value + 1;
   tlen = p - text + 1; // total length

   if (strncasecmp(name, "QTY", nlen) == 0 ||
       strncasecmp(name, "COPIES", nlen) == 0) {
      copies = MAX(1, atol(value));
      debug("saw PJL SET %.*s, set copies=%ld", (int) tlen, text, copies);
   }
   else if (strncasecmp(name, "DUPLEX", nlen) == 0) {
      duplex = getbool(value, vlen);
      debug("saw PJL SET %.*s, set duplex=%d", (int) tlen, text, duplex);
   }
   // else etc.
}

static int
getbool(const char *s, size_t len)
{
   if (strncasecmp(s, "ON", len) == 0) return 1;
   if (strncasecmp(s, "OFF", len) == 0) return 0;
   if (strncasecmp(s, "YES", len) == 0) return 1;
   if (strncasecmp(s, "NO", len) == 0) return 0;
   if (strncasecmp(s, "TRUE", len) == 0) return 1;
   if (strncasecmp(s, "FALSE", len) == 0) return 0;
   return 0; // default to false
}

static void
skip(long nbytes)
{
#if 1
   while (nbytes-- > 0) {
      int c = input();
      if (c == EOF) break;
   }
#else
   if (fseek(yyin, nbytes, SEEK_CUR) == 0) yyrestart(yyin);
   else exit(FAILSOFT);
#endif
}

static void
debug(const char *fmt, ...)
{
   va_list ap;
   va_start(ap, fmt);
   if (!verbose) return;
   fprintf(stderr, "Line %ld: ", lineno);
   vfprintf(stderr, fmt, ap);
   fprintf(stderr, "\n");
   va_end(ap);
}
