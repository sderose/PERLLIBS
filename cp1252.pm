#!/usr/bin/perl -w
#
# cp1252.pm: Do decent things with the Windows charset.
# 2011-03-23: Split out of 'vocab' by Steven J. DeRose.
#
use strict;
use charnames ':full';

package cp1252;

our %metadata = (
    'title'        => "cp1252.pm",
    'description'  => "Do decent things with the Windows charset.",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2006~02",
    'modified'     => "2021-11-11",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

cp1252.pm

Various funky char-set manipulations. For the moment, only deals
with the C1 control characters and non-breaking space, d128-160.

Really obsolete; use binmode(":encoding(cp1252)") instead.
Only still used by C<nmi2turk> and C<text2turk>.


=head1 Methods

=over

=item * B<cp1252toEntities(s)>

Convert C1 characters and non-breaking space to HTML entities.

=item * B<cp1252toUnicode(s)>

Convert C1 characters and non-breaking space to literal Unicode characters.

=item * B<cp1252getUnicodeNumber(c)>

=item * B<cp1252getUnicodeName(c)>

=back


=head1 Known Bugs/Limitations


=head1 Related commands

iconv: A *nix utility for converting character encodings.

nonascii: has nice info on char names.


=head1 History

  2011-03-23: Split out of 'vocab' by Steven J. DeRose.
  2021-11-11: New layout.


=head1 To do

  Add conversions for G1 set.
  Add conversions to full Unicode names
  Options to go to numeric entities instead of HTML.
  Add detector (utf8 validity, vs. presence of C1).


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons 
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.


=cut


##############################################################################
# Changes cp1252 control characters to spaces. Should also check higher 
# range.
#
my $c1toEntities = setupC1toEntities();
my $c1toUnicode  = setupC1toUnicode();

sub cp1252toEntities {
    my ($s) = @_;

	my $buf = "";
	for (my $i=0; $i<length($_[0]); $i++) {
		my $c = substr($_[0],$i,1);
		my $o = ord($c);
		if ($o>=0x80 && $o<=0xA0) {
            my $n = $c1toEntities->[$o];
            if ($n eq "-?-") {
                warn "cp1252toEntities: Bad code point $o\n";
                $buf .= sprintf("&#x%x;", $o);
            }
            else {
                $buf .= "&$n;";
            }
        }
		else {
            $buf .= $c;
        }
	}
	return($buf);
} # cp1252toEntities

sub cp1252toUnicode {
    my ($s) = @_;

	my $buf = "";
	for (my $i=0; $i<length($_[0]); $i++) {
		my $c = substr($_[0],$i,1);
		my $o = ord($c);
		if ($o>=0x80 && $o<=0xA0) {
            my $u = $c1toUnicode->[$o];
            $buf .= (defined $u) ? $u : "?";
        }
		else {
            $buf .= $c;
        }
	}
	return($buf);
} # cp1252toUnicode


sub cp1252getUnicodeNumber {
    my ($c) = @_;
    return(ord(cp1252toUnicode($c)));
} # cp1252toUnicodeNumber

sub cp1252getUnicodeName {
    my ($c) = @_;
    return(charnames::viacode(ord(cp1252toUnicode($c))));
} # cp1252getUnicodeName


###############################################################################
# Microsoft "code page 1252" (HTML entity names where handy)
# This array maps from code points to HTML entity names.
#
sub setupC1toEntities {
    my @C1toEntities = (
        "Euro",   "-?-",    "low9",   "Fhook",      # x80-
        "low99",  "hellip", "dagger", "ddag",       # x84-
        "circ",   "permil", "Scaron", "laquo",      # x88-
        "OElig",  "-?-",    "Zcaron", "-?-",        # x8C-
        "-?-",    "lquo",   "rquo",   "llquo",      # x90-
        "rrquo",  "bull",   "ndash",  "mdash",      # x94- 
        "stilde", "trade",  "scaron", "raquo",      # x98-
        "oelig",  "-?-",    "zcaron", "ydiaer",     # x9C-
        "nbsp");
    return(\@C1toEntities);
}

sub setupC1toUnicode {
    my @C1toUnicode = ();
        $C1toUnicode[0x80] = chr(0x20AC);  # EURO SIGN
        # ???
        $C1toUnicode[0x82] = chr(0x201A);  # SINGLE LOW-9 QUOTATION MARK
        $C1toUnicode[0x83] = chr(0x0192);  # LATIN SMALL LETTER F WITH HOOK
        $C1toUnicode[0x84] = chr(0x201E);  # DOUBLE LOW-9 QUOTATION MARK
        $C1toUnicode[0x85] = chr(0x2026);  # HORIZONTAL ELLIPSIS
        $C1toUnicode[0x86] = chr(0x2020);  # DAGGER
        $C1toUnicode[0x87] = chr(0x2021);  # DOUBLE DAGGER
        $C1toUnicode[0x88] = chr(0x02C6);  # MODIFIER LETTER CIRCUMFLEX ACCENT
        $C1toUnicode[0x89] = chr(0x2030);  # PER MILLE SIGN
        $C1toUnicode[0x8A] = chr(0x0160);  # LATIN CAP LETTER S WITH CARON
        $C1toUnicode[0x8B] = chr(0x2039);  # SINGLE LEFT-POINTING ANGLE QUOT
        $C1toUnicode[0x8C] = chr(0x0152);  # LATIN CAP LIGATURE OE
        # ???
        $C1toUnicode[0x8E] = chr(0x017D);  # LATIN CAP LETTER Z WITH CARON
        # ???
        # ???
        $C1toUnicode[0x91] = chr(0x2018);  # LEFT SINGLE QUOTATION MARK
        $C1toUnicode[0x92] = chr(0x2019);  # RIGHT SINGLE QUOTATION MARK
        $C1toUnicode[0x93] = chr(0x201C);  # LEFT DOUBLE QUOTATION MARK
        $C1toUnicode[0x94] = chr(0x201D);  # RIGHT DOUBLE QUOTATION MARK
        $C1toUnicode[0x95] = chr(0x2022);  # BULLET
        $C1toUnicode[0x96] = chr(0x2013);  # EN DASH
        $C1toUnicode[0x97] = chr(0x2014);  # EM DASH
        $C1toUnicode[0x98] = chr(0x02DC);  # SMALL TILDE
        $C1toUnicode[0x99] = chr(0x2122);  # TRADE MARK SIGN
        $C1toUnicode[0x9A] = chr(0x0161);  # LATIN SMALL LETTER S WITH CARON
        $C1toUnicode[0x9B] = chr(0x203A);  # SINGLE RIGHT-POINTING ANGLE QUOT
        $C1toUnicode[0x9C] = chr(0x0153);  # LATIN SMALL LIGATURE OE
        # ???
        $C1toUnicode[0x9E] = chr(0x017E);  # LATIN SMALL LETTER Z WITH CARON
        $C1toUnicode[0x9F] = chr(0x0178);  # LATIN CAP LETTER Y WITH DIAERESIS
        $C1toUnicode[0xA0] = chr(0x00A0);  # NO-BREAK SPACE
    return(\@C1toUnicode);
}

sub setupUnicodetoEntities {
    die "setupUnicodetoEntities not yet supported.\n";
}

1;
