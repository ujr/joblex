
Counting Print Job Pages
========================

**Joblex** was a quick'n'dirty tool to experiment with counting 
the number of pages in print jobs (PCL and PostScript), written in 2008. 

At that time I was working for a school where it was thought 
important to charge students for their printouts based on the 
number of pages. We did that by querying the printer's page counter 
(before and after each print job), a method sometimes referred 
to as “true counting”. 
With joblex we started to experiment with counting pages in the 
print job, which is sometimes referred to as “pre counting”. 
Needless to say, both methods have specific pros and cons.

The *joblex* posted here was written in a couple of hours 
(not counting debugging time) thanks to [lex][lex], the 
lexical scanner generator, that did most of the job. 
The C code in *joblex.l* really just drives `yylex` and 
helps with skipping sections of the binary PCL data. 
Note the use of *start states* to make the scanning context 
sensitive (in the code, `%s` lines declare start states and 
a state name in angle brackets limits the following pattern 
to that state).

Another approach was to send PostScript print files through
GhostScript using the null device, which still allows page
counting; see the *pagecount.sh* script.


Building
--------

From a shell prompt, type `make`, which should result in the 
`joblex` executable file.

This uses **lex** to generate *joblex.c* from *joblex.l* and 
then **cc** to compile *joblex.c* into the *joblex* executable. 
Note that *flex* is a free implementation of lex; most likely 
there is a package named *flex* for your operating system.


Usage
-----

> joblex \[-v] \[*jobfile*]

Use `-v` to turn on diagnostics to stderr; the print job 
is read from stdin or from the *jobfile* provided.

The output should be a single line to stdout of the form:

> *N* vpages=*P* copies=*C* struct=*S*

where *P* is the number of pages in the job, 
      *C* how many copies to print, *N=P⋅C*, 
  and *S* the ‘structure’ of the job, a string where 
each letter represents a part of the job as follows: 
`U` (UEL, see below), `J` (PJL), `P` (PostScript), `5` (PCL 5), 
`6` (PCL 6, aka PCL XL).


Limitations
-----------

This tool was written for experimentation, not for production. 
Known limitations include: 

  *  PJL variables (such as COPIES, DUPLEX, PAPER) are not evaluated 
     (doing so would be a simple enhancement); 
  *  PCL XL (aka PCL 6 Enhanced, see below) is ignored (parsing PCL6 
     is non-trivial); 
  *  PostScript mode relies on comments added by the printer driver; 
     more robust page counting would have to interpret the PostScript
     code, e.g. by passing it through [GhostScript][gs]; 
  *  support for other page description languages is missing, 
     PDF in particular, maybe others (such as HP-GL or ESC/P, 
     depending on the institution); 
  *  maliciously crafted print jobs could easily trip this tool.


What is PJL/PCL/PostScript?
---------------------------

**PostScript** is a page description language, developed by Adobe
in the early 1980ies. Many printers include PostScript interpreters
that drive rasterization. PostScript is a full programming language:
besides commands for describing graphics and glyphs it includes
operators for controlling program flow (looping and branching) and
provides data structures such as arrays and dictionaries. Because
PostScript is a full programming language, it is non-trivial to
determine the number of pages in a print job: the job has to be
interpreted. However, many print drivers include comments in the
generated PostScript code, among them the number of pages.

**PCL** is short for *Printer Command Language*, a page description
language developed by Hewlett-Packard (HP) that has become a de
facto industry standard. There are several revisions of PCL, where
PCL6 (also known as PCL XL) is significantly different from PCL 1 to 5.
PCL5 (and before) was a sequence of control sequences, processed in order.
PCL XL is stack-based, more like PostScript, but binary.

**PJL** is short for *Printer Job Language*, a language for controlling
print jobs. It was developed by Hewlett-Packard (HP) as an extension
to PCL but it quickly became supported by most PostScript printers
as well. To switch from whatever page description language back to PJL,
an unlikely string known as the *Universal Exit Language* or UEL is used.


Example Print Job
-----------------

At the time I experimented with *joblex* (2008), the typical Windows
printer driver generated either PCL or PostScript, and wrapped it in PJL
to create the *print job* that was then sent to the printing device.
Here is how a print job might look like (PostScript wrapped in PJL):

```
^[%-12345X@PJL JOB  
@PJL SET STRINGCODESET=UTF8  
@PJL COMMENT "Username: UNTITLED; App Filename: Testseite; 12-13-2003"  
@PJL SET JOBATTR="JobAcct1=UNTITLED"  
@PJL SET JOBATTR="JobAcct2=jupiter"  
@PJL SET JOBATTR="JobAcct3=WINGHOSTBOOK"  
@PJL SET JOBATTR="JobAcct4=20031213151817"  
@PJL SET USERNAME="UNTITLED"  
@PJL SET RESOLUTION=600  
@PJL SET BITSPERPIXEL=2  
@PJL SET ECONOMODE=OFF  
@PJL ENTER LANGUAGE=POSTSCRIPT  
%!PS-Adobe-3.0  
%%Title: Testseite  
%%Creator: PScript5.dll Version 5.2  
%%BoundingBox: (atend)  
%%Pages: (atend)  
%%EndComments  
...  
%%Pages: 1  
%%EOF  
^D^[%-12345X@PJL EOJ  
^[%-12345X
```

The magic string `^[%-12345X` is the UEL (universal exit language);
here `^[` stands for ASCII ESC (27 decimal); moreover, `^D` stands
for ASCII EOT (4 decimal), which terminates the PostScript code.


Test Data
---------

Once I had a large collection of print jobs. They cannot 
be published. Instead, a few PostScript and PCL files, most 
wrapped in PJL, can be found in the *jobs* folder, and the 
*test.sh* script will apply joblex to all of them.


License
-------

MIT

See the LICENSE file (or read the license text
at [choosealicense.com](https://choosealicense.com/licenses/mit/)
or [opensource.org](https://opensource.org/licenses/MIT)).


[lex]: https://en.wikipedia.org/wiki/Lex_(software\)
[gs]: https://www.ghostscript.com/

