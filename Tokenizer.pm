#!/usr/bin/perl -w
#
# Tokenize.pm: Generic tokenizer
#
# 2012-08-22ff: Written by Steven J. DeRose, based on
#     variations in tuples, vocab, volsunga, etc. Rationalize....
# 2012-08-29 sjd: Change option values from strings to numbers. Profile a bit.
#     Fix some regexes.
# 2012-09-04f sjd: Fix and doc ucc unify values and inheritance. Use in 'vocab'.
#     Factor out more regexes, and precompile for speed. Rest of currency.
#     Provide API for doing normalizing but not tokenizing
# 2012-09-10 sjd: break at = : ... emdash regardless of T_HYPHEN.
# 2013-08-29: Comment out digit->9 change in normalize(). Improve regexes
#     for percent, fraction, etc.
# 2014-04-10: Add temporal words. Improve abbreviation-detection (attach periods).
#     Change numerics to default to 'keep', not 'unify'.
# 2015-02-25: Speedup, cleanup. Add contraction lists. In progress.
# 2015-06-08: Get working again.
#
# More cases:
#     box(es).
#     Slash? 1/2, 1-1/2, b/c, and/or, he/she, 3/day,...
#     Abbreviation periods? Genitives?
#     Single/double quotes?
#     US$ CA$ U.S. loses final period, etc.
#     Personal names with middle initial with period not caught
#     Domain names (cf $tld)
#     Hex numbers
#     Sentence-leading words pulled into NER too readily.
#     DNA sequences:   [-ACGT]{10,}
#
# To do (see also "Known Bugs and Limitations")
#     Profile
#         Can we switch to UCS2 instead of UTF8 for speed?
#     Takes \d+ to 9999 too early, kills dates and numeric char refs.
#     Way to return tokens with accompanying token-types
#     Break at comma, --; trailing punc? trailing balancing punc?
#     Hashtags?
#     Option to control digit->9 change in normalize(). And move later?
#     Option to ignore text in () etc.
#     Leaves " on start/end of tokens -- "i )"
#     U+00AD is considered \p{Control}!!!! (soft hyphen)
#     Ignore case on URI matching, email,....
#     Tokens with any non-ASCII chars
#     Drop F_SPACE?
#     Unicode Word_Break and Sentence_Break properties
#     Ditch "filtering" options?
#
use strict;
use Getopt::Long;
use Encode;
use charnames ':full';
use Unicode::Normalize;
use Unicode::Normalize 'decompose';

#use Devel::DProf;

use sjdUtils;

our $VERSION_DATE = "2015-06-08";

#package LanguageSpecific;
# Cf 'vocab' script
our $titles = "Mr|Dr|Mrs|Ms|Messr|Messrs|Rev|Fr|St|Pres|Gen|Cpl";
our $months = "January|February|March|April|May|June|" .
              "July|August|September|October|November|December|" .
              "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sept?|Oct|Nov|Dec|";
our $weekdays = "Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|" .
                "Mon|Tues?|Weds?|Thurs?|Fri|Sat|Sun|";
our $relative = "today|tomorrow|yesterday|eve";
our $daypart  = "morning|noon|afternoon|night|midnight|dawn|dusk|matins|vespers|lauds";
our $eras     = "BC|AD|BCE|CE";
our $zones    = "EST|EDT|CST|CDT|MST|MDT|PST|PDT|Z";


###############################################################################
###############################################################################
###############################################################################
#
package Tokenizer;

# Reserved set of option values, mainly for how to map char classes.
# Use numbers for faster tests in map().
#
my %dispTypes = (
    # Keyword     Value    Classes that can use it
    # No change needed:
    "keep"      =>  1,     # "*"
    # Done via map():
    "unify"     => 11,     # "*"
    "delete"    => 12,     # "*"
    "space"     => 13,     # "*"
    "strip"     => 14,     # "Letter"
    "value"     => 15,     # "Number"
    # Not done via map()... probably should be....
    "upper"     =>  6,     # "Letter"
    "lower"     =>  7,     # "Letter"
    "decompose" =>  8,     # "Letter"
    );

# Cf Datatypes.pm
my %knownTypes = (
    'boolean'   => '0|1',
    'int'       => '[-+]?\d+',
    'float'     => '[-+]?\d+(\.\d+)',
    'string'    => '.*',
    'disp'      => '(' . join("|",keys(%dispTypes)) . ')',
    );

# See http://perldoc.perl.org/perlunicode.html#Unicode-Character-Properties
#     http://unicode.org/reports/tr44/tr44-4.html#General_Category_Values
#         (which has 30 entries, omitting the single-character meta ones)
#
# Changes here should be reflected in the Perldoc!
#
my $u = "";
my %ucc = (
    #    Unicode catagory name     Unify   Abbrev   NumberOfChars
    # LETTERS
    $u . "Letter"                => "A",   # "L",
    $u . "Cased_Letter"          => "A",   # "LC",
    $u . "Uppercase_Letter"      => "A",   # "Lu",  01441
    $u . "Lowercase_Letter"      => "a",   # "Ll",  01751
    $u . "Titlecase_Letter"      => "Fi",  # "Lt",  00031
    $u . "Modifier_Letter"       => "A",   # "Lm",  00037
    $u . "Other_Letter"          => "A",   # "Lo",  11788

    # MARKS
    $u . "Mark"                  => " ",   # "M",
    $u . "Nonspacing_Mark"       => " ",   # "Mn",  01280
    $u . "Spacing_Mark"          => " ",   # "Mc",  00353
    $u . "Enclosing_Mark"        => " ",   # "Me",  00012

    # NUMBERS
    $u . "Number"                => "9",   # "N",
    $u . "Decimal_Number"        => "9",   # "Nd",  00460
    $u . "Letter_Number"         => "9",   # "Nl",  00224
    $u . "Other_Number"          => "9",   # "No",  00464

    # PUNCTUATION
    $u . "Punctuation"           => ".",   # "P",
    $u . "Connector_Punctuation" => "_",   # "Pc",  00010 _ etc.
    $u . "Dash_Punctuation"      => "-",   # "Pd",  00023 Not incl. soft hyphens
    $u . "Open_Punctuation"      => "(",   # "Ps",  00072 Parentheses, etc.
    $u . "Close_Punctuation"     => ")",   # "Pe",  00071
    $u . "Initial_Punctuation"   => "`",   # "Pi",  00012 Sided quotes, etc.
    $u . "Final_Punctuation"     => "'",   # "Pf",  00012
    $u . "Other_Punctuation"     => "*",   # "Po",  00434 !"#%&'*,./:;?@\\ etc.

    # SYMBOLS
    $u . "Symbol"                => "#",   # "S",
    $u . "Math_Symbol"           => "=",   # "Sm",  00952
    $u . "Currency_Symbol"       => "\$",  # "Sc",  00049
    $u . "Modifier_Symbol"       => "#",   # "Sk",  00115
    $u . "Other_Symbol"          => "#",   # "So",  04404

    # SEPARATORS
    $u . "Separator"             => " ",   # "Z",
    $u . "Space_Separator"       => " ",   # "Zs",  00018
    $u . "Line_Separator"        => " ",   # "Zl",  00001
    $u . "Paragraph_Separator"   => " ",   # "Zp",  00001

    # OTHER CATEGORIES
    $u . "Other"                 => "?",   # "C",
    $u . "Control"               => "?",   # "Cc",  00065
    $u . "Format"                => "?",   # "Cf",  00139 shy, invis, joiner,
    $u . "Surrogate"             => "?",   # "Cs",  00006
    $u . "Private_Use"           => "?",   # "Co",  00006
    $u . "Unassigned"            => "?",   # "Cn",

    # BIDI PROPERTIES -- (not yet supported)
    # Issue: Colon vs. underscore (Getopt doesn't like colons)
    #
    # "BiDi_L"                => "A",   # "L",
    # "BiDi_LRE"              => "A",   # "LRE",
    # "BiDi_LRO"              => "A",   # "LRO",
    # "BiDi_R"                => "A",   # "R",
    # "BiDi_AL"               => "A",   # "AL",
    # "BiDi_RLE"              => "A",   # "RLE",
    # "BiDi_RLO"              => "A",   # "RLO",
    # "BiDi_PDF"              => "A",   # "PDF",
    # "BiDi_EN"               => "A",   # "EN",
    # "BiDi_ES"               => "A",   # "ES",
    # "BiDi_ET"               => "A",   # "ET",
    # "BiDi_AN"               => "A",   # "AN",
    # "BiDi_CS"               => "A",   # "CS",
    # "BiDi_NSM"              => "A",   # "NSM",
    # "BiDi_BN"               => "A",   # "BN",
    # "BiDi_B"                => "A",   # "B",
    # "BiDi_S"                => "A",   # "S",
    # "BiDi_WS"               => "A",   # "WS",
    # "BiDi_ON"               => "A",   # "ON",
    );


