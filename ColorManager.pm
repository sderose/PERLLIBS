#!/usr/bin/perl -w
#
# ColorManager: Unified handling of ANSI color.
#
use strict;

package ColorManager;

our %metadata = (
    'title'        => "ColorManager.pm",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2011-03-25",
    'modified'     => "2020-02-18",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

This Perl package (a Python version is also available)
provides easier access to ANSI terminal colors. The 8 basic
colors work for foreground and background in nearly all terminal programs.
This package also supports a variety of effects such as bold, underline,
blink, italic, and so on, but exactly which ones work varies quite a bit
from one terminal program to another.

To display a string in bold red type on a white background, do:

    use ColorManager;
    print ColorManager::colorize('red/white/bold', "a string");

You can also request the exact escape sequence needed to get to a given
color (or back to 'default'), like:

    getColorString("blue")

As shown, the returns the appropriate string with a literal ESC (U+0001B) as
the first character. You can also get strings with "\\e" or other forms,
since you might want those to paste into C<bash> scripts, etc.

To install this and make
sure Perl can find it via the C<@INC> directory-list, add the path to
environment variable C<PERL5LIB> --
see L<here|"http://stackoverflow.com/questions/2526804">.

B<Note>: If you're using this via C<sjdUtils.pm>,
then unless you call I<setColors(1)> and I<setVerbose(n)> to enable it,
you might not get the output you want.

If run directly (rather than used as a library), a small self-test happens,
or you can show a particular color with I<--color colorName> and/or I<--showAll>.


=head2 Color Names

The color names available are described in L<https://github.com/sderose/Color/colorNames.md>,
which supercedes anything in specific scripts (they I<should> match).

For example, "green" specifies green foreground (type),
while "red/blue/bold" specifies bold red on a blue background


=head2 General color methods

=over

=item * B<setColors>I<(b)>

Set up color handling; if I<b> is false, disables color.
Returns a reference to a hash with entries for the basic foreground colors
and "off", with the values being the escape-sequences for them.
Also sets up default handling for messages of types "v", "e", "h", and "x"
(see I<defineMsgType>()).

=item * B<getColorString>I<(name)>

Return the ANSI escape sequence to obtain the named color.
If the color name is not known, C<undef> is returned.

B<Note>: If I<setColors>() has not already been called to set up the ANSI
sequences for the various L<Color Name>s, then calling I<getColorString>() will
call it first.

=item * B<getNearestColorNameFromRGB>(r, g, b, bg)

Return the name of the nearest ANSI terminal color to the given RGB value
(this assume the default color settings for your terminal). If I<bg> is
on, return the background L<Color Name> instead of foreground.


=item * B<addColorName>I<(newName, oldName)>

Define a synonym for an existing L<Color Name>. OBSOLETE.

=item * B<getColorStrings>I<( )>

Synonym for I<getColorHash>I<( )>. OBSOLETE.

=item * B<getColorHash>I<( )>

Return a reference to a hash that maps L<Color Name> (see above) to
ANSI terminal escape sequences. OBSOLETE.

=back

The last few are obsolete because I switched from making a buge list of all
possible color combinations at setup time, in favor of parsing names and
assembling escape strings on demand. So there isn't an actual hash of
known color names around.

=over

=item * I<colorize(colorName, message, endAs)>

If color is enabled, then surround I<message> with ANSI color escapes for
the specified named color. If I<endAs> is specified, it is used as a
L<Color Name> to switch to at the end of the I<message> (instead of "off").

=item * B<colorize>I<(colorName, message)>

Return the string I<message>, but with the escapes to put it in the specified
I<colorName>. If I<colorName> is unknown, I<message> is returned unchanged.
If the last character of I<message> is a newline, then the color will be
turned off I<before> rather than after the newline itself, so Perl won't
complain if you pass the result to C<warn>.

The list of supported colors, effects, and combinations is in section
L<Colors|"Colors"> (above).

B<Note>: The ANSI escape sequence to switch to a given color, is
available via C<sjdUtils::getColorString(name)>.

=item * B<colorizeXmlTags>I<(s, defaultColorName, tagMap?)>

Apply the ANSI terminal escape for I<colorName>
to XML tags (not text content) in I<s>.

I<tagMap> is an optional reference to a hash that maps XML element type names
to L<Color Name>s. If supplied, tags for the listed element types
get the corresponding colors ("default" is ok);
unlisted element types get the I<defaultColorName>.

=item * B<colorizeXmlContent>I<(colorName)>

Apply the ANSI terminal escape for I<colorName>
to XML text content (not markup) in I<s>.

=item * B<uncolorize>I<(message)>

Remove any ANSI terminal color escapes from I<message>.

=item * B<uncoloredLen>I<(s)>

Return the length of I<s>, but ignoring any ANSI terminal color strings.
This is just shorthand for C<len(uncolorize(s))>.

=back


=head1 Command-line options

=over

=item * B<--color> I<colorName>

=item * B<--effects>

=item * B<--showAll>

Return the length of I<s>, but ignoring any ANSI terminal color strings.
This is just shorthand for C<len(uncolorize(s))>.

=back


=head1 Known bugs and limitations


=head1 Related commands

C<colorstring> -- fancier options for colorizing.

C<hilite> -- applies colors to regex matches.

C<showInvisibles> -- pretty-print control and non-ASCII chars.

C<colorConvert.py> -- convert string representatins of colors (RGB, etc.).

C<uncolorize> -- remove ANSI color escape from STDIN.<


=head1 History

=over

=item * Began as part of sjdUtils.

=item * 2011-03-25: Pulled out from various scripts.

=item * 2011-05-12: Use defaultColor in hWarn().

=item * 2016-07-21: Logically separate ColorManager package.
Sync color w/ python, logging....

=item * 2016-10-25: Physically separate ColorManager package.

=item * 2019-11-16: Improve driver. strict.

=item * 2020-02-18 Clean up. Sync color syntax with doc. Fix --color demo.

=back


=head1 To do

=over

=item * Sync ColorManager API with Python version.

=item * Get rid of rest of refs to %colorStrings. Maybe create escapes on the
fly from tokens rather than keeping a big list at all.

=item * Remove or finish 256-color stuff.

=item * Finish different color-sets for dark vs. light bg.

=back


=head1 Rights

Copyright 2011 by Steven J. DeRose. This work is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0>.

For the most recent version, see L<here|"http://www.derose.net/steve/utilities/"> or
L<https://github.com/sderose>.

=cut

###############################################################################
# Color management in general
#
# ANSI terminal-control codes (+30 foreground, +40 background)
#
my $verbose = 0;
my $ENABLED = 1;

my $newColorMethod = 1;

our %colorNumbers = (
    "black"   => 0,
    "red"     => 1,
    "green"   => 2,
    "yellow"  => 3,
    "blue"    => 4,
    "magenta" => 5,
    "cyan"    => 6,
    "white"   => 7,
    "default" => 9,
    "off"     => 9,
    );
our %effectNumbers = (
    "bold"       =>  1,  # off = 22 (eh???)
    "faint"      =>  2,
    "italic"     =>  3,
    "ul"         =>  4,  # off = 24. aka underscore, underline
    "blink"      =>  5,  # off = 25. see below
    "fblink"     =>  6,  # see below
    "inverse"    =>  7,  # off = 27. aka reverse
    "concealed"  =>  8,
    "strike"     =>  9,  # aka strikethru, strikethrough
    );
our %effectOffNumbers = (
    "bold"       =>  22,
    "faint"      =>  20, ###
    "italic"     =>  20, ###
    "ul"         =>  24,
    "blink"      =>  25,
    "fblink"     =>  20, ###
    "inverse"    =>  27,
    "concealed"  =>  20, ###
    "strike"     =>  20, ###
    );

# Be nice to people with blink sensitivities.
if (defined $ENV{'NOBLINK'}) {
    delete $effectNumbers{'blink'};
    delete $effectNumbers{'fblink'};
}
my %offNumbers = (
    "default"    =>  0,
    "off"        =>  0,
    );

my %colorStrings = ();


# If parameter $flag is true, even clear the most basic/plain/foreground colors.
#
sub setColors {
    my ($flag) = @_;
    if (!defined $flag) { $flag = 0; }
    $ENABLED = $flag;
    #warn("ColorManager::setColors: ENABLED set to $ENABLED.\n");

    #if (scalar keys %colorStrings > 0) { return; }

    if (!$newColorMethod) {
        fillColorHash(\%colorStrings);
    }
    return;
} # setColors


sub fillColorHash {
    my ($theHash) = @_;

    my %basics = (
        "black"   => "",
        "red"     => "",
        "green"   => "",
        "yellow"  => "",
        "blue"    => "",
        "magenta" => "",
        "cyan"    => "",
        "white"   => "",
        "off"     => "",
    );
    $basics{"off"} = "\e[0m";

    for my $c (keys %offNumbers) {
        $theHash->{$c} = "\e[0m";
    }

    my $eb = "\e[";
    my $fmt2 = "%s%d;%dm";

    for my $e (keys %effectNumbers) {
        my $en = $effectNumbers{$e};
        $theHash->{"$e"}  = "\e[" . $en . "m";
        $theHash->{"!$e"} = "\e[" . (20+$en) . "m";
    }

    for my $c (keys %colorNumbers) {
        my $cn = $colorNumbers{$c};
        $basics{$c}            =
        $theHash->{$c}      = "\e[" . (30+$cn) . "m";
        $theHash->{"/$c"}   = "\e[" . (40+$cn) . "m";

        for my $e (keys %effectNumbers) {    # fgcolor + effect
            my $en = $effectNumbers{$e};
            $theHash->{"$e/$c"}   = sprintf($fmt2, $eb,$en,30+$cn);
            $theHash->{"$e//$c"}  = sprintf($fmt2, $eb,$en,40+$cn);
            $theHash->{"!$e/$c"}  = sprintf($fmt2, $eb,20+$en,30+$cn);
            $theHash->{"!$e//$c"} = sprintf($fmt2, $eb,20+$en,40+$cn);
        }

        for my $c2 (keys %colorNumbers) {    # fgcolor + bgcolor
            my $c2n = $colorNumbers{$c2};
            $theHash->{"$c/$c2"} =
                "\e[" . (30+$cn) . ";" . (40+$c2n) . "m";
            for my $e (keys %effectNumbers) {    # fgcolor + effect
                my $en = $effectNumbers{$e};
                $theHash->{"$e/$c/$c2"} =
                    "\e[" . $en . ";" . (30+$cn) . ";" . (40+$c2n) . "m";
            }
        }
    } # for $c
} # fillColorHash

sub isColorName {
    my ($name) = @_;
    if (!$newColorMethod) {
        return((defined $colorStrings{$name}) ? 1:0);
    }
    else {
        return(getColorString($name) ne "");
    }
}

sub getColorString {
    my ($name, $theEscape) = @_;
    if (!defined $theEscape) {
        $theEscape = "\e";
    }
    #warn "ESC is " . ord($theEscape) . "\n";
    my $s = "";
    if ($name eq "off" || $name eq "default") {
        return $theEscape . "[0m";
    }

    if (!$newColorMethod) {            # From big static table
        my $cstr = $theEscape . '[' . $colorStrings{$name} . 'm';
        print("cstr is ###" . sjdUtils::showInvisibles($cstr) . "###\n");
        return $cstr;
    }

    # Parse on the fly
    my @tokens = split(/\s*\/\s*/, $name);
    #($verbose) && warn "Color names tokens from '$name': [ '" . join("', '", @tokens) . "' ]\n";

    # Sort out which token is which (this allows flexible order, though that's
    # not specified by colorName.pod). It also allows extra slashes.
    my $fg = my $bg = my $eff = "";
    my $neg = 0;
    for my $token (@tokens) {
        my $neg = (substr($token,0,1) eq '!') ? 1:0; # Use 20 to negate effects
        if ($neg) { $token = substr($token,1); }
        if ($token eq "") { next; }
        if (defined $colorNumbers{$token}) {
            if ($fg eq "") { $fg = $token; }
            elsif ($bg eq "") { $bg = $token; }
            else { warn("Too many color tokens in '$name'.\n"); }
        }
        elsif (defined $effectNumbers{$token}) {
            if ($eff eq "") { $eff = $token; }
            else { warn("Too many effects tokens in '$name'.\n"); }
        }
        else {
            warn("Bad token '$token' in color name '$name'.\n");
        }
    } # for $token

    # Now construct the right escape string
    my $theCode = "[";
    if ($fg) { $theCode .= (30 + $colorNumbers{$fg}) . ';'; }
    if ($bg) { $theCode .= (40 + $colorNumbers{$bg}) . ';'; }
    if ($eff) {
        if ($neg) { $theCode .= $effectNumbers{$eff} . ';'; }
        else { $theCode .= $effectNumbers{$eff} . ';'; }
    }
    if (substr($theCode, -1) eq ';') { chop $theCode; }
    $theCode .= 'm';
    #($verbose) && print("Got '$name' --> ESC + '$theCode': word \e$s WORD \e[0m word.\n");
    #($verbose) && print("word \e[31m word \e[0m word\n");
    return $theEscape . $theCode;
} # getColorString

sub getColorHash {
    my ($doEffect) = @_;
    if (!$doEffect) { $doEffect = 0; }
    if (!$newColorMethod) {
        if (scalar keys %colorStrings) {
            setColors(1);
        }
        return(\%colorStrings);
    }
    else {
        my %tempHash = ();
        for my $fg (keys %colorNumbers) {
            if ($fg eq "off") { next; }
            if ($fg eq "default") { $fg = ""; }
            $tempHash{$fg} = getColorString($fg);
            $tempHash{'/'.$fg} = getColorString('/'.$fg);
            for my $bg (keys %colorNumbers) {
                if ($bg eq "off") { $bg = ""; }
                if ($bg eq "default") { next; }
                $tempHash{$fg."/".$bg} = getColorString($fg."/".$bg);
                if ($doEffect) {
                    for my $e (keys %effectNumbers) {
                        my $cname = $e."/".$fg."/".$bg;
                        $tempHash{$cname} = getColorString($cname);
                    }
                }
            }
        }
        return(\%tempHash);
    }
}

sub dumpColors {
    warn("\nDumping color defs:\n");
    my $foo = getColorHash();
    for my $k (sort keys %$foo) {
        warn("    " . colorize($k, $k) . ".\n");
    }
}

sub addColorName {
    my ($newName, $oldName) = @_;
    if (!$newColorMethod) {
        $colorStrings{$newName} = $colorStrings{$oldName};
    }
    else {
        warn("addColorName no longer supported.");
    }
}

sub colorize {
    my ($colorName, $msg, $endAs) = @_;
    if (!$ENABLED) {
        return('*' . $msg . '*');
    }
    if (!$endAs) { $endAs = "off"; }
    my $cs1 = getColorString($colorName);
    my $cs2 = getColorString($endAs);
    if (!$cs1 || !$cs2) { return('*' . $msg . '*');
    }
    return($cs1 . $msg . $cs2);
}

# Remove any ANSI terminal color escapes from a string.
#
my $colorRegex = qr/\x1b\[\d+(;\d+)*m/;
#
sub uncolorize {
    my ($s) = @_;
    $s =~ s^$colorRegex^^g;
    if (index($s, chr(27)) >= 0) {
        warn("uncolorize: left some escape(s) in $s.");
    }
    return $s;
}

sub uncoloredLen {
    my ($s) = @_;
    return leng(ColorManager::uncolorize($s));
}


###############################################################################
# Support for xterm256 colors (unfinished).
# Usual convention is base colors, a 6-level RGB cube, and a grayscale.
#
sub setColorsXterm256 {
    for (my $i=0; $i<256; $i++) {
        $colorStrings{"fg_$i"} = "\e[38;5;$i"."m";
        $colorStrings{"/$i"} = "\e[48;5;$i"."m";
    }

    # Load X colors
    if (!open(XC, "</usr/share/X11/rgb.txt")) {
        return(0);
    }
    while (my $rec = <XC>) {
        chomp $rec;
        $rec =~ m/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.*)\s*$/;
        ($4) || next;
        my ($r, $g, $b, $name) = ($1, $2, $3, $4);
        my $nearest = getNearestColorNameFromRGB($r, $g, $b, 0);
        $colorStrings{"fg_$name"} = $colorStrings{$nearest};
        $nearest = getNearestColorNameFromRGB($r, $g, $b, 1);
        $colorStrings{"/$name"} = $colorStrings{$nearest};
    }
    close(XC);
}

sub getNearestColorNameFromRGB {
    my ($r, $g, $b, $bg) = @_;
    $r = oct($r) if $r =~ m/^0/;
    $g = oct($g) if $g =~ m/^0/;
    $b = oct($b) if $b =~ m/^0/;

    # main color space (not basic 16 or greys)
    $r = roundColorLevel($r);
    $g = roundColorLevel($g);
    $b = roundColorLevel($b);
    my $cnum = $r*36 + $g*6 + $b + 16;

    return(($bg) ? "/$cnum" : "fg_$cnum");
}

sub roundColorLevel {
    my ($n) = @_;
    my $nearest = 0;
    my @levels = (55, 95, 135, 175, 215, 255);
    for (my $lnum=1; $lnum<6; $lnum++) {
        if (abs($levels[$lnum]-$n) < abs($levels[$nearest]-$n)) {
            $nearest = $lnum;
        }
    }
    return($nearest);
}

# End package ColorManager


###############################################################################
# Tiny self-test
#
if (!caller) {
    use Getopt::Long;

    my $colorToShow    = '';
    my $effects        = 0;
    my $quiet          = 0;
    my $showAll        = 0;

    Getopt::Long::Configure ("ignore_case");
    my $result = GetOptions(
        "color=s"                 => \$colorToShow,
        "effects!"                => \$effects,
        "showAll!"                => \$showAll,
        "h|help"                  => sub { system "perldoc $0"; exit; },
        "q!"                      => \$quiet,
        "v+"                      => \$verbose,
        "version"                 => sub {
            die "Version of $VERSION_DATE, by Steven J. DeRose.\n";
        }
        );

    ($result) || die "Bad options.\n";

    print("\nTesting ColorManager.pm...\n");
    setColors(1);

    my @toShow = ();
    if ($colorToShow) {
        warn (sprintf("Sample of '%s': ## %s ##\n",
            $colorToShow, colorize($colorToShow, "Some text")));
        exit;
    }

    for my $b (@toShow) {
        my $name1 = $b;
        my $name2 = "white/$b";
        my $name3 = "$b/bold";
        my $name4 = "$b/white";
        warn (sprintf("## %s ## %s ## %s ## %s ##\n",
            colorize($name1, sprintf("%-14s", $name1)),
            colorize($name2, sprintf("%-14s", $name2)),
            colorize($name3, sprintf("%-14s", $name3)),
            colorize($name4, sprintf("%-14s", $name4))
        ));
    }

    if ($effects) {
        for my $b (sort keys %effectNumbers) {
            my $name1 = "$b/white/red";
            warn (sprintf("\nEffect %-12s  ## %s ##\n", $b,
            colorize($name1, sprintf("%-14s", $name1))));
        }
    }

    if ($showAll) { dumpColors(); }
}
1;
