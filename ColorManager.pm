#!/usr/bin/env perl -w
#
# ColorManager: Unified handling of ANSI terminal color.
#
use strict;

package ColorManager;

our %metadata = (
    'title'        => "ColorManager.pm",
    'description'  => "Unified handling of ANSI terminal color.",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5 (Python version also available)",
    'created'      => "2011-03-25",
    'modified'     => "2022-12-20",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};
my $me = "ColorManager.pm";

=pod

=head1 Usage

This Perl package provides easier access to ANSI terminal colors. The 8 basic
colors work for foreground and background in nearly all terminal programs.
This package also supports effects such as bold, underline,
blink, italic, and so on, but exactly which ones work varies quite a bit
from one terminal program to another.

(a Python version of this package is also available)

=head2 Usage from code

To display a string in bold red type on a white background:

    use ColorManager;
    print ColorManager::colorize('red/white/bold', "a string");

To generate the literal escape sequence needed to get to a given
color (color name "default" gets back to the terminal's default colors):

    my $escapeSequence = ColorManager::getColorString("blue");

This returns the appropriate string with a literal ESC (U+0001B) as
the first character. You can also get strings with "\\e" or other forms,
to paste into C<shell> scripts or prompts, etc.

B<Note>: If using this via C<sjdUtils.pm> (q.v.),
be sure to call I<setColors(1)> and I<setVerbose(n)> to enable it.

=head2 Usage from the command line

If run with no arguments a self-test happens.

With I<--color colorName>, a sample of that color is shown.

With I<--effects>, a sample of each effect is shown (we have
thousands of terminal programs, but only a few of them know them all).

With I<--showAll>, all the known color combinations are displayed.

=head2 Color Names

The color names available are described in
L<https://github.com/sderose/Color/colorNames.md>, and are generally
foreground/background/effect.
For example, "red/blue/bold" specifies bold red on a blue background,
while "green" specifies green foreground.

Color and effect names disregard case.

If the environment variable C<NOBLINK> is set, the "blink" and "fblink"
effects will not be used even if requested.


=head1 General color methods

=over

=item * B<setColors>I<(b)>

Set up color handling; if I<b> is false, disables color.
Returns a reference to a hash with entries for the basic foreground colors
and "off", with the values being the escape-sequences for them.

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

If the last character of I<message> is a newline, then the color will be
turned off (or set to the I<endAs> value) I<before> rather than after
the newline itself, in case you pass the result to C<warn>.

For the supported colors, effects, and combinations see above or L<colorNames.md>.

The ANSI escape sequence to switch to a given color is
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

Show a small sample of the specified color.

=item * B<--effects>

Show a sample of each potential effect.

=item * B<--showAll>

Show a sample of each of the many color combinations (sorted by name).


=back


=head1 Known bugs and limitations

There should be an option to generate the form needed in C<zsh> prompt
strings.


=head1 To do

=over

=item * Sync with Python version (add --colorize, --uncolorize, --bold, --pack).

=item * Get rid of rest of refs to %colorStrings. Create escapes on the
fly from tokens rather than keeping a big list at all.

=item * Remove or finish 256-color stuff.

=item * Finish different color-sets for dark vs. light bg.

=back


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

=item * 2020-02-18: Clean up. Sync color syntax with doc. Fix --color demo.

=item * 2022-12-20: Sync more closely with Python version.
Move in colorizeXmlTags() and colorizeXmlContent() from sjdUtils.pm.

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

my $newColorMethod = 1;  # TODO ???

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
            $theHash->{"$e/$c"}   = sprintf($fmt2, $eb, $en, 30+$cn);
            $theHash->{"$e//$c"}  = sprintf($fmt2, $eb, $en, 40+$cn);
            $theHash->{"!$e/$c"}  = sprintf($fmt2, $eb, 20+$en, 30+$cn);
            $theHash->{"!$e//$c"} = sprintf($fmt2, $eb, 20+$en, 40+$cn);
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
    $name = lc($name);
    if (!$newColorMethod) {
        return((defined $colorStrings{$name}) ? 1:0);
    }
    else {
        return(getColorString($name) ne "");
    }
}

