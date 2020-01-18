=PERLLIBS REPO=

PERL libraries used by my other Perl code, or of general use.
They always use strict and -w. These tend to be older, I now work more in Python.

* ArgParse.pm -- Unfinished port of Python argparse.
(also available in Python)

* BibleBooks.pm --

* ColorManager.pm -- Gives easy access to ANSI terminal color
(also available in Python)

* DataSource.pm --

* Datatypes.pm --
(also available in Python)

* DomExtensions.pm --
(also available in Python)

* DtdKnowledge.pm --

* ElementManager.pm --
(also available in Python)

* EntityManager.pm --
(also available in Python)

* RecordFile.pm --

* SimplifyUnicode.pm --
(also available in Python)

* StatLog.pm --

* TFormatSupport.pm -- Support code for TabularFormats.pm.

* TableSchema.pm --

* TabularFormats.pm -- Older package to support a variety of formats that
are semantically like CSV.
(also available in Python)

* Tokenizer.pm -- A pretty good NLP text tokenizer. Especially good at Unicode
punctuation and normalization issues.
(also available in Python)

* XmlOutput.pm -- Utility for generating well-formed XML from programs.
Straightforward methods like OpenElement(name, attrs), but maintains the
stack of what's open, so it can close down to a given element by names, tell
you how many of some element type are open, report if you try to close something
not open, etc. It also handles text and attribute escaping.
(also available in Python)

* XmlTuples.pm -- Support for XML files conforming to a tiny schema suitable for
CSV-like data. Nice because (unlike CSV) you can see what all the fields are,
and you can apply the whole XML suite of tools. Easy to get to/from CSV,
using the TabularFormats package.
(also available in Python)

* '''sjdUtils.pm''' -- This underlies lots of stuff, and is almost entirely API-compatible
with sjdUtil.py (in PYTHONLIBS).
(also available in Python)

* alogging.pm -- a simple logging package that support *nix-style "-v" levels,
automatic message indentation, color (see ColorManager.pm and .py), etc.
(also available in Python)

* cp1252.pm -- Quick access to information about Windows Code Page 1252, which
is like Latin-1 except that it uses the C1 control characters (0x80 through 0x9F)
as printables (mostly punctuation and accented Latin vowels). Note that Web
servers often tell you they're giving you Unicode, when they actually are
giving you cp1252.

