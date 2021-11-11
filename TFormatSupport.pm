#!/usr/bin/perl -w
#
# TFormatSupport.pm: Support specific file formats for TabularFormats.pm.
# Original, 2010-03-23 by Steven J. DeRose, as csvFormat.pm
#
package TFormatSupport;

use strict;
use feature 'unicode_strings';

use sjdUtils;

#sjdUtils::try_module("HTML::Entities") || warn
#    "Can't access CPAN HTML::Entities module.\n";

sjdUtils::try_module("Datatypes") || warn
    "Can't access sjd Datatypes module.\n";
#sjdUtils::try_module("FakeParser") || warn
#    "Can't access sjd FakeParser module (needed for quasi-XML support).\n";

our %metadata = (
    'title'        => "TFormatSupport",
    'description'  => "",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2010-03-23",
    'modified'     => "2021-09-16",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

use TFormatSupport.pm

Implements parsing and generation for basic record/field structures
across many syntactic forms, for use via C<TabularFormats.pm>.

The functionality and expressiveness are
essentially that of CSV and its kin; however, many formats
are supported for such simple data (even formats that can do more in general).


=head2 Formats and variations supported

The I<basicType> option values supported include these, which have a simple
records/fields structure:

    B<ARFF>    (for WEKA system),
    B<COLUMNS> (column-oriented),
    B<CSV>     (lots of variations),
    B<MIME>    (headers),
    B<XSV>     (a simple XML subset designed for CSV-style data).

and also the following more sophisticated formats, that
can be used in simple ways that correspond to
a basic records/fields structure (examples below):

    B<JSON>       (a single top-level array or hash, of hashes),
    B<Manchester> (a small subset of a syntax for RDF),
    B<PERL>       (a single top-level array or hash assignment),
    B<SEXP>       (LISP/Scheme S-expressions),
    B<XML>        (simple HTML table structures, using any tag names),

Formats that store data as binary fields (n-byte integers and float,
packed bits, length-prefixed strings, and such) are not supported,
though there's no particular reason they can't be added.

C<TabularFormats> is a way to move simple tabular data around!
Representing general XML, JSON, programming-language structure declarations,
or OWL in CSV-like formats
is awkward at best, and this script doesn't deal with data that complex.

For details on the particular formats,
see below under L</"Supported formats, with examples">.

First details on the API, see C<TabularFormats.pm>, which is who you
actually call. It forwards to the appropriate format's support code in
TFormatSupport as needed.

B<Note>: If an input format can have more than one physical line per
logical record (such as I<some> CSVs, MIME, ARFF, XSV, etc.), then definitely
use I<readRecord>() instead of just Perl reads, to make sure you get a
whole logical record each time. For example:

B<Note>: Some of the supported formats (such as JSON, SEXP, and XML)
can express much more complex structures than the others,
such as hierarchies rather than merely records and fields.
Only certain simple subsets of those formats are supported here:
the I<least common denominator>, if you will.
For example, XML support is limited to table-like structures (though you
can change tag names), with little but text inside individual cells; and
does not yet use a real parser (though it's pretty close).
JSON and SEXP are supported in  similar fashion.

=head2 Additional formats to add:

  mediaWiki table markup (do with CSV with I<fieldSep> C<||>?)
  Perl 'unpack'
  ARC (Internet Archive)
  Python (tweak Perl support?)
  RDF "Turtle"
  Sparkql results
  Google pbufs (unusual; unparseable without their schemas)
  Excel(r)'s xlsx (XML) or even binary formats.
    table = sheetData
    tr    = row @r="rownum"
    td    = c @r="A1etc" @t="s for string, n for numeric"
        (link to sharedtext when string?)
        inside c is v, containing a number: if cell is string, it's that
        item from sharedStrings.xml (0-base, <r> element,
        w/ <t> or <rPr> with markup).
    move sharedStrings into the sheet; change tags to HTML.


=head1 Options

See C<TabularFormats.pm> for additional information.
All options are always available to I<setOption> and I<getOption>,
even those that are specific to formats not in use.
Using an unknown option name will fail.
You can set an option to 0 or "", but not to C<undef>.

Unless otherwise specified below, options with unquoted default values
are boolean, and options with quoted values are strings.

=head3 General Options

=over

=item * B<comment>       (string, depending on basicType) --
Ignore records as comments if they begin with this string.
Some formats permit comments other than at start of line;
they are not all fully supported here yet).

The default value for I<comment> varies with the format:
"%" for ARFF,
None for COLUMNS,
"#" for CSV,
"//" for JSON,
"#" for Manchester,
None for MIME,
"#" for PERL,
";" for SEXP,
"<!--...-->" for XSV,
"<!--" for XML.

=item * B<prettyPrint>   (boolean) 1

Output line-breaks and/or indentation to pretty-print output
(the details depend on the I<basicType> in effect).

=item * B<stripFields>   (boolean) 1

Discard leading/trailing whitespace on fields.

=item * B<stripRecords>  (boolean) 1

Discard leading/trailing whitespace on records.

=item * B<TFverbose>     (integer) 0   # Show more trace information?

=back


=head3 Options for ARFF format

=over

(none)

=back

=head3 Options for COLUMNS format

=over

(none) However, you must use I<setFieldPosition>() to say where each field goes.

=back


=head3 Options for CSV format

=over

=item * B<recordSep>     (string) "\n"

Record separator

=item * B<fieldSep>      (string) "\t"

Field separator

=item * B<delim>

Synonym for I<fieldSep>

=item * B<escape>        (string) ""

Character used to escape others, typically
backslash (C<\>, d92) or escape (C<\e>, 0d27).
On input a generous range of escapes is expanded (there is presently
no way to disable particular case).
They are shown here, assuming I<escape> is set to backslash
(see unescapedValue() for the implementation):

    B<\a>         -- bell      (U+0007)
    B<\b>         -- backspace (U+0008)
    B<\e>         -- escape    (U+001b)
    B<\f>         -- form feed (U+000C)
    B<\n>         -- line feed (U+000A)
    B<\r>         -- return    (U+000D)
    B<\t>         -- tab       (U+0009)
    B<\0>         -- null      (U+0000)
    B<\\>         -- backslash (U+005C)
    B<\777>       -- 3-digit octal character code points
    B<\xFF>       -- 2-digit hexadecimal character code points
    B<\uFFFF>     -- 4-digit hexadecimal character code points
    B<\UFFFFFFFF> -- 8-digit hexadecimal character code points
    B<\x{F...}>   -- n-digit hexadecimal character code points

=item * B<escape2hex>    (character) ""

Character used to mark hex-escapes,
such as "%" for URI-style escapes. This applies after I<escape>.

=item * B<header>        (boolean) 0

Is record 1 a header with field names?

=item * B<nlInQuotes>    (boolean) 0

Allow newline in quotes?
B<Note>: With this option, you must read records via
I<readRecord>(); using normal Perl reads will of course not get
the multiple physical records that make up one logical record.
If this option is I<not> set, the library still checks for unbalanced
quotes, and issues a warning if found.

=item * B<qdouble>       (boolean) 0

Can embedded quotes be expressed by doubling them? Default: off.
If I<escape> is also set, it takes precedence over I<qdouble>.

=item * B<quote>         (string)  "\""

The character used to quote more complex field values (particularly those
containing the I<fieldSep> character, or newlines if I<nlInQuotes> is in effect.

=item * B<tableSep>      (boolean) ""

Start a whole new table on seeing this.
(unused) (not yet fully supported).

=back


=head3 Options for JSON format

=over

=item * B<jsonArray>     (boolean) 0

Should the JSON top level object be an array, or a hash?

=back


=head3 Options for Manchester OWL format

=over

=item * B<classField>    (name) "Type"

Treat the specified field as the "Class" (this matters when converting other
data to Manchester, since the name "Class" is special in OWL).

=back


=head3 Options for MIME format

=over

(none)

=back

=head3 Options for PERL format

=over

(none)

=back

=head3 Options for SEXP format

=over

(none; may add choice of alist vs. list, or SXML support)

=back

=head3 Options for XML format

The "XML" format here supports XML structurally like (X)HTML tables,
except that you can change tag names. I<readRecord> reads up to the
next end-tag for the I<trTag> value (default: "tr"). Parsing is overly
simplistic, but better if you use I<readAndParseRecord>
instead of I<readRecord> followed by I<parseRecord>.
HTML is somewhat supported, but you're better off running the data through
C<tidy> or similar first.

=over

=item * B<htmlTag>, B<tableTag>, B<theadTag>, B<tbodyTag>,
B<trTag>, B<tdTag>, B<thTag>.

These options can be used to replace the default HTML element type names
for XML input and output. In general, tags set to "" will be ignored/omitted.

=item * B<attrFields>    (string) ""

A whitespace-separated list of XML attribute names. These attribute
(regardless of what elements they occur on), will be treated as additional
fields, with the same names. An obviously useful one could be C<href>.

For input, if such attributes occur on multiple elements within a "record"
(in effect, within a table row), then the result is undefined.
Probably you'll get the last one.

For output, there is no way to put certain fields into attributes
rather than cell-like elements (yet).
This option may be extended to allow specifying an element name, child number,
or associtated C<class> attribute value (for example, C<h1@class>).

=item * B<idAttr>        (string) "id"

Use this name for ID attributes generated for output XML.
See I<idValue>, which must be set for this to have any effect.

=item * B<idValue>       (string) ""

If not "", turns on generation of ID attributes for each output row in XML.
The attribute name is taken from I<idAttr>, while I<idValue> specifies
where to get the value:

=over

=item * if it is a field name, that field's value will be used
(and that field will not be written out as a regular field);

=item * if it is a token ending in "*", the "*" will be replaced by
the row number in the table (counting from 1), and the result will be used
as the ID.

=back

=item * B<classAttr>     (name) "class"

Specifies the attribute of the "td" (field) elements,
onto which the field-name will be put (typically, this is so HTML table
output gets C<td> elements distinguished by a separate C<class> value
for each column, rather than being undistinguished.
If this is set to "", use field-names as the I<element type names> for fields
(instead of just using C<td> or the I<tdTag> value).

=item * B<colspecs>      (boolean) 0

Generate HTML table COL elements?
For this to be very useful, you'll probably want to use I<setFieldPosition>().
The column specifications can include width and alignment. You can also
use the I<classAttr> option to put field names in as class attributes on
cells, and use that to hook up style definitions.

=item * B<entityWidth>   (int) 5

Minimum digits to write for numeric character references, as an integer.

=item * B<entityBase>    (10|16) 16

Base for writing numeric character references, as an integer.

=item * B<HTMLEntities>  (boolean) 0

Use HTML entity names when applicable? (not yet supported)

=item * B<publicId>      (string) ""

Write out a DOCTYPE declaration, with this PUBLIC id, and
with the document type name taken from I<htmlTag>.

=item * B<systemId>      (string) ""

Write out a DOCTYPE declaration, with this SYSTEM id, and
with the document type name taken from I<htmlTag>.

=item * B<XMLEntities>   (boolean) 1

Use the 5 XML built-in entities (if turned off, then
use numeric character references even for escaping those 5 characters).

=item * B<XMLDecl>       (boolean) 0

Write out an XML Declaration.

=back


=head3 Options for XSV

=over

=item * B<typeCheck>     (boolean) 0

Check conformity to any datatypes
that are declared in the XSV <Head> (see L<XmlTuples.pm> for details).

=back


=head1 Methods

Each format-support package inherits from TFormatSupport.
It may inherit methods from there, and it overrides at most these methods:

    new()
    isOkFieldName(fname)         (usually just inherits)
    readAndParseHeader()
    readRecord()                 (usually just inherits)
    parseRecordToArray(s)        (usually just inherits)
    parseRecordToHash(s)
    assembleRecordFromArray()
    assembleField()
    assembleComment()
    assembleRecordFromHash()     (usually just inherits)
    assembleHeader()             (usually just inherits)
    assembleTrailer()            (usually just inherits)

These can all be reached via the C<TabularFormats> API, which generally
forwards them down to the format-support package currently in use,
except readAndParseHeader(), for which the C<TabularFormats> wrapper also
checks and fixes field names, and defines the named fields.
See the documentation there for how to use them.


=head1 Supported formats, with examples

Whitespace below (other than line-breaks)
has been inserted just for readability, and is not required
except where specially noted.
These examples are provisional, while I work out the details.


=head2 ARFF

This is the I<Attribute-Relation File Format> form for the C<WEKA> ML tookit
(see "References", below).

A logical data record in ARFF is just a physical line.
No comments.

This format begins with a multi-line C<@RELATION> section (the header),
The fields are called "attributes", and declare a name and
a datatype chosen from:

=over

=item * C<NUMERIC> -- real or integer numbers.
C<INTEGER> and C<REAL> are synonyms for C<NUMERIC>.

=item * C<STRING> -- single- or double-quoted if the value contains
spaces and/or commas (and/or curly braces?) How to put a single and/or double
quote inside a field delimited by double and/or single quotes, is unclear.
This script will fail for fields that contain I<both> kinds of quotes.

=item * C<< DATE [<format>] >> -- the format is optional, and defaults to
ISO 8601 combined form: C<yyyy-MM-dd'T'HH:mm:ss>. The ARFF documentation
is unclear whether the square and/or pointy-brackets are literal.
Formats supported are those of Java's C<SimpleDateFormat> class (see
L<http://docs.oracle.com/javase/1.4.2/docs>)

=item * C<{ name1, name2,... }> -- a "nominal-specification" or enum.
Values can contain spaces (and commas?), but then must be quoted.
Values are defined to be case-sensitive (though that doesn't matter
merely for parsing).

=back

Data follows, after a line beginning C<@DATA>, and is essentially a CSV.
Field values must be (single- or double-) quoted if they contain spaces
(or presumably commas).
Spaces outside of quotes are discarded.
C<?> is reserved for "missing values" (probably a literal "?" can be
expressed by quoting?).

There is a "sparse" data format as well, where each sparse record is enclosed
in curly braces (presumably, that also means values must be quoted if they
contain curly braces). For example:

    { 1 John, 3 MA }

The values inside sparse ARFF records are pairs, consisting of a field
number (counting from 0!) and a value (fields not specified are 0, not "?".
This script accepts but never generates sparse format.
Weka itself has a bug dealing with field 0 in sparse format.
This script has a bug dealing with commas within quotes in ARFF.

Example:

  % Signers data
  %
  @RELATION DeclarationOfIndependence

  @ATTRIBUTE Fname        STRING
  @ATTRIBUTE LName        STRING
  @ATTRIBUTE State        { PA, MA, RI, DE, NH, VT, VA }

  @DATA
  John,      Adams,      MA
  Benjamin,  Franklin,   PA
  John,      Hancock,    MA
  Stephen,   Hopkins,    RI
  Andries,   'van Dam',  RI


=head2 COLUMNS

Fixed column-oriented layout. To use this, you'll need to call
I<setFieldPosition>() to define column placements.

A logical data record in COLUMNS is just a physical line.
No comments allowed, although I<header> can be set.
Whitespace I<does> matter in COLUMNS format.

  Fname     LName      State
  John      Adams      MA
  Benjamin  Franklin   PA
  John      Hancock    MA
  Stephen   Hopkins    RI
  Andries   van Dam    RI


=head2 CSV

A wide variety of record/field delimited file formats, such as
CSV and TSV. "CSV" data varies in:

    the choice of delimiter character,
    repeatability of the delimiter (usually only for space),
    whether spaces are ignored (especially at start of record)
    whether fields can be quoted (or I<must> be),
    whether and how quotes can appear within quotes,
    whether newlines can appear within quotes,
    whether the first records is a header giving field names,
    and so on.

A logical record in CSV is a physical line unless I<nlInQuotes> is set,
in which case newlines can appear inside quotes as part of the data.
No comments are typically allowed, though this script does support them
if needed (see I<setOption>()).

For example, with I<fieldSep> set to "," and I<quote> to "\"":

  Id, Fname, LName, State
  Signer01, John, Adams, MA
  Signer02, Benjamin, Franklin, PA
  Signer03, John, Hancock, MA
  Signer04, Stephen, Hopkins, RI
  Signer05, Andries, "van Dam", RI


=head2 JSON

Javascript Object Notation, commonly used for passing
program data structures around.

A logical data record in JSON is essentially
a Javascript expression with balanced (), [], and/or {}.
Quoted contents doesn't count toward balancing.
JSON does not formally allow comments, although some implementations do,
as does the potentially dangerous but common technique of simply "eval()'ing"
a JSON expression in JavaScript. This script will ignore
physical lines in JSON that match /^\s*\/\/).

  { "Table": [
    "Signer01": {"Fname":"John",     "LName":"Adams",    "State":"MA" }
    "Signer02": {"Fname":"Benjamin", "LName":"Franklin", "State":"PA" }
    "Signer03": {"Fname":"John",     "LName":"Hancock",  "State":"MA" }
    "Signer04": {"Fname":"Stephen",  "LName":"Hopkins",  "State":"RI" }
    "Signer05": {"Fname":"Andries",  "LName":"van Dam",  "State":"RI" }
  ]}


=head2 Manchester

The Manchester OWL (Web Ontology Language) format is
used by C<Protege> and some other C<RDF> applications
(see "References" below).
This script only supports The Manchester "IndividualFrame" item,
for assigning Class, SubClassOf, and Facts to the individuals.
As with XML, JSON, and some others, this represents a
"least common denominator" subset, comparable to CSV and its kin.

A logical data record in Manchester is here defined (for now) as an
item which extends from wherever the input stream is at, up to
just before the next I<frame> keyword: "Individual:", "Datatype:", etc.
Full-line comments are discarded, but not part-line comments.

  # Some OWL data in Manchester format.
  # For TabularFormats, the "Prefix" and "Class" items are discarded.
  #
  Prefix: : http://www.example.org/mystuff
  Class: Signer
      SubClassOf: owl:Thing
  Individual: Signer01
    Types: Signer
    Facts: Fname John, LName Adams, State MA
  Individual: Signer02
    Types: Signer
    Facts: Fname Benjamin, LName Franklin, State PA
  Individual: Signer03
    Types: Signer
    Facts: Fname John, LName Hancock, State MA
  Individual: Signer04
    Types: Signer
    Facts: Fname Stephen, LName Hopkins, State RI
  Individual: Signer05
    Types: Signer
    Facts: Fname Andries, LName "van Dam", State RI


=head2 MIME

MIME mail header form (incomplete).
See L<RFC 1521>, L<RFC 2045>, L<RFC 822>.
Uses I<label:>-prefixed fields (with continuation lines indented), and
a blank line (only) before each entire record. For example:

    Name: Alexander
       the Great
    Nationality: Greek

A logical data record in MIME is a series of physical lines, up to a blank line.
Each "record" in this case is treated as comparable to a mail message,
with each field expressed by a header line (and possibly continuation lines,
which must be indented). No comments are allowed.

  Id:    Signer01
  Fname: John
  LName: Adams
  State: MA

  Id:    Signer02
  Fname: Benjamin
  LName: Franklin
  State: PA

  Id:    Signer03
  Fname: John
  LName: Hancock
  State: MA

  Id:    Signer04
  Fname: Stephen
  LName: Hopkins
  State: RI

  Id:    Signer05
  Fname: Andries
  LName: van
      Dam
  State: RI

This script does not insert headers such as MIME-Version, Content-Type,
Content-Transfer-Encoding, etc. (though perhaps it should, optionally).


=head2 PERL

This is mainly for output. It produces PERL source code that creates
an array (one element per record) of references to hashes (which map from
field names to values).
All the field names, and all non-numeric values, are quoted as strings.
You should be able to just paste this into a PERL program and then access
the data easily.

A logical data record in PERL input is here considered to be everything up to
the next unquoted/non-comment semicolon
(slightly simplper than PERL reality, but fairly close).
Comments run from any unquoted "#" to end of line.
For output, each "record" begins a new physical line.

  # Some data.
  #
  my @foo = (
      ( "Fname" => "John",
        "LName" => "Adams",
        "State" => "MA",
      ),
      ( "Fname" => "Benjamin",
        "LName" => "Franklin",
        "State" => "PA",
      ),
      ( "Fname" => "John",
        "LName" => "Hancock",
        "State" => "MA",
      ),
      ( "Fname" => "Stephen",
        "LName" => "Hopkins",
        "State" => "RI",
      ),
      ( "Fname" => "Andries",
        "LName" => "van Dam"",
        "State" => "RI",
      ),
  );


=head2 SEXP

S-Expressions should be familiar from LISP, Scheme, and their kin.
They are supported in two flavors: association lists vs. plain lists.
Field names and values are quoted (single left only if they consist only
of alphanumerics; otherwise double enclosed):

A logical data record in SEXP is data up to and including the balancing ")".
Parentheses inside quotes do not count toward balancing.
The final ")" may occur at mid-line; later data on that line is part of
the next SEXP. Physical lines matching /^\s*;/ are ignored (comments).

See also C<sexp2xml>, which is similar but also handles a variety of
additional features used in Penn TreeBank files.

 ; My data as an S-expression
 ;
 (
  ('Table
   ('Signer01 ('Fname . 'John)     ('LName . 'Adams)    ('State . 'MA))
   ('Signer02 ('Fname . 'Benjamin) ('LName . 'Franklin) ('State . 'PA))
   ('Signer03 ('Fname . 'John)     ('LName . 'Hancock)  ('State . 'MA))
   ('Signer04 ('Fname . 'Stephen)  ('LName . 'Hopkins)  ('State . 'RI))
   ('Signer05 ('Fname . 'Andries)  ('LName . "van Dam") ('State . 'RI))
  )

  (
   ('Signer01 'John     'Adams    'MA)
   ('Signer02 'Benjamin 'Franklin 'PA)
   ('Signer03 'John     'Hancock  'MA)
   ('Signer04 'Stephen  'Hopkins  'RI)
   ('Signer05 'Andries  "van Dam" 'RI)
  )
 )

I<SXML> syntax (see L<"References">)
is a variation on SEXP that is not yet supported.


=head2 XML

(X)HTML or XML table or table-like markup.
Elements for each record and field and field values in content.
HTML table tags are used by default, but tag names can be changed.
Attributes are not presently used for fields
(except see I<idAttr>, I<idValue>, and I<classAttr>), though this
is a desirable addition.

A logical data record in XML is here defined as an
entire <tr> element (or another name, if I<trTag> has been
changed from the default). I<readRecord> returns other things in SAX-like units
(tags, comments, text, etc.)

  <?xml encoding="utf-8" version="1.0"?>
  <html>
  ...
  <table>
    <tr Class="MySigner" id="Signer01">
      <td class="Fname">John</td>
      <td class="LName">Adams</td>
      <td class="State">MA</td>
    </tr>
    <tr Class="MySigner" id="Signer02">
      <td class="Fname">Benjamin</td>
      <td class="LName">Franklin</td>
      <td class">State">PA</td>
    </tr>
    <tr Class="MySigner" id="Signer03">
      <td class="Fname">John</td>
      <td class="LName">Hancock</td>
      <td class="State">MA</td>
    </tr>
    <tr Class="MySigner" id="Signer04">
      <td class="Fname">Stephen</td>
      <td class="LName">Hopkins</td>
      <td class="State">RI</td>
    </tr>
    <tr Class="MySigner" id="Signer05">
      <td class="Fname">Andries</td>
      <td class="LName">van Dam</td>
      <td class="State">RI</td>
    </tr>
  </table>
  ...

I plan to add options to allow you to switch to other popular schemas
in one step (rather than setting the tag names individually), and
to provide for treating chosen XML attributes also as fields.
I don't anticipate supporting column or row spans here at all
(though see my C<xml2tab> for some support).

  HTML     Docbook   NLM      TEI     CALS
  ----------------------------------------
  TABLE    table     table    table   table
  COLGROUP           colgroup
  COL      colspec            @rend   colspec
  THEAD    thead     thead    head
  TBODY    tbody     tbody
  TFOOT              tfoot            tfoot
  TR       row       tr       row     row
  TD       entry     td       cell    entry
  TH       entry     th       cell    entry
  CAPTION            caption
  @CLASS                      @role


=head2 XSV

XSV is a very simple subset
of XML, limited to about the same functionality as CSV, ARFF, etc.
It does, however, support datatype checking,
as well as default values, C<HTML>-like "BASE" factoring,
and a few other options that can save a great deal of space.
It is supported via its own package, C<XmlTuples.pm>.

Every XSV data set is a Well-Formed XML document (so can be processed
by perfectly normal XML software). However, not all WF XML documents
are XSV. In other words, XSV supports a subset of XML.

An XSV document has a single <Head> element, or a sequence of <Head> elements
contained in a single <Xsv> element (which may have Dublin Core attributes).
A <Head> in turn contains any number of (empty) <Rec> (record) elements,
with an attribute for each field.
XML comments are also allowed.
Each tag and comment must begin on a new physical line
(this is permitted but by no means required in XML).

The <Head> element lists the attributes (fields) that are permissible for
the <Rec> elements it contains. The value of each attribute on <Head>
(possibly just ""),
is the default for the like-named attribute on contained <Rec> elements,
except that if the value begins with "#" it specifies a datatype,
one of the XSD built-in ones, or a few others such as enums.
See C<XmlTuples.pm> for details.

For example:

  <!-- Some signers of the Declaration of Independence.
       List created: March 15, 1066 A.D.
    -->
  <Xsv creator="george@wasington.gov" title="The Framers">
  <Head  Id="#NMTOKEN" Fname="#string" LName="John"
         State="" DOB="#date">
    <Rec Id="Signer01" Fname="John"     LName="Adams"    State="MA" />
    <Rec Id="Signer02" Fname="Benjamin" LName="Franklin" State="PA" />
    <Rec Id="Signer03"                  LName="Hancock"  State="MA" />
    <Rec Id="Signer04" Fname="Stephen"  LName="Hopkins"  State="RI" />
    <Rec Id="Signer05" Fname="Andries"
         LName="v&aacute;n Dam" State="RI" />
  </Head>
  </Xsv>


=head1 Managing options

=over

=item * B<addOptionsToGetoptLongArg>I<(hashRef, prefix?)>

Add all of this package's options to the hash at I<hashRef>, in the form
you would pass to Perl's C<Getopt::Long> package. The options will be set
up to store their values directly to the TabularFormats instance, via
the I<setOption>() method.

If I<prefix> is defined,
it will be added to the beginning of each option name; this allows you
to avoid name conflicts with the caller, or between multiple instances of
TabularFormats (for example, one for input and one for output).

If an option is already present in the hash (note that the key, as always
for C<Getopt::Long>, includes aliases and suffixes like "=s"), a warning is
issued and the new one replaces the old.

=back


=head1 Known bugs and limitations

=over

=item * Not safe against UTF-8 encoding errors. Use C<iconv> if needed.

=item * Leading spaces on records are not reliably stripped.

=item * The I<ASCII> option is supported for JSON, Perl, XML, and XSV.
For some other formats it is not clear how to escape non-ASCII characters.
ARFF appears to have no such method at all.
MIME headers use I<quoted-printable> form, but support for full Unicode is not
yet finished.

=item * Support for decoding HTML entity references is implemented but
commented out; to use it, uncomment things starting C<HTML::Entities>
and install the eponymous CPAN package.

=item * Datatype checking is experimental.

=item * The behavior if using regexes rather than strings for I<fieldSep>,
I<quote>, I<comment>, etc. for CSVs is undefined.
Most likely it will work ok for input, but not for output.

=item * The behavior if a given field is found more than once in an input
record is undefined. This is only possible with some formats (essentially
those that identify fields by name, not position). Some options
may be added for this, perhaps taking the first or last, or concatenating
them with some separator, or serializing them somehow.

=item * B<ARFF> (WEKA) support has a few bugs: It may fail to parse records
that contain commas. Quoted fields that contain both single- and double-quotes
will likely fail for both input and output.

=item * B<COLUMNS>: widths can end up undefined if the caller uses
I<setFieldPosition>() and omits it, and defines columns in an order other
than right-to-left.

=item * B<CSV>: using both C<quote> and C<escape> may get unhappy.
In particular, the behavior of \"" and \\" are undefined.
Perhaps options I<qdouble> and/or I<nlInQuotes> should default on.

=item * B<JSON>: No exponential notation. No control for whether
output records are enclosed as an array or a dictionary.

=item * B<Manchester>: barely implemented (but see I<xml2tab>).

=item * B<MIME>: experimental, and has no support for internal
structure within MIME lines. Perhaps it should use Multipart?

=item * B<SEXP>: sub-types/options are not yet implemented.

=item * B<XML>: Plain HTML is not yet supported; only XHTML
(use C<tidy> if needed).
ID-related options can generate an ID attribute from a specified
field. However, that field will still be generated as a table column, too.
Support for getting/putting fields from/to attributes is experimental
(see the I<attrFields> option).

=back


=head1 References

L<http://weka.wikispaces.com/ARFF> "ARFF".

L<http://tools.ietf.org/html/rfc4180> --
"Common Format and MIME Type for Comma-Separated Values (CSV) Files".

L<http://www.json.org/> --
"Introducing JSON".

L<http://www.w3.org/TR/owl2-manchester-syntax/>) --
Matthew Horridge and Peter F. Patel-Schneider.
"OWL 2 Web Ontology Language: Manchester Syntax."
W3C Working Group Note, 27 October 2009.

L<http://www.oasis-open.org/specs/tm9901.html> --
(OASIS) "XML Exchange Table Model Document Type Definition".

L<http://cran.r-project.org/doc/manuals/R-data.pdf> --
"R Data Import/Export".

L<http://en.wikipedia.org/wiki/SXML> --
(Wikipedia article on) "SXML".

L<http://search.cpan.org/~msergeant/XML-Parser-2.36/Parser.pm> --
(CPAN documentation for XML::Parser).


=head1 History

# Original, 2010-03-23 by Steven J. DeRose, as csvFormat.pm
#     (many changes/improvements).
# 2012-03-30 sjd: Rename to TabularFormats.pm, major reorg.
# 2013-02-11 sjd: Split format-support packages and doc out to here.
# 2013-04-02f sjd: Lose setFieldNamesFromArray() calls, let TabularFormats.pm
#     do in parseHeader() and readAndParseHeader(). Work on -qdouble, speed
#     up parsing of noquote, noescape fields, better tracing/warnings.
# 2013-04-23 sjd: Add 'qstray' option. Kind of weird... Fix inf loop on
#     last field.
# 2013-05-14 sjd: Fix a few undef-handling bugs.


=head1 To do

#     Move each pkg to own file; move format-specific options to format-files.
#     Get rid of specialReader notion; make everybody go through our reader.
#         Handle blank records better (integrate readRealLine).
#     Finish readAndParseHeader for rest of formats.
#     Switch XML support to use XML::Parser, HTML::Parser, etc.
#
#     Option to write JSON arrays vs. dicts.
#     Option to parse XML attribute values as subfields.
#     Way to control order of writing fields where it doesn't matter:
#         xml, xsv (done?), json, mime
#     Integrate sjdUtils::unbackslash.
#
# Format-specific:
#     See what formats may have integrable CPAN libs:
#         ARFF:  ARFF::Util
#         COLS:  Parse::FixedLength
#         JSON:  JSON
#         Manch:
#         MIME:  MIME::QuotedPrint
#         OWL:   OWL::DirectSemantics::Element::NamedIndividual,
#                OBO::Parser::OWLParser, OWL::Simple::Parser,
#                RDF::YAML, RDF::Simple::Parser, RDF::Notation3::XML
#         SEXP:  Data::SExpression.
#         PBUF:  Google::ProtocolBuffers
#     COLUMNS: add fixFieldWidths() to setFieldPosition().
#     COLUMNS: how to pass in column positions?
#     COLUMNS: support reorderings in assembleRecordFromArray()
#     Manchester: Manage additional keywords per tupleset.
#     Manchester: add options for TypeName(s), SuperClass, ID,
#         inclusions. Implement header, prettyPrint.
#     Manchester, XML: finish readAndParseHeader().
#     SEXP: Option re. use/escaping of []. SXML. Option for (define 'x (
#     XML: support tag@attr values with attrFields?
#     XML: Select elements by QGI@, hand back list of children of each???
#
# Low priority:
#     Way to get the original offset/length of each field in record?
#     Improve handling of missing/extra/duplicate fields.


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.


=cut


###############################################################################
# List of supported formats
#
my @bt = qw/ARFF COLUMNS CSV JSON MIME Manchester PERL SEXP XSV XML/;
my $btExpr = join("|",@bt);

# SAX (XML parser) events (just the ones we actually generate)
#
my %saxEvents = (
    "Init"    => 1,
    "Fin"     => 1,
    "Start"   => 1,
    "End"     => 1,
    "Text"    => 1,
    "Default" => 1,
    );


###############################################################################
# Methods in TFormatSupport are only reached by inheritance onto a specific
# format object (from one of the packages below). Below are the "default"
# implementations for those methods, when nothing specific to the format
# needs to override. A few are truly virtual, and *must* be overridden.
#
#
sub new { # TFormatSupport
    alogging::vMsg(0, "Don't try to construct a 'TFormatSupport' object.");
    return(undef);
}

sub tfWarn {
    my ($self,$level, $m1, $m2) = @_;
    if (!$m1) { $m1 = ""; }
    if (!$m2) { $m2 = ""; }
    $self->{lastMessage} = $m1.$m2;
    alogging::vMsg($level,$m1,$m2);
}

sub tfError {
    my ($self,$level, $m1, $m2) = @_;
    if (!$m1) { $m1 = ""; }
    if (!$m2) { $m2 = ""; }
    $self->{lastMessage} = $m1.$m2;
    #sjdUtils::setUtilsOption("locs",4);
    alogging::eMsg($level,"TF::".$m1,$m2);
    ($level<0) && die "TF: Error is fatal.\n";
}

sub getLastMessage {
    my ($self) = @_;
    return($self->{lastMessage});
}

sub getOption { # TFormatSupport
    my ($self, $name) = @_;
    return($self->{dopt}->getOption($name));
}

sub isOkFieldName { # TFormatSupport
    my ($self, $fn) = @_;
    ($fn) || return(0);
    return(($fn =~ m/^\p{isAlpha}\w*$/) ? 1:0);
}
sub cleanFieldName { # TFormatSupport
    my ($self, $fn) = @_;
    $fn =~ s/\W/_/g;
    if ($fn =~ m/^\P{isAlpha}/) { $fn = "A_$fn"; }
    return($fn);
}

sub readAndParseHeader { # TFormatSupport
    my ($self) = @_;
    die "Call to virtual TFormatSupport method readAndParseHeader().\n";
}
sub readRecord { # TFormatSupport
    my ($self) = @_;
    die "Call to virtual TFormatSupport method readRecord().\n";
}

sub getFieldsHash { # TFormatSupport
    my ($self) = @_;
    return($self->{dcur}->getFieldsHash()); # A hash reference
}
sub getFieldsArray { # TFormatSupport
    my ($self) = @_;
    my @fields = ("");
    for (my $i=1; $i<=$self->{dsch}->getNSchemaFields(); $i++) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        $fields[$i] = (defined $fDef) ? $fDef : "";
    }
    return(\@fields);
}

# The heavy lifting
#
sub parseHeader { # TFormatSupport
    my ($self, $rec) = @_;
    $self->{dsrc}->seek(0,0);
    ($rec) || return(undef);
    $self->tfWarn(1,"TF::parseHeader for '$rec'");

    my @fieldNames = @{$self->parseRecordToArray($rec, "HEADER")};
    if (!@fieldNames) {
        $self->tfError(0,"TF::parseHeader: got nil for: ", $rec);
        return(undef);
    }
    shift @fieldNames; # Don't call addField() for unused [0].
    $self->tfWarn(1, "  TF::parseHeader: ", "(" . join(", ", @fieldNames) . ")");

    for my $name (@fieldNames) {
        $self->tfWarn(1, "    TF::parseHeader: Adding ", "'$name'");
        $self->{dsch}->appendField($name);
    }
    return(\@fieldNames);
}

sub parseRecordToArray { # TFormatSupport
    my ($self, $rec) = @_;

    if (!$rec || $rec =~ m/^\s*$/) {
        return(undef);
    }
    if ($self->getOption("comment") &&
        $rec =~ m/$self->getOption("comment")/) {
        return(undef);
    }
    $rec =~ s/[\n\r]+$//;

    if ($self->getOption("stripStart")) { $rec =~ s/^\s+//; }

    my $aHash = $self->parseRecordToHash($rec);
    # Switch to just use getFieldsArray?
    my @fields = ("");
    for (my $i=1; $i<=$self->{dsch}->getNSchemaFields(); $i++) {
        my $fName = $self->{dsch}->getFieldName($i);
        if (defined $aHash->{$fName}) {
            $fields[$i] = $aHash->{$fName};
        }
        else {
            $fields[$i] = ""; # Use nilValue?;
        }
    }
    return(\@fields);
} # parseRecordToArray

sub parseRecordToHash { # TFormatSupport
    my ($self, $rec) = @_;
    die "Call to virtual TFormatSupport method.\n";
} # parseRecordToHash

sub postProcessFields { # final (?)
    my ($self, $fieldHashRef) = @_;
    (ref($fieldHashRef) eq "HASH") || $self->tfError(
        0, "TF::postProcessFields: Not passed a hash ref.");
    for my $name (keys(%{$fieldHashRef})) {
        my $fDef = $self->{dsch}->getFieldDefByName($name);
        my $fValue = $fieldHashRef->{$name};
        if ($self->getOption("stripFields")) {
            $fValue =~ s/^\s*(.*)\s*$/$1/g;
        }
        if ($fDef->{fCallback}) {
            $fValue = $fDef->{fCallback}->($fValue);
        }
        if ($fDef->{fSplitter}) { # sub-fields to array
            my @subfields = split($fDef->{fSplitter}, $fValue);
            $fValue = \@subfields;
        }
        $fieldHashRef->{$name} = $fValue;
    } # for each field
    return($fieldHashRef);
} # postProcessFields


###############################################################################
# Output formatting stuff (VIRTUAL)
#
sub assembleRecordFromArray { # TFormatSupport
    my ($self, $aRef) = @_;
    die "In assembleRecordFromArray stub in TFormatSupport -- must override.\n";
}

sub assembleRecordFromHash { # TFormatSupport
    my ($self, $hRef) = @_;
    if (!$hRef) { $hRef = $self->{fields}; }
    my @fieldData = ("");
    my $nf = $self->{dsch}->getNSchemaFields();
    for (my $i=1; $i<=$nf; $i++) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        $fieldData[$i] = $hRef->{$fDef->{fName}};
    }
    return($self->assembleRecordFromArray(\@fieldData));
}

sub assembleField { # TFormatSupport
    my ($self, $fDef, $value) = @_;
    die "In assembleField stub in TFormatSupport -- must override.\n";
}

sub assembleComment { # TFormatSupport
    my ($self, $text) = @_;
    if (!$text) { $text = ""; }
    my $com = $self->getOption("comment");
    return (($com) ? "$com $text" : "");
}

sub assembleHeader { # TFormatSupport
    my ($self) = @_;
    return("");
}

sub assembleTrailer { # TFormatSupport
    my ($self) = @_;
    return("");
} # assembleTrailer


###############################################################################
#
# Following packages implement various specific formats.
# They all inherit from TFormatSupport (above).
# TabularFormats will instantiate a particular one as needed.
#
###############################################################################


###############################################################################
# ARFF (used for input to WEKA NLP system)
# See http://www.cs.waikato.ac.nz/~ml/weka/arff.html
# Doc says carriage returns, but I think WEKA doesn't care.
# Doc doesn't say what to do if a literal comma or CR is needed.
#
package formatARFF;
our @ISA = ('TFormatSupport');

sub new { # ARFF
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;
    my $self = {
        dsrc    => undef,
        dsch    => undef,
        dcur    => $dcur,
        dopt    => undef,
    };
    $self->{dopt}->setOption("comment", "%");
    bless $self, $class;
    return $self;
}

sub readAndParseHeader { # ARFF
    my ($self) = @_;
    my $relName = "";
    my $recnum = 0;
    my @lines = ();
    my @fieldNames = ("");
    while (my $rec = $self->{dsrc}->readline()) {
        $recnum++;
        if ($rec =~ m/^\s*%/) {                        # Comment
            next;
        }
        elsif ($rec =~ m/^\s*$/) {                     # Blank
            next;
        }
        elsif ($rec =~ m/^\s*\@RELATION\s*(.*)\s*$/i) {# @RELATION
            $self->tfWarn(1, "ARFF readAndParseHeader: got RELATION");
            $relName = $1;
        }
        elsif ($rec =~ m/^\s*\@ATTRIBUTE/i) {          # @ATTRIBUTE
            $rec =~ m/^\s*\@ATTRIBUTE\s+(\w+)\s*(.*)\s*$/;
            my ($name, $type, $junk) = ($1, $2);
            if (!$1 || !$2) {
                $self->tfWarn(
                    0, "ARFF: Syntax error in ATTRIBUTE, line $recnum of ARFF file.");
                next;
            }
            push @fieldNames, $name;
            $self->appendField($name);
            my $dt = "String";
            if ($type =~ m/\{(.*)\}/) {                # 'nominal'
                $dt = "X-Enum[$1]";
            }
            elsif (uc($type) eq "STRING") {            # string
                $dt = "String";
            }
            elsif (uc($type) eq "NUMERIC") {
                $dt = "Float";
            }
            elsif ($type =~ m/^DATE/) {                # date [format]
                $dt = "Date";
            }
            $self->setFieldDatatype($name, $dt);
            $self->tfWarn(1, "ARFF readAndParseHeader: ATTRIBUTE $name: $dt");
        }
        elsif ($rec =~ m/^\s*\@DATA/i) {               # @DATA
            $self->tfWarn(1, "ARFF readAndParseHeader: got DATA (so done)");
            last;
        }
        else {
            $self->tfWarn(0, "ARFF Syntax error, line $recnum of ARFF file.");
        }
    } # read til @DATA
    alogging::vMsg(0, "ARFF readAndParseHeader is not finished.");
    return(\@fieldNames);
} # readAndParseHeader ARFF

sub readRecord { # ARFF
    my ($self) = @_;
    my $rec = $self->{dsrc}->readline();
    return($rec);
}


### NOTE: Fails if there's a quoted comma!
#
sub parseRecordToHash { # ARFF
    my ($self, $rec) = @_;
    my $fields = {};
    if ($rec =~ s/^\s*\{//) {                     # "Sparse" ARFF format
        for my $f (split(/,\s*/,$rec)) {
            ($f =~ m/^\s*}/) && last;
            $f =~ m/^(\d+)\s+(.*)/;
            if (!$2) {
                $self->tfError(0,"ARFF Bad sparse format record:\n  $rec");
                return(undef);
            }
            my $i = $1; my $value = $2;
            if ($value eq "?") {
                $fields->{$self->{dsch}->getFieldName($i+1)} = undef;
            }
            else {
                $value =~ s/^\s*['"](.*)['"]\s*$/$1/;
                $fields->{$self->{dsch}->getFieldName($i+1)} = $value;
            }
        }
    }
    else {                                        # Regular ARFF format
        my $i = 1;
        for my $value (split(/,\s*/,$rec)) {
            if ($value eq "?") {
                $fields->{$self->{dsch}->getFieldName($i++)} = undef;
            }
            else {
                $value =~ s/^\s*['"](.*)['"]\s*$/$1/;
                $fields->{$self->{dsch}->getFieldName($i++)} = $value;
            }
        }
    }
    $fields = $self->postProcessFields($fields);
    return($fields);
}

sub assembleRecordFromArray { # ARFF
    my ($self, $aRef) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $buf = "";
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->getFieldObjectByNumber($i);
        $buf .= $self->assembleField($fDef,$aRef->[$i]) . ",";
    }
    $buf =~ s/,$//;
    return($buf);
}

sub assembleField { # ARFF
    my ($self, $fDef, $value) = @_;
    if (!$value) {                           # Reserved ARFF 'missing value'
        $value = "?";
    }
    if (ref($value) eq "ARRAY") {
        $value = join($fDef->{fJoiner}, @{$value});
    }
    if ($value =~ m/[?,\s{}]/) {        # Needs quoting
        if ($value =~ m/'/) {
            $value = '"' . $value . '"';
        }
        else {
            $value = "'" . $value . "'";
        }
    }
    return($value);
}

sub assembleHeader { # ARFF
    my ($self,$relationName) = @_;
    my $cr = "\r";
    my $buf = "\@RELATION $relationName$cr";
    for my $i (1..$self->{dsch}->getNSchemaFields()) {
        my $fiRef = $self->getFieldObjectByNumber($i);
        my $f = $fiRef->{fName};
        if ($f =~ m/\s/) { $f = '"' . $f . '"'; }
        my $dt = $fiRef->{fDataType};
        if ($self->{dt}->isNumericDatatype($dt)) { $dt = "NUMERIC"; }
        elsif ($dt eq "Date") { $dt = "DATE"; }
        else { $dt = "STRING"; }
        $buf .= sprintf("\@ATTRIBUTE %-24s %s$cr", $fiRef->{fName}, $dt);
    }
    return("$buf$cr");
}



###############################################################################
###############################################################################
# COLUMNS column formats
#
package formatCOLUMNS;
our @ISA = ('TFormatSupport');

sub new { # COLUMNS
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;
    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
    };
    bless $self, $class;
    return $self;
}

sub readRecord { # COLUMNS
    my ($self) = @_;
    my $rec = $self->{dsrc}->readline();
    return($rec);
}

sub parseRecordToHash { # COLUMNS
    my ($self, $rec) = @_;
    my $fields = {};
    my $nf = $self->{dsch}->getNSchemaFields();
    for (my $i=1; $i<=$nf; $i++) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        my $start = $fDef->{fStart};
        my $width = $fDef->{fWidth};
        my $widthAvailable = length($rec) - $start;
        if ($widthAvailable < 1) { last; }
        if ($widthAvailable<$width) {
            $width = $widthAvailable;
        }
        $fields->{$fDef->{fName}} = substr($rec,$start,$width);
    }
    $fields = $self->postProcessFields($fields);
    return($fields);
}

sub assembleRecordFromArray { # COLUMNS
    my ($self, $aRef) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $recWidth = $self->{starts}->[-1] + $self->{widths}->[-1];
    my $buf = "";
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        if (length($buf) > $self->{starts}->[$i]) {
            $self->tfError(0, "COLUMNS Column problem assembling record");
        }
        my $pad = $self->{starts}->[$i] - length($buf);
        if ($pad>0) { $buf .= " " x $pad; }
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        $buf .= $self->assembleField($fDef, $aRef->[$i]);
    }
    return($buf);
}

sub assembleField { # COLUMNS
    my ($self, $fDef, $value) = @_;

    if (ref($value) eq "ARRAY") {
        $value = join($fDef->{fJoiner}, @{$value});
    }
    my $w = $fDef->{fWidth};
    if ($w && length($value) > $w) {         # truncate
        $self->tabWarn(1, "Value too long: '$value'");
        $value = substr($value, 0, $w);
    }
    return($fDef->align($value));
}

sub howManyHaveSizes { # COLUMNS-specific
    my ($self) = @_;
    my $nOK = 0;
    my $nf = $self->{dsch}->getNSchemaFields();
    for (my $i=1; $i<=$nf; $i++) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        if ($fDef->{fStart} && $fDef->{fWidth}) { $nOK++; }
    }
    return($nOK);
}



###############################################################################
###############################################################################
# CSV: Comma, tab, and other similarly-delimited files.
#
package formatCSV;
our @ISA = ('TFormatSupport');

BEGIN {
    my ($fs, $q, $e, $qd) = undef;

    sub setupDelims {
        my ($self) = @_;
        $fs = $self->getOption("fieldSep");
        $e  = $self->getOption("escape");
        $q  = $self->getOption("quote");
        $qd = $self->getOption("qdouble");
    }

sub new { # CSV
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;

    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
    };
    bless $self, $class;
    return $self;
}

# Note: The header parse assumes there are no weird features like quoted delims.
# This is true even if the corresponding options are set.
#
sub readAndParseHeader { # CSV
    my ($self) = @_;
    if (!$self->{dopt}->getOption("header")) {
        return(undef);
    }
    $self->setupDelims();
    my $headerRecord = $self->readRecord();
    alogging::vMsg(1, "Header rec (quote '$q'): $headerRecord.");

    my @fieldNames = split($self->getOption("fieldSep"), $headerRecord);
    unshift @fieldNames, "";
    for (my $i=1; $i<scalar(@fieldNames); $i++) {
        (my $quotes = $fieldNames[$i]) =~ s/[^$q]+//g;
        if (length($quotes) % 2 == 1) {
            alogging::vMsg(1, "CSV: Header rec seems to have unbalanced quotes or " .
                "fieldSep in quotes near '" . $fieldNames[$i] . "'.");
        }
        $fieldNames[$i] =~ s/^\s*$q(.*)$q\s*$/$1/;
    }
    return(\@fieldNames);
}

sub readRecord { # CSV
    my ($self) = @_;
    my $rec = "";
    if (!$self->getOption("nlInQuotes")) {
        #alogging::vMsg(0, "readRecord(CSV), calling ds");
        $rec = $self->{dsrc}->readline();
        if (defined $rec &&
            $self->getOption("quote") &&
            !$self->areQuotesUnbalanced($rec)) {
            alogging::vMsg(0, "Unbalanced quotes -- forgot -nlInQuotes?\n$rec");
        }
    }
    else {
        alogging::vMsg(0, "readRecord(CSV), calling readToBalancedQuotes-XXX");
        #$rec = $self->readToBalancedQuotes();
    }
    #alogging::vMsg(0, "  readRecord(CSV) got: '$rec'");
    if ($rec) {
        chomp $rec;
        if ($self->getOption("stripRecords")) { # @@@ cf readline()
            $rec =~ s/\s+$//;
            $rec =~ s/^\s+//;
        }
    }
    return($rec);
} # readRecord CSV

# Read enough physical records so that we end up with balanced quotes, which
# should mean we then have one logical record.
#
# ### ==> can this be done just with the fancy DataSource reads?
#
sub readToBalancedQuotes { # CSV-specific
    my ($self) = @_;
    my $rec = $self->{dsrc}->readline();
    (defined $rec) || return(undef);

    my $nextPart = "";
    my $nParts = 1;
    while (!$self->areQuotesUnbalanced($rec)) {
        $nParts++;
        if (!($self->getOption("nlInQuotes"))) {
            $self->tfError(0,"CSV Unbalanced quotes, and -nlInQuotes is off: " .
                sjdUtils::showInvisibles($rec));
            #return($rec);
        }
        (defined($nextPart = $self->{dsrc}->readline())) ||
            $self->tfError(0,"CSV Unbalanced quotes at EOF.");
        $rec .= $nextPart;
    }
    return($rec);
}

# Check whether a buffer has an even number of real quotes.
# What *should* be the interpretation of \"" ?
# ### BUG: Miscounts if you have \\"!
#
sub areQuotesUnbalanced { # CSV-specific
    my ($self, $rec) = @_;

    my $q = $self->getOption("quote");
    my $e = $self->getOption("escape");

    if ($rec !~ m/$q/) {                     # No quotes, therefore ok
        return(1);
    }
    if ($self->getOption("qdouble")) {       # Nuke doubled quotes
        $rec =~ s/$q$q//g;
    }
    if ($e) {                                # Nuke escaped quotes
        $rec =~ s/$e$q//g;
    }
    $rec =~ s/[^$q]//g;                      # Nuke all but remaining quotes
    return((length($rec) % 2) ? 0:1);        # Even number?
}

sub parseRecordToArray { # CSV
    my ($self, $rec) = @_;
    my $aRef = $self->parseCSVRecordToArray($rec);
    return($aRef);
}

# Up top, parseRecordToArray is implemented by calling parseRecordToHash first.
# BUT for CSV, it's the reverse. So this method calls the very special parser needed
# to support all the wacky variations on CSV that one might see.
#     For now, the called has to set options to say what kind of CSV it is. It would
#     be nice to sniff it out, but of course that couldn't be completely certain.
#
sub parseRecordToHash { # CSV
    my ($self, $rec, $isHeader) = @_;
    $self->setupDelims();
    # This call should also define the fields:
    my $aRef = $self->parseCSVRecordToArray($rec, $isHeader); # special...
    if (ref($aRef) ne "ARRAY") {
        $self->tfError(0,"CSV parseRecordToHash: parse to array failed.");
        return(undef);
    }

    my $fields = {};
    my $nf = scalar(@{$aRef}) - 1;
    for (my $i=1; $i<=$nf; $i++) {
        #my $fdef = $self->{dsch}->getFieldName($i);
        my $fname = $self->{dsch}->getFieldName($i, "RECOVER");
        if (!$fname) {
            $self->tfError(0,"CSV parseRecordToHash: no name for field #$i.");
            $fname = sprintf("F_%03d", $i);
        }
        $fields->{$fname} = $aRef->[$i];
    }
    $fields = $self->postProcessFields($fields);
    return($fields);
} # parseRecordToHash [CSV]

# Parse a CSV record into an array of fields ([0] empty). However, if the
# record has no quote or escape characters (including when none are defined),
# just do a quick Perl split() instead.
#
# Some cases:
#      foo,bar,baz
#      ,,baz                            leading empty fields
#      foo,,                            trailing empty fields
#      foo,   bar   ,baz                whitespace
#        foo,bar,baz                    leading whitespace
#      foo,bar,baz___                   trailinging whitespace
#      foo,"bar",baz                    -quote
#      foo,"bar,bar",baz                fieldSep in quotes
#      foo,,baz                         empty field
#      foo,"",baz                       empty quote
#      foo,"bar""bar""bar",baz          qdouble
#      foo,"bar\"bar",baz               escaped quote
#      foo,"bar\,bar",baz               escaped fieldSep
#      foo,"bar\\bar",baz               escaped escape
#      foo,"bar\\",baz                  escaped escape before real quote
#      foo,\"bar,baz                    leading escaped quote
#      foo,"bar\"",baz                  escaped quote before real quote
#      foo,"ba"r, baz                   partially quoted field (???)
#
sub parseCSVRecordToArray { # CSV-specifica
    my ($self, $rec, $isHeader) = @_;
    $self->setupDelims();
    my $aRef = undef;
    if (($q && index($rec, $q) >= 0) ||
        ($e && index($rec, $e) >= 0)) {
        $aRef = $self->parseCsvRecord2($rec);
    }
    else { # Trivial, so use faster method
        # split() doesn't include trailing empty fields, so add " "!!!
        my @fields = split(/$fs/, "$rec ");
        unshift @fields, ""; # force empty field [0]
        $aRef = \@fields;
    }

    my $nFieldsKnown = $self->{dsch}->getNSchemaFields();
    my $nFieldsFound = scalar(@{$aRef}) - 1;

    # If it's the header, define the fields; else check there aren't too many.
    if ($isHeader || $nFieldsKnown<=0) {  # Define the fields
        for (my $i=1; $i<=$nFieldsFound; $i++) {
            my $name = ($isHeader) ? $aRef->[$i] : sprintf("F_%03d",$i);
            $self->{dsch}->addField($name, $i);
            #$self->tfError(0, "Defining CVS field #$i as '$name.");
        }
        my $check = $self->{dsch}->getNSchemaFields();
        if ($check != $nFieldsFound) {
            $self->tfError(
                0, "Fields known is $check, but defined $nFieldsFound.");
        }
    }
    elsif ($nFieldsFound > $nFieldsKnown) {
        $self->tfError(0, sprintf(
            "CSV parseRecordToArray: Found %d fields, expected %d.",
                           $nFieldsFound, $nFieldsKnown));
    }
    return($aRef);
} # parseCSVRecordToArray

sub parseCsvRecord2 { # CSV-specific
    my ($self, $orig) = @_;
    chomp $orig;
    my $rec = $orig;
    $self->tfWarn(1,"\n***CSV parseCsvRecord2 for ", "'$rec'");

    if ($self->getOption("stripRecords")) { # @@@ cf readline()
        $rec =~ s/^\s+//;
        $rec =~ s/\s+$//;
    }

    my @fields = ();

    # Parse and remove one field on each iteration
    while ($rec) {
        #warn "\n  Rec: <<$rec>>\n";
        my $nextSep = index($rec, $fs);
        my $nextE   = ($e) ? index($rec, $e) : -1;
        my $nextQ   = ($q) ? index($rec, $q) : -1;
        my $f = undef;

        if ($nextSep<0) {                                   # Last field
            $f = $rec;
            $rec = "";
        }
        elsif ($nextSep==0) {                               # Empty field
            $f = "";
            $rec = substr($rec,1);
        }
        elsif (my $rcq = $self->findRealCloseQuote($rec)) { # quo/esc
            $f = substr($rec, 0, $rcq+1);
            my $toShow = $rcq + 8;
            if ($toShow > length($rec)) { $toShow = -1; }
            #warn sprintf("\nrcq: %3d in %s...\n" .
            #             "            %s\n",
            #             $rcq, substr($rec,0,$toShow), (" " x $rcq) . "^");
            #warn "    F: <<$f>>\n";
            $f   = $self->unquote($f);
            #warn "    F: <<$f>> (unquoted).\n";
            $rec = substr($rec, $rcq+1);
            $rec =~ s/^\s*$fs//;
        }
        else {                                              # No quo/esc
            $f   = substr($rec, 0, $nextSep);
            $rec = substr($rec, $nextSep+1);
        }

        if (!defined $f) {                                  # FAIL
            $self->tfError(0,"CSV: Unparseable field at: ", "'$rec'");
            $f = $rec;
            $rec = "";
        }

        #######################################################################
        if ($e) { $f = $self->unescape($f); }
        push @fields, $f;

        #$self->tfWarn(
        #    2, "  CSV: Field [" . scalar(@fields) .
        #    "] '$f'\n    Rest: '" . sjdUtils::showInvisibles($rec) . "'");
    } # $rec

    return(\@fields);
} # parseCsvRecord2

sub findRealCloseQuote {
    my ($self, $s) = @_;

    my @chars = split(//,$s); # Faster for utf-8

    # Get past leading space and opening quote
    my $i=0;
    while (($chars[$i] eq " ") ||
           ($chars[$i] eq "\t" && $fs ne "\t")) {
        $i++;
    }
    ($chars[$i] eq $q) || return(undef);
    $i++;

    # Scan to unescaped undoubled q
    while ($i<scalar(@chars)) {
        if ($e && $chars[$i] eq $e) {             # escape
            $i += 2;
        }
        elsif ($qd && $chars[$i] eq $q            # qdouble
               &&   $chars[$i+1] eq $q) {
            $i += 2;
        }
        elsif ($chars[$i] eq $q) {                # real close quote
            return($i);
        }
        else {
            $i++;
        }
    }
    return(undef);
}

sub unquote {
    my ($self, $s) = @_;
    ($s && $q && index($s,$q)>=0) || return($s);
    $s =~ s/^\s*$q//;
    $s =~ s/$q\s*$//;
    return($s);
}

### needs some repairs...
#
sub unescape { # CSV-specific
    my ($self, $s, $oldway) = @_;

    my $e = $self->getOption("escape");
    if (!$e || index($s,$e)<0) { return($s); }

    $s =~ s/$e([0-7]{3,3}|x..|x\{.*?\}u....|U........|.)/{
                $self->unescapedValue($1); }/ge;

    if ($self->getOption("escape2hex")) {
        $s =~ s/$e([0-9a-f][0-9a-f])/{ chr(hex($1)); }/eig;
    }
    return($s);
} # unescape

sub unescapedValue { # Decode one backslash code
    my ($self, $seq) = @_;

    # mnemonics
    if (length($seq) == 1) {
        if ($seq eq "a") { return("\a"); } # bell
        if ($seq eq "b") { return("\b"); } # backspace
        if ($seq eq "e") { return("\e"); } # escape
        if ($seq eq "f") { return("\f"); } # form feed
        if ($seq eq "n") { return("\n"); } # line feed
        if ($seq eq "r") { return("\r"); } # carriage return
        if ($seq eq "t") { return("\t"); } # tab
        if ($seq eq "0") { return("\0"); } # null
        if ($seq eq "\e"){ return("\e"); } # backslash
        return($seq);
    }

    # numerics
    if ($seq =~ m/([0-7]{3,3})/)        { return(chr(octal($1))); }
    if ($seq =~ m/x([0-9a-xA-X]{2,2})/) { return(chr(hex($1)));   }
    if ($seq =~ m/x\{([0-9a-xA-X]+\})/) { return(chr(hex($1)));   }
    if ($seq =~ m/u([0-9a-xA-X]{4,4})/) { return(chr(hex($1)));   }
    if ($seq =~ m/U([0-9a-xA-X]{8,8})/) { return(chr(hex($1)));   }

    return($seq);
} # unescapedValue

sub assembleRecordFromArray { # CSV
    my ($self, $aRef) = @_;
    alogging::vMsg(2, "In assembleRecordFromArray[CSV]");
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $nAvail = scalar(@{$aRef}) - 1;
    my $nf = $self->{dsch}->getNSchemaFields();
    if ($nf<1) {
        $self->tfError(0, "CSV Field count: no fields in schema.");
        $nf = scalar(@{$aRef});
    }
    elsif ($nf != $nAvail) {
        $self->tfError(0, "CSV Field count: expected $nf, passed " .
            "$nAvail.");
        if ($nf > $nAvail) { $nf = $nAvail; }
    }

    my $buf = "";
    for my $i (1..$nf) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        ($fDef) || alogging::vMsg(0, "Can't find fDef for field #$i");
        alogging::vMsg(2,"assembleRecordFromArray found " .
            (defined $aRef->[$i]) ? $aRef->[$i] : "*UNDEF*");
        my $f = $self->assembleField($fDef, $aRef->[$i]);
        #alogging::vMsg(0, "  $i: '" . sjdUtils::showInvisibles($f) . "'");
        $buf .=  $f . $fs;
    }
    my $rs = $self->getOption("recordSep");
    $buf =~ s/$fs$/$rs/;
    return($buf);
} # assembleRecordFromArray CSV

sub assembleField { # CSV
    my ($self, $fDef, $value) = @_;
    if (!defined $value) {
        $self->tfError(0,"CSV Undefined field value for '" .
                        $fDef->{fName} . "' in assembleField [CSV].");
        $value = "";
    }

    # Gather relevant delims
    $self->setupDelims();
    my $rs = $self->getOption("recordSep");

    if (ref($value) eq "ARRAY") {
        $value = join($fDef->{fJoiner}, @{$value});
    }

    if ($value =~ m/$q/ && !$e && !$qd) {            # Oops!
        $self->tfWarn(
            0, "CSV Quote(s) in field '" . $fDef->{fName} .
            "', but no escape or qDouble. Quote(s) deleted.");
        $value =~ s/"//g;
    }

    if ($e) {                                        # Escape stuff?
        $value =~ s/$e/$e$e/g;
        $value =~
            s/$self->getOption("fieldSep")/$e$self->getOption("fieldSep")/g;
        $value =~ s/$q/$e$q/g;
    }
    elsif ($q && $qd) {                              # '""' for '"'?
        $value =~ s/$q/$q$q/g;
    }
    if ($e && !$self->getOption("nlInQuotes")) {     # \\n?
        my $en = $e . "n";
        $value =~ s/(\r\n|\r|\n|$rs)/$en/g;
    }

    if ($value =~ m/($q|$fs|$rs)/) {                 # Quote it all?
        $value = $q . $value . $q;
    }
    return($value);
} # assembleField CSV

sub assembleHeader { # CSV
    my ($self) = @_;
    my @names = @{$self->{dsch}->getFieldNamesArray()};
    $self->tfWarn(
        1, "CSV assembleHeader: calling assembleRecordFromArray " . "[inc 0]: ('" .
        (scalar(@names) ? join("',  '",@names) : "???") . "')");
    my $buf = $self->assembleRecordFromArray(\@names);
    return($buf);
} # assembleHeader CSV

# Try to guess at a likely CSV fieldSep character, given a sample record.
# Could also look at the char following close quotes...
# Should also be able to try /\s+/
#
# ### Who should call us?
#
sub sniffDelim { # CSV-specific
    my ($self, $rec) = @_;
    my $copy = $rec;
    $copy =~ s/"[^"]*"/0/g;             # Nuke quoted field values
    $copy =~ s/[\\\e].//g;              # Nuke escaped chars
    #$self->tfWarn(1,"CSV sniff: reduced to '$copy'");

    my @candidates = (
        ",",   "\t",   ":",   ";",   "\\s+",
        "|",   "!",    "@",   "#",   "/");

    my $bestChar = undef;
    my $bestCount = 0;
    for my $c (@candidates) {
        my $cCount = scalar(split(/$c/, $copy));
        if ($cCount > $bestCount) {
            $bestChar = $c;
            $bestCount = $cCount;
        }
    }
    return($bestChar);
} # sniffDelim CSV

} # END



###############################################################################
###############################################################################
# JSON
#
package formatJSON;
our @ISA = ('TFormatSupport');

sub new { # JSON

    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;

    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
    };
    $self->{dopt}->setOption("comment", "//");
    bless $self, $class;
    return $self;
}

