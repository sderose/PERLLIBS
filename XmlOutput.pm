#!/usr/bin/perl -w
#
# XmlOutput.pm: API to help sequentiually write valid XML.
# Written 2010-12-22 by Steven J. DeRose.
#
use strict;
use HTML::Entities;

use Exporter;
our @ISA = qw( Exporter );

our %metadata = (
    'title'        => "XmlOutput.pm",
    'description'  => "API to help sequentiually write valid XML.",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2010-12-22",
    'modified'     => "2020-08-24",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

use XmlOutput;

A Perl module to help with generating XML output.

Very similar to I<ElementManager.pm>, but enables creating XML structures, not
just getting information about one in process. You should always get WF XML,
unless you resort to I<makeRawText>().

You can tell it about various elements to save effort, such as putting newlines
before certain elements, ensuring that some are always empty (so you needn't
explicitly close them), and so on.
It can do generic or customized pretty-printing, too.

It keeps the output element stack and some other state information, handles
escaping for all syntactic contexts, and generally tries to
ensure that you end up with well-formed XML. It also makes your XML-generating
application more readable, because you only have to deal with high-level,
(hopefully) intuitive methods (e.g., closeThroughElement("foo"),
makeComment(text),...).

The I<adjustToRank(n)> method (see below) is especially useful when cleaning up HTML, or
creating XML from formats that do not have DIV-like containers with clear levels.


=head2 Example

    use XmlOutput;

    my $xo = new XmlOutput();
    $xo->setEmpty("br hr");
    $xo->setCantRecurse("p");
    $xo->setSpace("p li blockquote", 2);
    $xo->setSpace("h1 h2 h3 h4 h5 h6", 3);
    $xo->setInline("#HTML");

    $xo->makeDoctype("html");
    $xo->openElement("html");
    $xo->makeEmpty("head");
    $xo->openElement("body");
    $xo->openElement("div", "class='main'");
    $xo->openElement("p");
    $xo->makeText("Hello, world");
    $xo->closeAllElements("html");


=head1 Methods

B<Note>: Many of the methods are the same as ones in C<ElementManager.pm>, a
lighter-weight version meant to track state while you're using an XML Parser
such as CPAN's C<XML::Parser>. This package is mostly, though not yet entirely,
a superset of C<ElementManager.pm>, and may become a subclass.


=head2 General Methods

=over

=item * B<new>(outFH)

Create a new instance of the XmlOutput object.
XML output will go to file handle I<outFH> if specified, otherwise to STDOUT.

=item * B<getVersion>()

Return the version date of the XmlOutput.pm Perl module.

=item * B<getOption(name)>

Return the current value of option I<name>. See L<Options> section.

=item * B<getOptionList>()

Return an array of the known option names.

=item * B<setOption(name, value)>

Set option I<name> to I<value>.
The name is checked for being a known option, but no
checking is done on the value (values are Boolean (1 or 0) unless
otherwise noted). See L<Options> section below.

=item * B<setCantRecurse(types)>

Prevent any element type listed (space-separated) in I<types>
from being opened recursively.
For example, if you set this for C<p>, and the open elements
are html/body/div/p/footnote/, and you attempt to open another C<p>, then
the I<footnote> and I<p> elements will be automatically closed before
the new C<p> is opened.

=item * B<setSpace(types,n)>

Cause I<n> extra newlines to be issued before the start of each instance
of any element type listed (space-separated) in I<types>.

=item * B<setInline(types)>

Add each (space-separated) element type in I<types> to a list of elements
to be treated as inline (thus getting no breaks around it despite
general options for breaking).

If I<types> is "#HTML", the HTML 4 inline tags will all be added to the list:
A ABBR ACRONYM B BASEFONT BDO BIG BR CITE CODE DFN
EM FONT I IMG INPUT KBD LABEL Q S SAMP SELECT SMALL
SPAN STRIKE STRONG SUB SUP TEXTAREA TT U VAR.

Some other HTML tags are only sometimes inline
(APPLET BUTTON DEL IFRAME INS MAP OBJECT SCRIPT).
These are not added by #HTML,
but some or all can be added with another call to I<setInline>().

=item * B<setEmpty(types)>

Cause any element type listed (space-separated) in I<types> to be
written out as an empty element when opened (thus, no I<closeElement>() call
is needed for them). You can instead just issue them via I<makeEmptyElement>.

=item * B<setSuppress(types)>

Record that elements of any type listed (space-separated) in I<types>
(and their entire subtrees) should not be output at all.

=item * B<getCurrentElementName>() or B<getCurrentType>()

Return the element type name of the innermost open element.

=item * B<getCurrentFQGI>()

Return the sequence of the types of all open elements, from the top down.
For example, C<html/body/div/div/ul/li/p/i>.

=item * B<getCurrentLanguage>()

Return the present (possibly inherited) value of C<xml:lang>.

=item * B<getDepth>() or B<getCurrentDepth>()

Return how many elements are presently open.
See also I<howManyAreOpen(typelist)>.

=item * B<howManyAreOpen(typelist)>

Return the number of instances of the listed element type(s) that are open.
See also I<getCurrentDepth>().

=back


=head2 Attribute Queueing Methods

=over

=item * B<queueAttribute(name, value)>

Add an attribute, to be issued with the next start-tag.
If an attribute called I<name> is already queued, replace it.

=item * B<getQueuedAttributes>()

Return all queued attributes (if any) as a hash.
They are not cleared. This is typically only called internally.

=item * B<clearQueuedAttributes>()

Discard any queued attributes (this also happens automatically if
you open a new element, since it will use any queued attributes).

=back


=head2 Element Generation Methods

=over

=item * B<openElement(type, attrs, makeEmpty)>

Open an instance of the specified element I<type>.
If I<attrs> is specified, it will be added as a literal attribute string
(for example, you could pass "id='x1' class=\"foo\"").
If there are queued attributes (see I<queueAttribute>()), they will
also be issued and then de-queued.
If I<makeEmpty> is specified and true, the element will be an empty
element (and thus will not remain open).

=item * B<openMultiple(type1, type2,...)>

Call I<openElement>() on each argument in turn.

=item * B<openElementUnlessOpen(gi, attrs)>

Just like I<openElement>, except that it does nothing if the element
is already open (it need not be the innermost element).
Known in some quarters as "openElementIfNeeded".
See also I<openElementUnlessCurrent>.

=item * B<openElementUnlessCurrent(gi, attrs)>

Just like I<openElement>, except that it does nothing only when the element
is already I<current> (that is, it is open as the innermost element).

=item * B<makeEmptyElement(type, attrs)>

Output an XML empty element of the given element I<type> and I<attributes>.
Queued attributes (if any) will also be applied.

=item * B<makeElementWithText(type, text)>

Open a I<type> element, output the I<text> as with I<makeText>,
and then close the I<type> element.

=item * B<closeElement(type)>

Close the specified element. Wars if it is not the innermost open element,
and closes down to it.
I<type> may be omitted, in which case the innermost element is closed,
whatever its type. B<Note:> To close an element even if there are other
elements also close, and avoid the warning, use I<closeThroughElement(). >

=item * B<closeMultiple(type1, type2,...)>

Call I<closeElement>() on each argument in turn.

=item * B<closeAllElements>()

Close all open elements.

=item * B<closeToElement(type)>

Close down to, but not including, the innermost instance of the
specified element.
If the element is not open, nothing happens.
See also I<closeThroughElement> and I<closeAllOfThese>.

=item * B<closeThroughElement(type)>

Close down to and including, the specified element.
If the element is not open, nothing happens.
See also I<closeAllOfThese>.

=item * B<closeAllOfThese(typelist)>

Close all instances of any element types in the (space-delimited)
list I<typelist>. Other elements are also close if needed to do this.

=item * B<adjustToRank(n)>

This is specialized for helping make nested structures with tags like HTML's "div",
which do not have a depth number as part of the element type name, but nest.

This method will close and open as many elements as needed to get to a state
where a new instance of level I<n> of the nestable element type is open
(the type is chosen via the I<divTag> option). Specifically:

=over

=item * it closes elements if needed,
out to and including the I<n>th nested "div";

=item * it opens the nestable element type until I<n> are open,
automatically adding a I<class="level_X"> attribute to each;

=item * if the I<divClass> option
is set, its value will be used as the name of an attribute (default: C<class>)
on which to encode the level-number of the div.

=back

This will leave everything ready for opening a title or heading.
If you were already at level I<n> it will close the I<divTag> element
and open a new one;
if you were nested deeper, the deeper stuff will all be closed first;
and if you weren't that deep, it will open as many "div"s as needed
(it does not provide default titles or headings, however).

=back


=head2 Other Markup Generation Methods

=over

=item * B<makeDoctype(doctypename, publicID, systemID)>

Output an XML DOCTYPE declaration.

=item * B<endDocument>()

Do a closeAllElements(), and then close the output file.

=item * B<makeComment(text)>

Output an XML comment. Any instances of "--" within I<text> will have
a space inserted.

=item * B<makePI(target, text)>

Create a Processing Instruction directed to the specified I<target>,
with the given I<content>.

=item * B<makeCharRef(e)>

Create an entity or character reference.
If I<e> is numeric, it will make a 5-digit hexadecimal
numeric character reference;
otherwise it will assume I<e> is just an entity name.
See also I<--htmlEntities>.

=item * B<makeText(text)>

Output I<text> as XML content. It will have XML delimiters escaped as needed,
unless you unset the I<escapeText> option.
If you set the I<asciiOnly> option, all non-ASCII characters
will be turned into character references.

=item * B<makeRawText(s)>

Write I<s> literally to the output (this is mainly used internally).
No escaping is done. If you use this method, all bets are off as far
as producing Well-Formed XML.

=back


=head2 String and Escaping Methods

=over

=item * B<escapeAttribute(s)>

Escape the string I<s> to be acceptable as an attribute value
(removing <, &, and "). If the I<asciiOnly> option is set, escape non-ASCII
characters in I<s> as well.

=item * B<escapeAscii(s)>

Replace any non-ASCII characters in the text with entity references.

=item * B<escapeUri>()

Escape non-URI characters using the URI %xx convention.
If the I<iri> option is set, don't escape chars just because they're
non-ASCII; only escape URI-prohibited ASCII characters.

=item * B<escapeXmlContent>()

Escape XML delimiters as needed in text content.

=item * B<fixName(name)>

Ensure that the argument is a valid XML NAME.
Any other characters become "_".

=item * B<normalizeSpace>()

Do the equivalent of XSLT's I<normalize-space>() function on I<s>.
That is, remove leading and trailing whitespace, and reduce any internal
runs of whitespace to a single regular space character.

=item * B<sysgen>()

Return a unique identifier each time it's called. You can control the
prefix applied, via the I<sysgenPrefix> option (the default is the *nix time).
Other than the prefix, this just generates a counter.

=back


=head1 Options

These options are accessed via I<setOption> and I<getOption> (see above).

A few special options take lists of element type names as their values.
Those have separate functions, listed above under L<General Methods>:
i<setSpace>, i<setInline>, i<setEmpty>, i<setCantRecurse>, i<setSuppress>.
Those cannot be accessed via I<setOption> and I<getOption> as can the ones
listed below.

=over

=item * B<asciiOnly> -- Use entities for all non-ASCII content characters.
Default: off.

=item * B<breakSTAGO> -- Break before start-tags.
Default: on. See also I<indent>.

=item * B<breakAttrs> -- Break before each attribute.
Default: off.

=item * B<breakSTAGC> -- Break after start-tags.
Default: off.

=item * B<breakETAGO> -- Break before end-tags.
Default: off.

=item * B<breakETAGC> -- Break after end-tags.
Default: off.

=item * B<divClass> -- If non-empty, then with I<adjustToRank>(),
I<divTag> elements that are generated will also get an attribute
of this name, with the level number in the value.
Default: C<class>.

=item * B<divTag> -- what element type is used for nested containers,
like (the default) HTML C<div>. See method I<adjustToRank> for a handy
way to ensure that divs get handled right even if the source document
only has headings (H1, H2, or similar), not entire section containers.
There is presently no special support for
numbered (e.g., div1, div2,...), or
named (e.g. part, chapter, sec, subsec,...) division levels.
Default: C<div>.

=item * B<entityFormat> -- What form to use for numeric character references,
as a sprintf() format-string. Default "&#x%05x;"

=item * B<escapeText> -- Whether to escape <, &, etc. for XML.
Default: on. If you need to write some text that is not escaped,
you can do it with I<makeRawText> instead.

=item * B<escapeUris> -- Whether to add %xx escaping in attributes that
appear to be hrefs (they start with a scheme name and "://"). Default: off.
The escaping mechanism is also available separately, as I<escapeUri>.

=item * B<fixNames> -- Correct any requested element type names to be
valid XML NAMEs. Default: off.

=item * B<htmlEntities> -- Use HTML named entities for special
characters when possible. Default: off.

=item * B<htmlFormat> -- Use SGML/HTML rather than XML style empty elements.
Default: off (that is, use XML style)

=item * B<idAttrName> -- Specify an attribute name to treat as an XML ID (mainly
for use with I<trackIDs>. Default: id. (Not yet implemented).

=item * B<indent> -- Pretty-print the XML output. Default: on.
See also I<breakSTAGO>, I<breakAttrs>, I<breakSTAGC>, I<breakETAGO>,
I<breakETAGC>, and I<iString>, and the help section [#Indentation].

=item * B<iri> -- Allow non-ASCII characters in URIs. Default: on.

=item * B<iString> -- Use this string as the (repeated) indent-string
for pretty-printing. Default: "    " (4 spaces).
B<Note>: This can also be accessed using I<setIndentString>() and
I<setIndentString>(), for compatibility with C<ElementManager.pm>.
This only applies if I<indent>, certain of the I<break...> options, etc.

=item * B<normalizeText> -- Normalize white-space in output text nodes.
Default: off.

=item * B<oencoding> -- (unsupported) Default: utf8.

=item * B<suppressWSN> -- Do not output white-space-only text nodes.
Default: off.

=item * B<sysgenPrefix> -- Set what string is prefixed to a serial number
with the I<sysgen>() call. Default: the *nix time when the XmlOutput
object was instantiated. Default: "A" plus the current C<time()>.

=item * B<trackIDs> -- (unsupported) Warn if an "id" attribute value is
re-used (this does not see any DTD, it just goes by attribute name).
See I<idAttrName>. Default: off.

=item * B<URIchars> -- What characters are allowed (unescaped) in URIs.
If the I<iri> option is set, all non-ASCII characters are also allowed.
Default: "-.\\w\\d_!\$\'()*+".

=back


=head2 Indentation

Pretty-printing with newlines and indentation involves several options.
I<indent> defaults to on, and causes breaks and indentation before
start-tags (including empty element tags). I<iString> is the string
to be repeated to create indentation.

You can more tightly control where newlines are inserted, using
the I<breakSTAGO>, I<breakAttrs>, I<breakSTAGC>, I<breakETAGO>,
I<breakETAGC> options.

setInlines() can be used to provide a hash of element type names that should
be considered "inline" (basically in the CSS sense), and not get surrounding
newlines.

setSpaces() can be used to provide a hash of element type names, each with
the specific number of newlines to be issued before it (the last of which,
if any, will be followed by indentation space).

There is presently no way to control indentation more specifically than
per-element-type.


=head1 Known bugs and limitations

Should hook up to C<XML::DOM> so you can just write out an element or subtree
from DOM in one step.

Doesn't know much about namespaces yet.

Automation of C<xml:lang> attributes is not finished.

Doesn't know anything about conforming to a particular schema.


=head1 Related commands

C<ElementManager.pm> -- Similar, but mainly intended to keep track during
parsing, not generation. It tracks the stack, IDs, xml:lang, etc., but doesn't
do escaping or output, search around the stack for things, etc.


=head1 History

    Written 2010-12-22 by Steven J. DeRose.
    2011-03-14 sjd: IRI, makeCharRef().
    2011-03-15 sjd: Protect against empty stack. More doc. Better escaping.
Much better break management. Add empties and inlines lists.
    2011-03-24 sjd: Add Export of subr names.
    2011-08-26 sjd: Add $offset arg to getIndentString to fix ETAG[CO].
    2011-09-01 sjd: Add setInline("#HTML"). HTML::Entities,
    2012-03-02 sjd: Rename escape...() functions to escapeFor...(). OBS
    2012-03-30 sjd: Rename package.
    2012-04-26 sjd: Catch "--" in makeComment().
    2012-05-09 sjd: doPrint() -> makeRawText(). Add makeElementWithText().
    2012-11-05 sjd: Nuke escapeFor... in favor of escape....
    2013-01-23 sjd: Sync w/ ElementManager.pm, API.
    2013-06-06: Clean up options. Better doc. Sync w/ plain2html.
Support HTML named entities, escapeUris. Add attrStack.
Queue attrs as a hash, not a string, and clean up attr generation.
    2013-09-19: Re-sync w/ ElementManager.pm. Separate the common API portions.
    2014-01-10: Fix some bugs. Add getOptionList().
    2020-08-24: New layout.


=head1 To do:

    Re-sync with Python version (esp. XmlDcl support).
        setOutput
        startDocument
        startHTML
        makeXMLDeclaration
        makeSmallElement
        normalizeTag
    Add newElement(self, name) -- closeThroughElement, then open.
    Sync with ElementManager.pm.
    Implement -idAttrName.
    Consolidate rest of setters into setOption.
    Option to omit inheritable xml:lang and xmlns: attributes.
    Sync escape... methods w/ sjdUtils.pm (or just use).
    Add parseAndInsertXML(). OpenMultiple().
    Move in getCurrentNamespace from ElementManager.pm (last omission).


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut


# These are common to ElementManager.pm.
#
our @EXPORT = qw(
    new reset
    openElement closeElement

    getDepth getCurrentDepth howManyAreOpen
    getCurrentElementName getCurrentType getCurrentFQGI
    getCurrentLanguage
    getIndentString getCurrentIndent setIndentString
    getCurrentXPath getElementCount

    isOpen isCurrent findOpen findOutermost findNOpen
);
# ElementManage.pm also has:
#   getCurrentNamespace

# These are only supported here, not in ElementManager.pm.
#
push @EXPORT, qw(
    getVersion getOption getOptionList setOption
    setSpace setInline setEmpty setCantRecurse setSuppress

    openMultiple closeMultiple
    openElementUnlessOpen openElementUnlessCurrent
    closeAllElements closeToElement closeThroughElement closeAllOfThese
    adjustToRank

    makeDoctype endDocument
    makeElementWithText makeEmptyElement
    makeText makePI makeComment
    makeCharRef makeRawText

    queueAttribute getQueuedAttributes clearQueuedAttributes

    fixName normalizeSpace
    escapeXmlContent escapeUri escapeAttribute escapeAscii
    sysgen
 );

our $schemes = "http|https|ftp|mailto";


###############################################################################
#
package XmlOutput;

sub new {
    my ($class, $oFH) = @_;

    my $self = {
        version          => $VERSION_DATE,
        outputFH         => ($oFH) ? $oFH : \*STDOUT,

        ############################## # Output XML tree state
        queuedAttributes => {},
        tagStack         => [],
        langStack        => [],
        attrStack        => [],

        ############################## # Some basic stats
        elementCount     => 0,
        ids              => {},
        sysgenCounter    => 1,

        ############################## # Options
        options          => {
            asciiOnly        => 0,         # Entify anything that's not ASCII?
            breakSTAGO       => 1,         # Places to put line-breaks
            breakAttrs       => 0,
            breakSTAGC       => 0,
            breakETAGO       => 0,
            breakETAGC       => 0,
            defaultLang      => "",
            divClass         => "class",
            divTag           => "div",
            entityFormat     => "&#x%05x;",
            escapeUris       => 0,
            escapeText       => 1,
            fixNames         => 0,
            htmlFormat       => 0,
            htmlEntities     => 0,
            idAttrName       => "id",
            indent           => 1,
            iri              => 1,         # Allow Unicode in URIs?
            iString          => "    ",    # String to repeat to make indents
            normalizeText    => 0,
            oencoding        => "utf8",
            suppressWSN      => 0,
            sysgenPrefix     => "A" . time(),
            trackIDs         => 0,          # Unused
            URIchars         => "-.\\w\\d_!\$\'()*+",
        },

        ############################## # Options for categories of elements.
        spaceSpecs       => {},        # Elements w/ extra \n before
        cantRecurse      => {},
        inlines          => {},
        empties          => {},
        suppressed       => {},
    }; # self

    if ($oFH) {
        binmode($oFH,"utf8");
    }
    else {
        print "";
        binmode(STDOUT,"utf8");
    }
    bless $self, $class;
    return($self);
} # new

sub reset {
    my ($self) = @_;
    $self->{queuedAttributes} = {};
    $self->{tagStack}         = [];
    $self->{langStack}        = [];
    $self->{attrStack}        = [];
    $self->{elementCount}     = 0;
    $self->{ids}              = {};
    $self->{sysgenCounter}    = 1;
}


###############################################################################
# Generate markup (basic)
#
sub openElement {
    my ($self,
        $gi,                 # Element type name
        $attrs,              # Hash of attributes
        $makeEmpty           # Use empty-element syntax?
        ) = @_;

    if ($self->{cantRecurse}->{$gi}) {
        while($self->howManyAreOpen($gi) > 0) {
            $self->closeElement();
        }
    }

    # Figure how many newlines before start-tag
    my $extra = 0;
    if (defined $self->{spaceSpecs}->{$gi}) {
        $extra = $self->{spaceSpecs}->{$gi};
    }
    elsif (defined $self->{inlines}->{$gi}) {
        $extra = 0;
    }
    elsif ($self->{options}->{breakSTAGO} || $self->{options}->{indent}) {
        $extra = 1;
    }
    if ($extra>0) {
        $self->makeRawText(("\n" x $extra) . $self->getIndentString(0));
    }

    # Assemble any attributes (including queued ones)
    my $attrCache;
    if (ref($attrs) eq "HASH") { $attrCache = $attrs; }
    elsif ($attrs)             { $attrCache = $self->parseAttrString($attrs); }
    else                       { $attrCache = {}; }
    my $qa = $self->getQueuedAttributes();
    for my $a (keys(%{$qa})) {
        $attrCache->{$a} = $qa->{$a};
    }
    $self->clearQueuedAttributes();

    # Assemble the start-tag, and push it if not empty
    my $out = "<$gi";
    for my $a (sort keys(%{$attrCache})) {
        $out .= ($self->{breakAttrs} ? $self->getIndentString(1) : " ") .
            "$a=\"" . $self->escapeXmlAttribute($attrCache->{$a}) . "\"";
    }
    if ($makeEmpty) {
        $out .= "/>";
    }
    else {
        $out .= ">";
        push @{$self->{tagStack}}, $gi;
        push @{$self->{langStack}},
               $self->{langStack}->[-1] || $self->{options}->{defaultLang};
        push @{$self->{attrStack}}, $attrCache;
    }

    # Possibly add a newline after end of start-tag
    if ($self->{options}->{breakSTAGC} &&
        !defined $self->{inlines}->{$gi}) { $out .= "\n"; }
    $self->makeRawText($out);
} # openElement

sub closeElement {
    my ($self, $gi) = @_;
    if (!$gi) { $gi = $self->{tagStack}->[-1]; }
    if ($self->getDepth() <= 0) {
        warn "closeElement: Nothing open.\n";
        return;
    }
    if (defined $gi && $gi ne $self->{tagStack}->[-1]) {
        warn "closeElement: '$gi' is not the innermost open element (stack: " .
            $self->getCurrentFQGI() . ").\n";
        return;
    }
    if (scalar keys %{$self->{queuedAttributes}}) {
        warn "closeElement: Should not be these queued attributes: '" .
            join(", ",sort(keys(%{$self->{queuedAttributes}}))) . "'.\n";
        $self->clearQueuedAttributes();
    }
    my $out = "</$gi>";
    if ($self->{options}->{breakETAGO} &&  # Don't indent unless also breaking.
        !defined $self->{inlines}->{$gi}) {
        $out = $self->getIndentString(1,-1) . $out;
    }
    if ($self->{breakETAGC} &&
        !defined $self->{inlines}->{$gi}) { $out = $out . "\n"; }
    $self->makeRawText($out);
    pop @{$self->{tagStack}};
    pop @{$self->{langStack}};
    pop @{$self->{attrStack}};
} # closeElement


###############################################################################
# Get basic state information
#
sub getDepth {
    my ($self) = @_;
    my $d = scalar(@{$self->{tagStack}});
    return($d);
}
sub getCurrentDepth {
    getDepth(@_);
}
sub howManyAreOpen {
    my ($self, $giList) = @_;
    my @giList = split(/\s+/,$giList);
    my $nOpen = 0;
    for (my $i=0; $i<$self->getDepth(); $i++) {
        for (my $j=0; $j<scalar @giList; $j++) {
            if ($giList[$j] eq $self->{tagStack}->[$i]) {
                $nOpen++; last;
            }
        }
    }
    return($nOpen);
}

sub getCurrentElementName {
    my ($self) = @_;
    my $tsRef = $self->{tagStack};
    my @ts = @$tsRef;
    return(scalar(@ts) ? $ts[-1]:undef);
}
sub getCurrentType {
    getCurrentElementName(@_);
}
sub getCurrentFQGI {
    my ($self) = @_;
    my $tsRef = $self->{tagStack};
    return(scalar(@$tsRef) ? join("/",@$tsRef):undef);
}

sub getCurrentLanguage {
    my ($self) = @_;
    my $lsRef = $self->{langStack};
    my @ls = @$lsRef;
    return(scalar(@ls) ? $ls[-1]:undef);
}


###############################################################################
#
sub getCurrentXPath {
    my ($self,
        $form,               # L: count by GI; S: by element; else by nodes
        #useID,              # If true, lead with ID if available
        ) = @_;
    my $rc = "";
    for (my $i=$self->getDepth()-1; $i>=0; $i--) {
        my $frame = $self->{eStack}->[$i];
        if ($frame->{id}) {
            return($frame->{id} . "/" . $rc);
        }
        my $mygi = $self->getCurrentType($i);
        my $cnum = ($i==0) ? 1 : $self->{eStack}->[$i-1]->{nChildren};
        if ($form eq "L")    { $rc .= "/*[$cnum][self:$mygi]"; }
        elsif ($form eq "S") { $rc .= "/*[$cnum]"; }
        else                 { $rc .= "/$cnum"; }
    }
    return($rc);
} # getCurrentXPath

sub getElementCount {
    my ($self) = @_;
    return($self->{elementCount});
}


###############################################################################
# Get information about whether a given element type(s) is open.
#
sub isOpen {
    return((findOpen(@_)==-1) ? 0:1);
}
sub isCurrent {
    my ($self, $names) = @_;
    $names = " $names ";
    my $cur = $self->getCurrentType();
    return((index($names, " $cur ")>=0) ? 1:0);
}
sub findOpen {
    my ($self, $names) = @_;
    $names = " $names ";
    my $d = $self->getDepth();
    for (my $i=$d-1; $i>=0; $i--) {
        if (index($names, " $self->{eStack}->[$i]->{name} ")>=0) {
            return($i);
        }
    }
    return(-1);
}
sub findOutermost {
    my ($self, $names) = @_;
    $names = " $names ";
    my $d = $self->getDepth();
    for (my $i=0; $i<$d; $i++) {
        if (index($names, " $self->{eStack}->[$i]->{name} ")>=0) {
            return($i);
        }
    }
    return(-1);
}
sub findNOpen {
    my ($self, $names) = @_;
    $names = " $names ";
    my $d = $self->getDepth();
    my $nopen = 0;
    for (my $i=$d-1; $i>=0; $i--) {
        if (index($names, " $self->{eStack}->[$i]->{name} ")>=0) {
            $nopen++;
        }
    }
    return($nopen);
}


###############################################################################
# Option handling
#
sub getVersion {
    my ($self) = @_;
    return($self->{version});
}

sub getOption {
    my ($self, $oname) = @_;
    return($self->{options}->{$oname});
}
sub getOptionList {
    my ($self) = @_;
    my @opts = sort keys(%{$self->{options}});
    return(\@opts);
}
sub setOption {
    my ($self, $oname, $ovalue) = @_;
    if ($oname eq "oencoding") {
        binmode($self->{outputFH}, ":encoding($ovalue)");
    }
    elsif (!defined $self->{options}->{$oname}) {
        warn "setOption: Unknown option name '$oname'.\n    Known options: " .
            join(", ", @{$self->getOptionList()}) . ".\n";
        return;
    }
    $self->{options}->{$oname} = $ovalue;
}

sub getIndentString {
    my ($self) = @_;
    return($self->{options}->{iString});
}
sub setIndentString { # Compatibility w/ ElementManager.pm.
    my ($self, $s) = @_;
    $self->setOption("iString",$s);
}
sub getCurrentIndent {
    my ($self, $newline, $offset) = @_;
    ($self->{options}->{indent}) || return("");
    if (!defined $offset) { $offset = 0; }
    my $level = $self->getDepth() + $offset;
    return(($newline?"\n":"") . $self->{options}->{iString} x $level);
}

###############################################################################
# Options whose values are element-lists.
#
sub setSpace {
    my ($self, $enames, $code) = @_;
    for my $e (split(/\s+/, $enames)) {
        $self->{spaceSpecs}->{$e} = $code;
    }
}

sub setInline {
    my ($self, $enames) = @_;
    if ($enames eq "#HTML") {
        $enames =
            "A ABBR ACRONYM B BASEFONT BDO BIG BR CITE CODE DFN " .
            "EM FONT I IMG INPUT KBD LABEL Q S SAMP SELECT SMALL " .
            "SPAN STRIKE STRONG SUB SUP TEXTAREA TT U VAR";
        # Sometimes inline:
        #   "APPLET BUTTON DEL IFRAME INS MAP OBJECT SCRIPT";
    }
    for my $e (split(/\s+/, $enames)) {
        $self->{inlines}->{$e}++;
    }
}

sub setEmpty {
    my ($self, $enames) = @_;
    for my $e (split(/\s+/, $enames)) {
        $self->{empties}->{$e}++;
    }
}

sub setCantRecurse {
    my ($self, $enames) = @_;
    for my $e (split(/\s+/, $enames)) {
        $self->{cantRecurse}->{$e}++;
    }
}

sub setSuppress {
    my ($self,$enames) = @_;
    for my $e (split(/\s+/, $enames)) {
        $self->{suppressed}->{$e}++;
    }
}


###############################################################################
# Get information about the current output state (elements open, etc.)
#
sub queueAttribute {
    my ($self, $aname, $avalue) = @_;
    if (defined $self->{queuedAttributes}->{$aname}) {
        warn "queueAttribute: Attribute '$aname' already queued.\n";
    }
    $self->{queuedAttributes}->{$aname} =
        ($avalue) ? $self->escapeXmlAttribute($avalue):"";
}
sub getQueuedAttributes {
    my ($self) = @_;
    return($self->{queuedAttributes});
}
sub clearQueuedAttributes {
    my ($self) = @_;
    $self->{queuedAttributes} = {};
}

sub parseAttrString {
    my ($self, $s) = @_;
    my $xname = '(\w[-:.\w]*)';
    my $qlit  = '(\'[^\']*\'|"[^"]*")';
    my $attrHash = {};
    while ($s) {
        $s =~ s/^\s*$xname\s*=\s*$qlit//;
        ($2) || last;
        $attrHash->{$1} = $2;
    }
    if ($s =~ m/\S/) {
        warn "Bad attr string, remainder: '$s'.\n";
    }
    return($attrHash);
} # parseAttrString


###############################################################################
# Generate markup (fancier)
#
sub openMultiple {
    my $self = shift @_;
    for my $gi (@_) {
        $self->openElement($gi);
    }
}

sub openElementUnlessOpen {
    my ($self, $gi, $attrs) = @_;
    ($self->howManyAreOpen($gi)>0) && return;
    $self->openElement($gi, $attrs);
}

sub openElementUnlessCurrent {
    my ($self, $gi, $attrs) = @_;
    ($self->{tagStack}->[-1] eq $gi) && return;
    $self->openElement($gi, $attrs);
}

sub closeMultiple {
    my $self = shift @_;
    for my $gi (@_) {
        $self->closeElement($gi);
    }
}

sub closeAllElements {
    my ($self) = @_;
    while ($self->getDepth()) {
        $self->closeElement();
    }
}

sub closeToElement {
    my ($self, $gi) = @_;
    ($self->howManyAreOpen($gi)>0) || return;
    while ($self->getDepth()) {
        ($self->{tagStack}->[-1] eq $gi) && last;
        $self->closeElement();
    }
}

sub closeThroughElement {
    my ($self, $gi) = @_;
    ($gi) || die "closeThroughElement: No element specified.\n";
    ($self->howManyAreOpen($gi)>0) || return;
    while ($self->getDepth()) {
        my $cur = $self->{tagStack}->[-1];
        $self->closeElement();
        ($cur eq $gi) && last;
    }
}

# Call this with a list of space-separated element type names, to make sure
# all instances of any of those element types are closed.
#
sub closeAllOfThese {
    my ($self, $giList) = @_;
    my @giList = split(/\s+/,$giList);
    while ($self->howManyAreOpen($giList)>0) {
        $self->closeElement();
    }
}

# Close and/or open DIVs or similar elements, in order to get all set to
# issue a heading at a given (numbered) level (counting from 0).
#
sub adjustToRank {
    my ($self, $targetLevel) = @_;
    while ($self->howManyAreOpen($self->{options}->{divTag}) >= $targetLevel) {
        $self->closeThroughElement($self->{options}->{divTag});
    }
    for (my $cur=$self->howManyAreOpen($self->{options}->{divTag});
         $cur<=$targetLevel; $cur++) {
        if ($self->{options}->{divClass} ne "") {
            $self->queueAttribute($self->{options}->{divClass}, "level_$cur");
        }
        $self->openElement($self->{options}->{divTag});
    }
    # Now we're ready to put in the title (Hn in HTML).
}


###############################################################################
#
sub makeDoctype {
    my ($self, $documentElement, $pub, $sys) = @_;
    $self->makeRawText("<?xml version=\"1.0\" encoding=\"" .
                   $self->{options}->{oencoding} . "\"?>\n");
    $self->makeRawText("<!DOCTYPE $documentElement PUBLIC \"" .
        ($pub || "") . "\" \"" . ($sys || "") . "\" []>\n");
}

sub endDocument {
    my ($self) = @_;
    $self->closeAllElements();
    if ($self->{openFH} && $self->{openFH} != \*STDOUT) {
        close($self->{openFH});
        $self->{openFH} = undef;
    }
}

sub makeEmptyElement {
    my ($self, $gi, $attrs) = @_;
    $self->openElement($gi, $attrs, 1);
}

sub makeElementWithText {
    my ($self, $gi, $text) = @_;
    $self->openElement($gi);
    $self->makeText($text);
    $self->closeElement($gi);
}

sub makeComment {
    my ($self, $text) = @_;
    $text =~ s/--/- -/g;
    $self->makeRawText($self->getIndentString(1) . "<!--$text-->");
}

sub makePI {
    my ($self, $target, $text) = @_;
    $self->makeRawText($self->getIndentString(1) . "<?$target $text?>");
}

sub makeCharRef {
    my ($self, $text) = @_;
    if ($text =~ m/^\d+$/) {
        $self->makeRawText(sprintf($self->{options}->{entityFormat},$text));
    }
    else {
        $self->makeRawText("&$text;");
    }
}

sub makeText {
    my ($self, $text) = @_;
    ($self->{options}->{suppressWSN} && $text =~ m/^\s*$/) && return;
    if ($self->{options}->{normalizeText}) {
        $text = $self->normalizeSpace($text);
    }
    if ($self->{options}->{escapeText}) {
        $text = $self->escapeXmlContent($text);
    }
    $self->makeRawText($text);
}

sub makeRawText {
    my ($self, $x) = @_;
    if ($self->getDepth()) {
        my $suRef = $self->{suppressed};
        my %su = %$suRef;
        my $fqgi = $self->getCurrentFQGI();
        for my $gi (split(/\//, $fqgi)) {
            (defined $su{$gi}) && return;
        }
    }
    if ($self->{outputFH}) { my $ofh = $self->{outputFH}; print $ofh $x; }
    else { print $x; }
}


###############################################################################
# Escape as needed for various XML contexts.
# (these are all available in sjdUtils.pm as well).
#
#
sub fixName {
    my ($self, $name) = @_;
    $name =~ s/[^-:_\w\d.]/_/g;
    if ($name eq "" or index("0123456789.-_:",substr($name,0,1))>=0) {
        $name = "A.$name";
    }
    return($name);
}

sub normalizeSpace {
    my ($self, $s) = @_;
    ($s) || return("");
    $s =~ s/\s+/ /g;
    $s =~ s/^ //g;
    $s =~ s/ $//g;
    return($s);
}

sub escapeXmlContent {
    my ($self, $s) = @_;
    ($s) || return("");
    # We quietly delete the non-XML control characters!
    $s =~ s/[\x{0}-\x{8}\x{b}\x{c}\x{e}-\x{1f}]//g;
    $s =~ s/&/&amp;/g;
    if ($self->{options}->{htmlEntities}) {
        $s = HTML::Entities::encode($s);
    }
    $s =~ s/</&lt;/g;
    $s =~ s/]]>/]]&gt;/g;
    if ($self->{options}->{asciiOnly}) {
        $s =~ s/(\P{IsASCII})/ { sprintf($self->{options}->{entityFormat},ord($1)); }/ge;
    }
    return $s;
}

sub escapeUri {
    my ($self, $s) = @_;
    return($s) unless ($s =~ m/[^$self->{options}->{URIchars}]/);
    my $t = "";
    for (my $i=0; $i<length($s); $i++) {
       my $c = substr($s,$i,1);
       my $o = ord($c);
       if (($self->{options}->{iri} && $o > 127) ||
           $c =~ m/[$self->{options}->{URIchars}]/) { # Ok URI char
           $t .= $c;
       }
       elsif (ord($c) > 255) {
           warn "XmlOutput.escapeURI: Non-ASCII chars, IRI not set.\n";
       }
       else {
           $t .= sprintf("%%%02x",ord($c));
       }
    }
    return($t);
}

sub escapeXmlAttribute {
    my ($self,$s) = @_;
    ($s) || return("");
    if ($self->{options}->{escapeUris} && $s =~ m/^($schemes):\/\//) {
        $s = $self->escapeUri($s);
    }
    # We quietly delete the non-XML control characters!
    $s =~ s/[\x{0}-\x{8}\x{b}\x{c}\x{e}-\x{1f}]//g;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/"/&quot;/g;
    if ($self->{options}->{asciiOnly}) {
        $s =~ s/(\P{IsASCII})/{ sprintf($self->{options}->{entityFormat}, ord($1)); }/ges;
    }
    return($s);
}

sub escapeAscii {
    my ($self,$s) = @_;
    ($s) || return("");
    $s =~ s/(\P{IsASCII})/ { sprintf("&#x%04x;",ord($1)); }/ge;
    #$s = xmlEscape($s);
    return($s);
}

sub sysgen {
    my ($self) = @_;
    return($self->{sysgenPrefix} . $self->{sysgenCounter}++);
}

1;
