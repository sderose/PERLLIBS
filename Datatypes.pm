#!/usr/bin/env perl -w
#
# Datatypes.pm: Package to help with XSD datatype checking.
# 2012-04-24: Written by Steven J. DeRose.
#
use strict;

our %metadata = (
    'title'        => "Datatypes.pm",
    'description'  => "Package to help with XSD datatype checking.",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2012-04-24",
    'modified'     => "2020-11-22",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};

package Datatypes;

=pod

=head1 Usage

Type-checking for the XSD built-in datatypes, plus a few others.

  use Datatypes;
  my $dt = new Datatypes();
  ...
  if ($dt->checkValueForType("typename", "!", $value)) { ... }

Values are checked for lexical form, and numeric types are also
checked for min and max values. The second argument should be "?" if a nil
value is acceptable, otherwise "!" ("*" and "+" will likely be added).


=head1 Supported XSD built-in types

=over

=item * B<Truth values>:
I<boolean>.

=item * B<Real numbers>:
I<decimal>, I<double>, I<float>.

=item * B<Integers>:
I<byte>, I<int>, I<short>, I<integer>, I<long>,
I<nonPositiveInteger>, I<negativeInteger>,
I<nonNegativeInteger>, I<positiveInteger>,
I<unsignedByte>, I<unsignedShort>, I<unsignedInt>, I<unsignedLong>.

=item * B<Dates and times>:
I<date>, I<dateTime>, I<time>, I<duration>,
I<gDay>, I<gMonth>, I<gMonthDay>, I<gYear>, I<gYearMonth>.

=item * B<Strings>:
I<language>, I<normalizedString>, I<string>, I<token> .

=item * B<XML constructs>:
I<NMTOKEN>, I<NMTOKENS>, I<Name>, I<NCName>,
I<ID>, I<IDREF>, I<IDREFS>, I<ENTITY>, I<ENTITIES>, I<QName>.

=item * B<Net constructs>:
I<anyURI>, I<base64Binary>, I<hexBinary>.

=back


=head1 The extended types

Besides the XSD built-in types, this script supports several
other types, all of which begin with "". The first two require
a parenthesized argument following the basic type name (the parentheses
are I<permitted> after all typenames for consistency of syntax).

=over

=item * I<ENUM(X Y...)>

The value must be one of the (case-sensitive) space-separated XML NAME values
listed in the argument.

=item * B<STRING(regex)>

Acceptable values are any strings that match the regular expression argument.
Not to be confused with I<REGEX>.

=back

The remaining I<> types are described below.

=over

=item * I<REGEX>

Acceptable values must I<be> regular expressions (tested by C<eval()>)
Not to be confused with I<STRING>.

=item * I<ASCII>

An ASCII string.

=item * I<BASEINT>

An integer in hexadecimal (0xFFFF), octal (0777), or decimal (999).

=item * I<UChar> a single Unicode character.

=item * I<XmlNameChar> a single Unicode XML name character
(this is slightly too loose at present, allows all \w chars).

=item * I<XmlNameStart> a single Unicode XML name start character
(this is slightly too loose at present, allows all \w chars).

=item * I<LatinLetter> a single Latin letter: [a-zA-Z].

=item * I<LatinLower> a single lower-case Latin letter: [a-z].

=item * I<LatinUpper> a single upper-case Latin letter: [A-Z].

=item * I<Digit> a single Arabic digit: [0-9].

=back


=head1 Methods

=over

=item * B<new>()

Create a new instance.

=item * B<checkValueForType>(typeName, rep, value, report)

Returns whether the I<value> is ok for the I<typeName>.
If I<rep> is "?" or "*", an empty I<value> is also acceptable.
If I<report> is present, it determines whether datatype violations will be
reported via I<warn> (otherwise, reporting is controlled by the I<scream>
option).

=item * B<isXSD>(name)

Return whether the datatype I<name> is a built-in XSD one, or not.

=item * B<isNumericDatatype>(name)

