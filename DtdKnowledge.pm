#!/usr/bin/perl -w
#
# DtdKnowledge.pm
#
# Provide varoius info about HTML (or other) element types.
#
# 2011-06-02: Written by Steven J. DeRose.
# 2012-03-15: Integrate w/ XmlTuples.pm and tupleSets/DtdKnowledge.xsv.
#     Generalize set/get to handle any properties at all.
#
# To do:
#     Need this even exist given XmlTuples.pm does nearly all the work?
#
use strict;
use XmlTuples;

our $VERSION_DATE = "1.00";

package DtdKnowledge;

sub new {
    my ($class, $infoPath) = @_;
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
    $self->loadDTD($infoPath);
    return($self);
}

sub setElementInfo {
    my ($self, $name, $propName, $propValue) = @_;
    $self->{theHash}->{$name}->{$propName} = $propValue;
}

sub getElementInfo {
    my ($self, $name, $propName) = @_;
    if (!defined $propName) {
        return($self->{theHash}->{$name});
    }
    return($self->{theHash}->{$name}->{$propName});
}

sub loadDTD {
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
    return($self->getElementInfo($name, "Display"));
}

sub getSubs {
    my ($self, $name) = @_;
    return($self->getElementInfo($name, "Subs"));
}

sub getContent {
    my ($self, $name) = @_;
    return($self->getElementInfo($name, "Content"));
}

sub getDescription {
    my ($self, $name) = @_;
    return($self->getElementInfo($name, "Descr"));
}

sub getPreSpace {
    my ($self, $name) = @_;
    return($self->getElementInfo($name, "Pre"));
}

sub getPostSpace {
    my ($self, $name) = @_;
    return($self->getElementInfo($name, "Post"));
}



###############################################################################
###############################################################################
###############################################################################
#

=pod

=head1 Usage

use DtdKnowledge;
my $h = new DtdKnowledge("HTMLknowledge.xsv");

Identifies various information about a given element type in a given
DTD or schema.

Information on a particular DTD is set up by loading XML Tuples files (cf):

=over

=item * HTML

=item * DocBook

=item * NLM

=item * TEI

=back



=head2 Properties provided

=over

=item * Name -- the element name itself.

=item * Display -- a CSS display type.

=item * Content -- what the element may contain: 
document (it's the document element),
mongo (lots of blocks), soup (lots of sub-elements, like a paragraph can have),
textOnly, meta (contains code, stylesheets, metadata, etc), empty.

=item * Subs -- any number of keyword, indicating features such as
 whether the tag is more semantic or format oriented:
sem, fmt, link, form, tabular, head, list. Probably should add: language-shift,
microformat.xxx, citation, image, media, 

=item * Pre and Post -- preferred number of newlines to add before and after the
element in pretty-printing.

=item * Description -- human readable documentation string for the element type.

=back

Could also add the content model, attlist, etc., but those are already
available in typical schemas; this is meant to provide more abstract info
about the significance of the element, not mainly its syntax.



=head1 Methods

=over

=item * B<new>()

=item * B<loadDtd(path)>

=item * B<getTheHash>()

Just return a reference to the entire hash of data used. It is keyed on
element type name, and the values are all strings, with white-space-separated
tokens for the types. Spacing is indicated (for example) as pre_4 post_3.

=item * B<setElementInfo>(I<elementType, info>)

Set the element information for the element of type II<elementType>, to I<info>.
The information should include a dispay type, any applicable keywords,
and perhaps pre_N and/or post_N spacing information. Custom keywords can
also be used; keywords should be separated by word boundaries (generally
whitespace), and should not contain non-word characters.

=item * B<getElementInfo>(I<elementType>)

Look up and return the information associated with the element.
(presently a string, to become a hash).

=item * B<isDefined>(I<elementType>)

Returns true iff the active DTD defines an element type named I<elementType>.


=item * B<getDisplayType>(I<elementType>)

Returns the CSS "Display" property appropriate to the given element.

=item * B<isTagOfType>(I<elementType, typename>)

Checks for any keyword under the I<Subs> property,
most of which have to do with more "semantic" issues:

=over

=item * empty

Identifies syntactically empty elements, which do not take an end-tag in HTML
or SGML, and may use a special tag syntax in XML and XHTML.

=item * sem

Identifies element types that give particularly "semantic" information.
For example, abbr, acrony, em (not i). 

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



=head1 Related files

C<tupleData/XXXKnowledge.xsv> -- information for DTD "XXX",
as XML Tuples.



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



=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons 
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut

1;
