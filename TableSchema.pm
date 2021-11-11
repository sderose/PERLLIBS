#!/usr/bin/perl -w
#
# TableSchema.pm (split from older TabularFormats.pm).
#    (also includes package FieldDef)
# Written 2010-03-23 by Steven J. DeRose, as csvFormat.pm
#
use strict;
use feature 'unicode_strings';

use sjdUtils;

#use TFormatSupport; # Actual implementations of specific formats.

sjdUtils::try_module("Datatypes") || warn
    "Can't access sjd Datatypes module.\n";

our %metadata = (
    'title'        => "TableSchema",
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

    use TableSchema;

Provide information about record structures for TabularFormats.pm, etc.

The functionality and expressiveness are
essentially that of CSV and its kin.

Fields always have names and an ordering (regardless of the file format
we're dealing with, which this package should not care about).
Most methods can specify a field by either name or number
(numeric names are not recommended).

=head3 Package: package FieldDef

Used by TableSchema to represent each field of the records being read/written.
It knows the name, datatype, preferred width and justification, and other
information about a given field, but not about it's place in the record
(re. which see I<TableSchema>, previous).


=head1 Package: TableSchema

Get a reference to the active instance of this package, from the
I<TabularFormats> instance, using I<getTableSchema>().

Many of these methods allow you to identify a specific field
by either name or number. Fields always have both.

=over

=item * B<getNSchemaFields>()

Return the number of fields known to the B<schema> (that is, the
number of existing field definitions).
=item * B<addFieldIfNeeded>(name)

If the field does not exist, use I<addField> to create it.
Otherwise do nothing.

=item * B<appendField>(name)

Add a field of the given name, to the list of fields, assigning it the next available
position. If I<name> is nil, make up a name for it.

=item * B<addField>(name, num) (OBSOLETE?)

Append a field definition to the list of known fields.
Returns the number of fields defined so far (including the new one).
See also I<parseHeader>() and I<addFieldIfNeeded>().

=item * B<setNFields(n)>

Ensure that there are at least I<n> fields defined.

=item * B<setFieldName>(n, name)

Change the name of field I<n> (name or number).

=item * B<getFieldName(n)>

Return the name of field I<n> (name or number).

=item * B<setFieldNamesFromArray>(arrayRef)

Rename fields en masse. The names in the array referenced by I<arrayRef>
will be assigned to the fields in the known field order (if there are more
names than defined fields, new fields will be quietly defined and added as needed).
I<arrayRef>->[0] should be undefined or empty. Undefined or empty
elements will not cause renaming of the corresponding fields.
B<Note>: Changing field names while in the middle of reading a file is
unwise, at least for formats that have explicit field names in the data (as in
many or most formats other than CSV and ARFF).

=item * B<getFieldNamesArray>()

Return an array of the names of the fields, in field-number order.
As always, [0] will be present but empty.

=item * B<setFieldDatatype>(n, dtName)

Change the datatype of field I<n> (name or number).
The names are as supported by C<Datatypes.pm>, which include the
built-in XML Schema Datatypes plus some extensions.

=item * B<getFieldDatatype>(n)

Get the datatype of field I<n> (name or number).

=item * B<setFieldDefault>(n, defaultValue)

Set the default value for field I<n> (name or number).
This will be filled in when the field is missing in the input (in most
formats, whitespace counts as empty). For formats that have their own
defaulting mechanism, this operates I<after> that mechanism.

If the <omitDefaults> option is set, fields that match their default will
not have their values written to the output (this is only supported
for XSV so far).

Exactly what "missing" means depends on the specific format in use.
For example, XSV fields are identified by name so can be entirely omitted,
while CSV and COLUMNS necessitate a placeholder.

=item * B<getFieldDefault>(n)

Returns the present default value for field I<n> (name or number).

=item * B<setFieldSplitter>(n, regex, joinerString)

Enable support for "sub-fields" (experimental).
No splitting is done by default.
On input, any field for which I<regex> has been set will be split()
to make an array.

On output, any field whose value is an array reference
will combine the array elements into a single field.
Most of the supported formats do not define such a notion, so the output
field will simply be created by doing a Perl join() using the specifying
I<joinerString>, and putting quotes around the outside. For example,
if the second field is a reference to an array of the first five integers
and the I<joinerString)> is a space, for CSV the second field ends up
as shown here:

    field1, "1 2 3 4 5", field3

For output to formats that have a notion of hierarchy, their syntax is used:

=over

=item * For XML, sub-elements are created using the I<name> specified
as I<joinerString>. A typical example might be dividing table cells into
"<p>" or "<span>" elements. If I<joinerString> contains a space, anything
after the space will be deleted when writing the I<end-tag>; this allows
specifying attributes if desired (like 'p class="foo"').

=item * For JSON and Perl, the array elements will be separated by ", ",
and the whole list parenthesized (I<joinerString> is ignored).

= item * For SEXP, a parenthesized quoted list is created, with individual
items quoted if needed (I<joinerString> is ignored).

=back


=item * B<setFieldNumber>(n, newNumber)

Move field I<n> (name or number) to field ordering place I<newNumber>.
In effect, the field is deleted from the ordering (with all later
fields therefore moving down by 1 position), and then inserted before
field I<newNumber> (with all later fields moving up by 1 position).
See also I<getFieldNamesArray>().

B<Note>: The field ordering is used when parsing formats that are defined by order
(mainly ARFF, COLUMNS, CSV, and some variants of SEXP not yet supported). So if
you use I<setFieldNumber>, any records you later parse will assume the new
ordering.

To modify the order of fields in such formats,
create two instances of this package,
one for input (where you never call I<setFieldNumber>()),
and one for output (where you do).
Define the desired fields for the output with I<addField>(), perhaps
copying them from the input instance, perhaps renaming or reordering.
Then call I<parseRecordToHash>() in the first instance, and pass the returned
hashes to I<assembleRecordFromHash>() in the second instance.

=item * B<getFieldNumber(n)>

Return the field number corresponding to field I<n> (name or number),
or 0 if there is no such field.

=item * B<setFieldPositions>(startArrayRef)

Call I<setFieldPosition>() for each element in the array referenced by
I<startArrayRef> (as always, [0] should be present but empty). These entries
should be the start columns for the respective fields.
The widths will be set to be everything up to the next start column
(except for the last one, whose width is presently undefined).
Field alignments will not be set.

=item * B<setFieldPosition>(n,startCol,width?,align?)

Sets the column range (counting from 1) that field I<n> (name or number)
occupies. This only applies when dealing with COLUMNS format.
This is the only way to tell COLUMNS where the fields are.

Note that it uses I<width>, not I<endCol>. If I<width> is omitted, it will
be set to occupy everything up to just before the nearest following
I<startCol> (or undef is there is no following field has been defined yet).

The optional I<align> argument may be L (left), R (right), C (center),
D (decimal), or A (automatic), to specify how the data will be padded
if needed. "D" is limited to using "." to align on, and aligning that
character to the center of the permitted width.

This method checks for position conflicts (overlap).
If there is a conflict with an already-defined column range for
another field, it returns 0 (otherwise 1).

B<Note>: This method does I<not> change any fields' sequence number;
you may want to call I<setFieldNumbersByPosition>() afterward for that.

=item * B<getFieldPosition>(n)

Return the starting column, width, and alignment
for field I<b> (name or number).

=item * B<setFieldNumbersByPosition>()

If you moved fields around with I<setFieldPosition>(), this will
re-number them (like I<setFieldNumber>()) to be in ascending order by position.

=item * B<getAvailableWidth>(n)

Return the number of columns available, by searching for the nearest
following field by start position, and subtracting start positions.

=item * B<getNearestFollowingFieldDef>(n)

Return the field definition of the next field, in order of start position,
after field I<n> (name or number).

=item * B<setFieldCallback(n,cb)> (experimental)

Attach a callback function I<cb> to field I<n> (name or number).
Whenever that field is parsed out of input data, the callback will be called,
being passed a reference to the TabularFormats instance calling it,
and the string form of the field value,
and the returned value will be used in place of the value passed:

    theCallback($tf, $s)

B<Note>: There should be a way for the callback to do internal parsing and
return more than one field; but there isn't. However, the callback can
do explicit calls to I<< $tf->setFieldValue($n, $x) >>.
This feature is not yet integrated with sub-fields/splitters (cf), and
the result if you use both is undefined.

=back


=head1 Internal package: FieldDef



=head1 Related commands

TabularFormats.pm.


=head1 Known bugs and limitations

=over

=item * Datatype checking is experimental.

=back


=head1 History

# Written 2010-03-23 by Steven J. DeRose, as csvFormat.pm
#     (many changes/improvements).
# 2012-03-30 sjd: Rename to TabularFormats.pm, major reorg.
# ...
# 2013-02-06ff sjd: Don't call sjdUtils::setOptions("verbose").
#     Work on -stripRecord.
#     Break out DataSchema package, and tell it and DataSource what they need,
#     so they don't have to know 'owner' any more. Clean up virtuals a bit.
#     Also break out DataOptions and DataCurrent packages. Fix order of events
#     in pull-parser interface. Format-support packages to separate file.
#     Support repetition indicators on datatypes.
# ...
# 2017-04-19: Move DataSchema package to this separate file as TableSchema.


=head1 To do

#     Why continuous (-v) warnings about re-adding same fields?
#     Do something with date/time formats.
#     Option to default specific fields.
#
# Low priority:
#     Add compound-key-reifier to deriveField.
#     Rotate embedded layer (esp. for SEXP, XML, JSON, etc.)
#     Switch messaging to use sjdUtils?


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut


###############################################################################
# Package FieldDef
#
# Manage per-field-type information for one field. Aggregated by TableSchema.
# TabularFormats gets these from TableSchema, then modifies fields directly.
#
# Note: This does *not* include the field's number (order).
#
package FieldDef;

sub FieldDef::new {
    my ($class, $name, $ersatz) = @_;

    my $self = {
        # Where to find the field (not all always used)
        fName        => $name || undef,      # Field name
        fErsatz      => ($ersatz) ? 1:0,     # Was it created as error recovery?
        fStart       => 0,                   # Starting column (optional)
        fWidth       => 0,                   # Column width
        fTruncate    => 0,                   # If over fWidth, truncate?

        # Input processing and cleanup
        fDefault     => undef,               # Value to load if missing (?)
        fCharset     => "utf-8",             # Character encoding
        fNilValueIn  => "",                  # Reserved "nil" value
        fCallback    => undef,               # Last-minute callback

        fSplitter    => undef,               # Regex to split() sub-fields
        fSplitterC    => undef,              #     same, compiled
        fJoiner      => undef,               # String to join() sub-fields

        fDatatype    => "",                  # Datatypes.pm name for checking

        # Output possibilities (see align(), below)
        fAlign       => "",                  # l/c/r/d/a
        fNilValueOut => "",                  # Write this for undef
    };

    bless $self, $class;
    return $self;
}

# Mainly for COLUMNS, but anybody can use it.
# Left, Center, Right, Dot, Auto, or "".
#
sub FieldDef::align {
    my ($self, $value) = @_;
    if (!defined $value) {                        # Undefined / nil
        $value = $self->{fNilValueOut};
    }

    my $svalue = $value . "";
    if ($self->{fWidth} <= 0) {                   # No width known
        return($value);
    }

    my $needed = $self->{fWidth}-length($svalue); # How wide?
    if ($needed == 0) {
        return($svalue);
    }
    if ($needed < 0) {                            # Too wide
        if ($self->{fTruncate}) {
            $svalue = substr($svalue,0,$self->{fWidth});
        }
        return($svalue);
    }
                                                  # Room to pad it
    if ($self->{fAlign} eq "L") {                   # Left-align
        $svalue = $svalue . (" " x $needed);
    }
    elsif ($self->{fAlign} eq "C") {                # Center-align
        my $still = $needed - ($needed/2);
        $svalue = (" " x ($needed/2)) . $svalue . $still
    }
    elsif ($self->{fAlign} eq "R") {                # Right-align
        $svalue = (" " x $needed) . $svalue;
    }
    elsif ($self->{fAlign} eq "D") {                # lame Decimal-align
        my $ind = index($svalue, ".");
        if ($ind>=0 && $ind<$self->{fWdith}/2) {
            $needed = $self->{fWdith}/2 - $ind;
            $svalue = (" " x $needed) . $svalue;
        }
    }
    elsif ($self->{fAlign} eq "A") {                # Auto-align
        if ($svalue =~ m/^\s*\d+(\.\d+)?/) {
            $svalue = (" " x $needed) . $svalue;
        }
        else {
            $svalue = $svalue . (" " x $needed);
        }
    }

    return($svalue);
} # align

# End of FieldDef package.


###############################################################################
# Package TableSchema
#
# Manage fields: names, numbers, positions (stored in FieldDef objects)
# Mostly, these methods just find the right FieldDef object by name or number,
# then access its fields directly. FieldDef has few methods of its own.
#
package TableSchema;
my $sch = "TableSchema";

sub TableSchema::new {
    my ($class, $logger) = @_;
    my $self = {
        # Refs to FieldDef objects define what a record can contain
        #lg            => $logger ? $logger : new ,
        fDefsByName   => {},
        fDefsByNumber => [ "" ],        # [0] always unused. -> fDefs
        nominalNumberOfFields => 0,     # Only used if setNFields
    };

    bless $self, $class;
    return $self;
}

sub TableSchema::reset {
    my ($self) = @_;
    $self->fDefsByName   => {},
    $self->fDefsByNumber => [ "" ],
}

sub TableSchema::addFieldIfNeeded {
    my ($self, $name) = @_;
    if ($self->{fDefsByName}->{$name}) { return; }
    $self->appendField($name);
}
sub TableSchema::appendField {
    my ($self, $name) = @_;
    alogging::vMsg(1, "$sch:appendField called for '$name'.");
    if (scalar(@{$self->{fDefsByNumber}} == "")) {  # [0] stays empty!
        $self->{fDefsByNumber} = "";
    }
    my $fNum = $self->getNSchemaFields() + 1;
    if (!$name) {
        $name = "F_" . $fNum;
    }
    if (defined($self->{fDefsByName}->{$name})) {
        alogging::eMsg(1,"$sch:appendField: '$name' already defined.\n");
        return(0);
    }
    my $fDef = new FieldDef($name, 0);
    $self->{fDefsByName}->{$name} = $fDef;
    $self->{fDefsByNumber}->[$fNum] = $fDef;
    return($fDef);
}
sub TableSchema::addField { # ???
    my ($self, $name, $number) = @_;
    if (!defined $name)   { $name = ''; }
    if (!defined $number) { $number = $self->getNSchemaFields() + 1; }
    alogging::vMsg(2, "addField: number $number, name '$name'");

    if ($name && defined($self->{fDefsByName}->{$name})) {
        alogging::eMsg(1,"$sch:addField: '$name' already defined.\n");
        return(0);
    }

    my $fDef = new FieldDef($name);
    $self->{fDefsByName}->{$name} = $fDef;
    $self->{fDefsByNumber}->[$number] = $fDef;
    return($self->getNSchemaFields());
}

# Find field object, given name or number.
# For not-found errors, return undef and caller must fix.
#
sub TableSchema::getFieldDef {
    my ($self, $fieldNN) = @_;
    my $fDef = undef;
    if ($fieldNN =~ m/^\s*\d+\s*$/) {             # By number
        return($self->{fDefsByNumber}->[$fieldNN]);
    }
    else {                                        # By name
        return($fDef = $self->{fDefsByName}->{$fieldNN});
    }
}
sub TableSchema::schemaToString {
    my ($self, $compact) = @_;
    my @names = @{$self->getFieldNamesArray()};
    my $format = ($compact) ? "%d:%s, " : "    %3d: '%s'\n";
    my $buf = "";
    for (my $i=1; $i<scalar @names; $i++) {
        $buf .= sprintf($format, $i, $names[$i]);
    }
    return($buf);
}
sub TableSchema::getFieldDefByName {
    my ($self, $fieldNN) = @_;
    my $fDef = $self->{fDefsByName}->{$fieldNN};
    return($fDef);
}
sub TableSchema::getFieldDefByNumber {
    my ($self, $fieldNN) = @_;
    if ($fieldNN !~ m/^\s*\d+\s*$/) { # Disable for speed
        alogging::eMsg(0,"'$fieldNN' not numeric.");
        return(undef);
    }
    my $ndefs = $self->getNSchemaFields();
    while ($ndefs < $fieldNN) {
        alogging::eMsg(0,"Field #'$fieldNN' not in schema (only $ndefs).");
        $self->addField('f' . ($ndefs+1));
        $ndefs = $self->getNSchemaFields();
    }
    my $fDef = $self->{fDefsByNumber}->[$fieldNN];
    return($fDef);
}

# Set/get properties of a single FieldDef
#
sub TableSchema::setFieldName {
    my ($self, $fieldNN, $newName) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    if (!$fDef) {
        alogging::eMsg(-1,"Can't find field $fieldNN.");
    }
    if (!$self->isOkFieldName($newName)) {
        alogging::eMsg(0,"Bad name '$newName' -- defaulted.");
        $newName = "F_" . $fDef->getFieldNumber();
    }
    $fDef->{fName} = $newName;
    return(1);
}
sub TableSchema::getFieldName {
    my ($self, $fieldNN) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    return($fDef->{fName});
}

sub TableSchema::setFieldDatatype {
    my ($self, $fieldNN, $newDtName) = @_;
    if ($newDtName && !$self->{theDatatypes}->isKnownDatatype($newDtName)) {
        alogging::eMsg(
            0,"Unknown datatype for field '$fieldNN': '$newDtName'");
        return(0);
    }
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(0);
    $fDef->{fDatatype} = $newDtName;
    return(1);
}
sub TableSchema::getFieldDatatype {
    my ($self, $fieldNN) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    return($fDef->{fDatatype});
}

sub TableSchema::setFieldDefault {
    my ($self, $fieldNN, $newDefault) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    $fDef->{fDefault} = $newDefault;
    return(1);
}
sub TableSchema::getFieldDefault {
    my ($self, $fieldNN) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    return($fDef->{fDefault});
}

# Rudimentary support for one level of sub-fields (e.g., paragraphs inside
# table cells, tokens inside a field, etc.
#
sub TableSchema::setFieldSplitter {
    my ($self, $fieldNN, $splitterRegex, $joinerString) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(0);
    $fDef->{fSplitter} = $splitterRegex;
    $fDef->{fSplitterC} = qr/$splitterRegex/;
    $fDef->{fJoiner} = $joinerString;
    return(1);
}

# A field callback should always return an array of fields.
# For example the 'Encoding:' MIME header often has a 'Charset' field within.
# Or, the callback can be used to do normalization such as case-folding, etc.
# Called from postProcessFields() in each implementation.
#
sub TableSchema::setFieldCallback {
    my ($self, $fieldNN, $cb) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(0);
    $fDef->{fCallback} = $cb;
    return(1);
}


###############################################################################
# Manage properties and order of the whole set of fields.
#
sub TableSchema::setNFields {
    my ($self, $n) = @_;
    my $nf = $self->getNSchemaFields();
    while ($nf < $n) {
        $nf++;
        $self->appendField("");
    }
    $self->nominalNumberOfFields = $n;
}
sub TableSchema::getNSchemaFields {
    my ($self) = @_;
    my $nfNumbers = scalar(@{$self->{fDefsByNumber}}) - 1; # [0] unused!
    my $nfNames = scalar(keys(%{$self->{fDefsByName}}));
    ($nfNumbers == $nfNames) ||
        alogging::eMsg(1, "field-count: byNumber $nfNumbers, " .
            "byName $nfNames");
    return($nfNumbers);
}

sub TableSchema::setFieldNumber {
    my ($self, $fieldNN, $newNumber) = @_;
    if ($newNumber<1) {
        alogging::eMsg(0,"Bad field number '$newNumber'");
        return(undef);
    }
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    my $oldNumber = $self->getFieldNumber($fieldNN);
    splice(@{$self->{fDefsByNumber}},$oldNumber,1);
    splice(@{$self->{fDefsByNumber}},$newNumber,0,$fDef);
    return($newNumber);
}
sub TableSchema::getFieldNumber {
    my ($self, $fieldNN) = @_;
    if ($fieldNN =~ m/^\s*\d+\s*$/) { return($fieldNN); }
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    my $nf = $self->getNSchemaFields();
    for my $i (1..$nf) {
        my $iDef = $self->{fDefsByNumber}->[$i];
        if ($iDef->{fName} eq $fDef->{fName}) {
            return($i);
        }
    }
    return(undef);
}

sub TableSchema::setFieldNamesFromArray {
    my ($self, $aRef) = @_;
    for (my $i=1; $i<scalar(@{$aRef}); $i++) {
        my $name = $aRef->[$i];
        if ($name) {
            my $fDef = $self->{fDefsByNumber}->[$i];
            if (!$fDef) {
                $fDef = new FieldDef($name);
                $self->{fDefsByNumber}->[$i] = $fDef;
                $self->{fDefsByName}->{$name} = $fDef;
            }
            else {
                $fDef->{fName} = $name;
            }
        }
        else {
            alogging::vMsg(0, "$sch:setFieldNamesFromArray: [$i] is nil.");
        }
    }
    return(scalar(@{$aRef}));
}
sub TableSchema::getFieldNamesArray {
    my ($self) = @_;
    if (!$self->{fDefsByNumber}) {
        alogging::eMsg(0,"Nobody there.");
        return("");
    }
    my @names = ("");
    my $nf = $self->getNSchemaFields();
    for my $i (1..$nf) {
        my $fDef = $self->{fDefsByNumber}->[$i];
        if (!$fDef) {
            alogging::eMsg(0,"Missing fDef #$i.");
            my $name = "F_$i";
            my $fDef = new FieldDef($name);
            $self->{fDefsByName}->{$name} = $fDef;
            $self->{fDefsByNumber}->[$i] = $fDef;
        }
        push @names, $fDef->{fName}; # Includes empty [0]
    }
    return(\@names);
}

# Re. field positions: Do they need to be in order? Doesn't seem like it;
# only meaningful in COLUMNS, and you might want order for something else.
# Just have to be careful to get COLUMNS output right.
#
sub TableSchema::setFieldPositions {
    my ($self, $starts) = @_;
    my $laterStart = $starts->[-1] + 8; # Meh
    for (my $i=scalar(@{$starts})-1; $i>0; $i--) {
        my $width = $laterStart - $starts->[$i];
        if ($width <= 0) {
            alogging::eMsg(0,"$sch:Out of order.");
            $width = 1;
        }
        $self->setFieldPosition($i, $starts->[$i], $width);
        $laterStart = $starts->[$i];
    }
}

sub TableSchema::setFieldPosition {
    my ($self, $fieldNN, $start, $width, $align) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    my $nf = $self->getNSchemaFields();

    if (!$width) {                      # Pick a default width
        my $nearestFollowingStart = 99999999;
        for (my $i=1; $i<=$nf; $i++) {
            my $iDef = $self->{fDefsByNumber}->[$i];
            if ($iDef->{fStart} > $start &&
                $iDef->{fStart} < $nearestFollowingStart) {
                $nearestFollowingStart = $iDef->{fStart};
            }
        }
        if ($nearestFollowingStart> -1) {
            $width = $nearestFollowingStart - $start;
        }
    }
    else {                              # Check for column conflict
        for (my $i=1; $i<=$nf; $i++) {
            my $iDef = $self->{fDefsByNumber}->[$i];
            next if ($iDef == $fDef);
            my $istart = $iDef->{fStart};
            my $iwidth = $iDef->{fWidth};
            if ($istart < $start+$width &&
                $istart+$iwidth > $start) { # overlap
                return(0);
            }
        }
    }
    $fDef->{fStart} = $start;
    $fDef->{fWidth} = $width;
    if (!$align || $align =~ m/^[LRCDA]/i) {
        $fDef->{fAlign} = $align;
    }
    else {
        alogging::eMsg(
            0, "Bad 'align' argument '$align' for field '$fieldNN'");
    }
    return(1);
}

sub TableSchema::getFieldPosition {
    my ($self, $fieldNN) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    return($fDef->{fStart}, $fDef->{fWidth}, $fDef->{fAlign});
}

sub TableSchema::setFieldNumbersByPosition {
    my ($self) = @_;
    my @fDefArray = @{$self->{fDefsByNumber}};
    shift @fDefArray;
    @fDefArray = sort { return($a->{fStart} <=> $b->{fStart}); } @fDefArray;
    unshift @fDefArray, undef;
    $self->{fDefsByNumber} = \@fDefArray;
}

sub TableSchema::getAvailableWidth {
    my ($self, $fieldNN) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(0);
    my $near = $self->getNearestFollowingFieldDef($fieldNN);
    ($near) || return(0);
    return($near->{fStart} - $fDef->{fStart});
}

sub TableSchema::getNearestFollowingFieldDef {
    my ($self, $fieldNN) = @_;
    my $fDef = $self->getFieldDef($fieldNN);
    ($fDef) || return(undef);
    my $nf = $self->getNSchemaFields();
    my $near = undef;
    for (my $i=1; $i<=$nf; $i++) {
        my $iDef = $self->{fDefsByNumber}->[$i];
        if ($iDef->{fStart} &&
            (!$near || ($iDef->{fStart} < $near->{fStart})) &&
            $iDef->{fStart} > $fDef->{fStart}) {
            $near = $iDef;
        }
    }
    return($near);
}

# End package TableSchema


###############################################################################
#
if (!caller) {
    system "perldoc $0";
}

1;