Return whether the named datatype is a numeric datatype.
An ENUM or STRING does not count as numeric even if it can only
match data that could reasonably be interpreted as numeric.

=item * B<isWSNormalizable>

Return whether the type can safely have white-space normalized a la XML.

=item * B<isKnownDatatype>(name)

Return whether the type is actually known.

=item * B<getKnownDatatypes>()

Return a reference to an array of all the known datatype names.

=item * B<normalize>(name, value)

Normalizes the form of the given I<value>, according to the normalization
rules for the type I<name>. For example, booleans always return 0 or 1;
BASEINTs are converted to decimal; most string types have whitespace
normalized, etc.

=back


=head1 Known Bugs and Limitations

Doesn't check all types completely thoroughly.

Doesn't know exactly the right set of characters for XML Names (uses \w).

This isn't really maintained. See C<Datatypes.py>.


=head1 Related commands

My C<TabularFormats.pm> and I<XmlTuples.pm> use this.
But all those are obsolescent.

CPAN C<SOAP::WSDL::XSDLLTypelib::Builtin> (not used here),
provides classes corresponding to each XSD built-in type.


=head1 History

  2012-04-24: Written by Steven J. DeRose.
  2012-04-30 sjd: Handle 0x in datatype specs. Actually check ENUM and
new STRING. Check REGEX. Add 'scream' parameter to check,
and issue specific error messages. Add types for some sets of chars.
  2012-05-23 sjd: Drop XmlTuples to avoid circular dependency.
  2012-05-31 sjd: Fix REGEX.
  2012-06-08ff sjd: Change [arg] or \targ to (arg). Improve parsing of it.
Allow /[\s\|]+/ between ENUM tokens.
normalizeData(type, raw)? At least string, bool, baseint.
  2012-06-14 sjd: Add 'rep arg to checkValueForType().
  2012-11-26 sjd: Clean up.
  2020-11-22: New Layout.


=head1 To do

  Perhaps add File, Directory, WFile, Rfile
  addType()?
  conversions to/from ctime?
  methods to define/delete types?
  Make nonPositiveInteger and nonNegativeInteger deal with -0.


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut


###############################################################################
# Define the datatypes known (from XML Schema, mostly).
#
# Each gets a regex used to check it ('^' and '$' will be added by checker).
# For integers, bounds are added after the regex: \s*### min ### max)
# A few local (non-XML-Schema) types are defined, all starting with "".
# Of those, ENUM, STRING, and REGEX are validated specially.
#     ENUM and STRING take an (argument) after the type-name.
#
# ==> This could use XSV except for circular package dependency <==
#
my $NAME     = "[_.\\w][-_.:\\w\\d]*";   # XML Identifiers
my $NCNAME   = "[_.\\w][-_.\\w\\d]*";    # No namespace colon
my $NMTOKEN  = "[-_.:\\w\\d]+";          # No special first char

