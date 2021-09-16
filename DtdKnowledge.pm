#!/usr/bin/perl -w
#
# DtdKnowledge.pm: Provide varoius info about HTML (or other) element types.
# 2011-06-02: Written by Steven J. DeRose.
#
use strict;
use XmlTuples;

our %metadata = (
    'title'        => "DtdKnowledge",
    'description'  => "",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5.18",
    'created'      => "2011-06-02",
    'modified'     => "2021-09-16",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

*** UNFINISHED ***

use DtdKnowledge;
my $h = new DtdKnowledge("HTMLknowledge.xsv");

Identifies various information about a given element type in a given
DTD or schema.

Information on a particular DTD can be set up by loading special XSV files,
or (eventually) by loading a schema.

This is mainly intended to provide abstract info
about the significance of the element, not mainly its syntax.


=head2 Properties provided

Boolean property values should be coded as 1 or 0.

=over

=item * 'name': -- the element name itself.

=item * 'display': -- a CSS display type, mainly 'block' or 'inline'.

=item * 'content': -- what the element may contain:

    *document (it's the document element)
    *container (div, chapter, section, appendix, ToC, etc)
    *soup (lots of sub-elements (paragraph, etc)
    *textOnly (can only have text)
    *code (block-level monospace, not just code per se)
    *meta (TEI header, stylesheets, Dublin Core data, etc)
    *empty (whether it should always be empty
    *mixed (whether it can have mixed content)

=item * 'categories': -- any number of whitespace-separated keywords.
For example (with some illustrative cases from HTML or other schemas):

    * 'semantic' vs. 'format' (EM vs. I, DEL vs. STRIKE)
    * 'link' (A, OBJECT)
    * 'form' (FORM and all its components)
    * 'tabular' (TABLE, THEAD, TR, TD)
    * 'heading' (H3)
    * 'list' (UL, OL, DL)
    * 'verbatim' (XMP)
    * 'media' (IMG, OBJECT)
    * 'language-shift' (FOREIGN)
    * 'label' (LABEL, TH; perhaps heading is really a subclass of this?)
    * 'citation' (BibEntry, OSISRef, DC:Creator)
    * 'wordbreak' (true if the tag entails a word boundary. Defaults to true
for all block elements, but not for HTML inlines.

=item * 'pre' -- preferred number of newlines to add before the
element in pretty-printing. Should be zero or unspecified for inlines.

=item * 'post' -- preferred number of newlines to add after the
element in pretty-printing. Should be zero or unspecified for inlines.

=item * 'description': -- human readable documentation string for the element type.

=item * 'attributes': a list of permitted attribute names (this should add
types and defaults, too).

=item * 'model': The content model or other specification of what children
are permitted.

=back


=head1 Methods

=over

=item * B<new>()

=item * B<loadDtd(path)>

=item * B<getTheHash>()

Just return a reference to the entire hash of data used. It is keyed on
element type name. The valueis a hash, keyed on property name.

=item * B<setProp>(I<elementType, propName, propValue>)

Set a piece of element information for the element of type II<elementType>, to I<info>.
The information should include a dispay type, any applicable keywords,
and perhaps pre_N and/or post_N spacing information. Custom keywords can
also be used.

=item * B<getProp>(I<elementType, propName>)

Look up and return some information associated with the element.

=item * B<isDefined>(I<elementType>)

Returns true iff the active schema defines an element type named I<elementType>.


=item * B<getDisplayType>(I<elementType>)

Returns the CSS "Display" property appropriate to the given element.

=item * B<isTagOfType>(I<elementType, typename>)

Checks for any keyword under the I<Subs> property,
most of which have to do with more "semantic" issues:

=over

=item * empty

Identifies syntactically empty elements, which do not take an end-tag in HTML
or SGML, and may use a special tag syntax in XML, XHTML, and by convention in HTML.

=item * category

Identifies element types that give particularly "semantic" information.
For example, abbr, acrony, em (not i).

=over

=item * fmt

=item * heading

=item * list

Lists (not items, that's available as a CSS Display type)

=item * item

List items (not lists). This includes both dt and dd.

=item * link

Anything that refers to another URI.
For example, a, link, style, script, base.
Submit buttons in forms, however, are not included in this category.

=item * tabular

A table or any table component.

=item * form

Form components, including form itself.

=back


=item * B<getPreSpace>(name)

How many extra newlines to put before a given element when pretty-printing.
If no data is provided (for example for all inlines), this call returns 0
for inlines or unknown names, otherwise 1.

=item * B<getPostSpace>(name)

How many extra newlines to put after a given element when pretty-printing.
If no data is provided (for example for all inlines), this call returns 0
for inlines or unknown names, otherwise 1.

=back


=head1 Related files and information

C<tupleData/XXXKnowledge.xsv> -- information for DTD "XXX",
as XSV.

See also the Microsoft "Schema Object Model", which has some similar features to this: 
L<https://docs.microsoft.com/en-us/dotnet/standard/data/xml/xml-schema-object-model-overview>.


=head1 Known bugs and limitations

The set of categories is useful but far from definitive; it's also kind
of fuzzy. Some additional information that might be useful:

implies-word-break (redundant with non-inline?);
out-of-line-content (footnote),
non-content-content (del),
is-milestone (start, mid, end, joiner,....),
preserve-whitespace vs. discard whitespace at ends, vs. normalize,
content-notation,
rank-group (h)

information re. attributes: is-id, is-uri, inherits, is-accessibility-alt


=head1 To do

Need this even exist given XSV does nearly all the work?


=head1 History

* 2011-06-02: Written by Steven J. DeRose.
* 2012-03-15: Integrate w/ XmlTuples.pm and tupleSets/DtdKnowledge.xsv.
Generalize set/get to handle any properties at all.
* 2019-12-24: Update to fit better with DomExtensions.py, etc. Clean up
old usage of packed strings. Pin down properties better.
* 2021-09-16: Cleanup.


=head1 Rights

Copyright 2011-06-02 by Steven J. DeRose. This work is licensed under a
Creative Commons Attribution-Share Alike 3.0 Unported License.
For further information on this license, see
L<https://creativecommons.org/licenses/by-sa/3.0>.

For the most recent version, see L<http://www.derose.net/steve/utilities> or
L<https://github.com/sderose>.


=cut


###############################################################################
#
package DtdKnowledge;

my $infoPath = "";

sub new {
    my ($class, $DTDPath) = @_;
    if (!$infoPath) { $infoPath = ""; }
    if (!-f $infoPath) {
        warn "DtdKnowledge: Can't find XSV file '$infoPath'.\n";
        return(undef);
    }
    my $self = {
        version     => "2012-05-10",
        theHash     => {},
    };

    bless $self, $class;
    if ($DTDPath) { $self->loadDTD($infoPath); }
    return($self);
}

sub setProp {
    my ($self, $elementType, $propName, $propValue) = @_;
    $self->{theHash}->{$elementType}->{$propName} = $propValue;
}

sub getProp {
    my ($self, $elementType, $propName) = @_;
    if (!defined $propName) {
        return($self->{theHash}->{$elementType});
    }
    return($self->{theHash}->{$elementType}->{$propName});
}

sub loadFromDTD {
    my ($self, $path) = @_;
    if (!$path || !-r $path) {
        return(undef);
    }
    my $xt = new XmlTuples();
    ($xt) || die
        "DtdKnowledge.pm:loadDTD: Can't create new XmlTuples.\n";
    $xt->open($path) || die
        "DtdKnowledge.pm:loadDTD: Can't open '$path'.\n";
    $self->{theHash} = $xt->getAllAsHash("Name");
    return(1);
}

sub loadFromXSD {
    my ($self, $path) = @_;
    if (!$path || !-r $path) {
        return(undef);
    }
    my $xt = new XmlTuples();
    ($xt) || die
        "DtdKnowledge.pm:loadDTD: Can't create new XmlTuples.\n";
    $xt->open($path) || die
        "DtdKnowledge.pm:loadDTD: Can't open '$path'.\n";
    $self->{theHash} = $xt->getAllAsHash("Name");
    return(1);
}

sub getTheHash {
    my ($self) = @_;
    return($self->{theHash});
}


###############################################################################
# Check for properties of an element type
#
sub isDefined {
    my ($self, $name) = @_;
    return((defined $self->{theHash}->{$name}) ? 1:0);
}

sub getDisplay {
    my ($self, $name) = @_;
    return($self->getProp($name, "Display"));
}

sub getSubs {
    my ($self, $name) = @_;
    return($self->getProp($name, "Subs"));
}

sub getContent {
    my ($self, $name) = @_;
    return($self->getProp($name, "Content"));
}

sub getDescription {
    my ($self, $name) = @_;
    return($self->getProp($name, "Descr"));
}

sub getPreSpace {
    my ($self, $name) = @_;
    return($self->getProp($name, "Pre"));
}

sub getPostSpace {
    my ($self, $name) = @_;
    return($self->getProp($name, "Post"));
}

1;
