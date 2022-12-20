#!/usr/bin/env perl -w
#
# SimplifyUnicode.pm: Remove some Unicode complexities.
# 2010-11-19ff: Written by Steven J. DeRose.
#
use strict;
use Getopt::Long;
use Unicode::Normalize;
use Unicode::Normalize 'decompose';

our %metadata = (
    'title'        => "SimplifyUnicode.pm",
    'description'  => "Remove some Unicode complexities (no longer maintained).",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2010-11-19ff",
    'modified'     => "2021-11-11",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};

=pod

=head1 Usage

Maps many classes of Unicode characters to more basic ones.

Example:
  use SimplifyUnicode;
  my $su = new SimplifyUnicode();
  $su->setOptions("dashes", 1);
  $myString = $su->simplify($myString);


=head1 Methods

=head2 new(name, optionsRef?)

Create a new simplifier. You can set exactly what gets simplified using
the I<setOption> method described below, or by passing a reference to
a hash of options to set as I<optionsRef>.

=head2 setOption(name, value)

Use this method to configure just what kinds of characters will be
normalized:

=over

=item * B<compatibility> Do Unicode compatibility decomposition.

=item * B<accent>

Turns accents and other diacritics to some form:
decomposed, composed, deleted, strip, space, keep.

=item * B<dash>

Turns em dash, en dash, hyphen, etc. to hyphen.

=item * B<ligatureDomain> Whether I<ligatures> does only the basics, or all.

=item * B<ligature>

Turn ligatures to some form:
decomposed, composed, deleted, space, keep.

=item * B<math>

Normalize alternate math Latin alphabets to ASCII.

=item * B<number>

Normalize alternate forms of numbers to ASCII.

=item * B<qBack>

Normalizes backquote to apostrophe.

=item * B<qInitial>

Turns many kinds of open quotes to backquote.

=item * B<qFinal>

Turns many kinds of close quotes to apostrophe.

=item * B<quote>

Turns many kinds of quotes to apostrophe.

=item * B<space>

Normalize various whitespace chars to ASCII space.

=back

=head2 string = simplify(string)

Simplifies the Unicode string according to the current configuration options.


=head1 Related commands

C<iconv>

C<Tokenizer.pm> -- Has many similar normalization featurs, integrated into
a fairly generic tokenizer.

Might be nice to have a script that checked the scripts in use, and added
'<span xml:lang="...">' around block of text in various languages.
Or at least one that screams when it finds characters in the wrong xml:lang
context.


=head1 Known bugs and limitations

Can't map emdash to double hyphen and/or soft-hyphen to nil.

Doesn't know anything about various parentheses, brackets, etc.


=head1 History

  2010-11-19ff: Written by Steven J. DeRose.
Mostly pulled from domExtensions, via normalizeUnicode.
  2010-12-01 sjd: Make into Perl Module. Add uriEscapes. Clean up.
  2012-01-19 sjd: Debug. Fix setOption() to sync w/ Python version.
  2012-05-22 sjd: Drop entities and uriEscapes in favor of sjdUtils.
Simplify option handling.
  2012-08-31 sjd: Add 'compatibility', start changing to use UCD, etc.