my %dtInfoSource = (
    # SPECIALS (ENUM and STRING are parameterized)
    'ENUM'         => { NormWS=>"1", Expr=>'.*' },
    'STRING'   => { NormWS=>"1", Expr=>'.*' },

    'REGEX'        => { Expr=>'.*' },
    'ASCII'        => { Expr=>'\\p{isASCII}*' },
    'BASEINT'      => { Num=>1, Expr=>'([1-9]\\d*|0[0-7]+|0x\\s+)$' },

#    'UChar'        => { Expr=>'.' },
#    'XmlNameChar'  => { Expr=>'[-_.:\\w]' },
#    'XmlNameChar'  => { Expr=>'[-_.:\\w]' },
#    'XmlNameStart' => { Expr=>'\\w' },
#    'LatinLetter'  => { Expr=>'[A-Za-z]' },
#    'LatinLower'   => { Expr=>'[a-z]' },
#    'LatinUpper'   => { Expr=>'[A-Z]' },
#    'Digit'        => { Num=>1, Expr=>'\\d' },

    # Truth values
    'boolean'  => { Expr=>'(true|1|false|0)' },

    # Real numbers
    'decimal' => { Num=>1, Expr=>'[-+]?\\d+(\\.\\d+)' },
    'double'  => { Num=>1,
                   Expr=>'([-+]?\\d+(\\.\\d+)([eE][-+]?\\d+)?)|INF|-INF|NaN' },
    'float'   => { Num=>1,
                   Expr=>'([-+]?\\d+(\\.\\d+)([eE][-+]?\\d+)?)|INF|-INF|NaN' },

    # Various integers
    'byte'    => { Num=>1, Expr=>'[-+]?\\d+', Min=>'-0x80',   Max=>'0x7F' },
    'int'     => { Num=>1, Expr=>'[-+]?\\d+', Min=>'-0x8000', Max=>'0x7FFF' },
    'short'   => { Num=>1, Expr=>'[-+]?\\d+', Min=>'-0x8000', Max=>'0x7FFF' },
    'integer' => { Num=>1, Expr=>'[-+]?\\d+', Min=>'-0x80000000',
                   Max=>'0x7FFFFFFF' },
    'long'    => { Num=>1, Expr=>'[-+]?\\d+' },#Min=>$min64, Max=>$max64 },

    'nonPositiveInteger' =>
    { Num=>1, Expr=>'(-\\d+)|0+', Max=>'0' },#Min=>$min64 },
    'negativeInteger'    =>
    { Num=>1, Expr=>'-\\d+',      Max=>'-1'},#Min=>'$min64' },
    'nonNegativeInteger' =>
    { Num=>1, Expr=>'\\+?\\d+',   Min=>'0' },#Max=>$max64 },
    'positiveInteger'    =>
    { Num=>1, Expr=>'\\+?\\d+',   Min=>'1' },#Max=>$max64 },

    'unsignedByte'       =>
    { Num=>1, Expr=>'\\+?\\d+',   Min=>'0', Max=>'0x7F' },
    'unsignedShort'      =>
    { Num=>1, Expr=>'\\+?\\d+',   Min=>'0', Max=>'0x7FFF' },
    'unsignedInt'        =>
    { Num=>1, Expr=>'\\+?\\d+',   Min=>'0', Max=>'0x7FFFFFFF' },
    'unsignedLong'       =>
    { Num=>1, Expr=>'\\+?\\d+',   Min=>'0' },#Max=>$max64 },

    # Dates and times (imperfect...)
    'date'        => { Expr=>'-?\d{4,}-\d\d-\d\d([-+]\d\d:\d\d|Z)?' },
    'dateTime'    => {
        Expr=>'-?\d{4,}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?([-+]\d\d:\d\d|Z)?' },
    'time'        => { Expr=>'\d\d:\d\d:\d\d(\.\d+)?([-+]\d\d:\d\d|Z)?' },
    'duration'    => { Expr=> '--\\d+([-+]\d\d:\d\d|Z)?' },
    'gDay'        => { Expr=>'---\\d+([-+]\d\d:\d\d|Z)?' },
    'gMonth'      => { Expr=>'\\d+', Min=>'0', Max=>'12' },
    'gMonthDay'   => { Expr=>'--\d\d-\d\d+([-+]\d\d:\d\d|Z)?' },
    'gYear'       => { Expr=>'-?\d{4,}' },
    'gYearMonth'  => { Expr=>'-?\d{4,}-\d\d' },

    # Strings
    'language'           => { Expr=>'.+' },
    'normalizedString'   => { NormWS=>"1", Expr=>'[^\\r\\n\\t]*' },
    'string'             => { NormWS=>"1", Expr=>'.*' },
    'token'              => { NormWS=>"1", Expr=>'\\S( ?\\S+)*' },

    # XML constructs (note caps)
    "NMTOKEN"            => { NormWS=>"1", Expr=>"$NMTOKEN" },
    "NMTOKENS"           => { NormWS=>"1", Expr=>"$NMTOKEN(\\s+$NMTOKEN)*" },
    "Name"               => { NormWS=>"1", Expr=>"$NAME" },
    "NCName"             => { NormWS=>"1", Expr=>"$NCNAME" },
    "ID"                 => { NormWS=>"1", Expr=>"$NCNAME" },
    "IDREF"              => { NormWS=>"1", Expr=>"$NCNAME" },
    "IDREFS"             => { NormWS=>"1", Expr=>"$NCNAME(\\s+$NCNAME)*" },
    "ENTITY"             => { NormWS=>"1", Expr=>"$NCNAME" },
    "ENTITIES"           => { NormWS=>"1", Expr=>"$NCNAME(\\s+$NCNAME)*" },
    "QName"              => { NormWS=>"1", Expr=>"$NCNAME:$NCNAME" },

    # Net constructs
    'anyURI'       => {
        Expr=>'(([a-zA-Z0-9-$_.+!*,();\\/?:\@=&])|(%\\x\\x))+' },
    'base64Binary' => { Expr=>'[\s+\\/=a-zA-Z0-9]+' },
    'hexBinary'    => { Expr=>'([0-9a-fA-F][0-9a-fA-F])+' },
);


