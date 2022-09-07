#!/usr/bin/env perl -w
#
# TabularFormats.pm: Support a variety of CSV-ish formats.
# 2006~02: Written by Steven J. DeRose.
#
# The main packages:
#     TabularFormats;
#     pull_parser;
#     ExpatNB;
#
# Data management packages:
#     TableSchema, FieldDef: Moved out to TableSchema.pm.
#     DataSource: Moved out to DataSource.pm.
#     DataOptions;
#

our %metadata = (
    'title'        => "TabularFormats.pm",
    'description'  => "Support a variety of CSV-ish formats.",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2006~02",
    'modified'     => "2021-11-11",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

*** No longer really maintained. See TabularFormat.py and fsplit.py ***

use TabularFormats;

Provide parsing and generation for basic record/field structures
in many formats. The functionality and expressiveness are
essentially that of CSV and its kin; however, many more formats
are supported for such simple data (even formats that can do more in general).

APIs are provided to request a record at a time; a whole document parsed
to build a hash or array; a Sax API that makes the data look like a simple
HTML table (whether it was or not!); and "pull" API for SAX-equivalent events.
You can also generate records in any of the formats.

With this script, fields always have names and an ordering.
Most methods can specify a field by either name or number
(numeric names are not recommended).

=head2 Formats and variations supported

The formats ("basictype"s) supported include these, which have a simple
records/fields structure:
    B<ARFF> (for WEKA system),
    B<COLUMNS> (column-oriented),
    B<CSV> (lots of variations),
    B<MIME> (headers),
    B<XSV> (a simple XML subset designed for CSV-style data).

and also the following more sophisticated formats, that
can be used in simple ways, corresponding to
a basic records/fields structure:
    B<JSON>,
    B<MANCH> (a syntax for RDF),
    B<PERL> (array or hash declaration),
    B<SEXP> (LISP/Scheme S-expression),
    B<XML> (simple cases such as an HTML or analogous table),

C<TabularFormats> is a way to move simple tabular data around!
Representing general XML, JSON, PERL data, or OWL in CSV-like formats
is awkward at best, and this script doesn't deal with data that complex.
Formats that store data as binary fields (n-byte integers and float,
packed bits, length-prefixed strings, and such) are not supported.
Special support for date/time fields is not provided.

For more details, see below under L</"Supported formats">.

=head2 Example

First instantiate this package, choosing a format by name.
Some formats have options such as delimiter choices,
tag names, etc., which can be set on the constructor call or later.
This done, start parsing records. For example:

    use TabularFormats;
    my $tf = new TabularFormats("CSV");
    $tf->setOption("fieldSep", ":");
    $tf->open($myPath) || die "Can't open file '$myPath'.\n";
    my $fieldNamesRef = $tf->readAndParseHeader();
    while (my $rec = $tf->readRecord()) {
        my $arrayRef = $tf->parseRecordToArray($rec);
        for (my $i=1; $i<=$tf->getNSchemaFields(); $i++) {
        ...}
    }

Handles information about field names,
orders, positions, and so forth in the data.
It also owns a I<FieldDef> (see next) to represent the specific of the
field in itself, rather than the fields as part of a record.
You can get a reference to it via C<getTableSchema>().

=head3 Package: package FieldDef

Used by TableSchema (q.v.) to represent each field of the input/output data..
It knows the name, datatype, preferred width and justification, and other
information about a given field, but not about it's place in the record
(re. which see I<TableSchema>, previous).

=head3 Package: DataOptions

Handles all of the (many) TabularFormats options.
If stores and retrieves them, and provides a method to add them all
to a C<Getopt::Long> setup.


=head1 TabularFormats Methods and Options

=head2 Methods for basic setup

=over

=item * B<new TabularFormats(basicType, options)>

Create a new C<TabularFormats> object, which can then be customized
for the details of your format, and used to parse and/or assemble
records. For converting between alternate formats, allocate one
C<TabularFormats> object for input and one for output, and copy
between them.

I<basicType> specifies the overall format to be used (this can also
be specified later via I<setOption('basicType', value)>.
The value must be one of the types described below under
L</"Supported formats, with examples">.


If I<options> is specified, it must be a reference
to a hash of option names => values.
The pairs will be passed to I<setOption>().
Options can also be set directly using I<setOption>().
B<Note>: I<setOption>() interprets (unescape) any backslash-codes in values.

=item * B<sniffFormat(path)>

Look at extension, the *nix C<file> command, and the start of the data,
and return a best-guess as to the file format in use. This may be C<undef>,
or a name from the list of supported formats, or such a name plus a TAB
and additional information, such as the I<fieldSep> for CSV.
If I<path> leads to a compressed file (zip, gzip, etc.), you'll get
"COMPRESSED", a TAB, and the file extension back.

=item * B<reset()>

Resets the DataSource and TableSchema objects (but not DataOptions, which
knows what format you're dealing with). This would be used when reading
a number of data collections that are in the same format.

=item * B<hasFormat(name)>

Return true iff the data format I<name> is supported.
B<Note>: This does not necessarily mean that every defined feature of the
data format is supported (or meaningful in this context). For example,
this package supports simple HTML or XML tables (simple row/column arrangements
with no spans, embedded tables, etc. etc.); but it does not support the full
generality of HTML or XML (or JSON or SEXP or...).

=item * B<chooseFormat(name)>

Set up the implementation for a particular format such as CSV, ARFF, etc.
This is also called automatically if you do I<setOption("basicType", xyz)>.

=item * B<setOption(name, value)>

Set the option I<name> to the given I<value>.
The specific options available are discussed below.
If you choose I<basicType>, then I<chooseFormat(name)> is called automatically.
B<Note>: I<setOption>() interprets (unescapes) any backslash-codes in values.
This is because it is typically called directly from getOpt::Long(), which
leaves backslashes from the user's command line intact.

=item * B<getOption(name)>

Return the current value of the option I<name>.
B<Note>: I<setOption>() escapes (doubles) any backslashes in values
it returns, in order to be round-trippable with I<setOption()>.

=item * B<setOptionsFromHash(hashRef)>

Shorthand for calling I<setOption>() for each of the name/value pairs in
the referenced hash. See also I<getOptionHash>(). You can use the two together
to copy all options from one I<TabularFormats> instance to another.
B<Note>: I<setOption>() interprets (unescape) any backslash-codes in values.

=item * B<getOptionsHash>()

With no arguments, returns a reference to a copy of the hash of
all the options with their current values.
Calling this right after I<new>() will get you the defaults.

=item * B<getOptionHelps>(glob)

Returns a reference to a hash of the doc strings for the options,
keyed by option name. if I<glob> is provided, the information is sent to
that file as well.

=back

=head2 General Options

This is just a list; the full details are at C<TFormatsupport.pm>.

Use with I<setOption>() and I<getOption>().
Using an unknown option name will fail.
You can set an option to 0 or "", but not to C<undef>.

Unless otherwise specified below, options with unquoted default values
are boolean, and options with quoted values are strings.

Each format may use different options, which determine how data
will be parsed on input, or laid out on output:

=over

=item * B<basicType>     (string, naming the format) --
this may be set on the constructor, or set later like any other option.

=item * B<comment>       (string that starts comment lines) --

=item * B<prettyPrint>   (boolean) 1

=item * B<TFverbose>     (integer) 0

Show more trace information?

=item * B<recordSep>     (string) "\n"

=item * B<fieldSep>      (string) "\t" # Mainly for csv

=item * B<delim>

Synonym for I<fieldSep>

=item * B<escape>        (string) ""

Char to prefix to fieldSep or quote as literal

=item * B<escape2hex>    (character) "" # String to preceding hex char code
such as "%" for URI-style escapes. This applies after I<escape>.

=item * B<header>        (boolean) 0

Is there a header record (mainly for CSV)?

=item * B<nlInQuotes>    (boolean) 0

Allow newline in quotes?

B<Note>: With this option, you must read records via
I<readRecord>(); using normal Perl reads will of course not get
the multiple physical records that make up one logical record.
If this option is I<not> set, the library still checks for unbalanced
quotes, and issues a warning if they are found.

=item * B<qdouble>       (boolean) 0

Escape quotes in quotes, by doubling them.
Default: off. If I<escape> is also set, it takes precedence over I<qdouble>.

=item * B<qstray>        (boolean) 0

If a quote character is found in a field, not at the beginning,
and isn't escaped, doubled, or in
a quoted field (considering those related option settings), a warning
is issued. To suppress that warning, set I<qstray>.
(experimental, esp. wrt interaction with I<escape> and I<qdouble>).

=item * B<quote>         (string)  "\""

Char used to quote fields containing (e.g. fieldSep)

=item * B<stripFields>   (boolean) 1

Discard leading/trailing space on fields?

=item * B<stripRecords>  (boolean) 1

Discard leading/trailing space on records?

=item * B<classField>    (name) "Type"

(Manchester OWN only)
Treat the specified field as the "Class" (this matters when converting other
data to Manchester, since the name "Class" is special in OWL).

=back

=head3 Options applicable only to XML/HTML

=over

=item * B<htmlTag>, B<tableTag>, B<theadTag>, B<tbodyTag>,
B<trTag>, B<tdTag>, B<thTag>.

(XML) These options can be used to replace the default HTML element type names
for XML input and output. In general, tags set to "" will be omitted.

=item * B<idAttr>        (string) "id"

(XML) Use this name for any ID attributes generated for output XML.
You must set I<idValue> in order for this to have any effect.

=item * B<attrFields>    (string) ""

(XML) A whitespace-separated list of XML attribute names. These attribute
(regardless of what elements they occur on), will be treated as additional
fields, with the same names. An obvious example is C<href>.

=item * B<idValue>       (string) ""

(XML) If not "", generates ID attributes for each output row in XML.
The attribute name is taken from I<idAttr>, while I<idValue> specifies
where to get the value (a field name, or "*" for row number).

=item * B<classAttr>     (name) "class"

(XML) Put the field-name on this attribute of the "td" (field) elements.
If this is set to "", use field-names as the element type names for fields,
ignoring I<tdTag>.

=item * B<colspecs>      (boolean) 0

(XML) Generate HTML table COL elements?
For this to be very useful, you'll probably want to use I<setFieldPosition>().
The column specifications can include width and alignment. You can also
use the I<classAttr> option to put field names in as class attributes on
cells, and use that to hook up style definitions.

=item * B<entityWidth>   (int) 5

(XML) Minimum width for writing for numeric character references, as an integer.

=item * B<entityBase>    (10|16) 16

(XML) Base for writing numeric character references, as an integer.

=item * B<HTMLEntities>  (boolean) 0

(XML) Use HTML entity names for output when applicable? (not yet supported)

=item * B<publicId>      (string) ""

(XML) Write out a DOCTYPE declaration, with this PUBLIC id, and
with the document type name taken from I<htmlTag>.

=item * B<systemId>      (string) ""

(XML) Write out a DOCTYPE declaration, with this SYSTEM id, and
with the document type name taken from I<htmlTag>.

=item * B<XMLEntities>   (boolean) 1

(XML) Use the 5 XML built-in entities in output (if turned off, then
use numeric character references for those 5 characters).

=item * B<XMLDecl>       (boolean) 0

(XML) Write out an XML Declaration.

=back

=head2 Methods for operating on actual records

The main actions you can take are at the level of records: you can I<read>,
I<parse>, and I<assemble> records. You don't have to use the I<read> methods
here; however, some CSV files allow newlines within quoted field-values, and
the methods here take care of that, so can save you a lot of annoyance.
XML and XSV formats are also not as simple to read as I<readline>() or its
equivalent.

=over

=item B<hashToArray>(fromData, toNamesArray?)

Copy values from a hash into an array, and return a reference to it.
The data will be taken from the hash referenced by I<fromData>.

Fields will be copied in the order listed in the array referenced by
I<toNamesArray>; fields whose names do not appear in the array will not
be copied.
If I<toNamesArray> is not supplied, the defined field ordering will be used.

=item B<parseRecordFromString>(rec)

Parse the string in I<rec> and return a hash of the resulting fields.
You would use this if you're reading or creating records yourself, and
just need them parsed into fields.

B<Note>: Some common CSV variants allow line-breaks in the middle of quoted
field values. Many other formats do not regard line-breaks as particularly
important either. If you read such files with normal line-reading methods
and then pass those lines to I<parseRecordFromString>(rec), you'll get
bad results. Instead, use I<TabularFormats>' I<open>()
and I<readRecord>() methods.

=back

=head2 Input (non-parsing) methods

=over

=item * B<readRecord>()

Return a logical record from the data source (file, buffer, handle,... --
see I<open>() and I<attach>().
This must be used unless each logical record is always one physical record too.
The definition of "record" for each format, is described below
under L<"Supported formats, with examples">

=back

=head2 Input parsing methods

These take a record as a string (perhaps as returned by the I<readXXX>()
methods above, but not necessarily). The record is parsed according to the
format and options in effect, and returned somehow: as an array,
a hash, a sequence of SAX-equivalent events, or an XML::DOM structure.

=over

=item * B<readAndParseHeader>()

Reads the file header as defined by the format in effect, and uses it to
define the set of known fields. Some formats prohibit headers; some allow them,
and some require them. Some formats have the header look like a data
record, some (particularly ARFF) use a completely different format.
Many formats merely specify field names in the header, but some also give
datatype and/or other information. See also I<parseHeader>.
A reference to an array of the names is returned.
The 0th entry is never a field name (fields always count from 1).

=item * B<parseHeader(string)>

This parses a header out of a string, rather than extracting it from the
file. This only makes sense if the format defines header to be in the same
syntax as data records (for example, like CSV but unlike ARFF).
As with I<readAndParseHeader>, this sets up an
internal list of field-names, that can then be used to refer to fields more
mnemonically than using numbers.
A reference to an array of the names is returned.
The 0th entry is never a field name (fields always count from 1).

=item * B<parseRecordToArray(s)>

Takes a string (with or without a record
separator on the end), and parse it into an array of fields.
Returns a reference to the array, or undef if the record passed is a comment.

Field [0] is set to the null string, because fields are conventionally
numbered from 1 and it's easier to avoid the off-by-one correction.

B<Note>: With formats that allow logical records that do not exactly
correspond to physical records (for example XML, SEXP, and some forms of CSV),
you I<must> use I<readRecord> rather than merely Perl's <F> or similar.

B<Note>: This method is implemented by first using I<parseRecordToHash(s)>,
and then using the header information (or similar, if any)
to put the entries in an array, in a consistent order.
For formats that provide no names, names are made up
as fields are encountered (F_1, F_2,...).

=item * B<parseRecordToHash(s)>

Like I<parseRecordToArray>(), but returns
a reference to a hash, where each field is stored under its name.
This method can be called even for formats that do not provide names, because
names will be utomatically assigned as fields ar encountered.

=back

=head2 SAX-style API

=over

=item * B<setHandlers(hashRef)>

Attach callback functions to SAX-style events.
After doing this, call I<parsestring> to parse data from the source,
making it look like the event stream you'd get for the XHTML table
equivalent of the data.

The SAX events you can attach to are:
"Init", "Fin", "Start", "End", "Text", and/or "Default".

=item * B<parsestring>(s)

The data I<s> will be parsed according to the format and options in effect,
and will generate a stream of SAX-style callbacks (see I<setHandlers>()).

=item * B<parse_start>()

Begin a SAX "pull" parse. After calling this, call I<parse_more>() until
you get a "Fin" event.

=item * B<parse_more>()

Get the next event for a SAX "pull" parse. Call I<parse_more>() until
you get a "Fin" event. You will get an event stream that looks like an
XHTML I<table>, with no extraneous white-space nodes, just table/tr/td/#text.

=item * B<parsestringToDOM>(s)

Parse the input data, and return an XML::DOM instance. The DOM returned
will correspond to the structure you'd get if you used I<parse_more>.

=back

=head2 Output assembly methods

=over

=item * B<assembleHeader(arrayRef)>

Like I<assembleRecordFromArray>.

=item * B<assembleComment(text)>

If the output format supports comments, issue I<text> as a comment;
otherwise do nothing.

=item * B<assembleRecordFromHash(hashRef)>

Like I<assembleRecordFromArray>, but goes through the known fields in order (which
must each include a fieldName), and retrieves each field's value by name
from the hash at I<hashRef>, rather than getting them from an array.

In formats such as JSON, a record typically needs a comma after it, unless
it is the last record. The comma is not provided. However, for formats like
PERL where a comma after the last record is permitted, it is.

=item * B<assembleRecordFromArray(arrayRef)>

Take an array of fields (for example as
produced by I<parseRecord>(), and assemble them into a string according to
the format specifications.

In formats such as JSON, a record typically needs a comma after it, unless
it is the last record. The comma is not provided. However, for formats like
PERL where a comma after the last record is permitted, it is.

=item * B<assembleRecordFromHash(hashRef)>

Like I<assembleRecordFromArray>, but gets the fields by name from a hash
instead of from an array. It puts them in the order learned
from parseHeader() or from calls to I<addField>(), I<appendField>(),
I<setFieldNamesFromArray>(), and/or I<setFieldName>().

=back


=head1 Supported formats

The set of supported formats is determined by what implementations exist
in C<TFormatSupport.pm>. See its Perldoc for details and references.
At last check, the formats included were:

=head2 ARFF

This is the I<Attribute-Relation File Format> form for the C<WEKA> ML tookit.

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

  Fname     LName      State
  John      Adams      MA
  Benjamin  Franklin   PA
  John      Hancock    MA
  Stephen   Hopkins    RI
  Andries   van Dam    RI

=head2 CSV

A wide variety of record/field delimited file formats, such as
CSV and TSV. Forms vary by the choice of delimiter; repeatability of the
delimiter; whether spaces are ignored; whether fields can be quoted, and
if so when they I<must> be quoted; whether and how quotes and newlines can
appear within quotes; whether there's a header record (generally as the
very first record); and more.

A logical record in CSV is a physical line
unless I<nlInQuotes> is set, in which
case newlines can appear inside quotes and are counted as part of the data,
rather than as end of logical record.
No comments are typically allowed, though this script does support them
if needed (see I<setOption>()).

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
Quoted contents doesn't count toward balancing. This script only deals
with simplistic JSON (on par with CSV), such as:

  { "Table": [
    "Signer01": {"Fname":"John",     "LName":"Adams",    "State":"MA" }
    "Signer02": {"Fname":"Benjamin", "LName":"Franklin", "State":"PA" }
    "Signer03": {"Fname":"John",     "LName":"Hancock",  "State":"MA" }
    "Signer04": {"Fname":"Stephen",  "LName":"Hopkins",  "State":"RI" }
    "Signer05": {"Fname":"Andries",  "LName":"van Dam",  "State":"RI" }
  ]}

=head2 MANCH

The Manchester OWL (Web Ontology Language) format is
used by C<Protege> and some other C<RDF> applications
(see "References" below).
This script only supports The Manchester "IndividualFrame" item,
for assigning Class, SubClassOf, and Facts to the individuals.
As with XML, JSON, and some others, this represents a
"least common denominator" subset, comparable to CSV and its kin.

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
See L<RC 1521>, L<RFC 2045>, L<RFC 822>.
Uses I<label>-prefixed fields (with continuation lines indented), and
a blank line (only) before each entire record.

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

=head2 PERL

This is mainly for output. It produces PERL source code that creates
an array (one element per record) of references to hashes (which map from
field names to values).
All the field names, and all non-numeric values, are quoted as strings.
You should be able to just paste this into a PERL program and then access
the data easily.

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
They can express much more than CSV, but only simple cases are supported here.
They are supported in two flavors: association lists vs. plain lists.
Field names and values are quoted (single left only if they consist only
of alphanumerics; otherwise double enclosed).

I<SXML> syntax is a variation on SEXP that is not yet supported.

=head2 XML

(X)HTML or XML table or table-like markup (XML and HTML can of course
represent much more than that, but only tables or similarly-shaped
data are handled here):
Elements for each record and field and field values in content.
HTML table tags are used by default, but tag names can be changed.
Attributes are not presently used for fields
except via I<idAttr>, I<idValue>, and I<classAttr>.

=head2 XSV

This is a very simple subset
of XML, limited to about the same functionality as CSV, ARFF, etc.
It is slightly more verbose in some cases, slightly less verbose in others
(due to support for default values, C<HTML>-like "BASE" factoring, etc).
It is supported via a separate package, and supports simple datatype checking.

Every XSV data set is a Well-Formed XML document (so can be processed
by perfectly normal XML software). However, not all WF XML documents
are XSV. That is, XSV supports a subset of XML.

For example:

  <!-- Some signers of the Declaration of Independence.
       List created: March 15, 1066 A.D.
    -->
  <Head  Id="#NMTOKEN" Fname="#string" LName="John"
         State="" DOB="#date">
    <Rec Id="Signer01" Fname="John"     LName="Adams"    State="MA" />
    <Rec Id="Signer02" Fname="Benjamin" LName="Franklin" State="PA" />
    <Rec Id="Signer03"                  LName="Hancock"  State="MA" />
    <Rec Id="Signer04" Fname="Stephen"  LName="Hopkins"  State="RI" />
    <Rec Id="Signer05" Fname="Andries"
         LName="v&aacute;n Dam" State="RI" />
  </Head>


=head1 Managing options

=over

=item * B<addOptionsToGetoptLongArg>I<(hashRef, prefix?)>

Add all of this package's options to the hash at I<hashRef>, in the form
you would pass to Perl's C<Getopt::Long> package. The options will be set
up to store their values directly to the C<TabularFormats> instance, via
the I<setOption>() method.

If I<prefix> is defined,
it will be added to the beginning of each option name; this allows you
to avoid name conflicts with the caller, or between multiple instances of
C<TabularFormats> (for example, one for input and one for output).

If an option is already present in the hash (note that the key, as always
for C<Getopt::Long>, includes aliases and suffixes like "=s"), a warning is
issued and the new one replaces the old.

Returns: The number of options added.

=back


=head1 Related commands

=over

=item * C<DataSource.pm> provides input services to read files by line,
record, balance quote or () expression, etc.

=item * C<TableSchema> maintains information on the known fields.

=item * C<xml2tab> and C<tab2xml> are basic wrappers on top of this,
that just convert from one form to another. The names are historical.

=item * C<sexp2xml> -- a somewhat similar conversion, but specialized for
Penn TreeBank files, which are kind of like SEXP but contain
many other embedded syntaxes, which this script also converts.

=item * C<align> -- take a file and measure all the fields, then
space-pad them so they line up nicely.
Can also do box-drawing in ASCII or Unicode.

=item * C<XmlTuples.pm> -- support for the XSV format.

=item * C<RecordFile.pm> -- provices record-oriented i/o, with cached offsets.
Looks basically like a file, but
handles logical rather than physical records.
Very similar to C<DataSource.pm>, which this package currently uses.
The two packages should be integrated into one.

=item * C<FakeParser.pm>, C<YMLParser.pm> -- simple parsers for XML.
Much ike CPAN's C<XML::Parser>, but more forgiving of errors, and thus
not fully-conforming XML parsers. C<YMLParser.pm> also supports some
extra minimization conventions, especially for tables.

=item * Some sjd utilities that use C<TabularFormats.pm>:
    C<addup>,
    C<align>,
    C<countChars>,
    C<countData>,
    C<disaggregate>,
    C<dropDictionaryWords>,
    C<globalChange>,
    C<grepData>,
    C<lessTabular>,
    C<scraper>,
    C<splitFiles>,
    C<tab2xml2>,
    C<vocab>,
    C<xml2tab>.

=item * Some utilities that may not give access to all TF options yet:
    C<makeHTMLtable>*,
    C<makeNMIgraph>*,
    C<taWordlist2csv>* (unfinished),

=back

=head2 Which formats have Perl and/or Python libraries?

I<And which handle Unicode?>

CSV: https://metacpan.org/pod/Text::CSV_XS -- looks strong; awkward for \\n.


=head1 Known bugs and limitations

See also C<TFormatSupport.pm>.

=over

=item * Not safe against UTF-8 encoding errors. Use C<iconv> if needed.

=item * Leading spaces on records are not reliably stripped.

=item * Particular formats set their own values for the I<comment> option.
This means you can't override it until after calling I<chooseFormat>,
which is annoying.

=item * The I<ASCII> option is supported for JSON, Perl, XML, and XSV.
For some other formats it is not clear how to escape non-ASCII characters.
ARFF appears to provide no way at all.
MIME headers use I<quoted-printable> form, but support for full Unicode is not
yet finished.

=item * The behavior if using regexes rather than strings for I<delim>,
I<quote>, I<comment>, etc., for CSVs is undefined.
Most likely it will work ok for input, but not for output.

=item * Support for decoding HTML entity references is implemented but
commented out; to use it, uncomment things starting C<HTML::Entities>
and install the eponymous CPAN package.

=item * Datatype checking is experimental.

=item * The behavior if a given field is found more than once in an input
record is undefined. This is only possible with some formats (essentially
those that identify fields by name, not position). Some options
may be added for this, perhaps taking the first or last, or concatenating
them with some separator, or serializing them somehow.

=back


=head1 History

=over

=item Written 2010-03-23 by Steven J. DeRose, as csvFormat.pm
(many changes/improvements).

=item 2012-03-30 sjd: Rename to TabularFormats.pm, major reorg.
More work on adding XSV (XML Tuples) support.
Refactor to have package per form, plus RecordDef and FieldDef.
Use sjdUtils. Integrate sniffing code from lessCSV.

=item 2012-04-13 sjd: Track lastMessage.

=item 2012-04-20 sjd: Debugging, cleaning up separation of sub-packages.

=item 2012-04-25f sjd: Back to pretty much working. Start SAX i/f.
Let user *set* field-specific callbacks. Make setExpectedFields()
adjust fDefsByName to match. Add stubs for remaining formats.

=item 2012-04-30 sjd: Put all options into main pkg, add opt() in all pkgs.

=item 2012-05-23 sjd: Add PERL. Rationalize parseRecord... methods. Decide that
hash is the definitive internal form. Drop expectedFields notion.
Drop readRecordToHash() and readRecordToArray().
Do parseRecordToArray() by ...ToHash() and assemble in order.

=item 2012-05-25 sjd: Option to set up col specs for XML table output.
Implement option and field datatype checking.
Better way to organize subclasses.

=item 2012-05-29ff sjd: Pull parsestringtoDOM() from FakeParser.pm. Shift methods
between EntityStack/EntityFrame/EntityDef. Implement ARFF. Escaping.
Fix @class for XML, attr names for XSV output. Working for CSV again.
Drop {theRecord}, escapeMap option, add xDocument, -XMLDecl, systemId.
Move tfWarn and tfError into UNIVERSAL. Add assembleComment().
Make TF-level impl of all parseXXX() calls also do setRecord().
Add setFieldNumbersByPosition().

=item 2012-06-04 sjd: Support options hash arg for parse_start, parsefile, parse.
Implement actual pull parsing. Make parse_more() etc. like XML::Parser.

=item 2012-06-08 sjd: Add readBalanced(), readToUnquotedDelim().
Finish hooking up and documenting 'DataSource' package.
Finish readRecord() (incl. comments) for JSON, MANCH.
Make readRecord() really do exactly one record (sexp, xml, mime, manch...

=item 2012-06-11 sjd: Make some use of null value settings, esp. for output.

=item 2012-06-13 sjd: Add postProcessFields(), splitter/joiner. Fix JSON escaping.
Add notion of sub-fields. Trap CSV quoting error for output.
Add assembleComment() to more formats.

=item 2012-06-21 sjd: Sync w/ TabularFormats.pm changes. Add option help strings.

=item 2012-07-05 sjd: Implement ARFF readAndParseHeader(). Add readRealLine().
Add XML 'attrFields' option and support. Improve setFieldPosition()
and make width arg optional.

=item 2012-07-13 sjd: Check for nil from getFieldDef(); create field names at need.
setFieldPositions(), getAvailableWidth(), getNearestFollowingFieldDef().

=item 2012-07-30ff sjd: Better sub-field handling. Catch undef names. Fix
postProcessFields(). Error-check arg to setRecordFromXXX().

=item 2012-08-14 sjd: getOptions() call getFormatImplementation, for getOptions().

=item 2012-10-29 sjd: Improve unescaping.

=item 2012-11-02 sjd: Make args for assembleField() consistent. "FIXED"->"COLUMNS".

=item 2012-11-26 sjd: Add open() to pass through to DataSource.
Add DataSource::binmode(). Discard FieldDef->{fTruncate}.

=item 2012-12-17ff sjd:  Add getFieldsArray() and getFieldsHash(). Fix bug where it
lost [0] at one point. Treat theFields consistently as a hash.
Make assembleRecordFromHash default to current data. Move escapeJson to
sjdUtils. Omit empty fields for XSV output. Prettify output layouts.
Start fixing header handling.

=item 2012-12-19 sjd: Drop readHeader() for readAndParseHeader(). Make consistent.
Fiddle w/ XmlTuples API to make like the rest.

=item 2013-01-18 sjd: Add tell(), mainly for RecordFile.pm.

=item 2013-02-06ff sjd: Don't call sjdUtils::setOptions("verbose").
Work on -stripRecord.
Break out DataSchema package, and tell it and DataSource what they need,
so they don't have to know 'owner' any more. Clean up virtuals a bit.
Also break out DataOptions and DataCurrent packages. Fix order of events
in pull-parser interface. Format-support packages to separate file.
Support repetition indicators on datatypes.

=item 2013-02-14 sjd: Sync package DataSource's API, closer to RecordFile.pm.

=item 2013-04-02 sjd: Forward a few more calls down to sub-packages (for tab2xml).
Add dprev for prior data record. Centralize setFieldNamesFromArray() call
from parseHeader() and readAndParseHeader() -- not in TFormatSupport.pm.

=item 2013-04-03 sjd: Make getField() create unknown fields as needed.
Let addField and FieldDef::new take some optional params.

=item 2013-04-23 sjd: Add package prefixes to sub dcls. Debug getFieldValue(0.
Distinguish getNSchemaFields() vs getNCurrentFields().

=item 2013-06-03: Special-case XSV, which provides its own input handling.
Make sure -basicType shows up with addOptionsToGetoptLongArg().

=item 2013-06-17ff: Add TabularFormats::getOptionsHash(). Make tfError() print
package and function names. Fix \-codes in options. Add sniffFormat().

=item 2014-02-05ff: Fix setFieldNamesFromArray to fully create fields as needed.
Drop DataCurrent package entirely.

=item 2015-02-19: Drop 'recover' params for dealing with missing field name/number.
Instead just return undef and let caller deal.

=item 2017-04-19: Split DataSchema and FieldDef to separate file TableSchema.pm,
and DataSource to separate file DataSource.pm,

=item 2021-11-11: Minor cleanup. Not really maintained any more.

=back


=head1 To do

=over

=item * Why continuous (-v) warnings about re-adding same fields?

=item * Make each file format be its own subclass, allocated directly.

=item * Split subclasses into separate files.

=item * Add supportsFieldNames().

=item * Add formats for graphviz drawing links keyed by 2 fields? Separate app?

=item * Do something with date formats.

=item * Protect against UTF encoding errors.

=item * JSON: Option to write JSON arrays vs. dicts.

=item * XSV: output: omit defaults.

=item * XML: support tag@attr values with attrFields?

=item * XML: Option to parse up attribute values as subfields.

=item * Way to control order of writing fields where it doesn't matter:
#         xml, xsv (done?), json, mime

=item * Rename options to start with format they apply to?

=item * Fix handling of XSV headers.

=item * Finish padding/alignment for output, in FieldDef::align.

=item * Right-justify numeric fields.

=item * Handle blank records better (integrate readRealLine).

=item * Option to default specific fields.

=item * Replace getRecordAsString (and Array).

=item * Integrate into C<makeHTMLtable>, C<makeNMIgraph>.

=item * FormatSniffer.

=back

=head2 Format-specific

=over

=item * COLUMNS: add fixFieldWidths() to setFieldPosition().

=item * COLUMNS: easier way to pass in column positions?

=item * COLUMNS: support reorderings in assembleRecordFromArray()

=item * MANCH: Manage additional keywords per tupleset.

=item * MANCH: add options for TypeName(s), SuperClass, ID,
#         inclusions. Implement header, prettyPrint.

=item * MANCH, XML: finish readAndParseHeader().

=item * XML: Select elements by QGI@, hand back list of children of each???

=item * XML: switch to XML::Parser, HTML::Parser, etc.

=back

=head2 Low priority

=over

=item * Write merge: n files, (compound?) key designation per, field renaming.

=item * Add compound-key-reifier to deriveField.

=item * Rotate embedded layer (esp. for SEXP, XML, JSON, etc.)

=item * Switch messaging to use sjdUtils?

=item * Way to get the original offset/length of each field in record?

=item * Add quick options to set tags for docbook, tei, nlm (in and out)

=item * Improve handling of missing/extra/duplicate fields.

=item * Should chooseFormat go in TFormatSupport? Maybe ditch subclassing there?

=item * Additional formats? See TFormatSupport.pm.

=back


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.


=cut


###############################################################################
# Messaging ("UNIVERSAL" is inherited by everything)
#
use strict;
use feature 'unicode_strings';

use sjdUtils;
use alogging;

#sjdUtils::try_module("HTML::Entities") || warn
#    "Can't access CPAN HTML::Entities module.\n";
#sjdUtils::try_module("MIME::QuotedPrint") || warn
#    "Can't access CPAN MIME::QuotedPrint module.\n";

use TFormatSupport; # Actual implementations of specific formats.
use TableSchema;
use DataSource;

sjdUtils::try_module("Datatypes") || warn
    "Can't access sjd Datatypes module.\n";

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

# List of supported formats
#
my @bt = qw/ARFF COLUMNS CSV JSON MIME MANCH PERL SEXP XSV XML/;
my $formatNamesExpr = join("|",@bt);


###############################################################################
#
package DataOptions;


###############################################################################
# The main package.
# Instantiates one of the specific formats, and dispatches calls
# to it.  The top-level package handles messaging, options, field defs,
# and some interfaces (like SAX). The others handle format-specific i/o.
#
package TabularFormats;
my $tf = "TabularFormats"; # For messages

sub TabularFormats::new {
    my ($class, $format, $optionsHash) = @_;
    if (!$format) { $format = "CSV"; }

    # Manage the 'basicType'
    if ($optionsHash && ref($optionsHash) ne "HASH") {
        alogging::eMsg(
            0, "$tf: Arg 2 to constructor (options) is not a hash.");
        return(undef);
    }
    my $self = {
        format        => $format,  # Name of format in use
        formatImpl    => undef,    # -> instance for basicType impl
        dsrc          => undef,    # -> DataSource instance
        dsch          => undef,    # -> TableSchema instance
        dopt          => undef,    # -> DataOptions instance

        parsedARecord => 0,        # Finished w/ record 1 yet?

        saxCallbacks  => {},       # In case they want to parse this way
        gaveObsMsg    => 0,        # Already showed readRecord obsolete msg?
    }; # self

    bless $self, $class;

    $self->{dopt} = new DataOptions();
    if (defined $optionsHash && ref($optionsHash) eq "HASH") {
        $self->{dopt}->setOptionsFromHash($optionsHash);
    }
    $self->{dsrc} = new DataSource();
    $self->{dsch} = new TableSchema();

    $self->chooseFormat($format);
    return($self);
} # new

sub TabularFormats::reset { # TabularFormats
    my ($self) = @_;
    $self->{dsch}->reset();
    if ($self->{dprev}) { $self->{dprev}->reset(); }
}


###############################################################################
# Facilitate callers supporting our options, by providing a single method
# that adds them to a hash for the argument to Getopt::Long::GetOptions().
# The options invoke commands that store their values back here, so caller
# doesn't have to know about them at all.
# Options already defined before calling us are ok (warning on conflict).
#
sub TabularFormats::addOptionsToGetoptLongArg {
    my ($self,
        $getoptHash,          # The hash to pass to GetOptions()
        $prefix               # String to put on front of option names
        ) = @_;
    if (!defined $prefix) { $prefix = ""; }
    $self->{optionsPrefix} = $prefix;

    (ref($getoptHash) eq "HASH") || alogging::eMsg(
        -1, "$tf: Must provide a hashref.");

    my %getOptTypeMap = (
        "boolean"=>"!", "integer"=>"=i", "BaseInt"=>"=o",
        "string"=>"=s", "Name"=>"=s",
        );

    my $i = 0;
    for my $name (sort keys(%{$self->{dopt}->{options}})) {
        $i++;
        ($name =~ m/^\w+$/) || alogging::eMsg(
            0,"$tf: Bad option name '$name'");
        my $dt = $self->{dopt}->getOptionType($name);
        my $suffix = $getOptTypeMap{$dt};
        if (!$suffix) {
            alogging::eMsg(
                0, "$tf: Unknown type '$dt' for option '$name'.\n  " .
                "Known types: (" . join(", ", keys(%getOptTypeMap)) . ").");
            $suffix = "!";
        }
        if (defined $getoptHash->{"$prefix$name$suffix"}) {
            alogging::eMsg(0,"$tf: '$prefix$name$suffix' already in hash.");
        }
        $getoptHash->{"$prefix$name$suffix"} =
            sub { $self->setOption("$name", $_[1]); };
        #alogging::vMsg(
        #    3, sprintf("  $tf: Adding %-16s => %s", "\"$prefix$name$suffix\"",
        # "sub { \$self->setOption('" . $name . "',\t\$_[1]); }"));
    }
    return($i);
} # addOptionsToGetoptLongArg

sub TabularFormats::SniffFormat {
    my ($self, $path) = @_;
    (my $ext = lc($path)) =~ s/^.*\.//;

    # Extension should be sufficient
    if ($ext eq "csv") {
        return("CSV\t" . $self->{dopt}->getOption("fieldSep"));
    }
    if ($ext eq "tsv")                   { return("CSV\t\t"); }
    if ($ext =~ m/^(zip|Z|gz|lz|tar)$/)  { return("COMPRESSED\t$ext"); }
    if ($ext =~ m/^(xlsx)$/)             { return("XLSX"); }
    if ($ext =~ m/^(htm|html|xml)$/)     { return("XML");  }
    if ($ext =~ m/^(mbox)$/)             { return("MIME"); }
    if ($self->hasFormat($ext))          { return($ext);   }

    # Unix 'file' command
    my $ufile = `file $path`;
    if ($ufile !~ m/ text/)              { return(undef);  }
    if ($ufile =~ m/(HTML|XML)/)         { return("XML");  }
    if ($ufile =~ m/mail text/)          { return("MIME"); }

    # Sniff the beginning of the data
    my $head = `head -n 10 $path`;
    if ($head =~ m/\n\@RELATION/si)      { return("ARFF"); }
    if ($head =~ m/<!-- XSV|<Xsv/i)      { return("XSV");  }
    if ($head =~ m/<!DOCTYPE\s*(\w+)/)   { return("XML\t$1"); }
    if ($head =~ m/<x?html/i)            { return("XML");  }
    if ($head =~ m/^\s*\(/)              { return("SEXP"); }
    if ($head =~ m/\t.*\t.*\t/)          { return("CSV\t\t"); }
    if ($head =~ m/,.*,.*,/)             { return("CSV\t,"); }
    if ($head =~ m/:.*:.*:/)             { return("CSV\t:"); }
    if ($head =~ m/;.*;.*;/)             { return("CSV\t;"); }
    if ($head =~ m/\|.*\|.*\|/)          { return("CSV\t|"); }

    # Fail
    return(undef);
}

sub TabularFormats::hasFormat {
    my ($self, $f) = @_;
    return($f =~ m/^($formatNamesExpr)$/);
}
sub TabularFormats::chooseFormat {
    my ($self, $f) = @_;
    $f = uc($f);
    #alogging::vMsg(1, "$tf: In chooseFormat for '$f'.");
    if (!$f || $f !~ m/$formatNamesExpr/) {
        alogging::eMsg(-1, "$tf: Unknown format '$f'");
        return(undef);
    }

    my $fi = undef;
    my @args = ($self->{dsrc}, $self->{dsch}, undef, $self->{dopt});
    if    ($f eq "ARFF" )   { $fi = new formatARFF(@args) ;}
    elsif ($f eq "COLUMNS") { $fi = new formatCOLUMNS(@args);}
    elsif ($f eq "CSV"  )   { $fi = new formatCSV(@args)  ;}
    elsif ($f eq "JSON" )   { $fi = new formatJSON(@args) ;}
    elsif ($f eq "MIME" )   { $fi = new formatMIME(@args) ;}
    elsif ($f eq "MANCH")   { $fi = new formatMANCH(@args);}
    elsif ($f eq "PERL" )   { $fi = new formatPERL(@args) ;}
    elsif ($f eq "SEXP" )   { $fi = new formatSEXP(@args) ;}
    elsif ($f eq "XML"  )   { $fi = new formatXML(@args)  ;}
    elsif ($f eq "XSV"  )   { $fi = new formatXSV(@args)  ;}
    else {
        alogging::eMsg(-1,"$tf: Unknown format name '$f'.\n");
        return(undef);
    }
    $self->{format} = $f;
    $self->{formatImpl} = $fi;
    return($fi);
} # chooseFormat

sub TabularFormats::getOptionsHash {
    my ($self) = @_;
    return($self->{dopt}->getOptionsHash());
}

# Copy all the values from a hash whose keys appear in a given array.
# Typically used to get items from one instance to another by name.
# If toNamesRef array is omitted, write fields in normative order.
#
sub TabularFormats::hashToArray { # TabularFormats
    my ($self, $fromDataRef, $toNamesRef) = @_;
    if (!$toNamesRef)  {                     # default the field order
        $toNamesRef  = $self->getFieldNamesArray();
    }
    alogging::vMsg(0, "$tf: hashToArray: order = (" .
                      join(", ", @{$toNamesRef}) . ")");
    if (ref($fromDataRef) ne "HASH" ||       # args ok?
        ref($toNamesRef) ne "ARRAY") {
        alogging::eMsg(0,"$tf: Bad argument types: from '" .
                     ref($fromDataRef) . "' to '" . ref($toNamesRef) . "'\n");
        return(undef);
    }
    ($toNamesRef->[0]) &&
        alogging::eMsg(0, "$tf: Non-empty name[0].");
    my @toData = ("");
    for my $f (1..(scalar(@{$toNamesRef})-1)) {
        my $name = $toNamesRef->[$f];
        if (!$name) {
            alogging::eMsg(0, "$tf: Undefined name in order array [$f]");
            push @toData, "UNDEF";
            next;
        }
        my $value = $fromDataRef->{$name};
        push @toData, (defined $value ? $value : "");
    }
    return(\@toData);
} # hashToArray


sub TabularFormats::parseRecordFromString {
    my ($self, $rec) = @_;
    if (ref($rec)) {
        alogging::eMsg(0, "$tf: Not a string.");
        return();
    }
    return($self->parseRecordToHash($rec));
}


###############################################################################
# SAX and DOM i/f support
#
sub TabularFormats::parsestringtoDOM { # TabularFormats
    my ($self, $s, $optionsHash) = @_;

    sjdUtils::try_module("XML::DOM") || die
        "Can't access CPAN XML::DOM module. INC is {\n    " .
        join("\n    ", @INC) . "\n}\n";

    if (defined $optionsHash && ref($optionsHash) eq "HASH") {
        $self->setOptionsFromHash($optionsHash);
    }

    # Same event names as CPAN XML::Parser, except additions where marked.
    #
    my %eventNames = (
        "Init"          => 1,
        "Final"         => 1,
        "Start"         => 1,
        "End"           => 1,
        "Char"          => 1,
        "Proc"          => 1,
        "Comment"       => 1,
        "CdataStart"	=> 1,
        "CdataEnd"	    => 1,
        "Default"	    => 1,

        "Unparsed"	    => 1,
        "ExternEnt"	    => 1,
        "ExternEntFin"	=> 1,

        "Element"	    => 1, # Dcl
        "Attlist"	    => 1, # Dcl -- once per *attribute*!
        "Entity"	    => 1, # Dcl
        "Notation"	    => 1, # Dcl

        "Doctype"       => 1,
        "DoctypeFin"    => 1,
        "XMLDecl"       => 1,

        "Attr"          => 1, # Extension
        "AttrFin"       => 1, # Extension
        "ProcAttr"      => 1, # Extension
        "ProcAttrFin"   => 1, # Extension
        "ERROR"         => 1, # Extension
        );

    my $theDoc    = new XML::DOM::Document();
    my $curNode   = $theDoc->createElement("xhtml");
    $theDoc->setRoot($curNode);
    my $newNode   = undef;
    my $unhandled = 0;

    $self->parse_start();
    while (my @args = @{$self->parse_more()}) {
        my $eType = shift @args;
        if ($eType eq "XMLDecl") {                # XMLDecl
            # $newNode = $theDoc->createXMLDecl(shift @args);
            # $theDoc->setXMLDecl($newNode);
        }
        elsif ($eType eq "Doctype") {             # Doctype
            # $newNode = $theDoc->createDocumentType(shift @args);
            # $theDoc->setDoctype($newNode);
        }
        elsif ($eType eq "Start") {               # Start
            $newNode = $theDoc->createElement(shift @args);
            while (@args) {
                my $name = shift;
                my $value = shift;
                $newNode->setAttribute($name,$value);
            }
            $curNode->appendChild($newNode);
            $curNode = $newNode;
        }
        elsif ($eType eq "Attr") {                # Attr
            my $name = shift;
            my $value = shift;
            $curNode->setAttribute($name,$value);
        }
        elsif ($eType eq "End") {                 # End
            $curNode = $curNode->getParent();
        }
        elsif ($eType eq "Char") {                # Char
            $newNode = $theDoc->createTextNode(shift @args);
            $curNode->appendChild($newNode);
        }
        elsif ($eType eq "Proc") {                # Proc
            my $tgt = shift @args;
            my $txt = shift @args;
            $newNode = $theDoc->createProcessingInstruction($tgt,$txt);
            $curNode->appendChild($newNode);
        }
        elsif ($eType eq "Comment") {             # Comment
            $newNode = $theDoc->createComment(shift @args);
            $curNode->appendChild($newNode);
        }
        elsif ($eType eq "Unparsed") {            # Unparsed
            $newNode = $theDoc->createEntityReference(shift @args);
            $curNode->appendChild($newNode);
        }
        elsif ($eType eq "ExternEnt") {           # ExternEnt
            $newNode = $theDoc->createEntityReference(shift @args);
            $curNode->appendChild($newNode);
        }

        elsif ($eType eq "ERROR") {               # ERROR
            if ($self->{died}) { return(undef); }
        }

        elsif (defined $eventNames{$eType}) {
            $unhandled++;
            # "AttrFin" "Init" "Final" "CdataStart" "CdataEnd" "ExternEntFin"
            # "Default" "Element" "Attlist" "Entity" "Notation"
            # "DoctypeFin" "ERROR"
        }
        else {
            alogging::eMsg(-1,"$tf: Unknown event type '$eType'");
        }
    } # while parse_more
    return($theDoc);
} # parsestringtoDOM

sub TabularFormats::setHandlers {
    my ($self, $hands) = @_;
    for my $h (keys(%{$hands})) {
        if (!isHandlerName($h)) {
            alogging::eMsg(0,"$tf: Unknown event type '$h'\n");
        }
        else {
            $self->{saxCallbacks}->{$h} = $hands->{$h};
        }
    } # for each handler
}
sub TabularFormats::isHandlerName {
    my ($self, $name) = @_;
    return((defined $saxEvents{$name}) ? 1:0);
}


###############################################################################
# Parse data from various sources (cf FakeParser.pm, SAX. etc.).
#
sub TabularFormats::parsefile { # TabularFormats
    my ($self, $file, $optionsHash) = @_;
    (my $fh = $self->{dsrc}->open($file)) || return(undef);
    $self->{dsrc}->binmode($self->{encoding});
    $self->parse($fh);
    return(1); # (or result of Final() handler)
}

sub TabularFormats::parsestring {
    my ($self, $s, $optionsHash) = @_;
    $self->parse($s, $optionsHash);
}

sub TabularFormats::parse {
    my ($self, $fhOrString, $optionsHash) = @_;
    if (ref($fhOrString) eq "#IO") {
        $self->{dsrc}->attach($fhOrString);
        $self->{dsrc}->binmode($self->{encoding});
    }
    else {
        $self->{dsrc}->add_text($fhOrString);
    }
    $self->parse_run($optionsHash);
}

# Run the actual parse, using data fetched via readRecord().
#
sub TabularFormats::parse_run {
    my ($self, $optionsHash) = @_;
    if (defined $optionsHash && ref($optionsHash) eq "HASH") {
        $self->setOptionsFromHash($optionsHash);
    }

    my @fNames = @{$self->getFieldNamesArray()};

    $self->saxEvent("Init");
    $self->saxEvent("Start", "table");
    while (my $theRec = $self->readRecord()) {
        $self->saxEvent("Start", "tr");
        my @fields = @{$self->parseRecordToArray($theRec)};
        for (my $i=1; $i<scalar(@fields); $i++) {
            $self->saxEvent("Start", "td", "class", $fNames[$i]);
            $self->saxEvent("Text",  $fields[$i]);
            $self->saxEvent("End", "td");
        }
        $self->saxEvent("End", "tr");
    }
    $self->saxEvent("End", "table");
    $self->saxEvent("Fin");
}
sub TabularFormats::saxEvent {
    my $self = shift;
    my $e    = shift;
    my $cb = $self->{saxCallbacks}->{$e};
    if ($cb) {
        $cb->($self, @_);
    }
    elsif ($cb = $self->{saxCallbacks}->{"Default"}) {
        $cb->($self, @_);
    }
}

sub TabularFormats::parse_start {
    my ($self, $optionsHash) = @_;
    my $nb = new ExpatNB($self, $optionsHash);
    $nb->clear_data();
    return($nb);
}

sub TabularFormats::pull_start {
    my ($self, $rec, $optionsHash) = @_;
    my $pp = new pull_parser($self, $optionsHash);
    $pp->add_data($rec);
}


###############################################################################
# Relations to DataSource package
#
sub TabularFormats::getDataSource {
    my ($self) = @_;
    return($self->{dsrc});
}
sub TabularFormats::open {
    my ($self, $path) = @_;
    my $rc = undef;
    # XSV has its own input-handling, rather than using DataSource....
    if ($self->{format} eq "XSV") {
        $rc = $self->{formatImpl}->{xsvParser}->open($path);
        $self->{dsrc}->attach($rc);
    }
    else {
        $rc = $self->{dsrc}->open($path);
        $self->{dsrc}->binmode($self->{encoding});
    }
    return($rc);
}
sub TabularFormats::attach {
    my ($self, $fh) = @_;
    $self->{dsrc}->attach($fh);
    $self->{dsrc}->binmode($self->{encoding});
}
sub TabularFormats::close {
    my ($self) = @_;
    return($self->{dsrc}->close());
}
sub TabularFormats::rewind {
    my ($self) = @_;
    $self->{dsrc}->seek(0,0);
    return(1);
}
sub TabularFormats::seek {
    my ($self, $n) = @_;
    return($self->{dsrc}->seek($n));
}
sub TabularFormats::tell {
    my ($self) = @_;
    return($self->{dsrc}->tell());
}


###############################################################################
# Relations to TableSchema package
#
sub TabularFormats::getTableSchema {
    my ($self) = @_;
    return($self->{dsch});
}
sub TabularFormats::getNSchemaFields {
    my ($self) = @_;
    return($self->{dsch}->getNSchemaFields());
}
sub TabularFormats::getFieldName {
    my ($self, $fn) = @_;
    my $name = $self->{dsch}->getFieldName($fn);
    (ref($name)) &&  UNIVERAL::tfError(
        -1, "$tf: Ref wrongly passed to getFieldName().");
    return($name);
}
sub TabularFormats::getFieldNumber {
    my ($self, $fn) = @_;
    return($self->{dsch}->getFieldNumber($fn));
}
sub TabularFormats::getFieldNamesArray {
    my ($self) = @_;
    return($self->{dsch}->getFieldNamesArray());
}
sub TabularFormats::setFieldName {
    my ($self, $fieldNN, $newName) = @_;
    return($self->{dsch}->setFieldName($fieldNN, $newName));
}
sub TabularFormats::setFieldNamesFromArray {
    my ($self, $aRef) = @_;
    return($self->{dsch}->setFieldNamesFromArray($aRef));
}


###############################################################################
# Relations to DataOptions package
#
sub TabularFormats::setOption {
    my ($self, $optionName, $value) = @_;
    alogging::vMsg(1, "Setting TF option '$optionName' to '$value'.");
    if ($optionName eq "stripRecords") { # Notify other package of this one!
        $self->{dsrc}->{stripRecords} = $value;
    }
    if ($optionName eq "basicType") {
        $self->chooseFormat($value);
    }
    if ($optionName eq "TFverbose") {
        sjdUtils::setVerbose($value);
    }
    $self->{dopt}->setOption($optionName, $value); # Calls chooseFormat
}
sub TabularFormats::hasOption {
    my ($self, $optionName) = @_;
    return($self->{dopt}->hasOption($optionName));
}
sub TabularFormats::getOption {
    my ($self, $optionName) = @_;
    return($self->{dopt}->getOption($optionName));
}


###############################################################################
# Relations to the format-support packages.
#
# Methods below here forward to {formatImpl}, which will be
# a subclass of TFormatSupport, for a particular data format.
#
sub TabularFormats::isOkFieldName {
    my ($self, $fn) = @_;
    return($self->{formatImpl}->isOkFieldName($fn));
}
sub TabularFormats::cleanFieldName {
    my ($self, $fn) = @_;
    return($self->{formatImpl}->cleanFieldName($fn));
}
# Schema's names are set from here, not from formatImpl.
sub TabularFormats::readAndParseHeader {
    my ($self) = @_;
    if ($self->getOption("TFverbose")) {
        alogging::vMsg(2, "$tf:readAndParseHeader: Options in effect:");
        my $oRef = $self->getOptionsHash();
        for my $o (sort(keys(%{$oRef}))) {
            alogging::vMsg(0, sprintf("    %-16s  '%s'\n", $o, $oRef->{$o}));
        }
    }

    if (!$self->getOption("header")) {
        alogging::vMsg(1, "$tf:readAndParseHeader: --header not in effect.");
        return(undef);
    }
    alogging::vMsg(1, "$tf:readAndParseHeader.");
    my $fieldNames = $self->{formatImpl}->readAndParseHeader();
    if (!$fieldNames) {
        alogging::vMsg(1, "$tf: No header found.\n");
        return(undef);
    }
    if (scalar(@{$fieldNames}) <=2) {
        alogging::vMsg(
            0, "Header found only 1 field. Bad -basicType (" .
            $self->{dopt}->getOption("basicType") . ") or -fieldSep (" .
            sjdUtils::vis($self->{dopt}->getOption("fieldSep")) .
            ")?\n");
        return(undef);
    }


    my $nf = scalar(@{$fieldNames});
    for (my $i=1; $i<=$nf; $i++) {
        if (!$fieldNames->[$i]) {
            $fieldNames->[$i] = "F_$i";
        }
        else {
            my $h = $fieldNames->[$i];
            if (!$self->isOkFieldName($h)) {
                $fieldNames->[$i] = $self->cleanFieldName($h);
                alogging::vMsg(
                    0, "Bad field name in header: ",
                    "#$i: '$h' (converted to '" . $fieldNames->[$i] . "').");
            }
        }
    } # for
    alogging::vMsg(1, "readAndParseHeader: field names: ( " .
                      join(", ", @{$fieldNames}) . ")");
    alogging::vMsg(0, "About to set setFieldNamesFromArray");
    $self->{dsch}->setFieldNamesFromArray($fieldNames);
    return($fieldNames);
} # readAndParseHeader

# Skips comments, should only stop at real records.
sub TabularFormats::readRecord {
    my ($self) = @_;
    #alogging::vMsg(2, "$tf:readRecord. impl: ", ref($self->{formatImpl}));
    my $rec = $self->{formatImpl}->readRecord();
    #alogging::vMsg(2, "$tf:readRecord: Got logical rec:\n  ", $rec);
    return($rec);
}

sub TabularFormats::parseHeader {
    my ($self, $rec) = @_;
    my $fieldNames = $self->{formatImpl}->parseHeader($rec);
    $self->{dsch}->setFieldNamesFromArray($fieldNames); ### @@@ ???
    return($fieldNames);
}
sub TabularFormats::parseRecord { # OBS
    my ($self, $rec) = @_;
    if (!$self->{gaveObsMsg}) {
        alogging::eMsg(1,"$tf: obsolete, use parseRecordToArray().");
        $self->{gaveObsMsg} = 1;
    }
    return($self->{formatImpl}->parseRecordToArray($rec));
}

# Preferably, parse to Hash first, then arrange into an array.
# But can't do that if there wasn't a header or some def of field names to use.
# In that case, parseRecordToHash should set up field names automatically.
#
sub TabularFormats::parseRecordToArray {
    my ($self, $rec) = @_;
    my $hRef = $self->{formatImpl}->parseRecordToHash($rec);
    if (sjdUtils::getVerbose()) {
        alogging::vMsg(1, "$tf:parseRecordToArray for record :\n    '$rec'.");
        alogging::vMsg(1, "$tf: parseRecordToHash returned:");
        for my $k (sort keys %{$hRef}) {
            alogging::vMsg(1, sprintf("    %-24s '%s'", $k, $hRef->{$k}));
        }
    }
    if (0 && !$self->{parsedARecord} && $self->{dsch}->getNSchemaFields()==0) {
        alogging::vMsg(1, "$tf:parseRecordToArray: Looks like header.");
        my @fnames = keys(%{$hRef});
        my $nf = scalar(@fnames);
        alogging::vMsg(1, "$tf:parseRecordToArray: Adding fields to make schema.");
        for (my $i=0; $i<$nf; $i++) {
            $self->{dsch}->appendField($fnames[$i]);
        }
    }
    $self->{parsedARecord} = 1;
    my $nkeys = scalar keys %{$hRef};
    if ($nkeys != $self->{dsch}->getNSchemaFields()) {  # +1???
        alogging::vMsg(1, "$tf:parseRecordToArray: $nkeys hash fields but " .
            ($self->{dsch}->getNSchemaFields()) . " schema fields.");
    }
    my @vals = ("");
    for (my $i=1; $i<=scalar keys %{$hRef}; $i++) {
        my $fDef = $self->{dsch}->{fDefsByNumber}->[$i];
        push @vals, $fDef->{fName};
    }
    return(\@vals);
}
sub TabularFormats::parseRecordToHash {
    my ($self, $rec) = @_;
    my $fields = $self->{formatImpl}->parseRecordToHash($rec);
    #$self->setRecordFromHash($fields);
    $fields = $self->postProcessFields($fields);
    $self->{parsedARecord} = 1;
    return($fields);
}
sub TabularFormats::postProcessFields {
    my ($self, $fieldHashRef) = @_;
    return($self->{formatImpl}->postProcessFields($fieldHashRef));
}

sub TabularFormats::assembleRecord { # OBS
    my ($self, $aRef) = @_;
    return($self->{formatImpl}->assembleRecordFromArray($aRef));
}
sub TabularFormats::assembleRecordFromArray {
    my ($self, $aRef) = @_;
    return($self->{formatImpl}->assembleRecordFromArray($aRef));
}
sub TabularFormats::assembleField {
    my ($self, $fDef, $value) = @_;
    return($self->{formatImpl}->assembleField($fDef,$value));
}
sub TabularFormats::assembleComment {
    my ($self, $text) = @_;
    return($self->{formatImpl}->assembleComment($text));
}
sub TabularFormats::assembleRecordFromHash {
    my ($self, $hRef) = @_;
    return($self->{formatImpl}->assembleRecordFromHash($hRef));
}
sub TabularFormats::assembleHeader {
    my ($self) = @_;
    return($self->{formatImpl}->assembleHeader());
}
sub TabularFormats::assembleTrailer {
    my ($self) = @_;
    return($self->{formatImpl}->assembleTrailer());
}

# End of TabularFormats package


###############################################################################
# "pull" style parsing (not provided by SAX).
# Call start_file(), start_string(), or start_fh()
#
package pull_parser;

sub pull_parser::new {
    my ($class, $owner, $optionsHash) = @_;

    my $self = {
        owner         => $owner,
        data          => "",
        pendingEvents => [],
        DONE          => 0,
    }; # self

    bless $self, $class;

    if (defined $optionsHash && ref($optionsHash) eq "HASH") {
        $self->setOptionsFromHash($optionsHash);
    }

    $self->queueEvent("Init");
    $self->queueEvent("Start", "table");
}

sub pull_parser::clear_data { # pull_parser
    my ($self, $s) = @_;
    $self->data = "";
}

sub pull_parser::add_data { # pull_parser
    my ($self, $s) = @_;
    $self->data .= $s;
}

sub pull_parser::pull_more { # pull_parser
    my ($self) = @_;

    if ($self->{DONE}) {
        $self->{pendingEvents} = [];
        return(undef);
    }

    # Load one record and create the SAX-like events it represents.
    if (scalar(@{$self->{pendingEvents}}) <= 0) {
        if (my $rec = $self->readRecord()) {
            $self->queueEvent("Start", "tr");
            my @fields = @{$self->parseRecordToArray($rec)};
            for (my $i=1; $i<scalar(@fields); $i++) {
                $self->queueEvent(
                    "Start", "td", "class",
                    $self->{dsch}->getFieldDefByNumber($i)->{fName});
                $self->queueEvent("Text",  $fields[$i]);
                $self->queueEvent("End", "td");
            }
            $self->queueEvent("End", "tr");
        }
        else {
            $self->queueEvent("Fin");
        }
    }

    # Return the first pending event.
    return(shift @{$self->{pendingEvents}});
}

sub pull_parser::pull_done { # pull_parser
    my ($self) = @_;
    $self->{DONE} = 1;
}

sub pull_parser::queueEvent { # pull_parser
    my $self = shift;
    my $e    = shift;
    push @{$self->{pendingEvents}}, \@_;
}


###############################################################################
# This package is instantiated by TabularFormats::parse_start(), whose
# caller then calls our parse_more() method until done.
#
package ExpatNB;

sub ExpatNB::new {
    my ($class, $owner, $optionsHash) = @_;

    my $self = {
        owner         => $owner,
        data          => "",
        pendingEvents => [],
        DONE          => 0,
    }; # self

    bless $self, $class;

    if (defined $optionsHash && ref($optionsHash) eq "HASH") {
        $self->setOptionsFromHash($optionsHash);
    }

    $self->queueEvent("Init");
    $self->queueEvent("Start", "table");
}

sub ExpatNB::clear_data { # ExpatNB
    my ($self) = @_;
    $self->data .= "";
}

sub ExpatNB::parse_more { # ExpatNB
    my ($self, $s) = @_;

    if ($self->{DONE}) {
        $self->{pendingEvents} = [];
        return(undef);
    }

    $self->data .= $s;
    if (scalar(@{$self->{pendingEvents}}) <= 0) {
        if (my $rec = $self->readRecord()) {
            $self->queueEvent("Start", "tr");
            my @fields = @{$self->parseRecordToArray($rec)};
            for (my $i=1; $i<scalar(@fields); $i++) {
                $self->queueEvent(
                    "Start", "td", "class",
                    $self->{dsch}->getFieldDefByNumber($i)->{fName});
                $self->queueEvent("Text",  $fields[$i]);
                $self->queueEvent("End", "td");
            }
            $self->queueEvent("End", "tr");
        }
        else {
            $self->queueEvent("Fin");
        }
    }
    return(pop @{$self->{pendingEvents}});
}

sub ExpatNB::parse_done { # ExpatNB
    my ($self) = @_;
    $self->{DONE} = 1;
}

sub ExpatNB::queueEvent { # ExpatNB
    my $self = shift;
    my $e    = shift;
    push @{$self->{pendingEvents}}, \@_;
}


###############################################################################
# Options
# The datatypes are drawn from Datatypes.pm, which is based on XSD.
#
package DataOptions;

my $dop = "TF::DataOptions"; # For messages

sub DataOptions::new {
    my ($class) = @_;

    my $self = {
        theDataTypes  => new Datatypes(),
        optionPrefix  => "",
        optionFormats => {},
        optionTypes   => {},
        optionTypeReps=> {},
        optionHelps   => {},
        optionDefaults=> {},
        options       => {},
    };

    bless $self, $class;
    $self->defineOptions();
    return $self;
} # new

# See TFormatSupport.pm for option details.
#     Called from constructor.
#     Split these into the individual format subclasses.
#
sub DataOptions::defineOptions {
    my ($self) = @_;
    #                    Name            Datatype Name        Default
    # General options
    #
    $self->defineOption("ALL", "basicType"    , "string"          , "CSV",
        "Name of the format to apply.");

    $self->defineOption("ALL", "ASCII"        , "boolean"          , 0,
        "Reduce output to just ASCII.");
    $self->defineOption("ALL", "comment"      , "string"           , "",
        "Comment delimiter.");
    $self->defineOption("ALL", "TFverbose"    , "integer"          , 0,
        "Level of messages provided.");
    $self->defineOption("ALL", "encoding"     , "Name"             , "utf-8",
        "Character set to use.");
    $self->defineOption("ALL", "stripStart"   , "boolean"          , 0,
        "Remove whitespace from start of records?");
    $self->defineOption("ALL", "stripFields"  , "boolean"          , 1,
        "Remove whitespace from start and end of fields?");
    $self->defineOption("ALL", "stripRecords" , "boolean"          , 0,
        "Remove whitespace from start and end of records?");
    $self->defineOption("ALL", "typeCheck"    , "boolean"          , 1,
        "Do type checking on options?");

    # ARFF options
    #
    $self->defineOption("ARFF", "sparse"       , "boolean"          , 0,
        "ARFF: Create sparse-format when possible?");

    # COLUMNS options
    #

    # CSV options
    #
    $self->defineOption("CSV", "header"       , "boolean"          , 0,
        "CSV: Header record?");
    $self->defineOption("CSV", "tableSep"     , "string"           , "",
        "CSV: String separating entire tables.");
    $self->defineOption("CSV", "recordSep"    , "string"           , "\n",
        "CSV: String separating records.");
    $self->defineOption("CSV", "fieldSep"     , "string"           , "\t",
        "CSV: String separating fields.");

    $self->defineOption("CSV", "quote"        , "string"           , '"',
        "CSV: Quote character.");
    $self->defineOption("CSV", "nlInQuotes"   , "boolean"          , 0,
        "CSV: Allow newlines inside quotes field values?");
    $self->defineOption("CSV", "qdouble"      , "boolean"          , 0,
        "CSV: Escape quotes by doubling?");
    $self->defineOption("CSV", "qstray"       , "boolean"          , 0,
        "CSV: Are unescaped quotes allowed in field values?");

    $self->defineOption("CSV", "escape"       , "string"           , "",
        "CSV: Escape character?");
    $self->defineOption("CSV", "escape2hex"   , "string"           , "",
        "");

    # JSON options
    #
    $self->defineOption("JSON", "jsonArray"     , "boolean"         , 0,
        "JSON: Should the top-level be an array (vs. a hash)?");

    # MANCH options
    #
    $self->defineOption("MANCH", "typeField"    , "string"          , 78,
        "MANCH: What field has 'type'.");

    # MIME options
    #
    $self->defineOption("MIME", "lineLength"   , "integer"          , 78,
        "MIME: Max line length to output.");

    # SEXP options
    #

    # XML (incl. HTML) options
    #
    $self->defineOption("XML", "HTMLEntities" , "boolean"          , 0,
        "XML: Use HTML named entities?");
    $self->defineOption("XML", "XMLDecl"      , "boolean"          , 0,
        "XML: Write an XML Declaration?");
    $self->defineOption("XML", "XMLEntities"  , "boolean"          , 1,
        "XML: Use the 5 built-in XML entities?");
    $self->defineOption("XML", "colspecs"     , "boolean"          , 0,
        "XML: Create col elements in output tables?");
    $self->defineOption("XML", "entityBase"   , "integer"          , 16,
        "XML: Base 10 or 16 for numeric character references.");
    $self->defineOption("XML", "entityWidth"  , "integer"          , 4,
        "XML: Minimum number of digits for numeric character references.");
    $self->defineOption("XML", "idValue"      , "string"           , "",
        "XML: ");
    $self->defineOption("XML", "prettyPrint"  , "boolean"          , 1,
        "XML: Add whitespace to output for readability?");
    $self->defineOption("XML", "publicId"     , "string"           , "",
        "XML: PUBLIC identifier to write.");
    $self->defineOption("XML", "systemId"     , "string"           , "",
        "XML: SYSTEM identifier to write.");

    # X(HT)ML tag and attribute name substitutions
    #
    $self->defineOption("HTML", "htmlTag"      , "Name"             , "html",
        "XML: Tag to use in place of 'html'");
    $self->defineOption("HTML", "tableTag"     , "Name"             , "table",
        "XML: Tag to use in place of 'table'");
    $self->defineOption("HTML", "theadTag"     , "Name"             , "thead",
        "XML: Tag to use in place of 'thead'");
    $self->defineOption("HTML", "tbodyTag"     , "Name"             , "tbody",
        "XML: Tag to use in place of 'tbody'");
    $self->defineOption("HTML", "trTag"        , "Name"             , "tr",
        "XML: Tag to use in place of 'tr' (row)");
    $self->defineOption("HTML", "tdTag"        , "Name"             , "td",
        "XML: Tag to use in place of 'td' (field)");
    $self->defineOption("HTML", "thTag"        , "Name"             , "th",
        "XML: Tag to use in place of 'th' (field in header)");
    $self->defineOption("HTML", "pTag"         , "Name"             , "p",
        "XML: Tag to use in place of 'p' (sub-fields)");
    $self->defineOption("HTML", "classAttr"    , "Name?"            , "",
        "XML: Attribute name to use in place of 'class'");
    $self->defineOption("HTML", "idAttr"       , "Name?"            , "id",
        "XML: Attribute name to use in place of 'id'");
    $self->defineOption("HTML", "attrFields"   , "string?"          , "",
        "XML: Attributes to treat as additional fields");

    # XSV options
    #
    $self->defineOption("XSV", "typeCheck"    , "boolean"          , 0,
        "XSV: Enable type checking of input?");
    $self->defineOption("XSV", "omitDefaults" , "boolean"          , 0,
        "XSV: Don't write out values that match their defaults?");
} # defineOptions

sub DataOptions::defineOption {
    my ($self, $fmt, $optionName, $dtName, $default, $doc) = @_;
    (my $dtName2 = $dtName) =~ s/(\W+)$//; # Strip repetition indicator
    my $rep = $1 || "";
    if (!$self->{theDataTypes}) {
        alogging::eMsg(0,"$dop: Datatypes not set up.\n");
    }
    elsif (!$dtName) {
        alogging::eMsg(-1,"$dop: No data type for '$optionName'.\n");
    }
    elsif (!$self->{theDataTypes}->isKnownDatatype($dtName2)) {
        alogging::eMsg(-1,"$dop: Unknown datatype '$dtName' " .
            "for '$optionName'.\n");
    }
    $self->{optionFormats} ->{$optionName} = $fmt;
    $self->{optionTypes}   ->{$optionName} = $dtName2;
    $self->{optionTypeReps}->{$optionName} = $rep;
    $self->{optionDefaults}->{$optionName} = $default;
    $self->{options}       ->{$optionName} = $default;
    $self->{optionHelps}   ->{$optionName} = $doc || "";
    return(1);
} # defineOption

sub DataOptions::setOptionsFromHash {
    my ($self, $optionsHash) = @_;
    for my $opt (keys(%{$optionsHash})) {
        $self->setOption($opt,$optionsHash->{$opt});
    }
}
sub DataOptions::getOptionsHash {
    my ($self) = @_;
    my %copy = %{$self->{options}};
    return(\%copy);
}
sub DataOptions::getOptionHelps {
    my ($self) = @_;
    my %copy = %{$self->{optionHelps}};
    return(\%copy);
}

# Check that the options seem consistent and valid...
#
sub DataOptions::readyCheck {
    my ($self) = @_;
    if ($self->options->{"basicType"} eq "CSV") {
        if (!$self->options->{"fieldSep"}) {
            alogging::eMsg(0, "No fieldSep set.");
            return(0);
        }
        if (($self->options->{"qdouble"} || $self->options->{"nlInQuotes"}) &&
            !$self->options->{"quote"}) {
            alogging::eMsg(0, "qdouble or nlInQuotes set, but no quote char.");
            return(0);
        }
    }
    return(1);
}

# WARNING: Calling this directly to set basicType, will not cause
# chooseFormat() to be called as needed!
#
sub DataOptions::setOption {
    my ($self, $original, $value) = @_;
    alogging::vMsg(
        2, "  $dop:setOption: '$original'=$value, caller " .
        alogging::whereAmI(1));

    (defined $original) || alogging::eMsg(
        -1, "$dop:setOption: undefined name passed.");
    (defined $value) ||  alogging::eMsg(
        -1, "$dop: undefined value for '$original'.");

    my $name = $self->fixOptionName($original);
    if (!defined $self->{options}->{$name}) {
        alogging::eMsg(1, "$dop: Bad option '$name'.");
        alogging::eMsg(2, $self->toString());
        return(undef);
    }

    if (index($value, "\\")>=0) { # INTERPRET BACKSLASH CODES
        $value = sjdUtils::unbackslash($value);
    }

    # Datatype checks, if enabled.
    if (!$self->{theDataTypes}) {
        $self->{options}->{$name} = $value;
    }
    else {
        (my $type = $self->{optionTypes}->{$original}) || return(undef);
        my $rep = $self->{optionTypeReps}->{$original};
        my $req = ($rep =~ m/^(|!|\+)$/) ? 1:0;
        # "?" arg indicates nil is ok, "!" indicates value is required.
        # This should be in the actual datatype spec above.
        if ($req &&
            !$self->{theDataTypes}->checkValueForType($type,$req,$value,1)) {
            alogging::eMsg(
                0, "$dop: Invalid value '$value' for option '$name'");
            return(undef);
        }

        if ($self->{theDataTypes}->isNumericDatatype($type)) {
            $self->{options}->{$name} = $value + 0;
        }
        else {
            $self->{options}->{$name} = $value . '';
        }
    } # datatypes

    return($value);
} # setOption

sub DataOptions::hasOption {
    my ($self, $original) = @_;
    my $name = $self->fixOptionName($original);
    return(defined $self->{options}->{$name});
}

sub DataOptions::getOption {
    my ($self, $original) = @_;
    if (!$original) {
        alogging::eMsg(1, "$dop: Missing option name.");
        return(undef);
    }
    my $name = $self->fixOptionName($original);
    if (!defined $self->{options}->{$name}) {
        alogging::eMsg(1, "$dop: Bad option '$name'");
        return(undef);
    }
    my $value = $self->{options}->{$name};
    if ($value && index($value, "\\")>=0) { # ESCAPE ANY BACKSLASHES
        $value =~ s/\\/\\\\/g;
    }
    return($value);
}

sub DataOptions::getOptionType {
    my ($self, $name) = @_;
    if (!$name) {
        alogging::eMsg(1, "$dop: Missing option name.");
        return(undef);
    }
    $name = $self->fixOptionName($name);
    my $type = $self->{optionTypes}->{$name};
    if ($type) { return($type); }
    alogging::eMsg(
        1, "$dop: Bad option name '$name'" .
        ", known options: (" . join(", ", keys %{$self->{optionTypes}}) . ").");
    return(undef);
}
sub DataOptions::fixOptionName { # Synonyms for backward compatibility
    my ($self, $name) = @_;
    if ($name eq "delim") {
        $name = "fieldSep";
    }
    elsif ($self->{prefix} && $name eq $self->{prefix} . "delim") {
        $name = $self->{prefix} . "fieldSep";
    }
    return($name);
}

sub DataOptions::toString {
    my ($self) = @_;
    my $buf = "";
    my %opts = %{$self->{options}};
    for my $o (sort keys %opts) {
        $buf .= sprintf(" %-16s %s\n", $o, $opts{$o});
    }
    return($buf);
}

# End of DataOptions package.


###############################################################################
#
if (!caller) {
    system "perldoc $0";
}

1;
