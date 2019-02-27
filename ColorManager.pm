#!/usr/bin/perl -w
#
# ColorManager: Unified handling of ANSI color.

# Began as part of sjdUtils:
# 2011-03-25: Pulled out from various scripts.
# 2011-05-12 sjd: Use defaultColor in hWarn().
# 2016-07-21: Logically separate ColorManager package.
#     Sync color w/ python, logging....
# 2016-10-25: Physically separate ColorManager package.
#
# To do:
#     Block 'blink' effect if env var NOBLINK is set.
#     Sync ColorManager API with Python version.
#     Get rid of rest of refs to %colorStrings. Maybe create escapes on the
#         fly from tokens rather than keeping a big list at all.
#     Remove 256-color stuff?
#     Finish different color-sets for dark vs. light bg.
#     Sync with Python version.
#
package ColorManager;

###############################################################################
###############################################################################
# Color management in general
#
#
# ANSI terminal-control codes (+30 foreground, +40 background)
#
my $ENABLED = 1;

my $newColorMethod = 1;

my %colorNumbers = (
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
my %effectNumbers = (
    "bold"       =>  1,
    "faint"      =>  2,
    "italic"     =>  3,
    "ul"         =>  4,  # aka underscore, underline
    #"blink"      =>  5, # see below
    #"fblink"     =>  6, # see below
    "inverse"    =>  7,  # aka reverse
    "concealed"  =>  8,
    "strike"     =>  9,  # aka strikethru, strikethrough
    );

# Be nice to people with blink sensitivities.
if (!defined $ENV{'NOBLINK'}) {
    $effectNumbers{'blink'} = 5;
    $effectNumbers{'fblink'} = 6;
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
    #warn "Color names tokens from '$name': [ '" . join("', '", @tokens) . "' ]\n";
    my $ntokens  = scalar(@tokens);
    my $nColorsSeen = 0;
    my $n = 0;
    for my $token (@tokens) {
        if ($token eq "") {
            next;
        }
        if ($token eq "off" || $token eq "default") {
            $s .= "0;";
            last;
        }
        my $neg = (substr($token,0,1) eq '!') ? 20:0;
        if ($neg) { $token = substr($token,1); }
        if (defined $effectNumbers{$token}) {
            $n = $effectNumbers{$token} + $neg;
        }
        elsif (defined $colorNumbers{$token}) {
            if ($nColorsSeen == 0) {
                $n = $colorNumbers{$token} + 30;
                $nColorsSeen++;
            }
            elsif ($nColorsSeen == 1) {
                $n = $colorNumbers{$token} + 40;
                $nColorsSeen++;
            }
            else {
                warn("Too many color tokens in '$name'.\n");
                next;
            }
            $s .= "$n;";
        }
        else {
            warn("Bad color name token '$token' in '$name'.\n");
        }
    } # for $token
    $s =~ s/;$//;
    $s = "[" . $s . "m";
    #print("Got '$name' --> ESC + '$s': word \e$s WORD \e[0m word.\n");
    #print("word \e[31m word \e[0m word\n");
    return $theEscape . $s;
} # getColorString

sub getColorHash {
    if (!$newColorMethod) {
        if (scalar keys %colorStrings) {
            setColors(1);
        }
        return(\%colorStrings);
    }
    else {
        warn("getColorHash no longer supported.");
        return(undef);
    }
}

sub dumpColors {
    warn("Dumping color defs:");
    if (!$newColorMethod) {
        for my $k (keys %colorStrings) {
            warn("    " . $k . ": " . $colorStrings{$k} . "\n");
        }
    }
    else {
        warn("dumpColors no longer supported.");
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
        warn"uncolorize: left some escape(s) in $s.";
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
    if (scalar @ARGV && $ARGV[0] eq "-h") {
        system "perldoc $0";
        exit;
    }
    print("Testing ColorManager.pm...\n");
    setColors(1);
    my $e = chr(27);
    for my $b (keys %colorNumbers) {
        $n = 30 + $colorNumbers{$b};
        warn sprintf("word %s[$n;m $b %s[0m word\n", $e, $e);
        warn sprintf("word %s[$n;1;m $b/bold %s[0m word\n", $e, $e);
        $n = 40 + $colorNumbers{$b};
        warn sprintf("word %s[$n;m /$b %s[0m word\n", $e, $e);
    }
}
1;



###############################################################################
###############################################################################
#

=pod

=head1 Usage

use ColorManager;

Provide much easier management of ANSI terminal colors.

If you use my other scripts, you may need to install this and make
sure Perl can find it via the C<@INC> directory-list
(part of which is taken from the environment variable C<PERL5LIB> --
see L<here|"http://stackoverflow.com/questions/2526804">).

B<Note>: If you're using this via C<sjdUtils.pm>,
then unless you call I<setColors(1)> and I<setVerbose(n)> to enable it,
you might not get the output you want.

B<Note>: A Python version of this package is also available.

If run directly (rather than used as a library), a small self-test happens.


=for nobody ###################################################################

=head2 Color Names

The color names available are defined in F<bingit/SHELL/colorNames.pod>,
which supercedes anything in specific scripts (they I<should> match).

For example, "green" specifies green foreground (type),
while "bold/red/blue" specifies bold red on a blue background


=for nobody ###################################################################

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

=item * B<uncolorize>I<(message)>

Remove any ANSI terminal color escapes from I<message>.

=item * B<uncoloredLen>I<(s)>

Return the length of I<s>, but ignoring any ANSI terminal color strings.
This is just shorthand for C<len(uncolorize(s))>.



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


=back



=for nobody ###################################################################

=head1 Known bugs and limitations



=for nobody ###################################################################

=head1 Related commands

C<colorstring> -- fancier options for colorizing.

C<hilite> -- applies colors to regex matches.

C<showInvisibles> -- pretty-print control and non-ASCII chars.

C<colorConvert.py> -- convert string representatins of colors (RGB, etc.).

C<uncolorize> -- remove ANSI color escape from STDIN.<



=for nobody ###################################################################

=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<here|"http://creativecommons.org/licenses/by-sa/3.0/">.

For the most recent version, see L<here|"http://www.derose.net/steve/utilities/">.

=cut