sub isOkFieldName { # JSON
    my ($self, $fn) = @_;
    if ($fn =~ m/^[_\p{isAlpha}][-_.:\w]*$/) { return(1); }
    return(0);
}

sub readRecord { ### JSON
    my ($self) = @_;
    my $rec = $self->{dsrc}->readBalanced(
        "([{", ")]}", '"', 0, "", "//");
    # $rec = sjdUtils::unbackslash($rec);
    return($rec);
}

sub parseRecordToHash { # JSON
    my ($self, $rec) = @_;
    my $fields = {};
    $self->tfError(-1,"JSON parseRecordToHash not yet implemented.");
    $fields = $self->postProcessFields($fields);
    return($fields);
}

sub assembleRecordFromArray { # JSON
    my ($self, $aRef) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $buf = "{ ";
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        $buf .= $self->assembleField($fDef,$aRef->[$i]) .
            (($i<$nf) ? ",":"");
    }
    return($buf . "\n}\n");
}

sub assembleField { # JSON
    my ($self, $fDef, $value) = @_;
    if (ref($value) eq "ARRAY") {
        my $buf = "";
        for my $part (@{$value}) {
            $buf .= sjdUtils::escapeJSON(
                $part, $self->getOption("ASCII")) . ", ";
        }
        $buf =~ s/,\s*$//;
        $value = "[ " . $buf . " ]";
    }
    elsif ($value !~ m/^\s*[-+]?\d+(\.\d+)?(E[-+]?\d+)?\s*$/) {
        $value = '"' . sjdUtils::escapeJSON(
            $value, $self->getOption("ASCII")) . '"';
    }
    else {
        $value = sjdUtils::escapeJSON($value, $self->getOption("ASCII"));
    }
    my $buf = " { \"$fDef->{fName}\":$value }";
    if ($self->getOption("prettyPrint")) {
        $buf = "\n   $buf";
    }
    return($buf);
}

