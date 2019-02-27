#!/usr/bin/perl -w
#
# ElementManager: Maintain XML parser state for various other tools.
#
# 2013-01-21: Broken out from FakeParser.pm, Steven J. DeRose.
# 2013-01-23: Add StackFrame internal package, logTextNode(), logPI(),
#     logComment, isOpen(), isCurrent(), doStats. Track/check IDs.
# 2013-09-19: Add packages for AttributeDefinition and ElementDefinition.
#     Start content-model and tag-omission support. Re-sync w/ XmlOutput.pm.
#     Drop userData from elementStackFrames.
#
# To do:
#     Namespaces on start vs. end tags.
#     Make this superclass of XmlOutput.pm?
#     Integrate element library stuff from YMLParser.pm?
#     Integrate into XMLUTILS: !!!normalizeXml, !!!YMLParser.pm
#
# Low priority:
#     Make trivial to use atop XML::Parser
#         Register calls here with XML::Parser, then we call user cb's?
#     Integrate into anything that uses tagSTack
#
use strict;
use Getopt::Long;
use Encode;

#use sjdUtils;

our $VERSION_DATE = "1.10";

use Exporter;
our @ISA = qw( Exporter );

# These are common to XmlOutput.pm.
our @EXPORT = qw(
    new reset
    openElement closeElement

    getDepth getCurrentDepth howManyAreOpen
    getCurrentElementName getCurrentType getCurrentFQGI
    getCurrentLanguage
    getIndentString setIndentString getCurrentIndent
    getCurrentXPath getElementCount

    isOpen isCurrent findOpen findOutermost findNOpen
);

# These are just supported here.
#
push @EXPORT, qw(
    logTextNode logPI logComment
    getCurrentNamespace getCurrentDefaultNamespace mapNamespacePrefix

    defineElement defineAttribute canElementStart canElementEnd
);



###############################################################################
###############################################################################
###############################################################################
#
package ElementManager;

sub new {
    my $class = shift @_;
    my $self = {
        # Schema information
        eDefs         => {},           # ElementDefinition objects
        idDefs        => {},           # unused
        idrefDefs     => {},           # unused

        # Parser state (open element stack, mainly)
        eStack        => [],

        # Global/persistent parser state
        doStats       => 1,
        elementCount  => 0,         # Total elements seen so far
        ids           => {},        # All IDs seen so far
        iString       => "  ",      # For pretty-printing
    };

    bless $self, $class;
    return $self;
} # new ElementManager

sub reset {
    my ($self, $s) = @_;
    $self->{eStack}       = [];
    $self->{elementCount} = 0,
    $self->{ids}          = {};
}


###############################################################################
# Document-instance events
#
sub openElement {
    my ($self, $gi, $attrs) = @_; # maybe allow attrs string too?
    my $parent = $self->{eStack}->[-1];

    $gi =~ s/(.*)://;
    my $nsPrefix = $1;
    my $nsURI = $self->mapNamespacePrefix($nsPrefix);

    my $newFrame = new ElementStackFrame(
        $parent, $nsPrefix, $nsURI, $gi, $attrs);
    push @{$self->{eStack}}, $newFrame;

    if ($self->{doStats}) {
        $self->{elementCount}++;
    }

    my $id = $newFrame->{id};
    if ($id) {
        if (defined $self->{ids}->{$id}) {
            warn("Duplicate ID '$id'. Previous one was at element #" .
                $self->{ids}->{$id} . ".");
        }
        else {
            $self->{ids}->{$id} = $self->{elementCount};
        }
    }
} # openElement

sub closeElement {
    my ($self, $gi) = @_;
    my $curType = $self->getCurrentType();
    if (!$curType) {
        warn "closeElement called for '$gi', but nothing is open.\n";
        return(0);
    }
    elsif ($gi) {
        ($curType eq $gi) || warn
            "closeElement for '$gi', but current element is '$curType'.\n";
    }
    if ($self->{doStats}) {
    }
    pop @{$self->{eStack}};
} # closeElement


###############################################################################
# Get basic state information
#
sub getDepth {
    my ($self) = @_;
    return(scalar(@{$self->{eStack}}));
}
sub getCurrentDepth {
    return(getDepth(@_));
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
    return(getCurrentType(@_));
}
sub getCurrentType {
    my ($self, $n) = @_;
    if (!defined $n) { $n = -1; }
    if (abs($n) >= $self->getDepth()) { return(undef); }
    return($self->{eStack}->[$n]->{name});
}
sub getCurrentFQGI {
    my ($self, $sep) = @_;
    if (!$sep) { $sep = "/"; }
    my $buf = "";
    for my $i (0..$self->getDepth()-1) {
        $buf .= $self->{eStack}->[$i]->{name} . "/";
    }
    return($buf);
}

sub getCurrentLanguage {
    my ($self, $n) = @_;
    if (!defined $n) { $n = -1; }
    if (abs($n) >= $self->getDepth()) { return(undef); }
    return($self->{eStack}->[$n]->{lang});
}

sub getIndentString {
    my ($self, $s) = @_;
    return($self->{iString});
}
sub setIndentString {
    my ($self, $s) = @_;
    $self->{iString} = $s;
}
sub getCurrentIndent {
    my ($self, $offset) = @_;
    if (!$offset) { $offset = 0; }
    return($self->{iString} x ($offset+$self->getDepth()));
}



###############################################################################
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
###############################################################################
# Construction of other node types -- here we just record them, while
# XmlOutput.pm actually constructs and outputs them.
#
sub logTextNode {
    my ($self, $txt) = @_;
    return unless ($self->{doStats});
    $self->{eStack}->[-1]->{nTextNodes}++;
    if ($txt && $txt !~ m/\S/) {
        $self->{eStack}->[-1]->{nWSOs}++;
    }
}

sub logPI {
    my ($self) = @_;
    return unless ($self->{doStats});
    $self->{eStack}->[-1]->{nPIs}++;
}

sub logComment {
    my ($self) = @_;
    return unless ($self->{doStats});
    $self->{eStack}->[-1]->{nComments}++;
}



###############################################################################
###############################################################################
# Element type and namespaces
#
sub getCurrentNamespace {
    my ($self, $n) = @_;
    if (!defined $n) { $n = -1; }
    if (abs($n) >= $self->getDepth()) { return(undef); }
    return($self->{eStack}->[$n]->{nsPrefix},
           $self->{eStack}->[$n]->{nsURI});
}
sub getCurrentDefaultNamespace {
    my ($self, $n) = @_;
    if (!defined $n) { $n = -1; }
    if (abs($n) >= $self->getDepth()) { return(undef); }
    if ($n < 0) { $n = $self->getDepth() + $n; }
    for (my $i=$n; $i>=0; $i--) {
        my $dns = $self->{eStack}->[$i]->{namespaces}->{""}; # "xmlns:"
        if ($dns) { return($dns); }
    }
    return("", "");
}
sub mapNamespacePrefix {
    my ($self, $prefix) = @_;
    for (my $i=$self->getDepth()-1; $i>=0; $i--) {
        my $nss = $self->{eStack}->[$i]->{namespaces};
        if ($nss && defined $nss->{$prefix}) {
            return($nss->{$prefix});
        }
    }
    return(undef);
} # mapNamespacePrefix


###############################################################################
###############################################################################
# Schema stuff (see also following packages).
#
sub defineElement {
    my ($self, $gi, $model) = @_;
    $self->{eDefs}->{$gi} = new ElementDefinition($gi, $model);
    return(1);
}

sub defineAttribute {
    my ($self, $gi, $attr, $type, $dft) = @_;
    my $elem = $self->{eDefs}->{$gi};
    if (!$elem) {
        warn "No element '$gi' to hang attribute '$attr' on.\n";
        return(0);
    }
    $elem->addAttribute($attr, $type, $dft);

    if ($type eq "ID") {
        $self->{idDefs}->{$gi."@".$attr} = 1;
    }
    elsif ($type eq "IDREF" || $type eq "IDREFS") {
        $self->{idrefDefs}->{$gi."@".$attr} = 1;
    }
    return(1);
} # defineAttribute

# RC:
#     -2 Not even known
#     -1 Not valid even with omissions
#      0 Valid but only with omissions
#      1 Valid via inclusion exception (not "proper")
#      2 Valid via content model
# Also return list of what to imply to get there?
#
sub canElementStart {
    my ($self, $gi) = @_;
    if (!defined $self->{eDefs}->{$gi})    { return(-2); }
    if ($self->isElementOkViaModel($gi))   { return( 2); }
    if ($self->effectiveInclusionFor($gi)) { return( 1); }
    if ($self->canWeOmitOurWayThere($gi))  { return( 0); }
    return(-1);
}

sub canElementEnd {
    my ($self, $gi) = @_;
    if ($self->{eStack}->[-1]->{name} eq $gi) {
        return(2);
    }
    elsif ($self->isOpen($gi)) {
        # if everybody further in is end-tag omissable, return(1)
        return(0);
    }
    elsif (defined $self->{eDefs}->{$gi}) {
        return(-1);
    }
    else {
        return(-2);
    }
}

sub isElementOkViaModel {
    my ($self, $gi) = @_;
    return(1);
}

sub effectiveInclusionFor {
    my ($self, $gi) = @_;
    my $foundIncl = my $foundExcl = 0;
    for (my $i=$self->depth(); $i>=0; $i--) {
        my $curName = $self->{eStack}->[$i]->{name};
        my $curDef = $self->{eDefs}->{$curName};
        if (!$curDef) { return(1); }
        if ($curDef->{inclusions} && $curDef->{inclusions} =~ m/\b$gi\b/) {
            $foundIncl++;
        }
        if ($curDef->{exclusions} && $curDef->{exclusions} =~ m/\b$gi\b/) {
            $foundExcl++;
        }
    } # for
    if ($foundIncl && !$foundExcl) { return(1); }
    return(0);
}

# For real SGML compatibility, this would also allow omitted start-tags.
#
sub canWeOmitOurWayThere  {
    my ($self, $gi) = @_;
    return(0);
}



###############################################################################
###############################################################################
###############################################################################
#
package AttributeDefinition;

