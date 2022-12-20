#!/usr/bin/env perl -w
#
# sjdUtils: some generally useful Perl crud.
# Started around 2011-03-25 by Steven J. DeRose.
# There is also a Python version.
#
package sjdUtils;

use strict;
use Scalar::Util;
use Encode;
use Exporter;
#use HTML::Entities;

use ColorManager;
use alogging;

our %metadata = (
    'title'        => "sjdUtils.pm",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2011-03-25",
    'modified'     => "2022-12-19",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};

=pod

=head1 Usage

    use sjdUtils;

Provide some very basic useful utilities used by many of my other scripts.
Mostly for escaping, colorizing, handling error messages, as well as
pretty-printing XML, strings, numbers, and times; wrapping text;....

Some of my other scripts use this. If you're using one of them, install
this and make sure Perl can find it via the C<@INC> directory-list
(part of which is taken from the environment variable C<PERL5LIB> --
see L<here|"http://stackoverflow.com/questions/2526804">).

B<Note>: Unless you call I<setColors(1)> and I<setVerbose(n)>, you might
not get the output you want (see C<alogging.pm> for details).

B<Note>: A Python version of this package is also available.


=head1 Options

(prefix "no" to negate where applicable)

=over

=item * B<getUtilsOption>I<(name)>

Get the value of option I<name>, from the list below.
Returns C<undef> if you try to get an unknown option.

=item * B<setUtilsOption>I<(name, value)>

Set option I<name>, from the list below, to I<value>.
A warning will be printed if you try to set an unknown option.

=over

=item * I<colorEnabled> (boolean)