sub assembleHeader { # JSON
    my ($self) = @_;
    return("{ \"Table\": [");
}

sub assembleTrailer { # JSON
    my ($self) = @_;
    return("] }\n");
}



###############################################################################
###############################################################################
# MIME (headers) -- also useful for some simple outline-ish formats.
#
package formatMIME;
our @ISA = ('TFormatSupport');

sub new { # MIME
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;

    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
        lookAhead => undef,
    };

    bless $self, $class;
    return $self;
}

# d33 to d126 except colon (d58), per RFC822
sub isOkFieldName { # MIME
    my ($self, $fn) = @_;
    if ($fn =~ m/^[!-9;-~]+$/) { return(1); }
    return(0);
}

# For MIME header format, a Record is everything up to a blank line or EOF,
# and a Field is a label line plus any following indented lines.
#
sub readRecord { # MIME
    my ($self) = @_;
    my $buf = undef;
    while (defined(my $line = $self->{dsrc}->readline())) {
        if ($buf =~ m/^\s*$/) { last; }
        $buf .= $line;
    }
    return($buf);
}

sub readField { # MIME
    my ($self) = @_;
    my $buf = undef;
    if (defined $self->{lookAhead}) {
        $buf = $self->{lookAhead};
        $self->{lookAhead} = undef;
    }
    else {
        $buf = $self->{dsrc}->readline();
    }
    while (defined($self->{lookAhead} = $self->{dsrc}->readline())) {
        if ($self->{lookAhead} =~ m/^\S/) { last; }
        $buf .= $self->{lookAhead};
        $self->{lookAhead} = undef;
    }
    return($buf);
}

