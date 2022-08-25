#!/usr/bin/env perl -w
#
# TFNative: To replace TabularFormats.pm.
# ~2020: Written by Steven J. DeRose.
#
use strict;
use Text::CSV;

package TFNative;

our %metadata = (
    'title'        => "TFNative",
    'description'  => "A glue layer for Text::CSV.",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "~2020",
    'modified'     => "2022-04-13",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};

=pod

=head1 TFNative: A replacement for my old TabularFormats.pm, but:

=over

=item * just support obvious CSV variants

=item * use native cpan Text::CSV library (thus, no support for
all those non-CSV tabular variants).

=item * easily pluggable in place of old TF module.

=back

This is just glue to implement the functions my other Perl utils actually use,
with the minimal work to just do them via Text::CSV.
Methods used very little, are just dropped from the callers.


=head1 To Do

Move the utilities themselves to Python, using PowerWalk and fsplit.


=head1 History

~2020: Written by Steven J. DeRose (unfinished).

2022-04-13: Pick up again, get compiling and start testing.


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.


=cut

our $tf = "TFNative";  # Prefix to messages


#########################################################################################
#
# Text::CSV: See https://perlmaven.com/how-to-read-a-csv-file-using-perl,
#     https://metacpan.org/pod/Text::CSV
#
my %CSVOptionDefs = (
    # name                => (default,   type,   getopt suffix),
    eol                   => ("",        "str",  "=s"),
    sep_char              => (',',       "char", "=s"),
    sep                   => ("",        "bool", ""),
    quote_char            => ('"',       "char", "=s"),
    quote                 => (0,         "bool", ""),
    escape_char           => ('"',       "char", "=s"),
    binary                => (0,         "bool", "!"),
    decode_utf8           => (1,         "bool", "!"),
    auto_diag             => (0,         "bool", "!"),
    diag_verbose          => (0,         "bool", "!"),
    blank_is_undef        => (0,         "bool", "!"),
    empty_is_undef        => (0,         "bool", "!"),
    allow_whitespace      => (0,         "bool", "!"),
    allow_loose_quotes    => (0,         "bool", "!"),
    allow_loose_escapes   => (0,         "bool", "!"),
    allow_unquoted_escape => (0,         "bool", "!"),
    always_quote          => (0,         "bool", "!"),
    quote_empty           => (0,         "bool", "!"),
    quote_space           => (1,         "bool", "!"),
    escape_null           => (1,         "bool", "!"),
    quote_binary          => (1,         "bool", "!"),
    keep_meta_info        => (0,         "bool", "!"),
    strict                => (0,         "bool", "!"),
    skip_empty_rows       => (0,         "bool", "!"),
    formula               => (0,         "bool", "!"),
    verbatim              => (0,         "bool", "!"),
    undef_str             => (undef,     "str",  "=s"),
    comment_str           => (undef,     "str",  "=s"),
    types                 => (undef,     "",     "=s"),
    #callbacks             => (undef,     "",     "=s"),
);

sub TFNative::new {
    my ($class, $optionsRef) = @_;
    print($optionsRef . "\n");
    my $self = {
        "CSVOptions" => (),
        "ifh"        => undef,
        "csv"        => Text::CSV->new(\%optionsCopy),
        "fieldNames" => (),
        "lastValues" => (),
        "recnum"     => 0
    };
    bless $self, $class;
    $self -> initOptions(\%CSVOptionDefs, $optionsRef);
}

sub TFNative::initOptions {
    my ($self, $optionsRef) = @_;
    $self->CSVOptions = ();
    for my $oname keys(%CSVOptionDefs) {
        if (defined $optionsRef->{$oname}) {
            # TODO: typecheck
            $self->CSVOptions{$oname} = $optionsRef->{$oname};
        }
        else {
            $self->CSVOptions{$oname} = $optionsRef->{$oname}[0];
        }
    }
    return;
}

sub TFNative::attach {  # 7 calls
    my ($self, $ifh) = @_;
    $self->ifh = $ifh;
    $self->recnum = 0;
}

sub TFNative::getLastMessage { # 1 call
    my ($self) = @_;
    die "Not supported.\n";
}