###############################################################################
#
sub new {  # Tokenizer constructor
    my ($class, $bt) = @_;
    my $self = {
        version     => $VERSION_DATE,
        options     => {},
        optionTypes => {},
        optionHelps => {},
        anyFilters  => 1,
        su          => undef,
        srcData     => "",
        tokens      => [],
        nNilTokens  => [], # by place in record
        regexes     => {},
    };
    bless $self, $class;
    if (!sjdUtils::getUtilsOption("verboseSet")) {
        sjdUtils::setVerbose(0);
    }
    $self->defineOptions();

    if (!$bt) { $bt = "words"; }
    elsif ($bt !~ m/^(chars|words|none)$/) {
        alogging::eMsg(0, "Unknown Tokenizer type, must be chars|words|none.");
        $bt = "words";
    }
    $self->setOption("TOKENTYPE", $bt);
    $self->preCompileRegexes();
    return($self);
} # new

sub defineOptions { # Move to XSV, and pull in regexes and unify targets
    my ($self) = @_;
    #                   Name             Datatype   Default   Help
    $self->defineOption('TVERBOSE',      'boolean', 0,        '');
    $self->defineOption('TOKENTYPE',     'string',  'words',  '');

    # 1: Expand
    $self->defineOption('X_BACKSLASH',   'boolean', 0,        '');
    $self->defineOption('X_URI',         'boolean', 0,        '');
    $self->defineOption('X_ENTITY',      'boolean', 0,        '');

    # 2: Normalize
    $self->defineOption('Ascii_Only',    'boolean', 0,       '');
    $self->defineOption('Accent',        'disp',    'keep', '');
    $self->defineOption('Control_0',     'disp',    'keep', '');
    $self->defineOption('Control_1',     'disp',    'keep', '');
    $self->defineOption('Digit',         'disp',    'keep', '');
    $self->defineOption('Fullwidth',     'disp',    'keep', '');
    $self->defineOption('Ligature',      'disp',    'keep', '');
    $self->defineOption('Math',          'disp',    'keep', '');
    $self->defineOption('Nbsp',          'disp',    'space', '');
    $self->defineOption('Soft_Hyphen',   'disp',    'delete', '');

    for my $u (keys(%ucc)) { # The Unicode categories
        $self->defineOption($u,          'disp',    'keep', '');
    }

    # 3: Shorten
    $self->defineOption('N_CHAR',        'int',     0,       '');
    $self->defineOption('N_SPACE',       'int',     0,       '');

    # 4: Non-word tokens
    $self->defineOption('T_TIME',        'disp',    'keep','');
    $self->defineOption('T_DATE',        'disp',    'keep','');
    $self->defineOption('T_FRACTION',    'disp',    'keep','');
    $self->defineOption('T_NUMBER',      'disp',    'keep','');
    $self->defineOption('T_CURRENCY',    'disp',    'keep','');
    $self->defineOption('T_PERCENT',     'disp',    'keep','');

    $self->defineOption('T_EMOTICON',    'disp',    'keep','');
    $self->defineOption('T_HASHTAG',     'disp',    'keep','');
    $self->defineOption('T_USER',        'disp',    'keep','');
    $self->defineOption('T_EMAIL',       'disp',    'keep','');
    $self->defineOption('T_URI',         'disp',    'keep','');

    # 5: Special issues
    $self->defineOption('S_CONTRACTION', 'disp',    'keep', '');
    $self->defineOption('S_HYPHENATED',  'disp',    'keep',  '');
    $self->defineOption('S_GENITIVE',    'disp',    'keep',  '');

    # 6: Filter (0 means keep, 1 means filter out)
    $self->defineOption('F_MINLENGTH',   'int',     0,   '');
    $self->defineOption('F_MAXLENGTH',   'int',     0,   '');
    $self->defineOption('F_DICT',        'string',  '',  '');

    $self->defineOption('F_SPACE',       'boolean', 0,   ''); # OBS?
    $self->defineOption('F_UPPER',       'boolean', 0,   '');
    $self->defineOption('F_LOWER',       'boolean', 0,   '');
    $self->defineOption('F_TITLE',       'boolean', 0,   '');
    $self->defineOption('F_MIXED',       'boolean', 0,   '');
    $self->defineOption('F_ALNUM',       'boolean', 0,   '');
    $self->defineOption('F_PUNCT',       'boolean', 0,   '');
} # defineOptions

sub defineOption {
    my ($self, $name, $type, $default, $help) = @_;
    alogging::vMsg(
        2, sprintf("Defining option:  %-24s (%8s) = '%s'",
                   $name, $type, $default));
    (!defined $self->{options}->{$name}) ||
        die "Duplicate option def for '$name'\n";
    ($name =~ m/^\w+$/) ||
        die "defineOption: Non-word char in name '$name'\n";
    (defined $knownTypes{$type}) ||
        die "Unknown option type '$type' for option '$name'. Known: " .
        join(", ", sort(keys(%knownTypes))) . "\n";
    ($self->checkType($type,$default)) ||
        die "Bad default '$default' for option '$name' of type '$type'\n";
    $self->{optionTypes}->{$name} = $type;
    $self->{options}->{$name} = $default;
    $self->{optionHelps}->{$name} = $help;
} # defineOption

sub checkType {
    my ($self, $type, $value) = @_;
    (my $typeExpr = $knownTypes{$type}) ||
        die "Tokenizer::checkType: Unknown type name '$type'\n";
    return(($value =~ m/^$typeExpr$/) ? 1:0);
}

sub setOption {
    my ($self, $name, $value) = @_;
    if (!defined $self->{options}->{$name}) {
        warn "Tokenizer::setOption: Unknown option name '$name'.\n";
        return(undef);
    }
    if (!$self->checkType($self->{optionTypes}->{$name}, $value)) {
        warn "Tokenizer::setOption: Bad value '$value' for option '$name'\n";
        return(undef);
    }
    $self->{options}->{$name} = $value;
    if (index($name, "F_") == 0) {
        $self->setAnyFilters();
        warn "setOptions for '$name' led to $self->{anyFilters}.\n";
    }
    elsif (index($name,'_')>1) { # inherit (not during defineOptions()!)
        for my $u (keys(%ucc)) {
            next unless ($u =~ m/^$name\_/);
            $self->{options}->{$u} = $value;
        }
    }
    return($value);
}

sub setAnyFilters {
    my ($self) = @_;
    my $nFSet = 0;
    for my $op (keys(%{$self->{options}})) {
        if ($op =~ m/^F_/ && $self->{options}->{$op}) {
            $self->{anyFilters} = 1;
            return;
        }
    }
    $self->{anyFilters} = 0;
}

sub getOption {
    my ($self, $name) = @_;
    if (!defined $self->{options}->{$name}) {
        warn "Tokenizer::getOption: Unknown option name '$name'.\n";
        return(undef);
    }
    return($self->{options}->{$name});
}