sub parseRecordToHash { # MIME
    my ($self, $rec) = @_;
    my $fields = {};
    my $name = $self->{dsch}->getFieldDefByNumber(1)->{fName};
    my $value = "";
    for my $line (split(/\n/, $rec)) {
        if ($line !~ m/^\s/) {          # New field
            $line =~ s/^(.*?):\s*//;
            $fields->{$name} = $value;
            $name = $1;
            $value = $line;
        }
        else {                          # Continuation
            $value .= $line;
        }
    }
    $fields->{$name} = $value;
    $fields = $self->postProcessFields($fields);
    return($fields);
}

### Wrap to 80 columns?
sub assembleRecordFromArray { # MIME
    my ($self, $aRef) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $buf = "";
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        my $fVal = $self->assembleField($fDef,$aRef->[$i]);
        if ($fVal ne "" || !$self->getOption("omitDefaults")) {
            $buf .= $self->assembleField($fDef,$aRef->[$i]) . "\n";
        }
    }
    return($buf . " \n");
}

sub assembleField { # MIME (RFC 822 et al)
    my ($self, $fDef, $value) = @_;

    if (ref($value) eq "ARRAY") {
        $value = join($fDef->{fJoiner}, @{$value});
    }
    my $buf = $fDef->{fName} . ":" . $value;
    my $maxLen = $self->getOption("lineLength");
    my $buf2 = "";
    while ($maxLen>0 && length($buf) > $maxLen) {
        my $sp = rindex(substr($buf,0,$maxLen-1), " ");
        if ($sp < 0) { $sp = $maxLen-1; }
        $buf2 .= substr($buf,0,$sp) . "\r\n ";
        $buf = substr($buf,$sp);
    }
    $buf2.= $buf;
    if ($self->getOption("ASCII") && $buf2 =~ m/[^[:ascii:]]/) {
        # Need to get utf-8 bytes first....
        #use MIME::QuotedPrint;
        #$buf2 = encode_qp($buf2);
        $buf2 =~ s/([^[:ascii:]])/{ sprintf("=%02d",ord($1)); }/ge;
    }
    return($buf2);
}