sub TFNative::SniffFormat {  # 1 call
    my ($self) = @_;
    die "Not supported.\n";
}


#########################################################################################
# Options
#
# Facilitate callers supporting our options, by providing a single method
# that adds them to a hash for the argument to Getopt::Long::GetOptions().
# The options invoke commands that store their values back here, so caller
# doesn't have to know about them at all.
# Options already defined before calling us are ok (warning on conflict).
#
sub TFNative::addOptionsToGetoptLongArg {
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
    my $optsRef = $self->{CSVOptions};
    my %theOptions = %{$optsRef};
    for my $name (sort keys(%theOptions)) {
        $i++;
        my @tuple = $CSVOptionDefs{$name};
        my $dft = $tuple[0];
        my $typename =  $tuple[1];
        my $suffix = $tuple[2];
        if ($typename eq "") { next; }
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

sub TFNative::getOptionsHash {  # 3 calls
    my ($self) = @_;
    return $self->CSVOptions;
}

sub TFNative::getOption {
    my ($self, $name) = @_;
    if (defined $self->CSVOptions->{$name}) {
        return $self->CSVOptions->{$name};
    }
    return undef;
}

sub TFNative::setOption {
    my ($self, $name, $value) = @_;
    if (defined $self->CSVOptions->{$name}) {
        $self->CSVOptions->{$name} = $value;
        return $value;
    }
    return undef;
}

sub TFNative::hasOption { # 1 call
    my ($self, $name) = @_;
    return (defined $self->CSVOptions->{$name});
}

sub TFNative::getOptionHelps { # 1 call
    my ($self) = @_;
    my $buf = "TFNative options:\n";
    for my $m (keys(%CSVOptionDefs)) {
        $buf .= $CSVOptionDefs{$m} . ", ";
    }
    return $buf . ".\n";
}


#########################################################################################
#
# Read and parse
#
sub TFNative::readAndParseHeader {  # 4 calls
    my ($self) = @_;
    ($self->recnum) && die sprintf(
        "readAndParseHeader: not at rec 0, but %d.\n", $self->recnum));
    my $hrec = $self->readHeader();
    my $fieldsRef = $self->csv->parseHeader($hrec);
    return $fieldsRef;
}

sub TFNative::readHeader {  # 5 calls
    my ($self) = @_;
    ($self->ifh)  || die
        "Cannot parse header, no file or already read records.\n";
    }
    ($self->recnum) && die sprintf(
        "readHeader: not at rec 0, but %d.\n", $self->recnum);
    return $self->ifh->readline();
}

sub TFNative::parseHeader {  # 6 calls
    my ($self, $hrec) = @_;
    return $self->csv->header($self->{ifh});
}

sub TFNative::parseHeaderRecord { # 1 call
    my ($self) = @_;
    die "Not supported.\n";  # TODO: Nuke
}


sub TFNative::readRecord {  # 7 calls
    my ($self) = @_;
    return $self->csv->getline_all();
}

sub TFNative::parseRecordToHash { # 1 call
    my ($self, $rec) = @_;
    my $fieldsHRef = $self->{csv}->parse_hr($rec);
    return $fieldsHRef;
}

sub TFNative::parseRecordToArray {  # 9 calls
    my ($self, $rec) = @_;
    return $self->parseRecord($rec);
}

sub TFNative::parseRecord {  # 7 calls
    my ($self, $rec) = @_;
    my $fieldsRef = $self->{csv}->parse($rec);
    return $fieldsRef;
}


#########################################################################################
# Field stuff
#
sub TFNative::getFieldValue {  # 8 calls
    my ($self) = @_;
    die "Not supported.\n";  # TODO: Nuke -- not in original Perl!!!!
}

sub TFNative::getFieldNumber {  # 8 calls
    my ($self, $name) = @_;
    for (my $i=0; $i<length($self->{fieldNames}); $i++) {
        my $fdname = $self->{fieldNames}->[$i];
        ($fdname == $name) && return $i;
    }
    return -1;
}

sub TFNative::getFieldNamesArray { # 2 calls
    my ($self) = @_;
    return $self->{fieldNames};
}

sub TFNative::getFieldName { # 2 calls
    my ($self, $n) = @_;
    if ($n < scalar($self->{fieldNames})) {
        return $self->{fieldNames}->[$n];
    }
    return undef;
}