sub addOptionsToGetoptLongArg {
    my ($self,
        $getoptHash,          # The hash to pass to GetOptions()
        $prefix               # String to put on front of option names
        ) = @_;
    if (!defined $prefix) { $prefix = ""; }
    #alogging::vMsg(1, "In addOptionsToGetoptLongArg()");
    if (ref($getoptHash) ne "HASH") {
        alogging::eMsg(0,"addOptionsToGetoptLongArg: not a HASH.");
    }
    my %mapOptType = ( "boolean"=>"!", "int"=>"=i", "float"=>"=f",
                "string"=>"=s", "disp"=>"=s", "count"=>"+", );
    for my $name (sort keys(%{$self->{options}})) {
        if ($name !~ m/^\w+$/) {
            alogging::eMsg(
                0,"Tokenizer::addOptionsToGetoptLongArg: Bad name '$name'"
                );
        }
        my $dt = $self->{optionTypes}->{$name};
        my $suffix = $mapOptType{$dt};
        if (!$suffix) {
            alogging::eMsg(0,"addOptionsToGetoptLongArg: " .
                            "Unknown type '$dt' for option '$name'. " .
                            "Known: (" . join(", ", keys(%mapOptType)) . ").");
            $suffix = "!";
        }
        if (defined $getoptHash->{"$prefix$name$suffix"}) {
            alogging::eMsg(
                0,"Tokenizer::Option '$prefix$name$suffix' already in hash.");
        }
        $getoptHash->{"$prefix$name$suffix"} =
            sub { $self->setOption($name, $_[1]); };
    }
} # addOptionsToGetoptLongArg


###############################################################################
# The real work.
#
sub tokenize {
    my ($self, $s) = @_;
    my $tokens = undef;
    if ($self->{options}->{"TVERBOSE"} > 1) {
        $self->{srcData} = $s;
        alogging::hMsg(0, "Tokenize:    ", $self->{srcData});
        $self->expand();
        alogging::vMsg(0, " Expanded:   ", $self->{srcData});
        $self->normalize();
        alogging::vMsg(0, " Normalized: ", $self->{srcData});
        $self->shorten();
        alogging::vMsg(0, " Shortened:  ", $self->{srcData});
        $tokens = $self->splitTokens();
        alogging::vMsg(0, " Broken:     ", "(".join("|",@{$tokens}).")");
        ($self->{anyFilters}) && $self->filter($tokens);
        alogging::vMsg(0, " Filtered:   ", "(".join("|",@{$tokens}).")");
    }
    else {
        $self->{srcData} = $s;
        $self->expand();
        $self->normalize();
        $self->shorten();
        $self->nonWordTokens();
        $tokens = $self->splitTokens();
        ($self->{anyFilters}) && $self->filter($tokens);
    }

    #warn "tokenize: ", join("|", @{$tokens}) . "\n";
    for (my $i=0; $i<scalar(@{$tokens}); $i++) {
        next unless ($tokens->[$i] eq "");
        #warn "Nil.\n";
        $self->{nNilTokens}->[$i]++;
        splice(@{$tokens}, $i, 1);
    }
    return($tokens);
} # tokenize