Use [\p{Initial_Punctuation}\p{Final_Punctuation}'"`]
  2013-09-09: Allow setting options via hash on constructor.
  2021-11-11: New layout.

=head1 To do

  Redo ligatureDomain as ligatureAll or something.
  Precompile changes for ligatures, so one fancy change not many.
  What about generating ligatures, dashes, quotes, spaces?
  Pull in code from Tokenizer.pm.
  *soft* hyphens special, emdash to double hyphens
  Sync Unicode-name-checking with Python version
  Option to fix CP1252 stuff, or at least warn???
  Integrate into findKeyWords, normalizeXML, vocab, tokenizer, etc.


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut


package SimplifyUnicode;


###############################################################################
#
sub new {
    my ($class, $optionHash) = @_;
    my $self = {
        version       => "2013-09-09",

        options       => {
            compatibility  => "0",
            accent         => "keep",
            dash           => 0,
            ligatureDomain => "all",
            ligature       => "keep",
            math           => 0,
            number         => 0,
            qBack          => 0,
            qInitial       => 0,
            qFinal         => 0,
            quote          => 0,
            space          => 0,
        },

        # internal data
        ligatureChars      => setupLigatures(),
        mathStarts         => setupMaths(),       # HashRefs
        lig2seqBasic       => undef,
        seq2ligBasic       => undef,
        lig2seq            => undef,
        seq2lig            => undef,
    };
    bless $self, $class;
    if (ref($optionHash) eq "HASH") {
        for my $o (keys(%{$optionHash})) {
            $self->setOption($o, $optionHash->{$o});
        }
    }
    return($self);
}


###############################################################################
# Apply all the selected simplifications
#
sub simplify {
    my ($self, $rec) = @_;
    #if ($self->{entities}) {
    #    $rec = $self->handle_Entities($rec);
    #}
    #if ($self->{uriEscapes}) {
    #    $rec = $self->handle_UriEscapes($rec);
    #}
    if ($self->{options}->{compatibility} ne "keep") {
        $rec = decompose($rec, 1);
    }

    if ($self->{options}->{accent} ne "keep") {
        $rec = $self->handle_Diacritics($rec);
    }
    if ($self->{options}->{ligature} ne "keep") {
        $rec = $self->handle_Ligatures($rec);
    }
    if ($self->{options}->{math} ne "keep") {
        $rec = $self->handle_Maths($rec);
    }
    if ($self->{options}->{dash}) {
        $rec =~ s/\p{Pd}/-/g;
    }
    if ($self->{options}->{quote}) {
        $rec =~ s/\p{Pi}/`/g;
        $rec =~ s/\p{Pf}/'/g;
        $rec =~ s/`"/'/g;
    }
    else {
        if ($self->{options}->{qInitial}) {
            $rec =~ s/\p{Pi}/`/g;
        }
        if ($self->{options}->{qFinal}) {
            $rec =~ s/\p{Pf}/'/g;
        }
        if ($self->{options}->{qBack}) {
            $rec =~ s/`/'/g;
        }
    }
    if ($self->{options}->{space}) {
        $rec =~ s/\pZ/ /g;
    }
    if ($self->{options}->{number}) {
        die "numbers not yet supported.\n";
    }
    return($rec);
}


###############################################################################
#
sub setOption {
    my ($self, $oname, $value) = @_;

    # Check whether option name is actually valid.
    if (!defined $self->{options}->{$oname}) {
        warn("simplifyUicode.setOption: Unknown optoin '$oname'.\n");
        return(undef);
    }
    if (!$oname || !$value) {
        warn("Option value not passed to simplifyUicode.setOption.\n");
        return(undef);
    }
    $self->{options}->{$oname} = $value;

    # Check value for the non-Boolean ones
    ($self->{options}->{accent} =~
     m/^(composed|keep|decomposed|strip|space|delete)$/) ||
     warn "Bad value for simplifyUicode.setOption($oname, $value).\n";
    ($self->{options}->{ligatures} =~
     m/^(composed|keep|decomposed|strip|space|delete)$/) ||
     warn "Bad value for simplifyUicode.setOption($oname, $value).\n";
} # setOption


sub getOption {
    my ($self, $oname) = @_;
    return($self->{options}->{$oname});
}


###############################################################################
#
sub normalize_Space { # Normalize as for XML whitespace
    my ($self, $s) = @_;
    $s =~ s/\s\s+/ /g;
    $s =~ s/^\s+//g;
    $s =~ s/\s+$//g;
    return($s);
}

# Implement changes that have multiple options.
#
sub handle_Diacritics {
    my ($self, $rec) = @_;
    my $aopt = $self->{options}->{accent};
    if ($aopt eq "composed") {
        warn "unsupported -accent handling '$aopt'\n";
    }
    elsif ($aopt eq "decomposed") {
        $rec = Unicode::NFKD($rec);
    }
    elsif ($aopt eq "strip" || $aopt eq "translit") {
        $rec = Unicode::NFKD($rec);
        $rec =~ s/\pM+//g;
    }

    elsif ($aopt eq "space") {
        warn "unsupported -accent handling '$aopt'\n";
    }
    elsif ($aopt eq "delete") {
        warn "unsupported -accent handling '$aopt'\n";
    }
    else {
        # keep
    }
    return($rec);
}

# NOTE: Unicode compatibility decomposition does break up some ligs (ae,...)
#
sub handle_Ligatures {
    my ($self, $rec) = @_;
    my $s = "";
    my $s2lRef = $self->{seq2lig};
    my %s2l = %$s2lRef;

    my $lopt = $self->{options}->{ligatures};
    if ($lopt eq "space") {
        for my $lig (keys %s2l) {
            $rec =~ s/$lig/ /g;
        }
    }
    elsif ($lopt eq "delete") {
        for my $lig (keys %s2l) {
            $rec =~ s/$lig//g;
        }
    }
    elsif ($lopt eq "composed") {
        for my $lig (keys %s2l) {
            $rec =~ s/$lig/$s2l{$lig}/g;
        }
        warn "unsupported -ligatures handling '$lopt'\n";
    }
    elsif ($lopt eq "decomposed") {
        for my $lig (keys %s2l) {
            $rec =~ s/$lig/$s2l{$lig}/g;
        }
        warn "unsupported -ligatures handling '$lopt'\n";
    }
    else {
        # keep
    }
    return($rec);
}

# Return basic ASCII letter if we got a math letter; else undef.
#
sub handle_Maths {
    my ($self, $rec) = @_;
    my $buf = "";
    for (my $i=0; $i<lenght($rec); $i++) {
        my $c = substr($rec, $i, 1);
        if (my $letter = math2letter(ord($c))) {
            $buf .= $letter;
        }
        else {
            $buf .= $c;
        }
    }
    return($buf);
}

sub math2letter {
    my ($self, $n) = @_;
    my $mathStartsRef = $self->{mathStarts};
    my %ms = %$mathStartsRef;
    for my $mathRange (keys %ms) {
        my $diff = $n - $mathRange;
        next unless ($n>=0 && $n<26);
        my $type = $ms{$mathRange};
        if ($type eq "UPPER") {
            return(substr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", $diff, 1));
        }
        elsif ($type eq "LOWER") {
            return(substr("abcdefghijklmnopqrstuvwxyz", $diff, 1));
        }
        else {
            warn "Bad math alphabet type '$type'.\n";
        }
    }
    return(undef);
}


###############################################################################
# Non-Latin ligatures are not here yet, because there are *lots* of them.
#
sub setupLigatures {
    my %seq2ligBasic = (
        "ff"    => chr(0xFB00),
        "ff"    => chr(0xFB01),
        "fl"    => chr(0xFB02),
        "ffi"   => chr(0xFB03),
        "ffl"   => chr(0xFB04),
        );

    my %seq2lig = (
        "AE"    => chr(0x00C6), #	= latin capital ligature ae (1.0)
        "ae"    => chr(0x00E6), #	= latin small ligature ae (1.0)
        "IJ"    => chr(0x0132), #	LATIN CAPITAL LIGATURE IJ
        "ij"    => chr(0x0133), #	LATIN SMALL LIGATURE IJ
        "OE"    => chr(0x0152), #	LATIN CAPITAL LIGATURE OE
        "oe"    => chr(0x0153), #	LATIN SMALL LIGATURE OE
        "st"    => chr(0xFB06), #   LATIN SMALL LIGATURE ST

      # (chr(0x017F)."t") => chr(0xFB05), # long-s t
      # (chr(0x017F)."s") => chr(0x00DF), # in origin ligature of long s, s
        # there's also a combining long s at 1de5 and some accented one.
        );

    my %lig2seqBasic = ();
    my %lig2seq = ();

    # Add the basic to the main map
    for my $seq (keys %seq2ligBasic) {
        $seq2lig{$seq} = $seq2ligBasic{$seq};
    }

    # Make both reverse maps
    for my $seq (keys %seq2lig) {
        my $lig = $seq2lig{$seq};
        $lig2seq{$lig} = $seq;
        if (defined $seq2ligBasic{$seq}) {
            $lig2seqBasic{$lig} = $seq;
        }
    }

    my $foo = qq {
0587	ARMENIAN SMALL LIGATURE ECH YIWN
FB13	ARMENIAN SMALL LIGATURE MEN NOW
FB14	ARMENIAN SMALL LIGATURE MEN ECH
FB15	ARMENIAN SMALL LIGATURE MEN INI
FB16	ARMENIAN SMALL LIGATURE VEW NOW
FB17	ARMENIAN SMALL LIGATURE MEN XEH

04A4	CYRILLIC CAPITAL LIGATURE EN GHE
04B4	CYRILLIC CAPITAL LIGATURE TE TSE (Abkhasian)
04D4	CYRILLIC CAPITAL LIGATURE A IE

FB1F	HEBREW LIGATURE YIDDISH YOD YOD PATAH
FB4F	HEBREW LIGATURE ALEF LAMED
05F0	HEBREW LIGATURE YIDDISH DOUBLE VAV
05F1	HEBREW LIGATURE YIDDISH VAV YOD
05F2	HEBREW LIGATURE YIDDISH DOUBLE YOD
    };
}

# Maths are handled differently, because they generally include an entire
# Latin alphabet (lower and or upper case) for each variant; no use in
# listing 26 times as much data....
#
sub setupMaths {
    my %mathAlphabetStarts = (
         0x1d400 => "UPPER",  # mathematical bold
         0x1d41A => "LOWER",
         0x1d434 => "UPPER",  # mathematical italic
         0x1d434 => "LOWER",
         0x1d468 => "UPPER",  # mathematical bold italic
         0x1d482 => "LOWER",
         0x1d49C => "UPPER",  # mathematical script
         0x1d4B6 => "LOWER",
         0x1d4D0 => "UPPER",  # mathematical bold script
         0x1d4EA => "LOWER",
         0x1d504 => "UPPER",  # mathematical fraktur
         0x1d51E => "LOWER",
         0x1d538 => "UPPER",  # mathematical double-struck
         0x1d552 => "LOWER",
         0x1d56C => "UPPER",  # mathematical bold fraktur
         0x1d586 => "LOWER",
         0x1d5A0 => "UPPER",  # mathematical sans-serif
         0x1d58A => "LOWER",
         0x1d5D4 => "UPPER",  # mathematical sans-serif bold
         0x1d5EE => "LOWER",
         0x1d608 => "UPPER",  # mathematical sans-serif italic
         0x1d622 => "LOWER",
         0x1d63C => "UPPER",  # mathematical sans-serif bold italic
         0x1d656 => "LOWER",
         0x0249c => "LOWER",  # parenthesized lower (no upper!)
         0x024b6 => "UPPER",  # circled upper
         0x024d0 => "LOWER",  # circled lower
         0x1d670 => "UPPER",  # mathematical monospace
         0x1d68a => "LOWER",
        );
    # (couple extras at 1d6a4: dotless i, j)
    # greek upper+lower: 1d6a8, 1d6e2, etc.
    return(\%mathAlphabetStarts);
}

if (!caller) {
    system "perldoc $0";
}