sub assembleHeader { # MIME
    my ($self) = @_;
    my $buf = "MIME-Version: 1.0\n";
    return($buf);
}



###############################################################################
###############################################################################
# Manchester OWL (RDF-related)
#
package formatManchester;
our @ISA = ('TFormatSupport');

sub new { # Manchester
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;
    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
        frameExpr => "\\b(Individual|Datatype|Class|" .
                      "ObjectProperty|AnnotationProperty):",
    };
    bless $self, $class;
    return $self;
}

sub isOkFieldName { # Manchester
    my ($self, $fn) = @_;
    if ($fn =~ m/^[_\p{isAlpha}][-_.:\w]*$/) { return(1); }
    return(0);
}

sub readAndParseHeader { # Manchester
    my ($self) = @_;
    return(undef);
    die "TF::readAndParseHeader[Manchester]: not finished.\n";
}

sub readRecord { ### Manchester
    my ($self) = @_;
    my $buf = "";
    $self->tfWarn(0,"Manchester readRecord: Experimental.");
    while (defined(my $nextPart = $self->{dsrc}->readline())) {
        ($nextPart =~ m/^\s*#/) && next; # comment
        if ($nextPart =~ m/^(.*?)($self->{frameExpr})/) { # stop
            my $keep = ($1) ? $1:"";
            $buf .= $keep;
            $self->{dsrc}->pushback(substr($nextPart,length($keep)));
            last;
        }
        $buf .= $nextPart;
    }
    return($buf);
}

sub parseRecordToHash { # Manchester
    my ($self, $rec) = @_;
    my $fields = {};
    die "Manchester parseRecordToHash not implemented.\n";
    $fields = $self->postProcessFields($fields);
    return($fields);
}

sub assembleRecordFromArray { # Manchester
    my ($self, $aRef) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $buf = "";
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        $buf .= $self->assembleField($fDef,$aRef->[$i]);
    }
    return($buf . " \n");

}

sub assembleField { # Manchester
    my ($self, $fDef, $value) = @_;
    if (ref($value) eq "ARRAY") {
        $value = join($fDef->{fJoiner}, @{$value});
    }
    if ($value =~ m/['()\s]/) {
        $value = '"' . $value . '"';
    }
    my $f = " " . $fDef->{fName} . ": " . $value;
    return($f);
}

sub assembleHeader { # Manchester
    my ($self) = @_;
    return("");
}




###############################################################################
###############################################################################
# PERL structure inits (mainly meant for output...).
#
package formatPERL;
our @ISA = ('TFormatSupport');

sub new { # PERL
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;
    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
    };
    $self->{dopt}->setOption("comment", "#");
    bless $self, $class;
    return $self;
}

sub isOkFieldName { # PERL
    my ($self, $fn) = @_;
    if ($fn =~ m/^[_\p{isAlpha}]\w*$/) { return(1); }
    return(0);
}

sub readRecord { # PERL
    my ($self) = @_;
    my $rec = $self->{dsrc}->readToUnquotedDelim(
        ";",        # ending expr
        "'\"",      # quote chars
        0,          # qdouble?
        "\\",       # escape?
        "#");       # comment
    return($rec);
}

sub parseRecordToHash { # PERL
    my ($self, $rec) = @_;
    $rec = s/^\s*\{//;
    $rec = s/\}\s*\$//;

    my @pairs = split(/\s*,\s*/, $rec);
    my $fields = {};
    for my $pair (@pairs) {
        my ($name, $value) = spit(/\s*=>\s*/, $pair);
        $name = $self->deQuote($name);
        $value = $self->deQuote($value);
        $fields->{$name} = $value;
    }
    $fields = $self->postProcessFields($fields);
    return($fields);
}
sub deQuote { # PERL-specific
    my ($self, $s) = @_;
    $s =~ s/^\s*//;
    $s =~ s/\s*$//;
    $s =~ s/^['"](.*)['"]$//;
    return($s);
}

sub assembleRecordFromArray { # PERL
    my ($self, $aRef) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $buf = "  ( ";
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        $buf .= $self->assembleField($fDef, $aRef->[$i]) . ",\n";
    }
    $buf .= "  ),\n";
    return($buf);
}