###############################################################################
#
sub new {
    my ($class) = @_;
    my $self = {
        version     => "2012-11-26",
        options     => {
            verbose     => 0,
            scream      => 1,
        },
        dtInfo      => \%dtInfoSource,
    };

    (0) && warn("Constructing Datatypes object: (" .
        join(", ", sort keys(%{$self->{dtInfo}})) . ").\n");

    bless $self, $class;

    for my $dtName (sort keys(%{$self->{dtInfo}})) {
        my $dtSpec = $self->{dtInfo}->{$dtName};
        my $min = decimalize($dtSpec->{Min});
        my $max = decimalize($dtSpec->{Max});
        $dtSpec->{Min} = $min;
        $dtSpec->{Max} = $max;
        $self->vMsg(1, "*****Datatypes: $dtName: /$dtSpec->{Expr}/ >" .
            ($min ? $min:"N/A") . " <" . ($max ? $max:"N/A") . "\n");
    }
    return($self);
}

sub err {
    my ($self, $msg) = @_;
    return unless ($self->{scream});
    $self->vMsg(0,"Datatypes: $msg");
}

sub vMsg {
    my ($self, $level, $msg) = @_;
    return unless ($self->{options}->{verbose} >= $level);
    warn("$msg\n");
}

sub decimalize {
    my ($string) = @_;
    ($string) || return(undef);
    $string =~ s/^(-)//;
    my $sign = ($1) ? -1:1;
    # This will complain about the really big values
    if ($string =~ m/^0/) { $string = oct($string); }
    $string *= $sign;
    return($string);
}

sub getVersion {
    my ($self) = @_;
    return($self->{version});
}

sub setOption {
    my ($self, $name, $value) = @_;
    if (!defined $self->{options}->{$name}) {
        $self->err("Unknown option name '$name'.");
        return(undef);
    }
    $self->{options}->{$name} = $value;
    return($value);
}

sub getOption {
    my ($self, $name) = @_;
    if (!defined $self->{options}->{$name}) {
        $self->err("Unknown option name '$name'.");
        return(undef);
    }
    return($self->{options}->{$name});
}