sub TFNative::getDataSchema { # 2 calls
    my ($self) = @_;
    die "Not supported.\n";  # TODO: Nuke
}

sub TFNative::getNSchemaFields { # 1 call
    my ($self) = @_;
    die "Not supported.\n";  # TODO: Nuke
}


#########################################################################################
# Output
#
sub TFNative::assembleRecordFromArray { # 1 call
    my ($self, $fieldsRef) = @_;
    return $self->assembleRecord($fieldsRef);
}

sub TFNative::assembleRecord { # 2 calls  TODO move calls to ...FromArray?
    my ($self, $fieldsRef) = @_;
    my @fields = @{$fieldsRef};
    my $buf = "";
    for (my $i=0; $i<scalar @fields; $i++) {
        if ($buf ne "") { $buf .= $self->{CSVOptions}->{"sep_char"}; }
        $buf .= $fields[$i];
    }
    return $buf . $self->{CSVOptions}->{"eol"};
}

sub TFNative::setFieldValue { # 1 call
    my ($self) = @_;
    die "Not supported.\n";  # TODO: Nuke
}

sub TFNative::setFieldPositions { # 1 call
    my ($self) = @_;
    die "Not supported.\n";  # TODO: Nuke
}


#########################################################################################
# Options
#
package main;

use Getopt::Long;

my $color         = ($ENV{CLI_COLOR} && -t STDERR) ? 1:0;
my $header        = 0;
my $iencoding     = "";
my $ilineends     = "U";
my $oencoding     = "";
my $olineends     = "U";
my $quiet         = 0;
my $verbose       = 0;

my %getoptHash = (
    "color!"                       => \$color,
    "h|help"                       => sub { system "perldoc $0"; exit; },
    "iencoding=s"                  => \$iencoding,
    "ilineends=s"                  => \$ilineends,
    "listEncodings|list-encodings" => sub {
        warn "\nEncodings available:\n";
        my $last = ""; my $buf = "";
        for my $k (Encode->encodings(":all")) {
            my $cur = substr($k,0,2);
            if ($cur ne $last) {
                warn "$buf\n";
                $last = $cur; $buf = "";
            }
            $buf .= "$k ";
        }
        warn "$buf\n";
        exit;
    },
    "oencoding=s"                  => \$oencoding,
    "olineends=s"                  => \$olineends,
    "q!"                           => \$quiet,
    "unicode!"                     => sub { $iencoding=$oencoding="utf8"; },
    "v+"                           => \$verbose,
    "version"                      => sub {
        die "Version of $VERSION_DATE, by Steven J. DeRose.\n";
    },
);

my %DefaultCSVOptions = ();
for my $m (keys(%CSVOptionDefs)) {
    my @tuple = $CSVOptionDefs{$m};
    #my @tuple = @{$tupleRef};
    my $dft = $tuple[0];  # TODO Eh???
    $DefaultCSVOptions{$m} = $dft;
}

my $tfmt = new TFNative(\%DefaultCSVOptions);
$tfmt->addOptionsToGetoptLongArg(\%getoptHash);

Getopt::Long::Configure ("ignore_case");
GetOptions(%getoptHash) || die "Bad options.\n";


#########################################################################################
# Main
#
my $file = $ARGV[0] or die "Need to specify a CSV file on the command line\n";

my $tfn = new TFNative(\%DefaultCSVOptions);

my $sum = 0;
open(my $data, '<', $file) or die "Could not open '$file' $!\n";
binmode($data, ":encoding($iencoding)");
$tfn->attach($data);

if ($header) {
    $tfn->parseHeader();
    vMsg(1, "Header: [ " . join($tfn->fieldNames, ", ") . "].\n");
}

my $recnum = 0;
while (my $line = <$data>) {
    $recnum++;
    chomp $line;

    if ($tfn->{csv}->parse($line)) {
        my @fields = @{$tfn->{fields}};
        printf("%4d: [ %s ]\n", $recnum, join(@fields, ", "));
        $sum += $fields[2];

    } else {
        warn "Line could not be parsed: $line\n";
    }
}
print("Done after $recnum records.\n");