sub assembleField { # PERL
    my ($self, $fDef, $value) = @_;
    my $fName = $fDef->{fName};
    if (ref($value) eq "ARRAY") {
        $value = "(" . join(", ", @{$value}) . ")";
    }
    if ($value !~ m/^[-+]?\d+(\.\d+)?(E[-+]\d+)?/) {
        $value =~ s/([\\"])/\\$1/g;
        if ($self->getOption("ASCII")) {
            $value =~ s/([^[:ascii:]])/{ sprintf("\u%04d", ord($1)); }/ge;
        }
        $value = '"' . $value . '"';
    }
    my $buf = "    \"$fName\"\t=> $value";
    return($buf);
}

sub assembleHeader { # PERL
    my ($self) = @_;
    return("my \@foo = (\n");
}

sub assembleTrailer { # PERL
    my ($self) = @_;
    return("    \n);\n");
}



###############################################################################
###############################################################################
# LISP/Scheme-like S-expressions
#
package formatSEXP;
our @ISA = ('TFormatSupport');

sub new { # SEXP
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;
    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
    };
    $self->{dopt}->setOption("comment", ";");
    bless $self, $class;
    return $self;
}

sub isOkFieldName { # SEXP
    my ($self, $fn) = @_;
    if ($fn =~ m/^[_\p{isAlpha}][-_.:\w]*$/) { return(1); }
    return(0);
}

sub readRecord { # SEXP
    my ($self) = @_;
    my $buf = $self->{dsrc}->readBalanced(
        "(", ")", "\"", 0, "", ";");
    return($buf);
}

sub parseRecordToHash { # SEXP
    my ($self, $rec) = @_;
    my $fields = {};
    $rec =~ s/^\s*\(+(.*)\)+\s*$/$1/;
    my @pairs = split(/\)\s*\(/, $rec);
    for my $pair (@pairs) {
        $pair =~ m/\s*(\w+)\s+'(.*)'/;
        $fields->{$1} = $2;
    }
    $fields = $self->postProcessFields($fields);
    return($fields);
}

sub assembleRecordFromArray { # SEXP
    my ($self, $aRef) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $buf = "(" . $self->getOption("trTag");
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        $buf .= " " . $self->assembleField($fDef, $aRef->[$i]);
    }
    $buf .= ")\n";
    return($buf);
}

sub assembleField { # SEXP
    my ($self, $fDef, $value) = @_;
    my $fName = $fDef->{fName};
    my $buf = "";
    if (ref($value) eq "ARRAY") {
        $buf = "(";
        for my $v (@{$value}) {
            if ($v =~ m/['()\s]/) { $v = '"$v"'; }
            $buf .= " $v";
        }
        $buf = ")";
    }
    elsif ($value =~ m/[^\d]/) {
        $buf = '"' . $value . '"';
    }
    else {
        $buf = $value;
    }
    my $field = "($fName $buf)";
    return($field);
}

sub assembleHeader { # SEXP
    my ($self) = @_;
    my $buf = "(SEXP ";
    return($buf);
}

sub assembleTrailer { # SEXP
    my ($self) = @_;
    return(")\n");
}



###############################################################################
###############################################################################
# XML *tables* of (X)HTML-like structure.
# The tag names can be changed by options, however.
#
package formatXML;
our @ISA = ('TFormatSupport');

sub formatXML::new { # XML
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;

    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
    };
    $self->{dopt}->setOption("comment", "<!--");
    bless $self, $class;
    return $self;
}

sub formatXML::isOkFieldName { # XML
    my ($self, $fn) = @_;
    if ($fn =~ m/^[_\p{isAlpha}][-_.:\w]*$/) { return(1); }
    return(0);
}

sub formatXML::readAndParseHeader { # XML
    my ($self) = @_;
    return(undef);
    die "TF::readAndParseHeader[XML]: unfinished.\n";
}

# This will read an entire 'tr' (or equivalent) element if it's at one.
# Otherwise it will just read whatever is next (tag, comment, pi, etc.)
#
sub formatXML::readRecord {
    my ($self) = @_;
    $self->tfError(-1, "XML readRecord not yet supported.");
    my $buf = "";
    my $ender = "</" . $self->getOption("trTag") . ">";
    while (defined (my $newPart = $self->{dsrc}->readline())) {
        if ((my $loc = index($buf, $ender)) >= 0) {
            $self->{dsrc}->pushback(substr($newPart, $loc+length($ender)));
            $buf .= substr($newPart, 0, $loc+length($ender)-1);
            last;
        }
        $buf .= $newPart;
    }
    return($buf);
}

# Very rudimentary so far.
# Perhaps should be smart enough to skip to first <tr>?
#
sub formatXML::parseRecordToHash { # XML
    my ($self, $rec) = @_;
    my $fields = {};
    my $fbuf = "";
    my $i = 0;

    my @tagStack = ();
    my @attrStack = ();

    while ($rec) {
        if ($rec =~ m/^<?/) {                            # PI
            $rec =~ s/<\?.*?\?>//;
        }
        elsif ($rec =~ m/^<!--/) {                       # COMMENT
            $rec =~ s/<!--.*?-->//;
        }
        elsif ($rec =~ m/^<!\[CDATA\[/) {                # MS
            $rec =~ s/^<!\[CDATA\[.*?]]>//;
        }
        elsif ($rec =~ m/^<!/) {                         # DCL
            $rec =~ s/^<!.*?>//;
        }
        elsif ($rec =~ m/^&#/) {                         # Ent Ref
            $rec =~ s/^&#(x?)([0-9a-f]+);//;
            my $base = $1 ? 16:10;
            my $code = $2 ? $2 : 26; # ASCII SUB
            $code = ($base==16) ? hex($code):$code;
            $fbuf .= chr($code);
        }
        elsif ($rec =~ m/^<\//) {                        # End tag
            $rec =~ s/^<\/(.*?)\s*>//;
            if ($1 && $1 eq $self->getOption("recordSep")) {
                last;
            }
            my $gi = $tagStack[-1];
            if ($gi =~ m/^(td|th)$/) {
                $attrStack[-1] =~ m/\sclass\s*=\s*"([^"]*)"/i; # '' too?
                if ($1) { $gi = $1; }
            }
            $fields->{$gi} = $fbuf;
            $fbuf = "";
            pop @tagStack;
            pop @attrStack;
        }
        elsif ($rec =~ m/^</) {                          # Start tag
            $rec =~ s/^<(\w+)(\s+.*?)?>//;
            push @tagStack, $1;
            push @attrStack, $2;
            if (my $afList = $self->getOption("attrFields")) {
                $self->handleAttrFields($attrStack[-1], $afList);
            }
        }
        elsif ($rec =~ m/^[<&]/) {
            $self->tfError(1,"XML Syntax error in data");
            $rec =~ s/^.//;
        }
        else {                                           # Text
            $rec =~ s/^([^<&]+)//;
            $fbuf .= $1;
        }
    } # while anything left

    if ($fbuf) {
        $fields->{$tagStack[-1]} = $fbuf;
        $fbuf = "";
    }

    $fields = $self->postProcessFields($fields);
    return($fields);
} # parseRecordToHash XML

# Pull out and store, any attribute the caller specifically requested.
# If the same attribute occurs on multiple elements in a given 'record',
# result is undefined (currently you get the last one).
#
sub formatXML::handleAttrFields { # XML-specific
    my ($self, $atts, $attrFields) = @_;
    while ($atts =~ s/^\s*([-.:\w]+)\s*=\s*('.*?'|".*?")//) {
        my ($name, $value) = ($1, $2);
        if ($attrFields =~ m/\b$name\b/) {
            $self->{fields}->{$name} = $value;
        }
    }
} # handleAttrFields XML

# Why the rownum parameter?
sub formatXML::assembleRecordFromArray { # XML
    my ($self, $aRef, $rownum) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $trTagName  = $self->getOption("trTag");     # name to use for records
    my $idAttrName = $self->getOption("idAttr");    # name to use for id attr
    my $idFName    = $self->getOption("idValue");    # field with id value,+"*"
    my $nl  = ($self->getOption("prettyPrint")) ? "\n":"";

    # Generate a row ID attribute if requested
    my $idAttr = "";
    if ($idAttrName && $idFName &&
        (my $idVal = $self->{dcur}->getFieldValue($idFName))) {
        $idVal =~ s/^\*$/$rownum/;
        $idAttr = " $idAttrName=\"$idVal\"";
    }

    # Put together the whole row
    my $buf = "<$trTagName$idAttr>";
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        my $f = $self->assembleField($fDef, $aRef->[$i]);
        $buf .= ($nl eq "") ? $f : "$nl    $f";
    }
    $buf .= "</$trTagName>$nl";
    return($buf);
} #assembleRecordFromArray XML

sub formatXML::assembleField { # XML
    my ($self, $fDef, $value) = @_;

    my $fn  = $fDef->{fName};
    my $tag = $self->getOption("tdTag") || $fn;
    my $cl  = $self->getOption("classAttr");
    my $classAtt = ($cl) ? " $cl=\"$fn\"" : "";

    my $buf = "<$tag$classAtt>";
    if (ref($value) eq "ARRAY") {
        my $j = $self->{joiner} || $self->getOption("pTag") || "p";
        (my $k = $j) =~ s/\s.*//; # Attributes (if any) only in start-tag
        for my $part (@{$value}) {
            $buf .= "<$j>" . sjdUtils::escapeXmlContent($part) . "</$k>";
        }
    }
    else {
        $buf .= sjdUtils::escapeXmlContent($value, $self->getOption("ASCII"));
    }
    $buf .= "</$tag>";
    return($buf);
} # assembleField XML

sub formatXML::assembleComment { # XML
    my ($self, $text) = @_;
    if (!defined $text) { $text = ""; }
    $text =~ s/--/- -/g;
    return("<!--$text-->");
}

sub formatXML::assembleHeader { # XML
    my ($self) = @_;
    my $nl = ($self->getOption("prettyPrint")) ? "\n":"";
    my $buf = "";

    if ($self->getOption("XMLDecl")) {
        $buf .= '<?xml version="1.0" encoding="utf-8"?>$nl';
    }

    if ((my $sys = $self->getOption("systemId")) ||
        (my $pub = $self->getOption("publicId"))) {
        $buf .= "<!DOCTYPE " . $self->getOption("htmlTag") .
            "$nl  PUBLIC \"$pub\" \"$sys\">$nl";
    }
    $buf .= "<" . $self->getOption("htmlTag") . ">$nl";

    $buf .= "$nl<table>$nl";
    if ($self->getOption("colspecs")) {
        my $nf = $self->{dsch}->getNSchemaFields();
        for (my $i=1; $i<=$nf; $i++) {
            my $fDef = $self->{dsch}->getFieldDefByNumber($i);
            $buf .= "  <col width=\"" . ($fDef->{fWidth}*8) . "\"";
            if ($fDef->{fAlign}) {
                $buf .= " align-\"" . $fDef->{fAlign} . "\"";
            }
            elsif ($self->{theDatatypes}->
                   isNumericDatatype($fDef->{fDatatype})) {
                $buf .= " align=\"right\"";
            }
            $buf .= " />$nl";
        }
    }
    $buf .= "<thead></thead>$nl<tbody>$nl";
    return($buf);
} # assembleHeader XML

sub formatXML::assembleTrailer { # XML
    my ($self) = @_;
    my $nl = ($self->getOption("prettyPrint")) ? "\n":"";
    my $buf = "</tbody>$nl</table>$nl$nl";
    $buf .= "</" . $self->getOption("htmlTag") . ">$nl";
    return($buf);
} # assembleTrailer XML



###############################################################################
###############################################################################
# XSV (aka XML Tuples).
#
package formatXSV;
our @ISA = ('TFormatSupport');

sub formatXSV::new { # XSV
    my ($class, $dsrc, $dsch, $dcur, $dopt) = @_;
    my $self = {
        dsrc    => $dsrc,
        dsch    => $dsch,
        dcur    => $dcur,
        dopt    => $dopt,
        xsvParser  => undef,
    };
    bless $self, $class;

    sjdUtils::try_module("XmlTuples") || die
        "TFormatSupport.pm:formatXSV:" .
        "Can't access sjd XmlTuples module (needed for XSV support).\n";

    $self->{xsvParser} = new XmlTuples();
    ($self->{xsvParser}) || $self->tfError(
        -1, "formatXSV: Couldn't create XML Tuples parser.");
    $self->{xsvParser}->setOption("verbose",sjdUtils::getUtilsOption("verbose"));
    $self->{xsvParser}->attach($dsrc);
    # read Header
    return $self;
}

sub formatXSV::isOkFieldName { # XSV
    my ($self, $fn) = @_;
    if ($fn =~ m/^[_\p{isAlpha}][-_.:\w]*$/) { return(1); }
    return(0);
}

sub formatXSV::readAndParseHeader { # XSV
    my ($self) = @_;
    ($self->{xsvParser}) || alogging::eMsg(
        -1, "XSV::readAndParseHeader: XSV parser not available.");
    my $nameArray = $self->{xsvParser}->getHeader();
    ($nameArray) || alogging::vMsg(0, "TF.XSV: Header not found.");
    return($nameArray);
}

sub formatXSV::readRecord { # XSV
    my ($self) = @_;
    # Get the next XSV record. Discards comments, blanks, xml dcls.
    #warn "In formatXSV::readRecord\n";
    my $rec = $self->{xsvParser}->readNext();
    alogging::eMsg(2, "XSV::readRecord: Got '" ,
                   (defined $rec) ? $rec:"-UNDEF-");
    return($rec);
}

sub formatXSV::parseRecordToHash { # XSV
    my ($self, $rec) = @_;
    ($self->{xsvParser}) || die
        "TF::parseRecordToHash[XSV]: No XmlTuples parser.\n";
    if (!$rec) {
        $rec = $self->{xsvParser}->readNext();
    }
    if (!$rec) {
        return(undef); # EOF
    }
    my $href = $self->{xsvParser}->getNext($rec);
    ($href) || return(undef);
    $href = $self->postProcessFields($href);
    return($href);
}

# Also available as XmlTuples::makeXSVRecord().
#
sub formatXSV::assembleRecordFromArray { # XSV
    my ($self, $aRef) = @_;
    if (!$aRef) { @{$aRef} = @{$self->getFieldsArray()}; }
    my $buf = "<Rec";
    my $nf = $self->{dsch}->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->{dsch}->getFieldDefByNumber($i);
        my $fVal = $self->assembleField($fDef, $aRef->[$i]);
        if (!$self->getOption("prettyPrint") || $i==1) {
            $buf .= " ";
        }
        elsif ($fDef->{fWidth} > length($fVal)) {
            $buf .= " " x ($fDef->{fWidth} - length($fVal) + 1);
        }
        else {
            $buf .= "\t";
        }
        $buf .= $fVal;
    } # for each field
    $buf .= " />\n";
    return($buf);
}

sub formatXSV::assembleField { # XSV
    my ($self, $fDef, $value) = @_;
    if (ref($value) eq "ARRAY") {
        $value = join($fDef->{fJoiner}, @{$value});
    }
    if ($self->getOption("omitDefaults") &&
        $value eq $fDef->{fDefault}) {
        return("");
    }
    if (!$fDef || !$fDef->{fName}) {
        $self->tfWarn(1, "TF::XSV::assembleField: Bad fDef.");
        return("");
    }
    my $buf = $fDef->{fName} . "=\"" . sjdUtils::escapeXmlAttribute(
        $value, 0, $self->getOption("ASCII")) . "\"";
    return($buf);
}

# Doesn't generate defaults of datatype constraints
#
sub formatXSV::assembleHeader { # XSV
    my ($self) = @_;
    my $fing = `finger -l $ENV{USER} | head -n 1`;
    (my $user = $fing) =~ s/.*Name:\s*//;
    chomp $user;
    my $date = sjdUtils::isoDate();
    my $buf = qq@<!-- Xsv
     Generated by TabularFormats/TFormatSupport.
  -->
<Xsv contributor="$user"
     coverage=""
     creator="$user"
     date="$date"
     description=""
     format="XSV"
     identifier=""
     language=""
     publisher=""
     relation=""
     rights=""
     source=""
     subject=""
     title=""
     type="XSV"
     >
<Head @;

    my @names = @{$self->{dsch}->getFieldNamesArray()};
    shift @names; # nuke [0]
    $buf .= join('="" ', @names) . '="">' . "\n";
    return($buf);
}

sub formatXSV::assembleTrailer { # XSV
    my ($self) = @_;
    return("</Head>\n</Xsv>");
}

# End of formatXSV package.

1;