Globally enable/disable use of color.
Call this with a I<--color> option value (or equivalent)
from other scripts (mine default to on if environment variable I<CLI_COLOR> is
set and the relevant output is going to a terminal.
This is accomplished via my C<ColorManager.pm>.

=item * I<loremText> (string)

The text to be returned by I<lorem()>.
Default: the usual I<lorem ipsum...>, but you can set something else,
or generate random text and/or ensure there's a bunch of non-Latin 1 in there.

=item * I<plineWidth>

The number of columns to use for labels in messages printed with I<pline()>.

=item * I<stdout> (boolean)

Redirect STDERR messages to STDOUT instead.

=item * I<TEEFILE> (fileHandle)

If set, I<vMsg> etc. not only to write messages to STDERR,
but also to the file at I<fileHandle>. The caller is responsible for opening and closing
that file. No color escapes are written into the log file.

=item * I<verbose> (int)

Just forwards to the C<alogging> package.
I<vMsg>, I<hWarn>, and I<eWarn>
discard any requests whose first argument is greater than the
I<verbose> setting.
Messages use lower numbers for higher importance (priority).
Negative levels passed to I<eWarn> indicate fatal errors.

=item * I<indentString> (string)

The string used by I<vMsg>() to create indentation according to the level
set by I<vPush>(), I<vPop>, etc.

=back

=back


=head2 Color Names

The color names available are defined in F<Color/colorNames.pod>.
That supercedes documentation in specific scripts (they I<should> match).

Briefly, color names consist of I<foreground/background/effect>. For example:
    red/blue/bold

The base color names are
black, red, green, yellow, blue, magenta, cyan, white.
These are ANSI numbers 30-37 for foreground, and 40-47 for background.


=head2 Color methods available directly in C<sjdUtils>

Commonly-needed color functions are defined in C<sjdUtils>,
so you can just call them as part of C<sjdUtils>.
In fact, they just forward to the implementations in C<ColorManager>.

=over

=item * B<setColors>I<(b)>

Set up color handling; if I<b> is false, disables color.
Returns a reference to a hash with entries for the basic foreground colors
and "off", with the values being the escape-sequences for them.

=item * B<getColorString>I<(name)>

Return the ANSI escape sequence to obtain the named color
(see previous sections).

B<Note>: If I<setColors>() has not already been called,
then calling I<getColorString>() will call it first.

=item * I<colorize(colorName, message, endAs)>

If color is enabled, then surround I<message> with ANSI color escapes for
the specified named color. If I<endAs> is specified, it is used as a
color name to switch to at the end of the I<message> (instead of "off").

If I<colorName> is unknown, I<message> is returned unchanged.
If the last character of I<message> is a newline, then the color will be
turned off I<before> rather than after the newline itself, so Perl won't
complain if you pass the result to C<warn>.

B<Note>: The ANSI escape sequence to switch to a given color, is
available via C<sjdUtils::getColorString(name)>.
See also the C<colorstring> command-line utility, which can supply
colors in the forms needed for C<bash> prompt string or declarations in Perl
or Python; and can display lists and samples of the various colors.

=item * B<uncolorize>I<(message)>

Remove any ANSI terminal color escapes from I<message>.

=back

There are various other methods available in C<ColorManager>, which
are I<not> available directly in C<sjdUtils>.

=head2 Colorized and level-filtered messages

=over

=item * B<setVerbose>I<(level)>

Synonym for I<setUtilsOption("verbose", level)>.

=item * B<getVerbose>I<()>

Synonym for I<getUtilsOption("verbose")>.

=item * B<eMsg>I<(rank, message1, message2)> or B<eWarn>

Issue an error message if the current verbosity-level is high enough
(that is, it is at least as great as abs(I<rank>)). See I<setVerbose>.
If I<rank> is negative, the program is terminated.

=item * B<hMsg>I<(rank, message1, message2)> or B<hWarn>

Deprecated in favor of vMsg with message starting with "====".

=item * B<vMsg>I<(rank, message1, message2)> or B<vMsg>
Issue an informational message if the current setting for
I<verbose> is greater than I<rank>. See I<setVerbose>.
A newline is added after I<message2>.
If I<MsgPush> has been called, the message will be indented appropriately.

=item * B<MsgPush>() or B<vPush>()

Increment the message-nesting level, which causes indentation for messages
displayed via I<vMsg>. This is mainly useful for messages that reflect
successive levels of processing on input data (for example, notices about
each file, record, and field). The string to repeat to make indentation can
be set with I<setUtilsOption("indentString", string)>.

=item * B<MsgPop>() or B<vPop>()

Decrement the message-nesting level (see I<MsgPush>).

=item * B<vSet>(n)

Force the message-nesting level to I<n> (see I<MsgPush>).

=item * B<vGet>()

Return the message-nesting level (see I<MsgPush>).


=item * B<whereAmI>I<(n)>

Return the package and function name of the caller. If I<n> is supplied,
describe the I<n>th ancestor of the called instead.

=item * B<Msg>I<(typeOrColor, message1, message2)>

If I<typeOrColor> is a defined message type name, issue a message with
the corresponding settings.
Otherwise, if I<typeOrColor> is a known L<Color Name>, issue a message
in that color, unconditionally, with no stack trace.
Otherwise (including if I<typeColor> is
0, "", or undef), issue the message in the default color, with no stack trace.

=item * B<pline>I<(label, data, denominator?)>

Print a line to STDOUT (not STDERR), with I<label> padded to some constant
width, and I<data> printed as appropriate for being integer, real, or string.
If I<data> is numeric and I<denominator> is also present and non-zero,
then 100.0*data/denominator will also be printed, with a following "%".
Good for printing various reports and statistics.
You can set the width used for labels with C<setUtilsOption('plineWidth', n)>.


=item * B<setStat(name, value)>

=item * B<getStat(name)>

=item * B<bumpStat(name, amount)>

I<amount> defaults to 1.

=item * B<maxStat(name, value)>

Set the named statistic to I<value>, but only if I<value> is greater than the
current value of the statistic.

=back


=head2 XML formatting

See below under L<here|"Escaping and Unescaping"> for functions to prepare
strings for use as XML content, attribute values, etc.
See the C<XmlOutput.pm> package for more extensive features.

=over

=item * B<indentXml>I<(s, indentString?, maxIndent?, breakEnds?, elementInfo?)>

Insert newlines and indentation in an XML string I<s> for pretty-printing.
Does not use an actual parser, but is quick and pretty reliable
("<" inside comments, PIs, or markup declarations may trip it up).
You can safely use I<colorizeXmlTags>() or I<colorizeXmlContent>()
after I<indentXml>().

I<indentString> (default C<    >) is the string to repeat to create indentation.
I<maxIndent> is the maximum number of levels of indentation to use
(default: 0 = unlimited).
I<breakEnds> determines whether end-tags get separate lines.
I<elementInfo> is a reference to a hash that maps element type names
to either "block" or "inline", and causes any listed element types to be
displayed in the indicated fashion.


=item * B<isXmlChar>, B<isXmlSpaceChar>, B<isXmlNameStartChar>, B<isXmlNameChar>

Return true iff the single-character argument I<c>
is a legitimate XML character of a particular type.
These do the real check per the XML REC.

=item * B<isXmlName>I<(n)>, B<isXmlNmtoken(n)>

Return true iff I<n> is a legitimate XML C<Name> or C<Nmtoken>.

=item * B<makeXmlName>I<(n)>

If I<n> is not a legitimate XML C<Name>, make it one.
Entirely disallowed characters are replaced by C<_>;
a disallowed I<first> character causes C<_> to be prefixed.

=item * B<escapeXmlName> I<(n, asciiOnly)>

Like I<makeXmlName>(), but instead of replacing illegal characters with "_",
it changes them to a hyphen plus 4 hexadecimal digits (it also
replaces hyphen in the same way). If the I<ascii> flag is present and true,
all non-ASCII characters are also so converted.
This way, no information is lost.

=item * B<unescapeXmlName> I<(n)>

Undoes the transformation of C<escapeXmlName>.

=back


=head2 JSON formatting

See also I<Escaping and Unescaping>, below.

=over

=item * B<indentJson> I<(s, iString, maxIndent)>

Pretty-print the JSON string I<s>,
using I<iString> to build indentation (default "  "), and
not indenting more than I<maxIndent> levels (default: 0 = unlimited).

=back


=head2 Minor formatting tweaks and tools

=over

=item * B<wrap>I<(text, indent, width, breakChar)>

Wrap a block of I<text> to a given I<width> (default 80) and
I<indent>ation (default 0).
Only breaks at the specified I<breakChar> (default space) unless that's
not possible (say, 80 non-spaces in a row), in which case it just breaks
arbitrarily at C<width>.

=item * B<lengthInBytes>I<(s)>

Return the length of the string s measured in bytes (via 'use bytes').

=item * B<lengthInChars>I<(s)>

Return the length of the string s measured in Unicode code points (more or less,
"characters"). (via 'Encode::_utf8_on()').

=item * B<isUpper>I<(s)>

Return true iff the first character of I<s> is upper-case.

=item * B<isLower>I<(s)>

Return true iff the first character of I<s> is lower-case.

=item * B<isCapitalized>I<(s)>

Returns true iff the string I<s> starts with a capital letter and has no other
capitals.
Thus, a string containing multiple capitalized words returns false,
as do names like "DeRose", all-cap acronyms, and all-caps strings such as headings.
What happens with Titlecase Unicode chars is not yet defined.
("" returns false).

=item * B<sc>I<(s, forceRest)>
Applies sentence-case to the string
I<s>: capitalize the first letter.
If I<forceRest> is present and true, all I<other> characters in I<s>
will be forced to lower case.

=item * B<tc>I<(s, forceRest)>

Title-cases the string I<s>: capitalize the first letter of each word.
If I<forceRest> is present and true, all I<other> characters in each
word will be forced to lower case.

=item * B<ssubstr>I<(s, start, len)>

The same as Perl I<substr>, except that:

=over

=item * if I<s> is undefined or shorter than I<start>+1 characters,
or I<len> is nonpositive, then it just quietly returns ""; and

=item * if I<len> would reach beyond the end of I<s>, it just quietly
returns everything from I<start> to the end.

=back

=item * B<cpad>I<(string, n, char, quoteChar)>

Pad I<string> on both ends (thus, approximately centering it)
out to a length of at least I<n> characters (default: 0),
using I<char> as the pad character (default: space).
If I<quoteChar> is specified, add it at each end I<before> padding.

=item * B<rpad>I<(string, n, char, quoteChar)>

Like I<cpad>, but pad only on the right (end).

=item * B<lpad>I<(string, n, char, quoteChar)>

Like I<rpad( )> and I<cpad( )> except that it pads on the left,
and I<char> defaults to "0" instead of space.

=item * B<lpadc>I<(string, n, char, sep)>

Like I<lpad( )> except that it inserts I<sep> (default: comma) before
each group of 3 characters counting from the right (end) of I<string>.
After that, it left-pads with spaces to the final width.

=item * B<trim>I<(string)>

Remove whitespace characters from the start and end of I<string>.

=item * B<ltrim>I<(string)>

Remove whitespace characters from the start of I<string>.

=item * B<rtrim>I<(string)>

Remove whitespace characters from the end of I<string>.

=item * B<toHNumber>I<(n, flag)>

Convert a number to the human-readable format for large numbers,
like the I<-h> option of many *nix commands (that is, factor out
powers of 1024 (or 1000 if I<flag> is true) in favor of suffixes [KMGTPEZY]).
Only 2 post-decimal digits of precision are kept (therefore,
fromHNumber(toHNumber(n)) is not usually exactly n).

=item * B<fromHNumber>I<(s, flag)>

Convert I<s>, which should be a number (not necessarily an integer),
optionally with a unit suffix, to the full number.
The suffix must be one of [KMGTPEZY] (optionally followed by "i", since
usage varies); representing powers of 1024 (if I<flag> is absent or false),
or 1000 (if I<flag> is true).
The number is multiplied by the factor implied by the suffix, and
the suffix is removed.

=item * B<isNumeric>I<(n)>

Returns 1 if and only if I<n> can be interpreted as numeric: an optionally
signed decimal integer or real, optionally in exponential notation.

=item * B<isInteger>I<(n)>

Returns 1 if and only if I<n> can be interpreted as an integer (optional
sign plus one or more decimal digits). "1.0" doesn't count.

=item * B<isUnicodeCodePoint>I<(n)>

Returns 1 if the integer I<n> corresponds to a legitimate Unicode
character. Thus, it must be positive, smaller than 0x110000,
and not one of a few special values like 0xFFFE or 0xFFFF.
This method does not check whether the code point is actually
assigned to a character (about 75% aren't, as of this writing).

This is not the only concern about characters. Some software can only deal
with Unicode's BMP; some doesn't like surrogates; XML doesn't like control
characters; much software croaks on nulls, and many files claim to be Unicode
but use some characters incorrectly (especially d128-d159).

=item * B<getUTF8>(n, sep)

Returns a string containing the bytes for the
UTF-8 representation of the character at code point I<n>.
I<sep> is placed before each byte's 2 hex digits. If may be "" (to have no
separators inserted), but if it is I<not defined> it defaults to "%",
as needed for URIs.
For example, I<getUTF8(3000)> returns "%e0%ae%b8".

=back


=head2 Escaping and Unescaping

=over

=item * B<makePrintable>I<(c, mode, spaceAs, lfAs)>

Mainly internal, this is what I<showControls> and I<showInvisibles>
call to get a representation
for each character to change. Arguments are like I<showControls>.

=item * B<showControls>I<(s, spaceAs, lfAs)>

Return the string I<s>, with control characters and spaces replaced by
the corresponding Unicode "control symbol" characters (U+2400 and following).
These typically are little mnemonics, such as "ESC" and "CR",
packed into the space of one normal character.
For space and line feed, you can choose what to show, via the
corresponding options (see I<showInvisibles> for details).

=item * B<showInvisibles>I<(s, mode, spaceCode, lfCode)> or B<vis>I<(...)>

Return the string I<s>, with non-ASCII and control characters replaced by
more visible codes. I<mode> can be used to determine some details of
the replacements. By default, uses the same range of escapes as I<backslash>
The I<mode> values are ("OK" means char is unchanged):

   Mode        <d27  d27-d31  ASCII  Latin1  Other
   -------------------------------------------------------------
    'DFT'      \xFF    \xFF     OK   \xFF    \x{FFF}
    'C'        ^A-^Z   \xFF     OK   \xFF    \x{FFF}
    'SYM'      U+2400  +xx      OK   \xFF    \x{FFF}
    'LATIN1'   \xFF    \xFF     OK   OK      \x{FFF}
    'XML'      &#xF;   &#xF;    OK   &#xF;   \x{FFF}

Option I<spaceCode> determines what Unicode code point value
is used to display the space character:
    32 (U+0020) or "OK" or is the default, and leaves it unchanged.
    "SP" or 0x2420 shows a little "SP" symbol;
    "B" or 0x2422 shows a "b" with a slash through it;
    "U" or 0x2423 shows an underscore with serifs.

Option I<lfCode> determines what Unicode code point value
is used to display the Line Feed character:
    "OK" or is the default, and leaves it unchanged.
    "NL" shows a little "NL" symbol;
    "LF" shows a little "LF" symbol;

=item * B<escapeJson> I<(s, asciiOnly)>

Backslash any characters that are reserved within JSON strings.
If I<asciiOnly> is present and true, also replace non-ASCII characters
with \uXXXX codes.

=item * B<escapeRegex> I<(s, additionalChars)>

Put backslashes in front of potential regex meta-characters in I<s>.
Any characters in I<additionalChars> will also be escaped (perhaps the
most likely case is "/", so that the string can be used in eval'ing a regex
operation using "/" as the delimiter).

=item * B<escapeXml> I<(s, asciiOnly)> or B<escapeXmlContent> I<(s, asciiOnly)>

Turn ampersands, less-than signs, and any greater-than signs that are
preceded by two close square brackets, into XML predefined entity references.
Also delete any non-XML C0 control characters.
This is the needed escaping for XML text content.
If I<asciiOnly> is present and true, non-ASCII characters will also be replaced
by hexadecimal numeric character references.

=item * B<escapeXmlAttribute> I<(s, apos, asciiOnly)>

Turn ampersands, less-than signs, and double-quotes
into XML predefined entity references. If I<apos> is true, then leave
double-quotes unchanged, but turn single-quotes into C<&apos;> instead.
Also delete any non-XML C0 control characters.
This is the needed escaping for XML attribue values.
If I<asciiOnly> is present and true, non-ASCII characters will also be replaced
by hexadecimal numeric character references.

=item * B<escapeXmlPi> I<(s, asciiOnly)>

Turns "?>" into "?&gt;". Because that could collide with other uses of "&", also
turns "&" into "&amp;".
XML does not specify an escaping mechanism
within Processing Instructions, so this just uses one obvious choice.
If I<asciiOnly> is present and true, non-ASCII characters will also be replaced
by hexadecimal numeric character references.

=item * B<escapeXmlComment> I<(s, asciiOnly)>

Turns "--" into a Unicode em dash (U+2014).
XML does not specify an escaping mechanism
within Comments, so this just uses one obvious choice.
If I<asciiOnly> is present and true, non-ASCII characters will also be replaced
by hexadecimal numeric character references.

=item * B<normalizeXMLSpace> I<(s)> or B<normalizeXmlSpace> I<(s)>

Apply XML white-space normalization rules to the string I<s>.

=item * B<expandXml> I<(s, hashRef?)>

Expand (or "unescape") numeric character references, as well as
references to XML's predefined entities, in the string I<s>.
Does not know HTML named entities (see CPAN package C<HTML::Entities>).
However, you can pass in a reference to a hash that maps entity names
to values, and they will be handled too (you cannot override the five XML
pre-defined named entities).

=item * B<backslash> I<(s, asciiOnly)>

Re-codes the usual suspects via backslash-codes.
If I<asciiOnly> is present and true, also turns non-ASCII characters into
\uFFFF form.

The usual suspects are:

    Mnemonic   Codepoint  Result
      BEL        d07        \a
      BS         d08        \b
      TAB        d09        \t
      LF         d10        \n
      FF         d12        \f
      CR         d13        \r
      ESC        d27        \e
      \          d92        \\

NOTE: Does not replace single or double quotation marks.

=item * B<unbackslash>I<(s)>

Replace backslash-codes for special characters, with the actual characters.
The forms recognized are:

  \a \b (for BS/backspace) \e \f \n \r \t \\
  \777 \o{777} \xFF \x{FFF}

This does exactly the Perl set, because all it does is:
escape any double-quotes in the argument; quote the argument; call C<eval>.

B<Note>: This does not do the newer/Pythonesque
\uFFFF, \UFFFFFFFF, or \u{FFF} forms.
Also, \b means different things in different Perl contexts.

=item * B<unescapePerl>I<(s)>

A synonym for I<unbackslashs>().

=item * B<escapeURI>I<(s)>

Replace any character not allowed in URIs with %xx, where xx is the
hexadecimal value of the character. For characters >255, uses UTF-8 and
then escapes that. See L<here|"https://tools.ietf.org/html/rfc2318">.
See also L<here|"getUTF8">.

=item * B<unescapeURI>I<(s, plusToSpace)>

Replace any %xx sequence (as used in URIs), with the literal character.
This appears to behave correctly for UTF-8, but I haven't tested it thoroughly.
If I<--plusToSpace> is true, then also turn "+" to space.

=back


=head2 Time Methods

=over

=item * B<isoTime>I<(t?)>

Returns the present date and time in ISO 8601 combined date and time format,
also specified by RFC 3339.
Example: C<2011-11-30T08:22:05>.
If supplied, I<t> should be a value as from Perl's I<time>() function.
If absent, the present time is used.

=item * B<isoDate>I<(t?)>
Returns the date portion from I<isoTime>(). Example: C<2011-11-30>.
If supplied, I<t> should be a value as from Perl's I<time>() function.
If absent, the present time is used.

=item * B<elapsedTime>I<(start, end?)>

Returns the difference between I<start> and I<end>, which should be values
directly from Perl's I<time()> function
(not returned values from I<sjdUtils::isoTime()>, for example).
If I<end> is not supplied, the present I<time( )> is used.
The elapsed time is returned in the form C<hh:mm:ss>.

=back


=head2 Miscellaneous Methods

=over

=item * B<lorem>I<(length, type)>

Return the first I<length> characters of some arbitrary text.
The particular text is chosen by I<type>, from:
    a -- ASCII characters only (the default)
    u -- Unicode characters included
    x -- Unicode characters, entity references, and XHTML markup included.

Default: The particular text can be changed by calling
I<setUtilsOption("loremText", "your text")>.

=item * B<try_module>I<(name)>

Try to C<use> the named Perl module. Return 1 if successful, otherwise 0.

=item * B<availableFileNum>(base, width)

Find a filename that doesn't exist yet. If I<base> doesn't exist,
just return it. But if it does, try appending numbers (from 1 to 1000)
to base (but preceding a "." and extension if present). The number will
be 0-padded on the left, to a minimum of I<width> digits (default 0).
This first such filename that doesn't refer to an existing file, is returned.
If the limit is reached and no filename is available, I<undef> is returned.

=item * B<localize>I<()>

Activate information from the locale. At the moment, this only affects
the thousands-separator inserted by I<lpadc>().

=back


=head1 Known bugs and limitations

There's nothing to instantiate. Thus, values like the I<verbose> level
are shared among all users of the package. Whether that's a bug or a feature
is up to you. This differs from the Python version.

There is only one message-depth count, not one for each message type.
This may be a bug or a feature....

I<localize>() should also affect time and date formatting, and various
strings in messages (color and emphasis names, metric suffixes, etc.).


=head1 Related commands

C<colorstring> -- fancier options for colorizing.

C<hilite> -- applies colors to regex matches.

C<showInvisibles> -- pretty-print control and non-ASCII chars.

C<DomExtensions> -- library for various XML stuff, including pretty-printing.

C<normalizeXML>, C<prettyPrintXml.py>, C<jsonClean.py> -- format
particular syntaxes nicely.

C<alignData> -- pads fields in CSV-ish files.

C<unescapeURI> -- packages that method from here, for command line.


=head1 History

=over

=item 2011-03-25: Pulled out from various scripts.

=item 2011-05-12 sjd: Use defaultColor in hWarn().

=item 2011-06-09 sjd: Add unbackslash().

=item 2011-06-21 sjd: Add various xml, colorize and indent methods.

=item 2011-09-13 sjd: Add unescapeURI().

=item 2011-09-22 sjd: Improve indentXml().

=item 2011-10-12 sjd: Fix 'default' color. Add ().

=item 2011-10-19 sjd: Add escapeXmlAttribute().

=item 2011-11-07 sjd: Add eWarn(), setErrorColor(), setLocs(). Flip comparison
in warn() functions, and make eWarn() with negative level fatal.

=item 2011-12-11ff sjd: Start toHNumber(), fromHNumber(). Revamp color handling.

=item 2011-12-29 sjd: Clean up, group methods topically, extend big-number stuff.

=item 2012-01-05 sjd: Add escapeURI(), and fix unescapeURI().

=item 2012-01-06 sjd: Add isNumeric().

=item 2012-02-24 sjd: Add makePrintable(), %escape2char, %char2escape,
$ucLatin, $lcLatin, getUTF8() (disabled).

=item 2012-03-05 sjd: Fix color and verbose handling. Add interpretLevel().
Keep error count.

=item 2012-03-16 sjd: Hash of elements for indentXml(). Start Xterm256.

=item 2012-03-28 sjd: Add isXmlName(), makeXmlName().

=item 2012-04-26 sjd: Add normalizeXmlSpace(), isInteger().

=item 2012-05-01 sjd: Bugfixes in makePrintable(), unbackslash().

=item 2012-05-18 sjd: Add isXmlChar(), escapeXmlName().

=item 2012-05-22 sjd: Add expandXML().

=item 2012-05-31 sjd: Fix a couple bugs in unbackslash.

=item 2012-06-04 sjd: Fix case on XML-related function names.

=item 2012-06-05 sjd: Fix some color stuff. Add 'stdout' option. Add %SUoptions.

=item 2012-06-11 sjd: Add precise isXmlSpaceChar isXmlNameStartChar isXmlNameChar.

=item 2012-07-26f sjd: Add try_module. Add isUnicodeCodePoint().

=item 2012-08-14 sjd: Use Encode, work on getUTF8(). Drop $targetFile,
make warnings suppress stack trace.

=item 2012-09-27 sjd: Support 1000 multipliers with HNumbers, not just 1024.

=item 2012-10-16ff sjd: Compile XML char-set regexes. Add aliases vMsg, eMsg, hMsg.
Add unescapeXmlName(). Add hash arg to expandXml().

=item 2012-10-23 sjd: Improve showInvisibles, give space dispay options.

=item 2012-11-01 sjd: Add indentJson(). Clean up w/e/h message i/f a bit.

=item 2012-11-19 sjd: Add escapeXmlPi(), escapeXmlComment().

=item 2012-11-26 sjd: Add localize() and update lpadc() for it.

=item 2012-12-03 sjd: Drop setXColor() methods. Add MsgType(). Move color and
traceLevels control there, simplifying [ehvx]Msg. Add colorize().
Make setColors() return a ref to a hash of the most basic colors.

=item 2012-12-18 sjd: Add 'asciiOnly' param to escapeXML... methods. escapeJson().

=item 2013-01-04 sjd: Fix asciiOnly. Add 'sep' param to getUTF8().

=item 2013-02-06 sjd: Add vPush()/vPop() (mainly for grepData command).

=item 2013-02-25 sjd: Improve indentXml().

=item 2013-06-05 sjd: Add MsgType 'prefix' and 'suffix'.

=item 2013-06-18ff sjd: Add whereAmI(). Lose [ehv]Warn() (keep [ehv]Msg()).

=item 2013-06-27: Add lorem(), vis().

=item 2013-08-27: Add isUpper(), isLower(), isCapitalized(), sc(), tc(), ssubstr().

=item 2013-08-29: Clean up msgType handling.
Rename vPush/vPop to MsgPush/MsgPop, MsgType->Msg, setMessagesType... to
defineMsgType etc. Message option to do showInvisibles().

=item 2013-12-18: Add defineMsgType param for whether to indent per vpush/vpop.

=item 2014-06-11: XML functions get aliases for both "Xml" and "XML".
Add availableFileNum().

=item 2014-07-17: Resync w/ Python ver. Nuke SUset etc. Separate options vs. info.

=item 2014-09-01ff: Add LF choices to showInvisible. Document makePrintable().
Add ulorem option and ulorem().

=item 2015-03-26ff: Some sync to Python version enhancements: Discard locs,
do nLevels right. Clean up message-assembly. Add infix for defineMsgType,
insert indentation after all newlines, not just at beginning. Some stats.

=item 2015-08-28: Add uncolorize(), make pline() ignore color escapes.

=item 2015-09-11: Fix makePrintable to handle SP and LF consistently.

=item 2016-04-07f: Add trim(), ltrim(), rtrim(), cpad(). Avoid refs %colorStrings.
'underline'->'ul', 'reverse'->'inverse', to match colorstrings command.

=item 2016-07-21: Create ColorManager package. Sync color w/ python, logging....

=item 2016-10-25: Physically move ColorManager package out.
Drop ulorem option, ulorem(), and xlorem().

=item 2018-03-27: Split alogging to separate package, like Python version.

=item 2018-09-35: Add splitPath(), availableFileName().

=item 2018-11-27: Add splitPlus().

=item 2020-09-06: Add wrap from C<macFinderInfo>. Clean up a little.
Actually delete code that was moved to C<alogging.pm> some time ago.
Add a little test driver.

=item 2022-12-19f: Add lengthInBytes(), lengthInChars().
Move colorizeXmlTags() and colorizeXmlContent() to ColorManager.pm.

=back


=head1 To do

=over

=item * Fix toHNumber.

=item * Pull in grepData::Condition::getDate().

=item * Pull in struct pretty-printer from Volsunga TrellisNode.

=item * Pull in basic Unicode char normalization from findExamples.py.

=item * Support escaping to HTML entities, leaving Latin-1,....

=item * Drop rarely-used stuff (in sync w/ Python version, too).

=back


=head1 Rights

Copyright 2011-03-25 by Steven J. DeRose. This work is licensed under a
Creative Commons Attribution-Share-alike 3.0 unported license.
See L<http://creativecommons.org/licenses/by-sa/3.0> for more information.

For the most recent version, see L<http://www.derose.net/steve/utilities/>
or L<http://github.com/sderose>.

=cut


###############################################################################
#
our @ISA = qw( Exporter );
#    defineMsgType MsgType
#    vMsg eMsg hMsg Msg whereAmI
#    setStat getStat bumpStat
#    pLine vPush vPop MsgPush MsgPop vSet vGet MsgSet MsgGet
our @EXPORT = qw(
    getColorString colorize uncolorize

    setUtilsOption getUtilsOption setVerbose getVerbose setColors

    indentXml isXmlChar isXmlSpaceChar isXmlNameStartChar isXmlNameChar
    isXmlName isXmlNameToken isXmlNmtoken
    makeXmlName escapeXmlName unescapeXmlName

    indentJson

    wrap lengthInBytes lengthInChars isUpper isLower isCapitalized sc tc ssubstr
    rpad lpad lpadc cpad trim ltrim rtrim
    toHNumber fromHNumber isNumeric isInteger

    isUnicodeCodePoint getUTF8
    makePrintable showControls showInvisibles vis
    escapeJson
    escapeRegex
    escapeXml escapeXmlContent escapeXmlAttribute escapeXmlPi escapeXmlComment
    escapeXML escapeXMLContent escapeXMLAttribute escapeXMLPi escapeXMLComment
    normalizeXmlSpace normalizeXMLSpace expandXml expandXML
    backslash unbackslash
    escapeURI unescapeURI

    isoDate isoTime elapsedTime
    lorem
    try_module availableFileName splitPath localize splitPlus
    );

my $xmlCharExpr =
    "\t\n\r\x20-\x{D7FF}\x{E000}-\x{FFFD}";
    #"\x{00010000}-\x{0010FFFF}";
my $xmlSpaceExpr =
    "\t\n\r\x20";
my $xmlNameStartCharExpr =
    ":A-Z_a-z\xc0-\xd6\xd8-\xf6\xf8-\x{2ff}\x{370}-\x{37d}\x{37f}-\x{1fff}" .
    "\x{200c}\x{200d}\x{2070}-\x{218f}\x{2c00}-\x{2fef}" .
    "\x{3001}-\x{d7ff}\x{f900}-\x{fdcf}" .
    "\x{fdf0}-\x{fffd}";
    #"\x{00010000}-\x{000effff}";
my $xmlNameCharExpr =
    "-.0-9\x{b7}\\x{300}-\x{36f}\x{203f}-\x{2040}" . $xmlNameStartCharExpr;
#warn showInvisibles($xmlNameStartCharExpr) . "\n";

my $xce      = qr/^[$xmlCharExpr]$/;
my $xse      = qr/^[$xmlSpaceExpr]$/;
my $xnsce    = qr/^[$xmlNameStartCharExpr]$/;
my $xnce     = qr/^[$xmlNameCharExpr]$/;
my $xname    = qr/^[$xmlNameStartCharExpr][$xmlNameCharExpr]*$/;
my $xnmtoken = qr/^[$xmlNameCharExpr]*$/;


###############################################################################
# REMOVE, NOW IN alogging.pm
#
sub utilWarn { # For our own warnings if any
    my ($m1, $m2) = @_;
    if (!$m1) { $m1 = ""; }
    if (!$m2) { $m2 = ""; }
    warn "sjdUtils: $m1$m2\n";
}

my %info = (
    'msgTypesDefined' => 0,      # Have the default message types been set up?
    'errorCount'      => 0,      # Number of calls to eMsg() so far.
    'localeInfo'      => undef,  # Hash of locale settings.
    'msgIndentLevel'  => 0,      # Set via MsgPush()/MsgPop().
    'stats'           => {},     # For bumpStat() etc.
);

my %options = (
    'stdout'          => 0,      # Messages to STDOUT instead of STDERR?
    'TEEFILE'         => undef,  # Copy of messages goes here
    'colorEnabled'    => 1,      # Use color at all?
    'indentString'    => "  ",   # String to repeat to make indentation
    #'plineWidth'      => 40,     # Size of label portion for pline().
    'loremText'       =>
        "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do"
        . "eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad"
        . "minim veniam, quis nostrud exercitation ullamco laboris nisi ut"
        . "aliquip ex ea commodo consequat. Duis aute irure dolor in"
        . "reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla"
        . "pariatur. Excepteur sint occaecat cupidatat non proident, sunt in"
        . "culpa qui officia deserunt mollit anim id est laborum.",
    ); # options


# For defined message-types. Set up by defineMsgType() and defineMsgTypes().
my %msgTypes = ();

sub setUtilsOption {
    my ($name, $value) = @_;
    if (!exists $options{$name}) {
        utilWarn("Unknown option '$name'. Known: " .
                 join(", ", keys(%options)));
        return(0);
    }
    $options{$name} = $value;
    if ($name eq "verbose") { setVerbose($value); }
    return(1);
}

sub getUtilsOption {
    my ($name) = @_;
    return($options{$name});
}

sub setVerbose {
    my ($n) = @_;
    return(alogging::setLogOption("verbose", $n));
}

sub getVerbose {
    return(alogging::getLogOption("verbose"));
}


###############################################################################
### Forwards to ColorManager package
#
sub setColors {
    my ($flag) = @_;
    #warn "sjdUtils::setColors...\n";
    my $rc = ColorManager::setColors($flag);
    alogging::defineMsgTypes();
    setUtilsOption("colorEnabled", $flag);
    return($rc);
}
sub getColorString {
    my ($name) = @_;
    return(ColorManager::getColorString($name));
}
sub colorize {
    my ($colorName, $msg, $endAs) = @_;
    return(ColorManager::colorize($colorName, $msg, $endAs));
}
sub uncolorize {
    my ($s) = @_;
    return(ColorManager::uncolorize($s));
}


###############################################################################
#
# Most of the 'alogging' package used to be here. Not any more.
#


###############################################################################
# XML pretty-printing and naming.

# indentXml() breaks before start-tags and end-tags, etc.
# Puts in spurious breaks if "<" occurs within PI, comment, CDATA MS.
# If you want it really right, use my DomExtensions::collectAllXml().
#
sub indentXml {
    my ($s, $iString, $maxIndent, $breakEnds, $elementInfoHash) = @_;
    if (!defined $iString) { $iString = "    "; }
    $s =~ s|<|\n<|gs;
    my @lines = split(/\n/, $s);
    my $depth = 0;
    for (my $i=0; $i<scalar(@lines); $i++) {
        if ($lines[$i] =~ m/^<\//) { $depth--; }           # end-tag
        my $uDepthDepth = ($maxIndent && $depth>$maxIndent)?$maxIndent:$depth;
        my $ind = ($iString x $uDepthDepth);
        if ($lines[$i] =~ m/^<\w/ &&
            $lines[$i] !~ m/^<\w[^>]*\/>/) { $depth++; }   # start-tag
        $lines[$i] = $ind . $lines[$i];
    }
    $s = join("\n",@lines);

    if (!$breakEnds) {
        $s =~ s@\n\s+</@</@gs; # No break before end-tags
    }
    for my $e (keys %{$elementInfoHash}) {
        my $type = $elementInfoHash->{$e};
        #warn "***** handling '$e' as '$type'\n";
        if ($type eq "inline") {
            $s =~ s/\n\s*<$e\b/\t<$e/gs;
        }
        elsif ($type eq "block") {
            $s =~ s/\n(\s*<$e)\b/\n\n$1/gs;
        }
    }
    return("$s\n");
} # indentXml


###############################################################################
# Doesn't include characters beyond the BMP (ending FFFF).
#
sub isXmlChar { # XML REC, production 2
    my ($c) = @_;
    return(($c =~ m/$xce/) ? 1:0);
}
sub isXmlSpaceChar { # XML REC, production 3
    my ($c) = @_;
    return(($c =~ m/$xse/) ? 1:0);
}
sub isXmlNameStartChar { # XML REC, production 4
    my ($c) = @_;
    return(($c =~ m/$xnsce/) ? 1:0);
}
sub isXmlNameChar { # XML REC, production 4a
    my ($c) = @_;
    return(($c =~ m/$xnce/) ? 1:0);
}
sub isXmlName { # XML REC, production 5
    my ($s) = @_;
    return (($s =~ m/$xname/) ? 1:0);
}
sub isXmlNmtoken { # XML REC, production 7
    my ($s) = @_;
    return (($s =~ m/$xnmtoken/) ? 1:0);
}

sub makeXmlName {
    my ($s) = @_;
    $s =~ s/[^$xmlNameCharExpr]/_/g;
    $s =~ s/^([^$xmlNameStartCharExpr])/_$1/;
    return($s);
}

# Make into an XML Name, escaping all funky chars as -xxxx.
# Since the escape uses "-", escape "-", too.
# If $asciiFlag is true, also escape any non-ASCII characters.
#
sub escapeXMLName {
    return(escapeXmlName(@_));
}
sub escapeXmlName {
    my ($s, $asciiFlag) = @_;
    my $rc = "";
    my $len = length($s);
    for (my $i=0; $i<$len; $i++) {
        my $c = substr($s, $i, 1);
        if (($asciiFlag && $c !~ m/\p{isASCII}/) ||
            !isXmlChar($c) ||
            $c eq "-") {
            $rc .= sprintf("-%04x", ord($c));
        }
        else {
            $rc .= $c;
        }
    }
    return($rc)
}

my $unescapeExpr = '-([0-9a-f]{4,4})';
sub unescapeXMLName {
    return(unescapeXmlName(@_));
}
sub unescapeXmlName {
    my ($s) = @_;
    $s =~ s/$unescapeExpr/{ chr(hex("0x$1")); }/ge;
    return($s);
}


###############################################################################
#
sub indentJson {
    my ($s, $iString, $maxIndent) = @_;
    if (!defined $iString)   { $iString = "  "; }
    if (!defined $maxIndent) { $maxIndent = 0; }
    my $buf = "";
    my $level = 0;
    my $lastChar = "";
    my $lastPos = length($s)-1;
    for my $i (0..$lastPos) {
        my $c = substr($s, $i, 1);
        my $whitespace = "\n" . ($iString x $level);
        if ($c eq '{') {
            $level++;
            if (0 && $lastChar eq ":") { $buf .= $c; }
            else { $buf .= "  $whitespace$c"; }
        }
        elsif ($c eq '}') {
            $level--;
            $buf .= "$c";
            if ($lastChar eq "}") { $buf .= $whitespace; }
        }
        elsif ($c eq '"' && $lastChar eq "," &&
               substr($s, $i) !~ m/^"Value"/) {
            $buf .= "$iString$c";
        }
        else {
            $buf .= $c;
        }
        $lastChar = $c;
    }
    return($buf);
} # indentJson


###############################################################################
# Fiddly stuff for strings and numbers.
#
sub lengthInBytes {
    my ($s) = @_;
    use bytes;
    return length($s);
}

sub lengthInChars {
    my ($s) = @_;
    use Encode;
    Encode::_utf8_on($s);
    return length($s);
}

sub wrap {
    my ($s, $indent, $width, $breakChar) = @_;
    if (!$width)     { $width = $ENV{COLUMNS} || 80; }
    if ($indent)     { $width -= $indent; }
    if (!$breakChar) { $breakChar = " "; }

    my $istring = " " x ($indent || 0);
    my $buf = "";
    for my $line (split(/[\r\n]+/, $s)) {
        warn("***line>>>$line<<<\n");
        while ($line ne "") {
            if (length($line) < $width) {
                $buf .= $istring . $line . "\n";
                $line = ''; last;
            }
            my $lastShadow = rindex($line, $breakChar, $width);
            if ($lastShadow < 0) {  # no place to break
                $buf .= $istring . substr($line, 0, $width) . "\n";
                $line = (length($line) > $width) ?
                    substr($line, $width) : $line = '';
            }
            else {
                $buf .= $istring . substr($line, 0, $lastShadow) . "\n";
                $line = substr($line, $lastShadow+1);
            }
        }
    }
    return($buf);
} # wrap

sub isUpper {
    my ($s) = @_;
    return($s =~ m/^[[:upper:]]/);
}
sub isLower {
    my ($s) = @_;
    return($s =~ m/^[[:lower:]]/);
}

# What happens with Titlecase Unicode chars?
sub isCapitalized {
    my ($s) = @_;
    $s =~ m/^(\w)(.*)/;
    return(0) unless ($1 && isUpper($1));
    return(0) if ($2 && ($2 =~ m/[[:upper:]]/));
    return(1);
}

sub sc { # Sentence caps
    my ($s, $forceRest) = @_;
    if ($forceRest) {
        $s =~ s/^(\w)(.*)/\U$1\L$2/;
    }
    else {
        $s =~ s/^(\w)/\U$1/;
    }
    return($s);
}

sub tc { # Title caps
    my ($s, $forceRest) = @_;
    if ($forceRest) {
        $s =~ s/\b(\w)(\w*)\b/\U$1\L$2/g;
    }
    else {
        $s =~ s/\b(\w)/\U$1/g;
    }
    return($s);
}

sub ssubstr { # Safer substr(): handles out-of-bounds conditions quietly
    my ($s, $start, $len) = @_;
    my $lenAvail = length($s);
    if (!defined $len) { $len = $lenAvail-$start; }
    if (!defined $s || $start>=$lenAvail || $len<1) { return(""); }
    if ($len>$lenAvail-$start) { $len = $lenAvail-$start; }
    return(substr($s, $start, $len));
}

sub cpad {
    my ($s, $len, $padChar, $quoteChar) = @_;
    if (!defined $s)       { $s = ""; }
    if (!defined $len)     { $len = 0; }
    if (!defined $padChar) { $padChar = " "; }
    if (defined $quoteChar) {
        $s = $quoteChar.$s.$quoteChar;
    }
    my $needed = $len - length($s);
    if ($needed > 0) {
        $s = ($padChar x (($needed+1)/2)) . $s . ($padChar x ($needed/2));
    }
    return($s);
}

sub rpad {
    my ($s, $len, $padChar, $quoteChar) = @_;
    if (!defined $s)       { $s = ""; }
    if (!defined $len)     { $len = 0; }
    if (!defined $padChar) { $padChar = " "; }
    if (defined $quoteChar) {
        $s = $quoteChar.$s.$quoteChar;
    }

    my $needed = $len - length($s);
    if ($needed > 0) {
        $s .= ($padChar x $needed);
    }
    return($s);
}

sub lpad {
    my ($s, $len, $padChar, $quoteChar) = @_;
    if (!defined $s)       { $s = ""; }
    if (!defined $len)     { $len = 0; }
    if (!defined $padChar) { $padChar = "0"; }
    if (defined $quoteChar) {
        $s = $quoteChar.$s.$quoteChar;
    }
    my $needed = $len - length($s);
    if ($needed > 0) {
        $s = ($padChar x $needed) . $s;
    }
    return($s);
}

sub lpadc { # pad, and also insert commas every three digits.
    my ($s, $len, $padChar, $sepChar) = @_;
    if (!defined $s)       { $s = ""; }
    if (!defined $len)     { $len = 0; }
    if (!defined $padChar) { $padChar = "0"; }
    if (!defined $sepChar) {
        $sepChar = ",";
        if ($info{localeInfo}) {
            $sepChar = $info{localeInfo}->{mon_thousands_sep} || ",";
        }
    }

    my $buf = "";
    while (length($s) > 3) {
        $buf = $sepChar . substr($s, length($s)-3) . $buf;
        $s = substr($s, 0, length($s)-3);
    }
    $buf = "$s$buf";
    my $needed = $len - length($buf);
    if ($needed > 0) {
        $buf = (" " x $needed) . $buf;
    }
    return($buf);
}

sub trim {
	my ($s) = @_;
	$s =~ s/(^\s+|\s+$)//g;
	return($s);
}

sub ltrim {
	my ($s) = @_;
	$s =~ s/^\s+//;
	return($s);
}

sub rtrim {
	my ($s) = @_;
	$s =~ s/\s+$//;
	return($s);
}

# Convert between raw and human-readable big numbers, like many -h options.
# Returns as many post-decimal digits as specified in '$format'.
#
sub toHNumber {
    my ($n, $use1000) = @_;
    my @bits = ("?", "K", "M", "G", "T", "P", "E", "Z", "Y" );
    my $format = "%3.2f%1s";
    my $rc = "$n";
    for (my $i=scalar(@bits)-1; $i>0; $i--) {
        my $factor = ($use1000) ?
            (1000**$i) : (1 << (10*$i));
        if ($factor == 0) {
            $rc = $n;
        }
        elsif ($n > $factor) {
            $rc = sprintf($format, $n / $factor, $bits[$i]);
            last;
        }
    }
    return($rc);
}

sub fromHNumber {
    my ($n, $use1000) = @_;
    my $rc = "";
    my %bits = (
        "K"=>1, "M"=>2, "G"=>3, "T"=>4,
        "P"=>5, "E"=>6, "Z"=>7, "Y"=>8,
        );
    $rc =~ s/([KMGTP])i?\s*$//;
    my $suffix = $1 ? $1:"";
    if ($suffix) {
        if ($use1000) {
            $rc = $n * (1000**$bits{$suffix});
        }
        else {
            $rc = $n * (1 << (10*$bits{$suffix}));
        }
    }
    return($rc);
}

# Return 1 iff the argument is interpretable as a number.
#
sub isNumeric {
    my ($n) = @_;
    (defined $n) || return(0);
    # This doesn't seem to work as expected:
    #return(Scalar::Util::looks_like_number($n));
    if ($n =~ m/^\s*[-+]?\d+(\.\d+)?(E[-+]?\d+)?\s*$/i) { return(1); }
    return(0);
}
sub isInteger {
    my ($n) = @_;
    (defined $n) || return(0);
    if ($n =~ m/^\s*[-+]?\d+/) { return(1); }
    return(0);
}


###############################################################################
#
my $ucLatin = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
my $lcLatin = "abcdefghijklmnopqrstuvwxyz";

# Plane 0     0x000000 to 0x00FFFF  BMP
# Plane 1     0x010000 to 0x01FFFF  Suppl MP
# Plane 2     0x020000 to 0x02FFFF  Supple Ideographic
# Plane 3-13  0x030000 to 0x0DFFFF  Unassigned
# Plane 14    0x0E0000 to 0x0EFFFF  Suppl Special-purpose
# Plane 15-16 0x0F0000 to 0x10FFFF  Suppl Private Use Area
#
sub isUnicodeCodePoint {
    my ($n) = @_;
    if ($n  < 0x000000 || $n  > 0x10FFFF ||
        $n == 0x00FFFE || $n == 0x00FFFF ||
        ($n >= 0x000080 && $n < 0x0000a0)
        ) { return(0); }
    return(1);
}

# Return the UTF-8 byte sequences for a given character code,
# punctuated as needed to put in a URI.
#
sub getUTF8 {
    my ($n, $sep) = @_;
    if (!defined $sep) { $sep = "%"; }
    my $utf8 = Encode::encode('utf8', chr($n));
    my $ux = ();
    for (my $i=0; $i<length($utf8); $i++) {
        $ux .= sprintf("%s%02x", $sep, ord(substr($utf8, $i, 1)));
    }
    return($ux);
}


# Convert non-graphic and non-ASCII characters.
#
#   Mode      <d27 d27-d31 ASCII Lat1  Other
#   -------------------------------------------------------------
#    DFT      \xFF    \xFF   OK  \xFF  \x{FFF}
#    C       ^A-^Z    \xFF   OK  \xFF  \x{FFF}
#    SYM        U+2400+xx    OK  \xFF  \x{FFF}
#    LATIN1   \xFF    \xFF   OK    OK  \x{FFF}
#    XML      &#xF;   &#xF;  OK  &#xF; \x{FFF}
#
# Space is special, and is typically a control picture.
#   ' ' U+0020 (default), SP U+2420, B/ U+2422, _ U+2423.
#   DEL U+2421. NL U+2424, LF U+240a.
#
my %char2escape = (
    "\a"   => "\\a",  # bell
    "\b"   => "\\b",  # backspace
    "\e"   => "\\e",  # escape
    "\f"   => "\\f",  # form feed
    "\n"   => "\\n",  # line feed
    "\r"   => "\\r",  # carriage return
    "\t"   => "\\t",  # tab
    "\\"   => "\\\\", # backslash
    );
my %spaceCodes = (
    "SP"       => chr(0x2420), # SP
    "B"        => chr(0x2422), # B/
    "U"        => chr(0x2423), # _
    "OK"       => ' ',
    "NBSP"     => chr(0x00A0), # Non-breaking space
    );
my %lfCodes = (
    "LF"       => chr(0x240A),
    "NL"       => chr(0x2424),
    "OK"       => "\n",
);

sub makePrintable {
    my ($c, $mode, $spaceAs, $lfAs) = @_;
    my $spaceChar = (defined $spaceAs) ? $spaceCodes{$spaceAs} : " ";
    my $lfChar = (defined $lfAs) ? $lfCodes{$lfAs} : chr(0x240A);
    if (!$mode) { $mode = "DFT"; }
    binmode(STDERR, ":encoding(utf8)");  # Just in case
    #warn "sp $spaceAs ('$spaceChar'), lf $lfAs ('$lfChar'), mode $mode.\n";

    my $o = ord($c);
    my $buf = "$c";

    if ($mode eq "DFT") { # cf unbackslash()
        if (defined $char2escape{$c}) { $buf =  $char2escape{$c}; }
        elsif ($o ==    10) { $buf = $lfChar; }
        elsif ($o <=    31) { $buf = sprintf("\\x%02x", $o); }
        elsif ($o ==    32) { $buf = $spaceChar; }
        elsif ($o <=   126) { $buf = $c; }
        elsif ($o ==   127) { $buf = sprintf("\\x%02x", $o); }
        elsif ($o <=   255) { $buf = sprintf("\\x%02x", $o); }
        else                { $buf = sprintf("\\x{%x}", $o); }
    } # "DFT" mode

    elsif ($mode eq "C") {
        if (defined $char2escape{$c}) { $buf =  $char2escape{$c}; }
        elsif ($o ==    10) { $buf = $lfChar; }
        elsif ($o <=    26) { $buf = "^" . substr('@'.$ucLatin, $o, 1); }
        elsif ($o <=    31) { $buf = sprintf("\\x%02x", $o); }
        elsif ($o ==    32) { $buf = $spaceChar; }
        elsif ($o <=   126) { $buf = $c; }
        elsif ($o ==   127) { $buf = sprintf("\\x%02x", $o); }
        elsif ($o <=   255) { $buf = sprintf("\\x%02x", $o); }
        else                { $buf = sprintf("\\x{%x}", $o); }
    } # "C" mode

    elsif ($mode eq "SYM") {
        if    ($o ==    10) { $buf = $lfChar; }
        elsif ($o <=    31) { $buf = chr(0x2400+$o); }
        elsif ($o ==    32) { $buf = $spaceChar; }
        elsif ($o <=   126) { $buf = $c; }
        elsif ($o ==   127) { $buf = chr(0x2421); }
        elsif ($o <=   255) { $buf = sprintf("\\x%02x", $o); }
        else                { $buf = sprintf("\\x{%x}", $o); }
    } # "SYM" mode

    elsif ($mode eq "LATIN1") {
        if    ($o ==    10) { $buf = $lfChar; warn "Got one!\n"; }
        elsif ($o <=    31) { $buf = sprintf("\\x%02x", $o); }
        elsif ($o ==    32) { $buf = $spaceChar; }
        elsif ($o <=   126) { $buf = $c; }
        elsif ($o ==   127) { $buf = sprintf("\\x%02x", $o); }
        elsif ($o <=   255) { $buf = $c; }
        else                { $buf = sprintf("\\x{%x}", $o); }
    } # "SYM" mode
    elsif ($mode eq "XML") {
        if    ($o ==    10) { $buf = $lfChar; }
        elsif ($o <=    31) { $buf = sprintf("&#x%x;", $o); }
        elsif ($o ==    32) { $buf = $spaceChar; }
        elsif ($o <=   126) { $buf = $c; }
        else                { $buf = sprintf("&#x%x;", $o); }
    }
    else {
        die "makePrintable: unknown mode '$mode'\n";
    }
    return($buf);
} # makePrintable


# Show control characters as Unicode control symbols (tiny mnemonics).
# Space: U'2422 = bSlash, U'2423 = underbar, U'2420 = SP.
# LF: U'240a = LF, U'2424 = NL.
#
sub showControls {
    my ($s, $spaceAs, $lfAs) = @_;
    (defined $s) || return("");
    $s =~ s/(\p{IsCntrl})/{ chr(0x2400+ord($1)); }/ges;
    my $spaceSym = chr(0x2422);
    $s =~ s/ /$spaceSym/g;
    return($s);
}

sub vis {
    return(showInvisibles(@_));
}
sub showInvisibles {
    my ($s, $mode, $spaceAs, $lfAs) = @_;
    (defined $s) || return("");
    $s =~ s/(\P{IsASCII}|\p{IsCntrl}| )/{
        makePrintable($1, $mode, $spaceAs, $lfAs); }/ges;
    return($s);
}

sub escapeJSON {
    my ($s, $asciiOnly) = @_;
    if ($s =~ m/["'(){}[]\s]/) {
        $s =~ s/([\\"])/\\$1/g;
        $s = '"' . $s . '"';
    }
    if ($asciiOnly) {
        $s =~ s/([^[:ascii:]])/{ sprintf("\u%04d", ord($1)); }/ge;
    }
    return($s);
}

sub escapeRegex {
    my ($s, $additionalChars) = @_;
    (defined $s) || return("");
    my $toEsc = '().?*+\\[\\]{}^\\$\\|\\\\' . ($additionalChars || "");
    $s =~ s/([$toEsc])/\\$1/g;
    return($s);
}


sub escapeXMLContent {
    return(escapeXmlContent(@_));
}
sub escapeXML {
    return(escapeXmlContent(@_));
}
sub escapeXmlContent {
    my ($s, $asciiOnly) = @_;
    (defined $s) || return("");
    return(escapeXml($s, $asciiOnly));
}
sub escapeXml {
    my ($s, $asciiOnly) = @_;
    (defined $s) || return("");
    # We quietly delete the non-XML control characters!
    $s =~ s/[\x{0}-\x{8}\x{b}\x{c}\x{e}-\x{1f}]//g;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/]]>/]]&gt;/g;
    if ($asciiOnly) {
        $s =~ s/([^[:ascii:]])/{ sprintf("&#x%04x;", ord($1)); }/ge;
    }
    return($s);
}

sub escapeXMLAttribute {
    return(escapeXmlAttribute(@_));
}
sub escapeXmlAttribute {
    my ($s, $apostrophes, $asciiOnly) = @_;
    (defined $s) || return("");
    # We quietly delete the non-XML control characters!
    $s =~ s/[\x{0}-\x{8}\x{b}\x{c}\x{e}-\x{1f}]//g;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    if ($asciiOnly) {
        $s =~ s/([^[:ascii:]])/{ sprintf("&#x%04x;", ord($1)); }/ge;
    }
    if ($apostrophes) {
        $s =~ s/'/&apos;/g;
    }
    else {
        $s =~ s/"/&quot;/g;
    }
    return($s);
}

sub escapeXMLPi {
    return(escapeXmlPi(@_));
}
sub escapeXmlPi {
    my ($s, $asciiOnly) = @_;
    (defined $s) || return("");
    # We quietly delete the non-XML control characters!
    $s =~ s/[\x{0}-\x{8}\x{b}\x{c}\x{e}-\x{1f}]//g;
    $s =~ s/&/&amp;/g;
    $s =~ s/\?>/?&gt;/g;
    if ($asciiOnly) {
        $s =~ s/([^[:ascii:]])/{ sprintf("&#x%04x;", ord($1)); }/ge;
    }
    return($s);
}

sub escapeXMLComment {
    return(escapeXmlComment(@_));
}
sub escapeXmlComment {
    my ($s, $asciiOnly) = @_;
    (defined $s) || return("");
    # We quietly delete the non-XML control characters!
    $s =~ s/[\x{0}-\x{8}\x{b}\x{c}\x{e}-\x{1f}]//g;
    $s =~ s/--/\x{2014}/g; # em dash
    if ($asciiOnly) {
        $s =~ s/([^[:ascii:]])/{ sprintf("&#x%04x;", ord($1)); }/ge;
    }
    return($s);
}

sub normalizeXMLSpace {
    my ($s) = @_;
    return(normalizeXmlSpace($s));
}
sub normalizeXmlSpace {
    my ($s) = @_;
    (defined $s) || return("");
    $s =~ s/\s+/ /g;
    $s =~ s/^ //;
    $s =~ s/ $//;
    return($s);
}

sub expandXML {
    my ($s, $myHashRef) = @_;
    return(expandXml($s));
}
sub expandXml {
    my ($s, $myHashRef) = @_;
    (defined $s) || return("");
    $s =~ s/&(#x?[a-f\d]+|\w[-.:\w]*);/{ mapEntity($1, $myHashRef); }/gei;
}
sub mapEntity {
    my ($e, $myHashRef) = @_;
    (defined $e) || return("");
    if (substr($e, 0, 1) eq '#') {                       # Numeric char ref
        if (lc(substr($e, 1, 1)) eq 'x') {               # Hexadecimal
            return(chr(hex("0".substr($e, 1))));
        }
        else {                                         # Decimal
            return(chr(substr($e, 1)));
        }
    }
    elsif ($e eq "lt")   { return("<"); }              # XML built-ins
    elsif ($e eq "gt")   { return(">"); }
    elsif ($e eq "amp")  { return("&"); }
    elsif ($e eq "apos") { return("'"); }
    elsif ($e eq "quot") { return('"'); }
    elsif ($myHashRef && defined $myHashRef->{$e}) {   # Custom
        return($myHashRef->{$e});
    }
                                                       # fail
    utilWarn("Unknown entity '$e' (use CPAN HTML::Entities if needed).");
    return($e);
}


# Handle \\ codes.
#
sub backslash {
    my ($s, $asciiOnly) = @_;
    (defined $s) || return("");
    $s =~ s/\\/\\\\/g; # BACKSLASH This one first!
    $s =~ s/\a/\\a/g;  # d07  BEL
    $s =~ s/\t/\\t/g;  # d09  TAB
    $s =~ s/\n/\\n/g;  # d10  LF
    $s =~ s/\f/\\f/g;  # d12  FF
    $s =~ s/\r/\\r/g;  # d13  CR
    $s =~ s/\e/\\e/g;  # d27  ESC
    #$s =~ s/\b/\\b/g;  # bell or backspace or word boundary
    if ($asciiOnly) {
        $s =~ s/(\P{IsASCII})/{ sprintf("\\u%04x", ord($1)); }/ge;
    }
    return($s);
}

# Perl's backslash cases:
#    tnrfbae\  x{}  xFF  N{unicodename}  N{U+FFFF}  cZ o{7777} \777
#
sub unescapePerl {
    return unbackslash($_[0]);
}

sub unbackslash {
    my ($s) = @_;
    if (index($s,"\\")<0) { return($s); }        # Nothing to do
    $s =~ s/(^|[^\\])"/$1\\"/g;                  # Esc. unescaped quotes
    my $e = eval('"'.$s.'"');                    # Quote it and eval
    if ($@) { utilWarn("unbackslash: eval problem for '$s': $@.\n"); }
    return($e);
} # unbackslash


# Handle URI escaping.
#
sub escapeURI {
    my ($s) = @_;
    (defined $s) || return("");
    $s =~ s/([^-!\$'()*+.0-9:;=?\@A-Z_a-z])/{
        if (ord($1) < 256) {
            sprintf("%02x", ord($1));
        }
        else {
            getUTF8(ord($1));
        }
      }/ge;
    return($s);
}

# See also version in unescapeURI, which can also turn result into numeric char refs.
#
sub unescapeURI {
    my ($s, $plusToSpace, $escapeChar) = @_;
    if (!$escapeChar) { $escapeChar='%'; }
    ($s) || return("");
    if ($plusToSpace) {
        $s =~ s/\+/ /g;
    }
    if ($escapeChar eq '%') {
        $s =~ s/%([0-9a-f][0-9a-f])/{ chr(hex("0x$1")); }/gie;
    }
    else {
        $s =~ s/$escapeChar([0-9a-f][0-9a-f])/{ chr(hex("0x$1")); }/gie;
    }
    # Seems to work fine for UTF-8
    return($s);
}


###############################################################################
# Human-readable times and dates (see ISO 8601)
#
sub isoTime {
    my ($s) = @_;
    if (!$s) { $s = time(); }
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        localtime($s);
    return(sprintf("%04d-%02d-%02dT%02d:%02d:%02d",
                   $year+1900, $mon+1, $mday, $hour, $min, $sec));
}

sub isoDate {
    my ($s) = @_;
    return(substr(isoTime($s), 0, 10));
}

sub elapsedTime {
    my ($startTime, $endTime) = @_;
    if (!$endTime) { $endTime = time(); }

    my $elapsed = $endTime - $startTime;
    my $h = int($elapsed / 3600);
    my $m = int($elapsed / 60) % 60;
    my $s = $elapsed % 60;
    return(sprintf("%02d:%02d:%02d", $h, $m, $s));
}

# Should vary it if it needs to be repeated.
# Should add a random text generator.
sub lorem {
    my ($length) = @_;
    if (!defined $length) { $length = 79; }
    return(substr($options{loremText}, 0, $length));
}


###############################################################################
# Try to load a Perl module, and warn if not found.
#
sub try_module {
    my ($mod, $quiet) = @_;
    eval("use $mod");
    if ($@) {
        if ($quiet) { return(0); }
        my $msg = "sjdUtils::try_module: Couldn't find Perl module '$mod'. " .
            "Includes: [\n";
        for my $inc (@INC) {
            $msg .= ((-e $inc) ? "    " : " ?? ") . $inc . "\n";
        }
        utilWarn($msg . "]\n");
        return(0);
    }
    return(1);
}

# Find a version of the given file name, that does not already exist.
# Appends increasing integers to the name (before any extension,
# and with optional zero-padding).
#
# FIX: Add option to avoid the unsuffixed name (require a number).
#
sub availableFileName {
    my ($path, $width) = @_;
    if (!$width) { $width = 0; }
    if (! -e $path) { return($path); }
    my ($dir, $file, $ext) = splitPath($path);
    my $n = findHighestSuffixedName($dir, $file, $ext);
    if ($n) {
        return sprintf("%s%s%".$width."d.%s", $dir, $file, $n, $ext);
    }
    return undef;
}

# Return the highest integer found as a suffix to the given
# filename (there could be earlier gaps, and they don't all need to be
# equally zero-padded).
#
sub findHighestSuffixedName {
    my ($baseDir, $filename, $ext) = @_;
    my $expr = $filename + '(\\d+)' + $ext + '\$';
    my $maxN = 0;
    foreach my $ch (listdir($baseDir)) {
        if ($ch =~ m/$expr/) {
            my $n = int(group(1));
            if ($n > $maxN) { $maxN = $n; }
        }
    }
    return $maxN;
}

sub splitPath {
    my ($path) = @_;
    my $dir = my $file = my $ext = "";
    $path =~ m@^(.*/)?([^/]*?)(\.(\w*))?$@;
    if ($1) { $dir = $1; }
    if ($2) { $file = $2; }
    if ($4) { $ext = $4; }
    return ( $dir, $file, $ext );
}


# Localize
#         currency_symbol $
#         decimal_point .
#         frac_digits 2
#         int_curr_symbol USD
#         int_frac_digits 2
#         mon_decimal_point .
#         mon_grouping
#         mon_thousands_sep ,
#         n_cs_precedes 1
#         n_sep_by_space 0
#         n_sign_posn 1
#         negative_sign -
#         p_cs_precedes 1
#         p_sep_by_space 0
#         p_sign_posn 1
#
sub localize {
    try_module('POSIX "locale_h"');
    $info{localeInfo} = localeconv();
}

# Basically the same as string split(), but supports backslashing
# the delimiter, and discarding empty tokens.
# Does NOT decode backslash/escape codes by default.
#
sub splitPlus {
    my ($st, $delim, $esc, $unbackslash, $empties) = @_;
    if (!defined $delim)       { $delim = " "; }
    if (!defined $esc)         { $esc = "\\"; }
    if (!defined $empties)     { $empties = 1; }
    if (!defined $unbackslash) { $unbackslash = 0; }
    #assert (len(delim) == 1)
    #assert (len(esc) <= 1)
    my @tokens = ();
    my $token = "";
    my $gotEscape = 0;
    for (my $i=0; $i < length($st); $i++) {
        my $ch = substr($st, $i, 1);
        if ($gotEscape == 1) {
            $token += $ch;
            $gotEscape = 0;
        }
        elsif ($ch == $esc) {
            $token += $ch;
            $gotEscape = 1;
        }
        elsif ($ch == $delim) {
            if ($token!='' or $empties) { push @tokens, $token; }
            $token = "";
        }
        else {
            $token += $ch;
        }
    }
    if ($token != '') {
        push @tokens, $token;
    }
    if ($unbackslash) {
        for (my $i=0; $i < scalar(@tokens); $i++) {
            $tokens[$i] = unbackslash($tokens[$i]);
        }
    }
    return @tokens;
}


###############################################################################
# Main (just to show help, or to test).
#
if (!caller) {
    use Getopt::Long;

    my $ignoreCase    = 0;
    my $quiet         = 0;
    my $split         = 0;
    my $verbose       = 0;
    my $wrap          = 0;

    my %getoptHash = (
        "h|help"                  => sub { system "perldoc $0"; exit; },
        "i|ignoreCase!"           => \$ignoreCase,
        "q|quiet!"                => \$quiet,
        "split!"                  => \$split,
        "v|verbose+"              => \$verbose,
        "version"                 => sub {
            die "Version of $VERSION_DATE, by Steven J. DeRose.\n";
        },
        "wrap!"                   => \$wrap
        );
    Getopt::Long::Configure ("ignore_case");
    GetOptions(%getoptHash) || die "Bad options.\n";

    if ($wrap) {                       # test wrap()
        print("Testing wrap()\n");
        my $txt = lorem().rtrim() . ".\n\n" . lorem() . "\n";
        print("\n======= Original:\n$txt\n\n======= Wrapped to 72, ind 2:\n");
        my $txt2 = wrap($txt, 72, 2);
        print("$txt2\n=======\n");
    }
    elsif ($split) {
        print("Testing splitPath()\n");
        my $path = "/tmp/foo/bar/baz.html";
        my ($dir, $file, $ext) = sjdUtils::splitPath($path);
        print("splitPath on '$path' gives $dir, $file, $ext.\n");
        my $n = sjdUtils::availableFileName($path);
        print("availableFileName on '$path' is $n.\n");
    }
    else {                             # No args, just show help
        system "perldoc $0";
    }
}

1;