###############################################################################
# Since regexes get passed to map(), avoid recompiling every time.
# This alone saves >50% of runtime.
#
sub preCompileRegexes {
    my ($self) = @_;

    $self->{regexes}->{"Ascii_Only"}  = qr/[^[:ascii:]]/;

    for my $ugcName (sort(keys(%ucc))) {
        $self->{regexes}->{$ugcName}  = qr/\p{$ugcName}/;
    } # for

    $self->{regexes}->{"Accent"}      = qr//; ### FIX ###
    $self->{regexes}->{"Control_0"}   = qr/[\x00-\x1F]/;
    $self->{regexes}->{"Control_1"}   = qr/[\x80-\x9F]/;
    $self->{regexes}->{"Digit"}       = qr/[0-9]/;
    #$self->{regexes}->{"Fullwidth"}  = qr//; ### FIX ###
    #$self->{regexes}->{"Ligature"}   = qr//; ### FIX ###
    #$self->{regexes}->{"Math"}       = qr//; ### FIX ###

    ###################################################### VERY SPECIAL CHARS
    $self->{regexes}->{"Nbsp"}        = qr/\xA0/;
    $self->{regexes}->{"Soft_Hyphen"} = qr/\xAD\u1806/;

    ###################################################### DATE/TIME
    # Doesn't deal with alphabetic times
    #
    my $yr       = '\b[12]\d\d\d';                         # Year
    my $era      = '(AD|BC|CE|BCE)';                       # Which half of hx
    my $zone     = '\s?[ECMP][SD]T';                       # Time zone
    $self->{regexes}->{"T_TIME"}      =
        qr/\b[012]?\d:[0-5]\d(:[0-5]\d)?\s*(a\.?m\.?|p\.?m\.?)?($zone)?\b/;
    # Also '60s 60's 60s
    $self->{regexes}->{"T_DATE"}      =
        qr/\b($yr".'[-\/][0-3]?\d[-\/][0-3]?\d)|($yr ?$era)\b/;

    ###################################################### NUMERICS
    # Also float, exp, 1,234,567, 5'6", roman numerals, Europen punctuation
    #
    $self->{regexes}->{"T_NUMBER"}    = qr/\b[-+]?\d+\b/;
    $self->{regexes}->{"T_FLOAT"}     = qr/\b[-+]?\d+(\.\d+)?([Ee][-+]?\d+)?\b/;

    ###################################################### FRACTIONS
    # Doesn't deal with "one half" etc.
    #
    my $fractionChars =
    	"\u00BC" .   # VULGAR FRACTION ONE QUARTER
		"\u00BD" .   # VULGAR FRACTION ONE HALF
		"\u00BE" .   # VULGAR FRACTION THREE QUARTERS
		"\u0B72" .   # ORIYA FRACTION ONE QUARTER
		"\u0B73" .   # ORIYA FRACTION ONE HALF
		"\u0B74" .   # ORIYA FRACTION THREE QUARTERS
		"\u0B75" .   # ORIYA FRACTION ONE SIXTEENTH
		"\u0B76" .   # ORIYA FRACTION ONE EIGHTH
		"\u0B77" .   # ORIYA FRACTION THREE SIXTEENTHS
		"\u0C78" .   # TELUGU FRACTION DIGIT ZERO FOR ODD POWERS OF FOUR
		"\u0C79" .   # TELUGU FRACTION DIGIT ONE FOR ODD POWERS OF FOUR
		"\u0C7A" .   # TELUGU FRACTION DIGIT TWO FOR ODD POWERS OF FOUR
		"\u0C7B" .   # TELUGU FRACTION DIGIT THREE FOR ODD POWERS OF FOUR
		"\u0C7C" .   # TELUGU FRACTION DIGIT ONE FOR EVEN POWERS OF FOUR
		"\u0C7D" .   # TELUGU FRACTION DIGIT TWO FOR EVEN POWERS OF FOUR
		"\u0C7E" .   # TELUGU FRACTION DIGIT THREE FOR EVEN POWERS OF FOUR
		"\u0D73" .   # MALAYALAM FRACTION ONE QUARTER
		"\u0D74" .   # MALAYALAM FRACTION ONE HALF
		"\u0D75" .   # MALAYALAM FRACTION THREE QUARTERS
		"\u2044" .   # FRACTION SLASH Sm 0 CS     N
		"\u2150" .   # VULGAR FRACTION ONE SEVENTH
		"\u2151" .   # VULGAR FRACTION ONE NINTH
		"\u2152" .   # VULGAR FRACTION ONE TENTH
		"\u2153" .   # VULGAR FRACTION ONE THIRD
		"\u2154" .   # VULGAR FRACTION TWO THIRDS
		"\u2155" .   # VULGAR FRACTION ONE FIFTH
		"\u2156" .   # VULGAR FRACTION TWO FIFTHS
		"\u2157" .   # VULGAR FRACTION THREE FIFTHS
		"\u2158" .   # VULGAR FRACTION FOUR FIFTHS
		"\u2159" .   # VULGAR FRACTION ONE SIXTH
		"\u215A" .   # VULGAR FRACTION FIVE SIXTHS
		"\u215B" .   # VULGAR FRACTION ONE EIGHTH
		"\u215C" .   # VULGAR FRACTION THREE EIGHTHS
		"\u215D" .   # VULGAR FRACTION FIVE EIGHTHS
		"\u215E" .   # VULGAR FRACTION SEVEN EIGHTHS
		"\u215F" .   # FRACTION NUMERATOR ONE
		"\u2189" .   # VULGAR FRACTION ZERO THIRDS
		"\u2CFD" .   # COPTIC FRACTION ONE HALF
		"\uA830" .   # NORTH INDIC FRACTION ONE QUARTER
		"\uA831" .   # NORTH INDIC FRACTION ONE HALF
		"\uA832" .   # NORTH INDIC FRACTION THREE QUARTERS
		"\uA833" .   # NORTH INDIC FRACTION ONE SIXTEENTH
		"\uA834" .   # NORTH INDIC FRACTION ONE EIGHTH
		"\uA835" .   # NORTH INDIC FRACTION THREE SIXTEENTHS
		"\u10E7B" .   # RUMI FRACTION ONE HALF
		"\u10E7C" .   # RUMI FRACTION ONE QUARTER
		"\u10E7D" .   # RUMI FRACTION ONE THIRD
		"\u10E7E" .   # RUMI FRACTION TWO THIRDS
    	"";
    #
    $self->{regexes}->{"T_FRACTION"}  = qr/\b((\d+-)?\d+\/\d+|[$fractionChars])\b/;

    ###################################################### CURRENCY
    my $currency = '$' .
    	"\u00A3" .   # pound sign
    	"\u00A4" .   # currency sign
    	#"\u09F4" .   # to U+09F9: Bengali currency numerators/denominator
    	"\u0E3f" .   # Thai bhat
    	"\u17DB" .   # Khmer riel
    	"\u20A0" .   # Euro sign ~~ U+20CF
    	"\uFFE1" .   # fullwidth pound sign
    	"\uFE69" .   # SMALL DOLLAR SIGN
    	"\uFF04" .   # FULLWIDTH DOLLAR SIGN
        #"\u1F4B2" .  # HEAVY DOLLAR SIGN
    	"";
    $self->{regexes}->{"T_CURRENCY"}  = qr/\b[$currency]\d+(\.\d+)?[KMB]?\b/;

    ###################################################### PERCENT, etc.
    my $pct = "%" .
    	"\u2030" .   # Per Mille Sign
    	"\u2031" .   # Per Ten Thousand Sign
    	"\u0609" .   # Arabic-indic Per Mille Sign
    	"\u060a" .   # Arabic-indic Per Ten Thousand Sign
    	"\u066a" .   # Arabic-indic Percent Sign
    	"\uFE6A" .   # Small Percent Sign
    	"\uFF05" .   # Fullwidth Percent Sign
    	"";
    $self->{regexes}->{"T_PERCENT"}   = qr/\b\d+(\.\d+)[$pct]\b/;

    ###################################################### Internet conventions
    #
    my $uriChars = '[-~?\\[\\]\\(\\)&@+\w.:\\/\\$\\#]';    # Chars ok in URIs
    my $schemes  = "(shttp|http|https|ftp|mailto)";        # URI scheme prefixes
    my $tld      = "(com|org|edu|net|uk|ca)";              # Some top-level domains
    $self->{regexes}->{"T_EMOTICON"}  = qr/[-:;]+[(){}<>]\b/;
    $self->{regexes}->{"T_HASHTAG"}   = qr/\b#\p{Letter}+\b/;
    $self->{regexes}->{"T_EMAIL"}     = qr/\b\w+@\w+(\.\w+)+\b/;
    $self->{regexes}->{"T_USER"}      = qr/\s@[.\w+]\b/;
    $self->{regexes}->{"T_URI"}       = qr/\b$schemes:\/\/$uriChars+\w\b/;

    ###################################################### Hyphenation
    $self->{regexes}->{"S_HYPHENATED"}= qr/(\w)-(\w)/;

    my $n = $self->{options}->{"N_CHAR"};
    $self->{regexes}->{"N_CHAR"}       = qr/(\w)\1{$n,}/;
    my $s = $self->{options}->{"N_SPACE"};
    $self->{regexes}->{"N_SPACE"}      = qr/\s{$s,}/;
} # preCompileRegexes


###############################################################################
# Replace various kinds of 'escapes' so we actually see special chars.
#
sub expand {
    my ($self) = @_;
    if ($self->{options}->{"X_BACKSLASH"}) {
        $self->{srcData} = sjdUtils::unbackslash($self->{srcData});
    }
    if ($self->{options}->{"X_URI"}) {
        $self->{srcData} = sjdUtils::expandURI($self->{srcData});
    }
    if ($self->{options}->{"X_ENTITY"}) {
        $self->{srcData} = sjdUtils::expandXml($self->{srcData});
    }
} # expand


###############################################################################
# Fiddle with the character set.
#
sub normalize {
    my ($self) = @_;

    if ($self->{options}->{"Ascii_Only"} ) { # boolean
        $self->{srcData} =~ s/[^[:ascii:]]//g;
    }
    else {
        for my $ugcName (sort(keys(%ucc))) {
            my $optValue = $self->{options}->{$ugcName};
            next if ($dispTypes{$optValue} == 1); # keep
            $self->map($ugcName, $ucc{$ugcName});
        } # for

        $self->map("Accent",            '???');
        $self->map("Control_0",         ' ');
        $self->map("Control_1",         ' ');
        # The digit normalization should be optional:
        #$self->map("Digit",             '9');
        #$self->map("Fullwidth"
        #$self->map("Ligature"
        #$self->map("Math"
        $self->map("Nbsp",              ' ');
        $self->map("Soft_Hyphen",       '');
    }
} # normalize

###############################################################################
# Deal with character ruuuuuuuuuuuuns. aaarrrrrrrrggggggghh.
#
sub shorten {
    my ($self) = @_;
    if ((my $n = $self->{options}->{"N_CHAR"}) > 1) {
        $self->{srcData} =~ s/$self->{regexes}->{"N_CHAR"}/$1$1/g;
    }
    if ((my $n = $self->{options}->{"N_SPACE"}) > 1) {
        $self->{srcData} =~ s/$self->{regexes}->{"N_SPACE"}/ /g;
    }
} # shorten


###############################################################################
# Special handling for special kinds of tokens.
# Don't need to tokenize these because they're normally already surrounded
# by spaces or other breaking punctuation. But, can unify/space/delete them.
#
sub nonWordTokens {
    my ($self) = @_;
    #          TYPE           NEUTRALIZED VALUE
    $self->map("T_TIME",      "09:09");
    $self->map("T_DATE",      "2009-09-09");
    $self->map("T_FRACTION",  "9/9");
    #$self->map("T_NUMBER",    "9999");
    #$self->map("T_CURRENCY",  "\$99");
    $self->map("T_PERCENT",   "99%");

    $self->map("T_EMOTICON",  ":)");
    $self->map("T_HASHTAG",   "#nine");
    $self->map("T_EMAIL",     "user@example.com");
    $self->map("T_USER",      "\@nine");
    $self->map("T_URI",       "http://www.example.com");
} # nonWordTokens


###############################################################################
# Break into tokens at spaces, and split off leading/trailing punctuation.
# Add spaces first for a few special cases.
# What about emoticons?
#
sub splitTokens {
    my ($self) = @_;

    # A few specials
    $self->{srcData} =~ s/--+/ -- /g;                  # em dash
    for my $c ("\\.", "\\/", "\\*", "\\\\", "#", "=", "\\?", "\\!") {
        $self->{srcData} =~ s/($c\s*){3,}/ $c$c$c /g;
    }

    $self->map("S_HYPHENATED",          "\$1 - \$2");

    #$self->map("S_GENITIVE"

    if ($self->{options}->{"S_CONTRACTION"} ne "keep") {
        $self->doContractions();
    }

    my @tokens = undef;
    my $bt = $self->getOption("TOKENTYPE") || "";
    if ($bt eq "words") {                             # WORD/TOKEN SPLITTING
        # Break periods *not* for abbreviations
        $self->{srcData} =~ s/(\w)\. (\p{PosixUpper})/$1 . $2/g;
        $self->{srcData} =~ s/($titles) \./$1./g;
        $self->{srcData} =~ s/\b(\w) \. (\w) \.\b/$1.$2./g;

        # Separate punct at start/end of words
        $self->{srcData} =~ s/(\s+)([^\w\s#@]+)(\w)/ $2 $3/g;
        $self->{srcData} =~ s/(\w)([^\w\s.]+)(\s|$)/$1 $2 /g; # Not periods!

        # Finally, split on all spaces.
        @tokens = split(/\s+/, $self->{srcData});
    }
    elsif ($bt eq "chars") {                          # CHARACTER SPLITTING
        @tokens = split(//,$self->{srcData});
        #warn "Split into: {" . join(" ", @tokens) . "}\n";
    }
    elsif ($bt eq "none") {                           # NO SPLITTING AT ALL
        push @tokens, $self->{srcData};
    }
    else {
        die "Unknown TOKENTYPE '$bt' (must be words, chars, or none).\n";
    }
    return(\@tokens);
} # splitTokens


# Check the setting for a given option, then apply a regex change (that
# was already compiled!), to do the right thing to matching data.
#
sub map {
    my ($self, $optName, $norm) = @_;
    (scalar(@_) == 3) || die "Bad args to map().\n";

    my $optValue = $self->{options}->{$optName};
    if (!defined $optValue) {
        alogging::eMsg(0, "No option value found for '$optName'.");
        $optValue = $self->{options}->{$optName} = "keep";
    }

    my $cregex = $self->{regexes}->{$optName};
    ($cregex) || die "No compiled regex available for '$optName'\n";

    #warn "Firing $optName\t'$optValue': \t/$regex/ on\n  $self->{srcData}\n";
    my $optCode = $dispTypes{$optValue};

    if    ($optCode == 1) {             # keep
        return;
    }
    elsif ($optCode > 10) { # regex cases
        if ($optCode == 11) {	            # unify
            $self->{srcData} =~ s/$cregex/$norm/g;
        }
        elsif ($optCode == 12) {	        # delete
            $self->{srcData} =~ s/$cregex//g;
        }
        elsif ($optCode == 13) {	        # space
            $self->{srcData} =~ s/$cregex/ /g;
        }
        elsif ($optCode == 14) {	        # strip
            $self->{srcData} =~ s/($cregex)/{ strip_diacritics($1); }/ge;
        }
        elsif ($optCode == 15) {	        # value
            $self->{srcData} =~ s/($cregex)/{ get_Value($1); }/ge;
        }
        else {
            die "map: bad (disp) value '$optValue' (=$optCode)\n";
        }
    }
    elsif ($optCode == 6) {	            # upper
        $self->{srcData} = uc($self->{srcData});
        # OR: $self->{srcData} =~ s/($cregex)/\U$1\E/g;
    }
    elsif ($optCode == 7) {	            # lower
        $self->{srcData} = lc($self->{srcData});
        # OR: $self->{srcData} =~ s/($cregex)/\L$1\E/g;
    }
    elsif ($optCode == 8) {	            # decompose
        $self->{srcData} = Unicode::reorder(
            Unicode::decompose($self->{srcData},1));
    }
    else {
        die "map: bad (disp) value '$optValue' (=$optCode)\n";
    }
} # map

sub strip_diacritics {
    my ($c) = @_;
    my $de = Unicode::NFKD($c);
    if (!defined $de || $de eq "") { return($c); }
    # Ditch accents, but not ligature parts...
    $de =~ s/\pM+//g;
    return($de);
}

sub get_value {
    my ($c) = @_;
    my $v = UCD::charinfo($c)->{numeric};
    if (!defined $v || $v eq "") { return($c); }
    return($v);
}


###############################################################################
# English-specific code here...
# This should move to a file, along with Twitterisms
#
sub setupContractions {
    my ($self) = @_;
    $self->{contractionList} = {
        # Irregular (do before regular?)
        "I'm"			=> "I am ",
        "y'all"			=> "you all",
        "y'know"		=> "you know",
        "it's"			=> "it is",
        "'tis"			=> "it is",
        "g'ahn"			=> "go on",
        "let's"			=> "let us",
        "let'r"			=> "let her",
        "let'm"			=> "let them",
        "c'mon"			=> "come on",

        # Without apostrophe
        "coulda"        => "could have",
        "woulda"        => "would have",
        "shoulda"       => "should have",
        "musta"		    => "must have",
        "oughta"		=> "ought to",
        "hafta"		    => "have to",
        "howda"		    => "how do",
        "whaddya"		=> "what do you",
        "willya"		=> "will you",
        "gonna"			=> "going to",
        "gotta"			=> "got to",
        "wanna"		    => "want to",
        "wanta"		    => "want to",

        "cannot"		=> "can not",
        "lookit"		=> "look at",
        "lemme"			=> "let me",
        "gimme"			=> "give me",
        "ahm"			=> "I am",

        "tain't" 		=> "it is not",
        "ain't"			=> "is not",     # or am not
        "can't"			=> "can not",
        "won't"			=> "will not",
        };

    $self->{semiRegularContractionList} = {
        # Semi-regular, that require a word before
        "n't"		    => "not",          # On modals etc.
        "'ve"	        => "have",         # On plural nouns
        "'ll"		    => "will",         # On nouns
        "'n"		    => "than",         # On adjectives
        };

    my $expr = join("|", (keys %{$self->{contractionList}}));
    $self->{contExpr} = qr/\b($expr)\b/;

    my $srexpr = join("|", (keys %{$self->{semiRegularcontractionList}}));
    $self->{srContExpr} = qr/(\w)($srexpr)\b/; # Remember $1

    # wh words can take 're 's 'd (some ambiguous)
    $self->{whContrExpr} = qr/"\b(who|where|what|when|why|how)('re|'s|'d)\b"/;
}

sub doContractions {
    my ($self) = @_;
    $self->{srcData} =~ s/$self->{contExpr}/ {
        $self->{contractionList}->{$1}; } /ge;
    if (index($self->{srcData}, "'") < 0) { return; }
    $self->{srcData} =~ s/$self->{srContExpr}/ {
        $self->{semiRegularContractionList}->{$1}; } /ge;
    $self->{srcData} =~ s/$self->{contExpr}/ {
        $self->{contractionList}->{$1}; } /ge;
} # doContractions


###############################################################################
# Discard unwanted kinds of tokens.
# Faster to discard by nilling out, and dropping at the end.
sub filter {
    my ($self, $tokens) = @_;
    #warn "filtering...\n";
    for (my $i=0; $i<scalar(@{$tokens}); $i++) {
        my $nillable = 0;
        my $t = $tokens->[$i];
        if (length($t) < $self->{options}->{"F_MINLENGTH"}) { $nillable = 1; }
        elsif ($self->{options}->{"F_MAXLENGTH"} > 0 &&
                 length($t) > $self->{options}->{"F_MAXLENGTH"}) { $nillable = 1; }
        elsif ($self->{options}->{"F_DICT"}  &&      # dictionaries
                 defined $self->{dict}->{$t}) { $nillable = 1; }
        elsif ($self->{options}->{"F_SPACE"} &&      # boolean
                 $t =~ m/^\s*$/) { $nillable = 1; }
        elsif ($self->{options}->{"F_UPPER"} &&      # UPPER
                 $t =~ m/^[[:upper:]]+$/) { $nillable = 1; }
        elsif ($self->{options}->{"F_LOWER"} &&      # lower
                 $t =~ m/^[[:lower:]]+$/) { $nillable = 1; }
        elsif ($self->{options}->{"F_TITLE"} &&      # Title
                 $t =~ m/^[[:upper:]][[:lower:]]*$/) { $nillable = 1; }
        elsif ($self->{options}->{"F_MIXED"} &&      # mIxED
                 $t =~ m/^[[:alpha:]]+$/) { $nillable = 1; }
        elsif ($self->{options}->{"F_ALNUM"} &&      # 4x4
                 $t =~ m/\d/ && $t =~ m/\w/) { $nillable = 1; }
        elsif ($self->{options}->{"F_PUNCT"} &&      # AT&T /^[#@]/ ?
                 $t =~ m/[^-'.\w]/) { $nillable = 1; }
        if ($nillable) { $tokens->[$i] = ""; }
    }
    return($tokens);
} # filter


1;


###############################################################################
###############################################################################
###############################################################################
#

=pod

=head1 Usage

This is a natural-language tokenizer, intended as a front-end to NLP
software, particularly lexico-statistical calculators.
It can also be used to normalize text without tokenizing, or
as a preprocessor for more extensive NLP stacks.

It is particularly focused on handling a few complex issues well, which I
think especially iomportant when deriving lexicostatistics (less so when
simply cranking out processed texts):

=over

=item * Character represented in special ways, such as %xx codes used in URIs;
character references like &quot; or &#65; in HTML and XML, and so on. These are
very often found in lexical databases, and are often handled incorrectly.

=item * Less-common characters such as ligatures, accents,
non-Latin digits, fractions, hyphen and dashess, quotes, and spaces, presentation variants,
angstrom vs. a-with-ring, etc.

Very many of the NLP systems I've examined fail on quite common cases such as
"hard" spaces, ligatures, curly quotes, and em-dashes.
That seems to me sloppy as well as parochial.

=item * Many kinds of non-word tokens, such as URIs, Twitter hashtags, userids, and jargon
(Twitter has gotten more attention, no doubt to to its overall popularity);,
numbers, dates, times, email addresses, etc.

=item * Contemporary conventions such as emphasis via special puntuations (*word*),
or via repeating letters (aaaarrrrrggggghhhhhh, hahahaha).

=item * Choice of how to divide edge cases such as contractions and possessives
(with and without explicit apostrophes), hyphenated words
(not the same thing as em-dash-separated clauses), etc.

=item * When collecting or measuring vocabulary,
options to filter out unwanted tokens are very useful.
For example, the non-word types already mentioned are important for some purposes, but
not for others. Words already listed in a given dictionary(s) can be discarded. Tokens
in all lower, all upper, title, camel, or other case patterns; numers;
tokens containing special characters, long or short tokens, etc. There are many filtering
options, so you can easily winnow a list down to just what you want.

=back

=head2 Example

  use Tokenizer;
  my $myTok = new Tokenizer("characters");
  $myTok->setOption("Uppercase_Letter", "lower");
  while (my $rec = <>) {
      my @tokens = @{myTok->tokenize($rec)};
      for my $token (@tokens) {
          $counts{$token}++;
      }
  }



=for nobody ###################################################################

=head1 The process

There are several steps to the process of tokenizing, each controlled
by various options:

    * Expand special character codes
    * Fix character-set issues
    * Shorten long repetition sequences
    * Recognize non-word tokens (numbers, date, URIs, emoticons,...)
    * Generate the actual tokenized result.

Option names appear in B<BOLD>, and values in I<ITALIC> below.
The type of value expected is shown in (parentheses): either (boolean), (int),
or (disp), unless otherwise described.


=for nobody ###################################################################

=head2 1: Expand escaped characters

These options all begin with "X_" and all take (boolean) values,
for whether to expand them to a literal character.

=over

=item * B<X_BACKSLASH> -- A lot of cases are covered.

=item * B<X_URI> -- %-escapes as used in URIs.
Not to be confused with the B<T_URI> option for tokenizing (see below).

=item * B<X_ENTITY> -- Covers HTML and XML named entities and
numeric character references (assuming the caller didn't already parse and
expand them).

=back


=for nobody ###################################################################

=head2 2: Normalize the character set

These options are distinguished by being named in Title_Case with underscores
(following the Perl convention for Unicode character class names.
 See L<http://unicode.org/reports/tr44/tr44-4.html#General_Category_Values>.

This all assumes that the data is already Unicode, so be careful of CP1252.

=over

=item * B<Ascii_Only> (boolean) -- a special case.
Discards all non-ASCII characters, and turns control characters (such as
CR, LF, FF, VT, and TAB) to space. If you specify this, you should not specify
other character set normalization options.

=back

All other character set normalization options are of type (disp):

(disp) values that apply to any character category at all:
  "keep"      -- Don't change the characters
  "delete"    -- Delete the characters entirely
  "space"     -- Replace the characters with a space
  "unify"     -- Convert all matches to a single character (see below)

(disp) values only for Number and its subtypes:
  "value"     -- Replace with the value

(disp) values only for Letter and its subtypes:
  "upper"     -- Force to upper-case
  "lower"     -- Force to lower-case
  "strip"     -- Decompose (NFKD) and then strip any diacritics
  "decompose" -- Decompose (NFKD) into component characters

I<Letter> and its subcategories default to C<keep>; all other
character categories default to C<unify> (see below for the
meaning of "unify" for each case).

B<Note>: A character may have multiple decompositions, or may be
undecomposable. The resulting string will also be in Compatibility decomposition
(see L<http://unicode.org/reports/tr15/>) and
Unicode's Canonical Ordering Behavior. Compatibility decomposition combines
stylistic variations such as font, breaking, cursive, circled, width,
rotation, superscript, squared, fractions, I<some> ligatures
(for example ff but not oe), and pairs like angstrong vs. A with ring,
ohm vs omega, long s vs. s.

C<#unify> changes each character of the given class
to one particular ASCII character to represent the class (this is useful for finding
interesting patterns of use):

  Letter                  unifies to "A"
  Cased_Letter            unifies to "A"
  Uppercase_Letter        unifies to "A"
  Lowercase_Letter        unifies to "a"
  Titlecase_Letter        unifies to "Fi"
  Modifier_Letter         unifies to "A"
  Other_Letter            unifies to "A"

  Mark                    unifies to " "
  Nonspacing_Mark         unifies to " "
  Spacing_Mark            unifies to " "
  Enclosing_Mark          unifies to " "

  Number                  unifies to "9"
  Decimal_Number          unifies to "9"
  Letter_Number           unifies to "9"
  Other_Number            unifies to "9"

  Punctuation             unifies to "."
  Connector_Punctuation   unifies to "_"
  Dash_Punctuation        unifies to "-"
  Open_Punctuation        unifies to "("
  Close_Punctuation       unifies to ")"
  Initial_Punctuation     unifies to "`"
  Final_Punctuation       unifies to "'"
  Other_Punctuation       unifies to "*"

  Symbol                  unifies to "#"
  Math_Symbol             unifies to "="
  Currency_Symbol         unifies to "\$"
  Modifier_Symbol         unifies to "#"
  Other_Symbol            unifies to "#"

  Separator               unifies to " "
  Space_Separator         unifies to " "
  Line_Separator          unifies to " "
  Paragraph_Separator     unifies to " "

  Other                   unifies to "?"
  Control                 unifies to "?"
      (includes > 64 characters. For example, U+00A0.
  Format                  unifies to "?"
  Surrogate               unifies to "?"
  Private_Use             unifies to "?"
  Unassigned              unifies to "?"

C<unify> can also be used for the Non-word token options (see below); in that
case, each option has a particular value to which matching I<tokens> unify.

Setting the option for a cover category (such as I<Letter>) is merely shorthand for
setting all its subcategories to that value. Some or all subcategories can
still be reset afterward, but any I<earlier> setting for a subcategory
is discarded when you set its cover category.

To get a list of the category options run C<Tokenizer.pm -list>.

The following character set normalization options can also be used
(but are not Unicode General Categories):

=over

=item * B<Accent> --
These are related to Unicode B<Nonspacing_Mark>,
but that also would include vowel marks, which this doesn't.
I<#decompose> and I<strip> are important value for this option:
the format splits a composed letter+diacritic or similar combination
into its component parts; the latter discards the diacritic instead.
I<#delete> discards the whole accent+letter combination (?).
B<Note>: There is a separate Unicode property called "Diacritic",
but it isn't available here yet.

=item * B<Control_0> -- The C0 control characters.
That is, the usual ones from \x00 to \x1F.
This option only matters if I<Control> is set to C<keep>.

=item * B<Control_1> -- The C1 control characters.
That is, the "upper half" ones from \x80 to \x9F.
B<Note>: These are graphical characters in the common Windows(r) character
set known as "CP1252", but not in Unicode or most other sets.
This option only matters if I<Control> is set to C<keep>.

=item * B<Digit> -- characters 0-9 -- Cf Unicode B<Number>, which is broader.

=item * B<Ligature> characters -- This also includes titlecase and digraph
characters. B<Note>: Some Unicode ligatures, particular in Greek, may also
be involved in accent normalization.
See also L<http://en.wikipedia.org/wiki/Typographic_ligature>
B<(not yet supported)>

=item * B<Fullwidth> --
See L<http://en.wikipedia.org/wiki/Halfwidth_and_fullwidth_forms>
B<(not yet supported)>

=item * B<Math> -- Unicode includes many variants of the entire Latin
alphabet, such as script, sans serif, and others.
These are in the Unicode B<Math> general category.
B<(not yet supported)>

=item * B<Nbsp> -- The non-breaking space character, U+00A0. This
defaults to being changed to a regular space.

=item * B<Soft_Hyphen> -- The soft (optional) hyphen characters,
U+00AD and U+1806. These default to being deleted.

=back


=for nobody ###################################################################

=head2 3: Shorten runs of the same character

These options are all (boolean).

=over

=item * B<N_CHAR> Reduce runs of >= N of the same
word-character in a row, to just N occurrences. This is for things like
"aaaaaaaarrrrrrrrrgggggggghhhhhh". However, it does not yet cover things
like "hahahaha".

=item * B<N_SPACE> Reduce runs of >= N white-space characters
(not necessarily all the same) to just N.

=back



=for nobody ###################################################################

=head2 4: Non-word tokens

This step can tweak various kinds of non-word tokens, such as
numbers, URIs, etc. The options are of type (disp), but the
only meaningful settings are "keep", "delete", "space", and "unify".

=over

=item * B<T_TIME> tokens, such as "6:24 pm".

=item * B<T_DATE> tokens, such as "2012-08-22" or "2012 BCE".
Month names and abbreviations are not yet supported.

=item * B<T_FRACTION> (including Unicode fraction characters if they
were not already normalized).

=item * B<T_NUMBER> tokens, including signed or unsigned integers, reals,
and exponential notation (however, fractions are dealt with separately).
This does not include spelled-out numbers such as "five hundred".
(not yet supported)

=item * B<T_CURRENCY> tokens, consisting of a currency symbol and a number,
such as $1, $29.95, etc.

=item * B<T_EMOTICON> items

=item * B<T_HASHTAG> items as in Twitter (#ibm)

=item * B<T_USER> items as in Twitter (@john)

=item * B<T_EMAIL> addresses

=item * B<T_URI> items (see also the B<X_URI> unescaping option earlier)

=back


=for nobody ###################################################################

=head2 4: Split tokens

The text can be broken into C<words> at each white-space character(s),
at all individual C<characters>, or C<none> at all. The choice depends on the
I<TOKENTYPE> option.

Then leading and trailing punctuation are broken off.
This prevents leaving parentheses, commas, quotes, etc. attached to words.
However, the script is not smart (at least, yet) about special cases such as:

  $12       ~5.2      #1        +12
  5'6"      5!        5%
  U.S.      p.m.
  ).        ."        +/-
  (a)       501(c)(3)
  @user     #topic    ~a        AT&T
  e'tre     D'Avaux   let's     y'all     and/or

This needs some adjustments re. which punctuation is allowed on which
end.  Harder problems include plural genitives: "The three I<dogs'> tails."
and abbreviations versus sentence-ends.

A few special cases are controlled by these ("S_") options, such as
re-mapping contractions and breaking up hyphenated words (by inserting
extra spaces).

=over

=item * B<S_CONTRACTION> can be set to "unify> in order to
expand most English contractions. For example:
won't, ain't, we'll, we'd, we're, we'll, somebody'd,
y'all, let's, gonna, cannot.
Not very useful for non-English text, even like "dell'" or "c'est".
(see also POS/multitagTokens).

=item * B<S_HYPHENATED> break at hyphens, making the hyphen a separate
token. (Doesn't deal with soft hyphens or other B<Format> characters.

=item * B<S_GENITIVE> break "'s" to a separate token. This does not actually
catch all genitives, even in English (and, many "'s" cases in English
can be either genitives or contractions of "is".
B<(not yet supported)>

=back


=for nobody ###################################################################

=head2 6: Filter out unwanted tokens ('words' mode only)

These options are all (boolean) except for B<F_MINLENGTH> and B<F_MAXLENGTH>.
For Boolean filter options, the default is off, which means the tokens
are not discarded.

=over

=item * B<F_MINLENGTH> (int) -- Discard all tokens shorter than this.

=item * B<F_MAXLENGTH> (int) -- Discard all tokens longer than this.

=item * B<F_SPACE> (boolean) -- can be used to delete all white-space items.

=item * Filter by case and special-character pattern
Each of the following (disjoint) categories
can be controlled separately (see also I<--ignoreCase>, I<--Letter>, etc.):

=over

=item * B<F_UPPER> (boolean) -- remove words with only capital or caseless letters

=item * B<F_LOWER> (boolean) -- remove words with only lower case or caseless letters

=item * B<F_TITLE> (boolean) -- remove words with only an initial capital or titlecase
letter, followed by only lower case or caseless letters.

=item * B<F_MIXED> (boolean) -- remove words with at least two capital and/or
titlecase letters, along with any number of lower case or caseless letters.

=item * B<F_ALNUM> (boolean) -- remove words that contain both digits and
letters.

=item * B<F_PUNCT> (boolean) -- remove words that contain both punctuation and
letters. However, hyphens, apostrophes, and periods do no count.

=back

=item * Tokens in any specified B<F_DICT> list. B<F_MINLENGTH> I<4>
(see above) can serve as a passable substitute for a dictionary of
function words.

=back


=head1 Outline of token types (unfinished)

(see also earlier sections)

(is there a useful type for "nested syntax"? dates, times, formulae, phone numbers,
music,

    Numeric
        Int
            Dec, Oct, Bin, Hex, Roman
        Real
            Float, Exp, Frac, pct/pmil
        Ordinal
            1st, #1, first
        Complex
        Matrix
        Math forms, roman and frac unicode, circled,....
        Formula
            SPecial constants: pi, euler, c, angstrom, micro prefix

    Date/time (under numeric? unit?)

    Unit
        Currency
        Dimension, scale
        32F 100C 273.15K

    Punc
        Quote
            Left/right/plain, single/double/angle
        Dash
            em/en/fig/soft?
        Brace
            left/right/shape/balanced
        Grammatical
            period, ellipsis, colon, semi, comma
        Verbal
            &, &c

    Identifier
        URL
        domain name
        email (incl. mailto?)
        hashtag
        @user
        Phone
        PostCode
        element
        substance

    Lexeme
        simplex
            lower, title, mixed, caps, uncased
            abbrev
                single initial?
            mixed-script
            construct
                dimethyltrichloroacetate
                genome (incl. end indicators)
        multiplex
            hyphenated
            acronym
            contraction (vs. possessive)
                gonna, ima, afaik
            idiom
                as far as, so as to,

    Dingbat
        Bullet, arrow
        emoticon, emoji
        sepline

    Mixture
        (>1 of alpha, num, punc)

Oddball cases:
    4x4 1'2" AT&T and/or
    60's
    Ph.D. vs. PhD (treat like soft hyphen?
    > or | for email quoting
    Mg2+ H2O
    gender symbols
    footnote numbers, daggers, etc.
    dominos, cards, dice
    c/o
    +/-
    O'Donnell




=for nobody ###################################################################

=head1 Methods

=over

=item * B<new>(tokenType)

Instantiate the tokenizer, and set it up for the I<tokenTYpe> to be
either B<characters> or B<words>.

=item * B<addOptionsToGetoptLongArg(hashRef,prefix)>

Add the options for this package to I<hashRef>, in the form expected by
Getopt::Long. If I<prefix> is provided, add it to the beginning of each
option name (to avoid name conflicts). All the options for this package
are distinct even ignoring case, so callers may ignore or regard case
for options as desired.

=item * B<setOption>(name,value)

Change the value of the named option.
Option names are case-sensitive (but see previous method).

B<Note>: Setting the option for a Unicode cover category
(such as B<Letter> rather than B<Uppercase_Letter>), is merely shorthand for
setting all its subcategories to that value
(subcategories can still be reset afterward).

=item * B<getOption>(name)

Return the present value of the named option.
Option names are case-sensitive.

=item * B<tokenize>(string)

Break I<string> into tokens according to the settings in effect, and return
a reference to an array of them. B<Note>: This method uses several other
internal methods; they can be invoked separately is desired, but are not
documented fully here; the methods are as shown below ($s is a string to
handle):

    $s = $tkz->expand($s);
    $s = $tkz->normalize($s);
    $s = $tkz->shorten($s);
    $s = $tkz->nonWordTokens($s);
    @tokens = @{$tkz->splitTokens($s)};
    @tokens = @{$tkz->filter(\@tokens)};


=back



=for nobody ###################################################################

=head1 A few examples

Can we expand &#65; to 'A', &#x0000042; to 'B', &lt; to '>'? U+FFFD

But then (I think), (a) is a label. So is [bracket] and {brace}.
http://bit.ly/840284028#xyz or email me at user@example.com.
mailto://user@example.com amounts to the same thing.
And other schemas like https ftp mailto local data doi
or example.com itself,
Emoticons like :) and :( and :P are a pain, even at sentence end :).

Contractions it's good to have but we cannot, 'til we're gonna add 'em.
But we don't get foreign words d'jour; c'est la vie.

CCAGTTGTGTATGTCCACCC-3 8-hydroxydeoxyguanosine 2,3,4-dihydrogen-monoxide

DATETIME
    12:45pm on June 15, 2012, i.e., 2012-06-15. or 12:24 P.M., not noon.
    August/September or Summer of 2018. 03/20/2017  20/03/2017
    What happened in the 20's? aka the '20s or '20's or just 20s. As in, 2012 CE.
    or the 1910's, 1920's, 1930s, 1940's, and so on.

UNITS
    120V 240VAC 12VDC 12mm 14msec 55MPH 80KPH 6'3"
    r=0.151 p<0.01 0.3-mm

NUMERICS
    It's a 1-horse (one-horse) town--with one horse-- right?
    25mm is 1", which is smaller than 5'4". MCMLX.
    12 deg. C is far warmer than 12K, unless that's 1/3 to 1-1/2 of your RAM.
    -3.145000 == 27.3% of 12,001, or -2.4. 3.14E+28; it costs $12.1M or $.99.
    1,234,567 and .1 are also numbers. 1.03-2.01 is a range.
    A 3-fold cord is not easily broken, at density 10ppb
    95th birthdays are nice.
    Sixty-one and a hundred fifty
    cell/mL or about ~20.2
    1.234 +/- 0.001

PERIOD
    Ph.D. Pharm.D. U.S.A.
    Section A.1.12.3

UNDERSCORE

TWIDDLE
    ~22 ~15lpm ~0.1

PARENTHESES
    A(1)
AMPERSAND
    AT&T is a company, as is B&O, and other companies....

SHARP
    #hotTopic A#1 #3

AT-SIGN
    @userids?
    user@example.com

PERCENT
    10% 12.2%
    And unpercent %42 (plus per-mill and per-10mil unicode), like %C8%82?

COLON
    URLs, but also 3:1 ratios.

PLUS
    A+ C++ +12.1E+8 Li+2

CURRENCY
    $12 $12M $12 million $12.40
    cents, and other currency markers

SLASH
    and/or c/o M/F I/O m/s/s N/S left/right dorsal/ventral

BACKSLASH
    And unbackslash \n \r\\\" \x42 \u0043 \U------44?


EMBEDDED LETTERS
    2x4 is a board; 4x4 can also be a car they might drive in M*A*S*H.
    interleukin-17

OTHER
    But C++ and C# are programming languages and A-1 is a steak-sauce.
    He said, "I'm the Dr." "Dr. Who?" Just the Dr., from Gallifrey.

Common hypheated affixes
    non- pre- post- self- high- low- all- over- under- anti- early- late-
    alpha- beta- gamma- mono- bi- tri- co- pro- cross- intra- inter-
    first- second- one- five- single- meta- mid- multi- re- right- left-
    drug- sub- super- time- space- well- poorly- half- quarter- hyper- hypo-

    -positive -negative -specific -based -induced -triggered -dependent -oriented
    -shaped -like -associated -related -tolerant -derived -selective -shaped
    -resistant -sensitive -effective -point -coupled -free -spaced -driven -responsive
    -threatening -focused

    NN-VBD
    12-fold 12-level 12-unit

chemical substance components
    mono di tru tetra penta hexa
    ethano phenyl amino phosph[oa] gluco acetyl adren butyric binz gluta
    hydroxy methyl metha carboxyl trypt propion
    -ase -ergic -azine -idine -ositol -terol -amine -asone -inine -eptin
    -sonide -inine -oate -osine

conditions and such
    -taxis -phobia -itis -osis -cemic -etic -emia -pathic


=for nobody ###################################################################

=head1 Known Bugs and Limitations

=over

Not all options are finished. For example:
I<Ligature, Math, Fullwidth, S_GENITIVE,> etc.
I<T_NUMBER> is disabled for the moment.
Titlecase characters, etc.
Some of this can be done in a pre-pass with:

    iconv -f utf8 -t ascii//TRANSLIT

(disp) values upper, lower, and decompose do not restrict themselves
to just a single category, but affect all if set for any.

Can't distinguish single vs. double quotes while unifying variants.

Can't break words in orthographies that lack spaces (such as many ideographic
scripts).

Abbreviations, acronyms, and other cases with word-final punctuation
are a little wonky: "U.S." loses the final ".".
Acronyms with periods I<and> spaces aren't caught at all.
Acronyms aren't allowed within Names Entity References.

Too generous about expanding contractions (e.g. "Tom's")

W/ testTokenizer defaults, turns B&O into 9/9&O ... into \.\.\. doesn't
separate }. Default unifies URIs, emails, and some (?) numerics.  Doesn't do @userid.
Maybe move Unification out of Tokenizer?

Processing XML/HTML with default options, ends up splitting the SGML delimiters
apart from their constructs. Use C<dropXMLtags> is necessary first.

=back



=for nobody ###################################################################

=head1 Related commands

C<vocab>, C<ngrams>, C<normalizeSpace>, C<SimplifyUnicode>,
C<volsunga>, C<findNERcandidates>,....



=for nobody ###################################################################

=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut
