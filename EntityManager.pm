#!/usr/bin/perl -w
#
# EntityManager.pm
# 2011-03-11: Written by Steven J. DeRose, based on my ymlParser.pm.
#
use strict;
use XML::DOM;
#use XML::Catalog;
use HTML::Entities;
# http://search.cpan.org/~adamk/Archive-Zip-1.30/lib/Archive/Zip/MemberRead.pm
#use Archive::Zip;
#use Archive::Zip::MemberRead;

our %metadata = (
    'title'        => "EntityManager",
    'description'  => "",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5.18",
    'created'      => "2011-03-11",
    'modified'     => "2021-09-16",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

use EntityManager;

Utility to support XML and XML-like parsers by:

=over

=item * maintaining a dictionary of known entities

=item * manage interaction with XML entity catalogs (for resolving
entity references to system objects such as URIs or files)

=item * maintaining a stack of currently-open entities

=item * providing transparent input from the resulting data stream

=item * supporting expansion of entities and numeric character references

=item * handle data-encoding issues (future)

=back

=head2 Example code

(most likely, this will be done from somewhere in an XML implementation)

  use EntityManager;
  $fp = new EntityManager();
  $fp->openCatalog($path);
  $fp->defineTextEntity("gfdl", "This document is license under the GFDL.");
  ...various parsing stuff...
    my $newTextNode = $fp->expandGeneralEntities($oldTextNode);
  ...

=head2 Kinds of entities

See L<http://www.w3.org/TR/REC-xml/#sec-entity-decl>

=over

=item * Parameter vs. General

=item * Internal vs. External

=item * Parsed (always Internal) vs. Unparsed

=item * Notation (can only be General)

=back


=head1 Methods

=over

=item * B<new>()

=item * B<reset>()

Close all open entities. However, defined entities are not undefined.


=item * B<getOption>(I<name)

Return the current value of the named option (see I<setOption>).

=item * B<setOption>(I<name, value>)

Set the named option to the given value. Options available include:

=over

=item I<verbose> -- (integer) issue various messages to STDERR.

=item I<canRedefine> -- Allow entities to be redefined (if declarations are
being passed in from a parser reading an XML DTD, this should be off.

=item I<Stream_Delimiter> -- See C<XML::Parser>.

=item I<useHTMLEntities> -- Recognize the HTML 4 named entities.

=item I<useXMLEntities> -- Recognize XML's 5 predefined entities.

=item I<useGenrlEntities> -- Recognize declared general entities.

=item I<useParamEntities> -- Recognize declared parameter entities.

=item I<useNumericRefs> -- Recognize decimal and hex character references.

=item I<useNDATAEntities> -- Recognize declared unparsed / ndata / notation
entities.

=item I<expandGeneralEntities> -- (Boolean) if turned off,
entities will be returned as I<unparsed> events with a single argument,
which is the original form of the entity (or numeric character) reference.

=back



=item * B<addPath>(path)

Add I<path> to the end of the list of directories, in which to search
for external entities. First added, is first searched.
By default, only the current working directory is searched.

=item * B<addCatalog>(path)

Add the file at I<path> to the list of open XML entity-resolution catalogs.
See L<http://www.oasis-open.org/committees/entity/specs/cs-entity-xml-catalogs-1.0.html> for the implementation used,
and L<http://search.cpan.org/~ebohlman/XML-Catalog-0.02/Catalog.pm>
for a more current Catalog format specification.
For example:

  <public publicId="ISO 8879:1986//ENTITIES Added Latin 1//EN"
          uri="iso-lat1.gml"/>
  <public publicId="-//USA/AAP//DTD BK-1//EN"
          uri="aapbook.dtd"/>
  <public publicId="-//Example, Inc.//DTD Report//EN"
          uri="http://www.example.com/dtds/report.dtd"/>

=item * B<addEntityCallback>(cb)

Attach the callback function I<cb> to handle entity references that cannot
be resolved otherwise (including ones that could be resolved except that
their resolution is turned off by some option (see I<setOption>).
I<cb> will be called like:

    resolver(theEntityManager, entityName, system, public, isParam)

And it must return either an open file handle, or a string, or undef.

=item * B<addDefaultEntity>(I<string>)

Modeled after an C<SGML> feature, this entity will be used if an attempt is
made to expand a nonexistent entity.


=item * B<defineEntity>(I<$name,$valueType,$value,$sys,$pub,$notation,$isParam>)

Associate the entity I<name> with the specified data. The argument are
the same as returned by CPAN's C<XML::Parser>'s I<Entity> event, which
reflects any XML ENTITY declaration in a DTD.
I<sysid> can be any of:

=over

=item * a file or http or https URI fetched via C<curl>

=item * a URI starting 'local:',
searched for along the current path (see I<appendPath>)

=item * a local file with no URI-style prefix,
searched for along the current path (see I<appendPath>)

=back


=item * B<openEntity>(I<name>)

This is the internal method called when a start (or empty) tag is parsed.
It stacks the element, xml:lang, and some other information, then issues
the start-element event (and if the I<attrEvents> option is set,
possibly also some number of following attribute events).

=item * B<closeAllEntities>()

Call I<closeEntity> until you can't any more.

=item * B<closeEntity>()


=item * B<getDepth>()

Returns the number of open entities.

=item * B<isOpen>(name)

Returns true iff the (general) entity is open.

=item * B<getCurrentName>()

Returns the name of the currently-open entity.

=item * B<getCurrentEntityDef {

Returns the Entity Definition object for the currently-open entity.

=item * B<getCurrentEntityFrame {

Gets the Frame object representing the currently-open entity.

=item * B<getCurrentEntityLoc>

Returns ($name, $line, $char, $path) for the EntityFrame
of the innermost open Entity.

=item * B<getWholeEntityLoc>

Returns a string describing the location in each open entity,
from the innermost, progressing outward.
Each line is equivalent to a result from I<getCurrentEntityLoc>.

=back



=head1 Known bugs and limitations

There is no way to take the current working directory out of the path
used to resolve local-file entities.



=head1 Related commands

C<xmlOutput.pm> provides an API for managing well-formed output, such
as maintaining the stack, handling escaping for content, attributes, PIs,
and comments, etc. etc.

C<FakeParser.pm> and C<YmlParser> use this package.


=head1 History

# 2011-03-11: Written by Steven J. DeRose, based on my ymlParser.pm (q.v.).
# ...
# 2012-05-18 sjd: Split EntityManager to external package.
#     Split out EntityStack, EntityFrame, and EntityDef packages.
#     Hook up XML::Catalog from CPAN. Add entity callback, path, defaultEntity.
#     Sync i/f with temp version in FakeParser.pm.
# 2013-01-21 sjd: Sync w/ users, merge EntityStack into EntityManager.
#
# To do:
#     Let readLine() handles inner EOFs by itself?
#     Sync/integrate w/ YMLParser.pm, FakeParser.pm, xmlparser, RecordFile.
#     Finish direct reading of Zip files.
#     Param entities can't be referenced outside the DTD.
#     Test entityDepth at end of each entity.
#     Unparsed entities can only be named on ENTITY(IES) attrs, not referenced.


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License, with one additional restriction:

For further information on
the CCLI license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut


###############################################################################
# Manage an entity dictionary, and a stack of open entities.
# This is used for entities
# that map to file or URI objects; entities that are just declared as
# strings, and character references, are handled inline rather than here (?).
#
# (promoted from 'xmlparser' into 'ympParser', then to EntityManager)
#
package EntityManager;

my $xname = "\\w[-.:\\w]*"; # Good enough approximation of XML NAME

sub new {
    my ($class) = @_;

    my $self = {
        options    => {
            verbose          => 0,      # issue various messages to STDERR.
            canRedefine      => 0,      # can we redefine entities?
            Stream_Delimiter => undef,  # see C<XML::Parser>
            useHTMLEntities  => 1,      # the HTML 4 named entities
            useXMLEntities   => 1,      # the XML predefined entities
            useGenrlEntities => 1,      # declared general entities
            useParamEntities => 1,      # declared parameter entities
            useNumericRefs   => 1,      # decimal and hex character references.
            useNDATAEntities => 1,      # entities in various notations.
        },

        # Various DTD construct definitions (by name)
        genrlEnts      => {},           # general entities (EntDef objects)
        paramEnts      => {},           # parameter entities (EntDef objects)
        notations      => {},           # notations (NotationDef objects)

        # Data re. how to resolve PUBLIC and SYSTEM identifiers
        catalogObject => [],
        entPath        => [],           # dirs to look in
        defaultEntity  => undef,        # cf sgml

        # Input stream state, currently-open entities
        entFrames       => [],
        totLine        => 0,            # overall lines processed
        totChar        => 0,            # overall chars processed
    }; # self

    push @{$self->{entPath}}, $ENV{PWD};

    bless $self, $class;
    return $self;
} # new

sub reset {
    my ($self, $defsToo) = @_;
    $self->closeAllEntities();
    $self->{entFrames} = [];
    $self->{totLine} = 0;
    $self->{totChar} = 0;
    if ($defsToo) {
        $self->{genrlEnts}      = {};
        $self->{paramEnts}      = {};
        $self->{notations}      = {};
        $self->{catalogObject} = [];
        $self->{entPath}        = [];
        $self->{defaultEntity}  = undef;
    }
} # reset

sub clearText {
    my ($self, $s) = @_;
    $self->{theText} = "";
    $self->{curCharInLine} = 1;
    $self->{curLine} = 1;
    $self->{curCharInSource} = 0;
}

sub setOption {
    my ($self, $name, $value) = @_;
    (defined $self->{options}->{$name}) || die "Bad option name '$name'\n";
    $self->{options}->{$name} = $value;
}
sub getOption {
    my ($self, $name) = @_;
    return($self->{options}->{$name});
}


###############################################################################
# Catalog and initial data-source (document) support.
#
sub addText {
    my ($self, $s) = @_;
    $self->{entFrames}->[-1]->addText($s);
}

sub addFile {
    my ($self, $path) = @_;
    open(F, "<$path") || return(0);
    while (my $rec = <F>) {
        $self->{entFrames}->[-1]->addText($rec);
    }
    close(F);
    return(1);
}

sub addEntityPath {
    my ($self,$path) = @_;
    if (!-d $path) {
        warn("addPath: '$path' not a directory.\n");
    }
    push @{$self->{entPath}}, $path;
}

sub addCatalog {
    my ($self,$path) = @_;
    die "addCatalog not yet supported.\n";
    $path =~ s@^local://@@;
    if (!-f $path) {
        warn("addCatalog: '$path' not a file; will try anyway.\n");
    }
    if (!$self->{catalogObject}) {
        $self->{catalogObject} = undef; # new XML::Catalog("local://$path");
    }
    else {
        $self->{catalogObject}->add("local://$path");
    }
} # addCatalog

sub addEntityCallback {
    my ($self, $cb) = @_;
    $self->{ecb} = $cb;
}

sub addDefaultEntity {
    my ($self, $s) = @_;
    $self->{defaultEntity} = $s;
}


###############################################################################
# Maintain ENTITY library
#
sub defineEntity {
    my ($self,$ename,$valueType,$value,$sys,$pub,$notation,$isParam) = @_;

    # Complicated parameter list, so do a lot of checking.
    (scalar(@_)) || die
        "defineEntity: Wrong number of params (" . scalar(@_) . ").\n";
    ($self->isXmlName($ename)) || die
        "defineEntity: Bad entity name '$ename'.\n";
    if (!$notation) { $notation = ""; }
    ($isParam==0 || $isParam==1) || die
        "Bad 'isParam' value '$isParam'.\n";

    my $entDef =
        new EntityDef($ename, $value, $sys,$pub, $notation, $isParam);

    # Save the object.
    if ($isParam) {
        $self->{pentDefs}->{$ename} = $entDef;
    }
    else {
        $self->{entDefs}->{$ename} = $entDef;
    }
}

sub isGeneralEntity {
    my ($self, $name) = @_;
    return((defined $self->{genrlEnts}->{$name}) ? 1:0);
}

sub isParameterEntity {
    my ($self, $name) = @_;
    return((defined $self->{paramEnts}->{$name}) ? 1:0);
}


###############################################################################
# Maintain NOTATION library
#
sub defineNotation {
    my ($self, $name, $sys, $pub) = @_;
    $self->{notations}->{$name} = new NotationDef($name, $sys, $pub);
}

sub isNotation {
    my ($self, $name) = @_;
    return((defined $self->{notations}->{$name}) ? 1:0);
}


###############################################################################
# General information
#
sub getDepth {
    my ($self) = @_;
    return(scalar(@{$self->{entFrames}}));
}

sub getCurrentName {
    my ($self) = @_;
    return($self->{entFrames}->[-1]->getName());
}

sub isOpen {
    my ($self, $name) = @_;
    for (my $i=$self->getDepth()-1; $i>=0; $i--) {
        if ($self->{entFrames}->[$i]->getName() eq $name) {
            return(1);
        }
    }
    return(0);
}

sub getCurrentEntityDef {
    my ($self) = @_;
    my $cframe = $self->getCurrentEntityFrame();
    return(($cframe) ? $cframe->{efDef} : undef);
}

sub getCurrentEntityFrame {
    my ($self) = @_;
    if ($self->getDepth() > 0) {
        return($self->{entFrames}->[-1]);
    }
    return(undef);
}

# Returns ($name, $line, $char, $path)
sub getCurrentEntityLoc {
    my ($self) = @_;
    my $ef = $self->getCurrentEntityFrame();
    return($ef ? $ef->{getCurrentLoc()} : "???");
}

sub getWholeEntityLoc {
    my ($self) = @_;
    my $buf = "";
    for (my $i=$self->getDepth()-1; $i>=0; $i--) {
        my $ef = $self->getCurrentEntityFrame();
        my ($name, $line, $char, $path) = $ef->{getCurrentLoc()};
        $buf .= sprintf("%-12s: %6d:%06d %s\n",$name, $line, $char, $path);
    }
    return($buf);
}


###############################################################################
#
sub openParameterEntity {
    my ($self, $ename) = @_;
    my $entDef = undef;
    if (!defined $self->{paramEnts}->{$ename}) {
        warn("Parameter entity '$ename' is not defined.'\n");
    }
    if ($self->isOpen($entDef->{name})) {
        warn("Recursive parameter entity reference: '$entDef->{name}'.\n");
        return(-1);
    }
    warn("Opening entity '$entDef->{name}'.\n");
    push @{$self->{entFrames}}, new EntityFrame($entDef);
    return($self->getDepth());
} # openEntity

sub openEntity {
    my ($self, $ename) = @_;
    my $entDef = undef;
    if (!defined $self->{genrlEnts}->{$ename}) {
        warn("General entity '$ename' is not defined.'\n");
    }
    if ($self->isOpen($entDef->{name})) {
        warn("Recursive entity reference: '$entDef->{name}'.\n");
        return(-1);
    }
    warn("Opening entity '$entDef->{name}'.\n");
    push @{$self->{entFrames}}, new EntityFrame($entDef);
    return($self->getDepth());
} # openEntity

sub closeAllEntities {
    my ($self) = @_;
    while ($self->getDepth()) {
        $self->closeEntity();
    }
    return(0);
}

sub closeEntity {
    my ($self) = @_;
    $self->getCurrentEntityFrame()->closeEntity();
    pop @{$self->{entFrames}};
    return($self->getDepth());
}


###############################################################################
# At this level, get a line from the current entity; once it ends,
# close it and keep reading in any containing entity(ies) until successful.
# If we never get anything, then it's the real EOF.
#
sub readLine {
    my ($self) = @_;
    my $line = undef;
    while ($self->getDepth()>0) {
        my $curFrame = $self->getCurrentEntityFrame();
        $line = $curFrame->readLine();
        if ($line) { last; }
        $self->closeEntity();
    }
    if ($line && $line eq $self->{Stream_Delimiter} . "\n") {
        $self->closeAllEntities();
        return(undef); # Quasi-EOF, see XML::Parser.
    }
    return($line);
}

sub getLinesUpto { # Typically scanning to ">", "?>", etc)
    my ($self, $delim) = @_;
    my $buf = undef;
    while (defined(my $line = $self->getExpandedLine())) {
        $buf .= $line;
        (index($line, $delim) >= 0) && last;
    }
    return($buf);
}

sub getExpandedLine {
    my ($self) = @_;
    return($self->expandGeneralReferences($self->readLine()));
}

# Return the character the cursor is on, AND consume it
sub consumeChar {
    my ($self) = @_;
    my $ef = $self->getCurrentEntityFrame();
    my $c = curChar();
    nextChar();
    return($c);
}

# Move to and return the next character.
sub nextChar {
    my ($self) = @_;
    my $ef = $self->getCurrentEntityFrame();
    $ef->{cursor}++;
    return(curChar());
}

# Return the character the cursor is on without consuming it
sub curChar {
    my ($self) = @_;
    my $ef = $self->getCurrentEntityFrame();
	if ($self->getDepth()<1) {
        # warn "Nothing on open entity stack!\n";
        return(undef);
    }
    if ($ef->{cursor} >= length($ef->{efBuffer})) {
        $ef->{efBuffer} = $ef->readline();
        if (!$ef->{efBuffer}) { return(undef); }
    }
    return(substr($ef->{efBuffer}, $ef->{cursor},1));
}

# Put a character(s) back onto the input, to be read again.
# You can push back at most as far as the start of the current line.
# All pushback is to the current entity.
# ---not presently used---
#
sub pushBack {
    my ($self, $s) = @_;
    my $ef = $self->getCurrentEntityFrame();
    $ef->{efBuffer} = $s . $ef->{efBuffer};
}


###############################################################################
# Expand entity and numeric character references
# ### NOTE: Need to become recursive in case of <!ENTITY...> dcls.
#
sub expandGeneralReferences {
    my ($self, $s) = @_;
    my $buf = "";
    $s =~ s/^&(#\d+|#x[\da-f]+|$xname);/{ $self->expander($1); }/gie;
    return($s);
} # expandGeneralEntities

sub expander {
    my ($self, $s) = @_;
    if (substr($1,0,1) eq "#") {
        return($self->expandNumericCharacterReference($1));
    }
    return($self->expandGeneralEntity($1));
}

sub expandNumericCharacterReference {
    my ($self, $raw) = @_;
    my $buf = "";
    if ($raw =~ s/^&#x([0-9a-f]+);//si) {         # Hexadecimal Char Ref
        my $c = chr(hex($1));
        (!$c || !isXmlChar($c)) && $self->pushEvent(
            "ERROR", "WF: Character reference to non-XML Char 0x$1\n");
        $buf = $c;
    }
    elsif ($raw =~ s/^&#([0-9]+);//s) {           # Decimal Char Ref
        my $c = chr($1);
        (!$c || !isXmlChar($c)) && $self->pushEvent(
            "ERROR", "WF: Character reference to non-XML Char 0d$1\n");
        $buf = $c;
    }
    else {                                        # Fail
        $self->vMsg(0,"WF: Bad reference syntax: '$raw'.\n");
        $buf = $raw; # ???
    }
    return($buf);
} # expandNumericCharacterReference

sub expandGeneralEntity {
    my ($self, $name) = @_;

    if ($self->useXmlEntities) {                  # XML built-in
        if ($name eq "lt")   { return("<"); }
        if ($name eq "gt")   { return(">"); }
        if ($name eq "amp")  { return("&"); }
        if ($name eq "apos") { return("'"); }
        if ($name eq "quot") { return("\""); }
    }
    elsif ($self->{useGenrlEnts}) {               # Declared Entities
        my $entDef = $self->{genrlEnts}->{$name};
        if ($entDef) {
            $self->openEntity($entDef);
            return("");
        }
    }
    elsif ($self->{useHtmlEntities}) {            # HTML entities
        my $eref = "&$name;";
        my $evalue = decode_entities($eref);
        if ($evalue ne $eref) { return($evalue); }
    }
    else {                                        # All options OFF
        return("");
    }

    # If we get here, we can't find it.
    if ($self->{defaultEntity}) {                 # Fall back to default
        return($self->{defaultEntity});
    }
                                                  # FAILED
    $self->vMsg(0,"Unrecognized entity '$name'.\n");
    return("<!-- Unrecognized general entity '$name' -->");
} # expandGeneralEntity

sub expandParameterEntity {
    my ($self, $name) = @_;
    if ($self->{useParamEnts}) {                  # Declared Entities
        my $entDef = $self->{paramEnts}->{$name};
        if ($entDef) {
            $self->openEntity($entDef);
            return("");
        }
    }
    else {                                        # Option OFF
        return("");
    }
                                                  # FAILED
    $self->vMsg(0,"Unrecognized parameter entity '$name'.\n");
    return("<!-- Unrecognized parameter entity '$name' -->");
} # expandParameterEntity


###############################################################################
# General utilities
#
sub isXmlName {
    my ($self, $theName) = @_;
    return(($theName =~ m/^$xname$/) ? 1:0);
}

sub isXmlChar {
    my ($self, $c) = @_;
    my $n = ord($c);
    if ($n == 0x0009 ||
        $n == 0x000A ||
        $n == 0x000D ||
        ($n >= 0x0020 && $n <= 0xD7FF) ||
        ($n >= 0xE000 && $n <= 0xFFFD) ||
        ($n >= 0x10000 && $n <= 0x10FFFF)) {
        return(1);
    }
    return(0);
}

sub vMsg {
    my ($self, $level, $msg) = @_;
    if (!$msg) { $msg = ""; };
    chomp $msg;
    if ($self->{options}->{verbose}) {
        warn "ymlParser: $msg\n";
    }
}

# End of EntityManager package


###############################################################################
# A currently *open* entity. This points to an EntityDef object, which has
# the non-changing information. This also has things like the current file
# handle, cursor position in the entity, etc.
#
# These objects do not exist for XML pre-defined, HTML special-character,
# or numeric-character references, because they cannot contain other refs.
#
package EntityFrame;

sub new {
    my ($class, $entDef) = @_;
    if (ref($entDef) ne "EntityDef") {
        die "Trying to construct an EntityFrame without an EntityDef.\n";
    }
    my $self = {
        efDef      => $entDef,  # EntityDef object

        efPath     => undef,    # Resolved path
        efHandle   => undef,    # File handle (for non-ZIP files)
        efZipObj   => undef,    # Zip implementation (for ZIP files)

        efBuffer   => "",       # Current record of input file
        efTagDepth => -1,       # Initial element nesting level
        efLineNum  => 0,        # Current line-number in the entity
        efCharNum  => 0,        # Current chare-number in the entity
        efOffset   => 0,        # Current byte loc in the input record
    }; # self

    bless $self, $class;
    $self->openEntity($entDef);
    return $self;
} # new

sub openEntity { # INTERNAL, called from constructor.
    my ($self, $entDef) = @_;
    my $name = $entDef->{name};
    my $sysid = $entDef->{system};

    my $gotit = 0;
    if ($entDef->{value}) {                            # Literal sring
        $self->{efBuffer} = $entDef->{value};
        $gotit = 1;
    }
    elsif ($sysid =~ m@^(https?|ftp|file)://@) {       # URI
        die "URIs are not yet supported, except 'local'.\n";
    }
    elsif ($sysid =~ s@^local://@//@) {                # Local path
        for (my $d=0; $d<scalar(@{$self->{entPath}}); $d++) {
            if (-f "$self->{entPath}->[$d]/$sysid") {
                $sysid = "$self->{entPath}->[$d]/$sysid";
                $gotit = 1;
                last;
            }
        }
    }
    elsif ($sysid =~ m/\.zip$/) {                      # Local zip file
        $self->{efZipObj} = Archive::Zip->new($sysid);
        if ($self->{efZipObj}) {
            $gotit = 1;
        }
    }

    return(1) if ($gotit);

    warn "External entity '$name' not found, referenced from:\n" .
        $self->wholeLoc();
    return(undef);
} # openEntity

sub getCurrentLoc {
    my ($self) = @_;
    return($self->{efDef}->{name},
           $self->{efLineNum},
           $self->{efCharNum},
           $self->{efPath});
}

sub getName {
    my ($self) = @_;
    return($self->{efDef}->{name});
}

sub closeEntity {
    my ($self) = @_;
    my $name = $self->{efName};
    warn("Closing entity '$name'.\n");
    if ($self->{theText}) {
        warn "Leftover text lost on closeEntity for '$name':\n" .
            "    '$self->{theText}'\n";
    }
    if ($self->{efHandle}) {
        # (doesn't report failure to reach EOF)
        close $self->{efHandle};
        $self->{efHandle} = undef;
    }
    elsif ($self->{efZipObj}) {
        # (doesn't report failure to reach EOF)
        $self->{efZipObj}->close();
        $self->{efZipObj} = undef;
    }
} # closeEntity

# Hands back one more line from *this* open entity.
# On EOF, caller should close the entity and move up.
# If it's a text entity, destructively parse a line from our *copy*.
# If it's a text or zip file, read a line.
#
sub readLine {
    my ($self, $maxlen) = @_;
    my $line = undef;
    if ($self->{efBuffer}) {
        $self->{efBuffer} =~ s/^([^\n]*\n?)//;
        $line = $1;
    }
    elsif ($self->{efHandle}) {
        $line = readline($self->{efHandle});
    }
    elsif ($self->{efZipObj}) {
        $line = $self->{efZipObj}->getline();
    }
    else {
        warn "Screwed-up frame:\n" . $self->getWholeEntityLoc() . "\n";
    }
    if (defined $line) {
        $self->efLineNum++;
        $self->efCharNum = 0;
        $self->efOffset += length($line);
    }
    return($line);
} # readLine

sub checkPath { # EntityFrame
    my ($self, $sys) = @_;
    for my $dir ($self->{path}) {
        if (-f "$dir/$sys") {
            return("$dir/$sys");
        }
    }
    return(undef);
}

sub checkCatalog { # EntityFrame
    my ($self, $sys) = @_;
    for my $dir ($self->{catalog}) {
        if (-f "$dir/$sys") {
            return("$dir/$sys");
        }
    }
    return(undef);
}

# End of EntityFrame package


###############################################################################
# The definition of one entity (of whatever type).
# This tightly corresponds to the information available from the DTD (if any).
# These objects do not exist for XML pre-defined, HTML special-character,
# or numeric-character references.
#
package EntityDef;

sub new {
    my ($class, $ename, $value, $system ,$public, $notation, $isParam) = @_;

    my $self = {
        name     => $ename,
        value    => $value,
        system   => $system,
        public   => $public,
        notation => $notation,
        isParam  => $isParam,

        # unused for now (cf SGML)
        isCDATA  => 0,
        isRCDATA => 0,
    }; # self

    bless $self, $class;
    return $self;
} # new

sub isLiteral {
    my ($self) = @_;
    if (!$self->{system} && !$self->{public}) { return(1); }
    return(0);
}

# End of EntityDef package


###############################################################################
# One notation definition.
#
package NotationDef;

sub new {
    my ($class, $name, $sys, $pub) = @_;

    my $self = {
        name     => "",
        system   => "",
        public   => "",
    };

    bless $self, $class;
    return $self;
} # new

# End of NotationDef package

1;