# Return true iff value is ok.
#
sub checkValueForType {
    my ($self,
        $dtName,         # Descriptive name of the datatype
        $rep,            # Repetition indicator (just "?" or "!" for now)
        $value,          # Value to be checked
        $scream,         # Whether to report mismatch to STDOUT
        ) = @_;

    if ($rep !~ m/(?|!)/) {
        $self->vMsg(1, "checkValueForType: Bap rep: '$rep'.\n");
        $rep = "!";
    }
    if ($value eq "" && ($rep eq "?" || $rep eq "*")) { return(1); }
    if (defined $scream) { $self->{scream} = $scream; }
    my $dtSpec = $self->{dtInfo}->{$dtName};
    ($dtSpec) || return(0); # Scream about this, too?

    my $expr = $dtSpec->{Expr} || "";
    $self->vMsg(1, "Checking '$dtName': value '$value' vs. /$expr/");

    if ($dtName =~ m/[\t\[\{\]\}]/) { # obsolete syntax!
        $self->err("Bad char in datatype '$dtName'");
    }

    $dtName =~ s/\((.*)//;                        # Extract (arg) if present
    my $arg = $1 ? $1:"";
    $arg =~ s/\).*//;

    if ($dtName eq "ENUM") {                    # ENUM
        my @vals = split(/[\s\|,]+/, $arg);
        shift @vals;
        for my $v (@vals) {
            if ($dtName eq $v) { return(1); }
        }
        $self->err("Value '$value' is not in enum (" .
                   join(", ", @vals) . ").");
        return(0);
    }
    elsif ($dtName eq "STRING") {           # STRING
        my $rc = $value =~ m/$arg/ ? 1:0;
        (!$rc) && $self->err(
            "Value '$value' does not match STRING Expr /$arg/");
        return($rc);
    }

    elsif ($dtName =~ m/^REGEX$/) {             # REGEX
        my $x = "'x' =~ m/$value/;";
        #warn "About to eval '$x'\n";
        eval($x); # On error, $@ is set to non-empty error message.
        my $rc = $@ ? 0:1;
        (!$rc) && $self->err("Bad regex: /$value/.\n");
        return($rc);
    }
    if ($value !~ m/$expr/) {                     # Normal expr-based type
        $self->err("$dtName value '$value' does not match /$expr/.\n");
        return(0);
    }
    my $min = $dtSpec->{Min};                     # Numeric ranges
    if ($min && $value < $min) {
        $self->err("$dtName value $value is below min $min.\n");
        return(0);
    }
    my $max = $dtSpec->{Max};
    if ($max && $value > $max) {
        $self->err("$dtName value $value is above max $max.\n");
        return(0);
    }
    return(1);
}

sub isXSD { # Built-in type from XSD?
    my ($self, $dtName) = @_;
    my $dtSpec = $self->{dtInfo}->{$dtName};
    return(($dtSpec && $dtSpec !~ m/^/) ? 1:0);
}

sub isNumericDatatype {
    my ($self, $dtName) = @_;
    my $dtSpec = $self->{dtInfo}->{$dtName};
    return(($dtSpec && $dtSpec->{"Num"}) ? 1:0);
}

sub isWSNormalizable {
    my ($self, $dtName) = @_;
    my $dtSpec = $self->{dtInfo}->{$dtName};
    return(($dtSpec && $dtSpec->{"Norm"}) ? 1:0);
}

sub isKnownDatatype {
    my ($self, $dtName) = @_;
    # (following two types have appended args
    if ($dtName =~ m/^(ENUM|STRING)\(.*\)/) { return(1); }
    my $dtSpec = $self->{dtInfo}->{$dtName};
    return(defined($dtSpec) ? 1:0);
}

sub getKnownDatatypes {
    my ($self) = @_;
    my @foo = keys(%{$self->{dtInfo}});
    return(\@foo);
}


###############################################################################
#
sub normalize {
    my ($self, $typeName, $value) = @_;
    if ($typeName eq "BASEINT") {               # BASEINT
        $value = oct($value) if ($value =~ m/^0/);
    }
    elsif (isNumericDatatype($typeName)) {        # Other numeric
        $value = $value + 0;
    }
    elsif (isWSNormalizable($typeName)) {         # WS normalizing
        $value =~ s/\s+/ /g;
        $value =~ s/^ //g;
        $value =~ s/ $//g;
    }
    elsif ($typeName eq "boolean") {              # Boolean
        $value = (!$value || $value eq "false") ? 0:1;
    }
    return($value);
}

1;