# Look up or construct the escape string, given a compound color name
# such as "red/white/bold".
#
sub getColorString {
    my ($name, $theEscape) = @_;
    $name = lc($name);
    if (!defined $theEscape) {
        $theEscape = "\e";
    }
    my $s = "";
    if ($name eq "off" || $name eq "default") {
        return $theEscape . "[0m";
    }

    if (!$newColorMethod) {            # From big static table
        if (!defined $colorStrings{$name}) {
            warn "$me.getColorString: Color name '$name' not recognized.\n";
            return "";
        }
        my $cstr = $theEscape . '[' . $colorStrings{$name} . 'm';
        print("cstr is ###" . sjdUtils::showInvisibles($cstr) . "###\n");
        return $cstr;
    }

    # Parse on the fly
    my @tokens = split(/\s*\/\s*/, $name);
    ($verbose) && warn "$me.getColorString: Color name tokens from '$name': [ '"
        . join("', '", @tokens) . "' ]\n";

    # Sort out which token is which (this allows flexible order, though that's
    # not specified by colorName.pod). It also allows extra slashes.
    my $fg = my $bg = my $eff = "";
    my $neg = 0;
    for my $token (@tokens) {
        my $neg = (substr($token, 0, 1) eq '!') ? 1:0; # Use 20 to negate effects
        if ($neg) { $token = substr($token, 1); }
        if ($token eq "") { next; }
        if (defined $colorNumbers{$token}) {
            if ($fg eq "") { $fg = $token; }
            elsif ($bg eq "") { $bg = $token; }
            else { warn("$me.getColorString: Too many color tokens in '$name'.\n"); }
        }
        elsif (defined $effectNumbers{$token}) {
            if ($eff eq "") { $eff = $token; }
            else { warn("$me.getColorString: Too many effects tokens in '$name'.\n"); }
        }
        else {
            warn("$me.getColorString: Bad token '$token' in color name '$name'.\n");
        }
    } # for $token

    # Now construct the right escape string
    return $theEscape . getColorStringFromArgs($fg, $bg, $eff);
} # getColorString

# Construct the actual code, NOT INCLUDING THE ESCAPE.
#
sub getColorStringFromArgs {
    my ($fg, $bg, $eff) = @_;
    $fg = lc($fg);
    $bg = lc($bg);
    $eff = lc($eff);
    my $theCode = "[";
    if ($fg) { $theCode .= (30 + $colorNumbers{$fg}) . ';'; }
    if ($bg) { $theCode .= (40 + $colorNumbers{$bg}) . ';'; }
    if ($eff) {
        if (substr($eff, 0, 1) eq "!") {
            $theCode .= $effectOffNumbers{substr($eff, 1)} . ';';
        }
        else {
            $theCode .= $effectNumbers{$eff} . ';';
        }
    }
    if (substr($theCode, -1) eq ';') { chop $theCode; }
    $theCode .= 'm';
    return $theCode;
}

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
    warn("$me: \nDumping color definitions:\n");
    my $foo = getColorHash();
    for my $k (sort keys %$foo) {
        warn("    " . colorize($k, $k) . ".\n");
    }
}

sub addColorName {
    my ($newName, $oldName) = @_;
    warn "addColorName is deprecated.\n";
    if (!$newColorMethod) {
        $colorStrings{$newName} = $colorStrings{$oldName};
    }
    else {
        warn("$me: addColorName no longer supported.");
    }
}

sub colorize {
    my ($name, $msg, $endAs) = @_;
    $name = lc($name);
    if (!$ENABLED) {
        return('*' . $msg . '*');
    }
    if (!$endAs) { $endAs = "off"; }
    my $cs1 = getColorString($name);
    my $cs2 = getColorString($endAs);
    if (!$cs1 || !$cs2) { return('*' . $msg . '*');
    }
    return($cs1 . $msg . $cs2);
}

# Can pass a tag-name to color-name hash as 3rd argument, to be fancy.
#
sub colorizeXmlTags {
    my ($s, $defaultColorName, $colorMapRef) = @_;
    setColors(1);
    alogging::setLogColors(1);
    my $on = getColorString($defaultColorName);
    my $off = ($on) ? getColorString("off") : "";

    if (!$colorMapRef) {
        $s =~ s/(<.*?>)/$on$1$off/g;
    }
    else {
        $s =~ s/(<\/?)([-_.:\w\d]+)([^>]*>)/{
            ((defined $colorMapRef->{$2}) ?
                getColorString($colorMapRef->{$2}):$on) . $1 . $2 . $3 . $off }
            /ge;
    }
    return($s);
}

sub colorizeXmlContent {
    my ($s, $colorName) = @_;
    setColors(1);
    my $on = getColorString($colorName);
    my $off = ($on) ? getColorString("off") : "";
    $s =~ s/>(.*?)</>$on$1$off</g;
    return($s);
}


# Remove any ANSI terminal color escapes from a string.
#
my $colorRegex = qr/\x1b\[\d+(;\d+)*m/;
#
sub uncolorize {
    my ($s) = @_;
    $s =~ s^$colorRegex^^g;
    if (index($s, chr(27)) >= 0) {
        warn("$me: uncolorize: left some escape(s) in $s.");
    }
    return $s;
}

# Return the length of I<s>, but ignoring any ANSI terminal color strings.
# This is just shorthand for C<len(uncolorize(s))>.
#
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

    ($quiet) || print("\nTesting ColorManager.pm...\n");
    setColors(1);

    my @toShow = ();
    if ($colorToShow) {
        warn (sprintf("Sample of '%s': ## %s ##\n",
            $colorToShow, colorize($colorToShow, "Some text")));
        exit;
    }
    elsif ($showAll) {
        dumpColors();
    }
    elsif ($effects) {
        for my $b (sort keys %effectNumbers) {
            my $name1 = "white/red/$b";
            warn (sprintf("\nEffect %-12s  ## %s ##\n", $b,
            colorize($name1, sprintf("%-14s", $name1))));
        }
    }
    else {
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
    }
}
1;