sub new {
    my ($class, $name, $dclValue, $dftValue, $isFixed) = @_;

    if ($name !~ m/^\w[-_.:\w]*$/) {
        warn "Bad attribute name '$name'\n";
        $name =~ s/[^-_.:\w]/_/g;
    }
    if ($dclValue !~ m/^(ID|IDREFS?|CDATA|NAMES?|NMTOKENS?|ENTITY|ENTITIES)$/ &&
        $dclValue !~ m/^\(\w+([|,&]\w*)*\)$/) {
        warn "Bad declared value '$dclValue' for attribute '$name'\n";
        $dclValue = "CDATA";
    }
    if ($dftValue !~ m/^(#REQUIRED|#IMPLIED|'[^']*'|"[^"]*")$/) {
        warn "Bad default value '$dftValue' for attribute '$name'\n";
        $dftValue = "#IMPLIED";
    }
    my $self = {
        name          => $name,             # id
        dclValue      => $dclValue,         # ID
        dftValue      => $dftValue,         # #REQUIRED
        isFixed       => $isFixed,
    };
    bless $self, $class;
} # new AttributeDefinition

sub isValueOk {
    my ($self, $value) = @_;

    if ($self->{dftValue} eq "#REQUIRED" && !defined $value) { return(0); }
    if ($self->{isFixed} && $value ne $self->{dftValue}) { return(0); }

    if ($self->{dclValue} =~ m/^(ID|IDREF|NAME|NMTOKEN|ENTITY)$/) {
        if ($value !~ m/^\w[-_.:\w]*$/) { return(0); }
    }
    elsif ($self->{dclValue} =~ m/^(IDREFS|NAMES|NMTOKENS|ENTITIES)$/) {
        if ($value !~ m/^\w[-_.:\w]*(\s+\w[-_.:\w]*)+$/) { return(0); }
    }

    if ($self->{dclValue} eq "ID") {
        # record and check uniqueness
    }

    return(1);
}



###############################################################################
###############################################################################
###############################################################################
#
package ElementDefinition;

sub new {
    my ($class, $name, $model, $inclusions, $exclusions) = @_;

    my $self = {
        name          => $name,
        omitStart     => 0,
        omitEnd       => 0,
        dclContent    => undef,
        model         => undef,
        inclusions    => $inclusions,
        exclusions    => $exclusions,
        # Added later:
        attrs         => undef,
        idAttr        => "",
    };
    if ($model =~ m/^(EMPTY|CDATA|RCDATA|ANY)$/) {
        $self->{dclContent} = $model;
    }
    elsif ($model =~ m/^\([-_.:\w\s|&,()#]+\)$/) {
        $self->{model} = $model;
    }
    else {
        warn "Bad model for element '$name': $model.\n";
        $self->{dclContent} = "ANY";
    }
    bless $self, $class;
} # new ElementDefinition

sub addAttribute {
    my ($self, $name, $dclValue, $dftValue, $isFixed) = @_;
    if (defined $self->{attrs}->{$name}) {
        warn "Duplicate attribute '$name' to element '$self->{name}'\n";
    }
    $self->{attrs}->{$name} =
        new AttributeDefinition($name, $dclValue, $dftValue, $isFixed);
}



###############################################################################
###############################################################################
###############################################################################
#
package ElementStackFrame;

sub new {
    my ($class, $parent, $nsPrefix, $nsURI, $name, $attrs) = @_;
    if (scalar(@_) < 5 || scalar(@_) > 6) {
        warn "Bad number of args (" . scalar(@_) .
            ") to ElementStackFrame constructor.\n";
    }
    if (!$name || $name =~ m/[^-_.:\w]/) {
        warn "Bad element type '$name' in ElementStackFrame constructor.\n";
    }

    my $self = {
        name          => $name,
        nsPrefix      => $nsPrefix,
        nsURI         => $nsURI,
        attrs         => undef,
        id            => "",
        lang          => "",
        nameSpaces    => {},            # just ones defined *here*
        startedAt     => "",            # unimplemented

        # Stats
        nChildren     => 0,
        childTypes    => [],
        nDescendants  => 0,
        nTextNodes    => 0,
        nWSOs         => 0,
        nComments     => 0,
        nPIs          => 0,
    };
    bless $self, $class;

    if ($parent) {
        $self->{lang} = $parent->{attrs}->{"xml:lang"};
        $parent->{nChildren}++;
        push @{$parent->{childTypes}}, $name;
    }
    else {
        $self->{lang} = "en";
    }

    if (ref($attrs) ne "HASH") {
        $attrs = $self->parserAttrString($attrs);
    }

    for my $a (keys(%{$attrs})) {
        if ($a =~ m/^xmlns:(.*)/) {
            $self->{nameSpaces}->{$1} = $attrs->{$a};
        }
        elsif ($a eq "xml:lang") {
            $self->{lang} = $attrs->{$a};
        }
        elsif ($a =~ m/^(.*:)id$/i) {
            $self->{id} = $attrs->{$a};
        }
    }
    return $self;
} # new ElementStackFrame

sub parseAttrString {
    my ($self, $s) = @_;
    my $attrHash = {};
    while ($s =~ s/^\s*([-_:.\w]+)\s*=\s*('[^']*'|"[^"]*")//) {
        $attrHash->{$1} = $2;
    }
    if ($s =~ m/\S/) {
        warn "Badd attr string, remainder: '$s'.\n";
    }
    return($attrHash);
} # parserAttrString

1;



###############################################################################
###############################################################################
###############################################################################
#

=pod

=head1 Usage

use ElementManager;

Manage an XML parser's stack state, and return various state information.
Track the cumulative list of defined namespaces.

Similar to, but lighter weight than, C<XmlOutput.pm>, which does
similar tracking for programs that I<generate> XML, and has many more
features for adjusting the stack to keep things valid (closeToElement,
closeElementIfOpen, etc.)



=head1 Methods

=over

=item * B<setIndentString>(s)

Set the indent string, which is used by I<getCurrentIndent>() to generate
indentation for pretty-printing.

=item * B<getCurrentIndent>()

Return the current indent string, repeated as many times as the current depth.

=item * B<openElement>(I<self, gi, attributes?>)

This should be called when a start (or empty) tag is parsed.
It stacks the element, sets or inherits xml:lang and namespaces, etc.
I<attributes> can be a reference to a hash of name=>value pairs,
or a literal attribute string, which will be parsed (only the XML predefined
entities and numeric character references will be expanded in the latter case).
ID attributes will have their values stored, along with the sequence number
of the new element (this can be used to check later IDs and IDREFs).

=item * B<closeElement>(I<self, gi?>)

This should be called when a end tag is parsed.
It pops the information that I<openElement> pushed.
If I<gi> is supplied but does not match the current element type,
a warning is issued and nothing is closed.

=item * B<getDepth>() or B<getCurrentDepth>()

Returns the number of open elements.

=item * B<getCurrentFQGI>()

Returns the list of all open element types, separated by "/".

=item * B<getCurrentXPath>(form)

Return an XPointer-style XPath expression that uniquely identifiers the
current element (sorry, no pointers to text nodes at this time).
If I<form> is "L", it will be like /*[1][self:DIV]/*[4][self:P]....
If I<form> is "S", it will be like /*[1]/*[4]....
Otherwise, it will be like /1/4.... (which is also an XPointer).

=item * B<getCurrentType>I<(n?)> or B<getCurrentElementName>I<(n?)>

Returns the element type name at index I<n> in the open element stack.
If I<n> is undefined, the current element type is returned .
I<n> may be positive, negative, or zero.
Zero is the document element, -1 is the current element.
If I<n> is out of range, C<undef> is returned.

=item * B<getCurrentLanguage>(n?)

Returns the I<xml:lang> value presently in effect.

=item * B<getCurrentNamespace>(n?)

=item * B<getElementCount>()

How many elements have been seen (opened) in all?
This is elements, not nodes (thus attributes, namespace nodes,
pis, comments, and text nodes are not counted).

=item * B<findOpen>(typelist)

Returns true if at least one element of a specified I<type> is open.
Multiple names in I<typelist> must be separated by spaces (not tabs, etc.).

=item * B<findNOpen>(typelist)

Returns how many elements of any specified I<type>(s) are open.
Multiple names in I<typelist> must be separated by spaces (not tabs, etc.).

=item * B<findOutermost>(typelist)

Returns the index into the stack of open elements (0 is the document element),
of the outermost (largest) instance of any of the types listed
Multiple names in I<typelist> must be separated by spaces (not tabs, etc.).

=back



=head1 Known Bugs and Limitations

This doesn't support nearly all the logic for SGML/HTML tag omission.
Mainly meant for XML.


=head1 Related commands

C<FakeParser.pm> -- uses this.

C<XmlOutput.pm> -- similar package, but heavier weight, intended for B<output>
construction rather than parsing. For example, it provides:

=over

=item * escaping for text, PIs, comments, attributes, URIs, etc.

=item * attribute queuing

=item * much more for pretty-printing (though see also C<sjdUtils::indentXml>).

=item * far more stack manipulations: I<openElementUnlessOpen>,
I<openElementUnlessCurrent>, I<adjustToRank>, etc.

=item * a notion of 'cantRecurse', which can be used to force an element
(and any descendants) to close when you try to open a new instance of it.

=back

C<littleParser.py> -- Simple Python XML parser.



=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut
