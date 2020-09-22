#!/usr/bin/perl -w
#
# alogging: some generally useful Perl crud for logging.
#     Split from sjdUtils, 2018-03.
#
# To do:
#     Add error/warn/info/fatal to sync w/ Python version.
#
package alogging;

use strict;
use Scalar::Util;
use Encode;
use Exporter;
#use HTML::Entities;
#use Carp;

use ColorManager;

our %metadata = (
    'title'        => "alogging.pm",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2011-03-25",
    'modified'     => "2020-03-01",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE  = $metadata{'modified'};

our @ISA = qw( Exporter );
our @EXPORT = qw(
    setLogVerbose getLogVerbose setLogColors
    defineMsgType
    MsgType
    vMsg eMsg hMsg Msg whereAmI
    setStat getStat bumpStat
    pLine vPush vPop MsgPush MsgPop vSet vGet MsgSet MsgGet
    );

binmode(STDERR, ":encoding(utf8)");  # Just in case

=pod

=head1 Usage

use alogging;

Some basic utilities for handling error messages.
In addition to the usual warning and error messages methods, it provides
definable named message types that can set leading and trailing text to
insert, colors and spacing, etc. And it knows about indentation levels,
so you can easily arrange your messages like an outline to reflect your logic.

There is also a C<pline()> method for printing nicely-aligned columns
for labels and values.

Finally, all the messaging calls can take an extra parameter, for the name
of a counter to increment (counters can also be modified directly). This is
an easy way to keep stats on what things happen (the counters still get
incremented even if the trace level prevents a message from displaying).

B<Note>: Unless you call I<setLogColors(1)> and I<setLogVerbose(n)>, you might
not get the output you want. But if you do, C<ColorManager> provides pretty nice
color features.

B<Note>: A Python version of this package is also available.


=head1 Options

(prefix "no" to negate where applicable)

See also I<defineMsgType>, I<setLogColors>, and I<setLogVerbose>.

=over

=item * B<getLogOption>I<(name)>

Get the value of option I<name>, from the list below.
Returns C<undef> if you try to get an unknown option.

=item * B<setLogOption>I<(name, value)>

Set option I<name>, from the list below, to I<value>.
A warning will be printed if you try to set an unknown option.

=over

=item * I<colorEnabled> (boolean)

Globally enable/disable use of color.
Call this with a I<--color> option value (or equivalent)
from other scripts (mine default to on if environment variable I<USE_COLOR> is
set and the relevant output is going to a terminal.
This is accomplished via my C<ColorManager.pm>.

=item * I<plineWidth>

The number of columns to use for labels in messages printed with I<pline()>.

=item * I<stdout> (boolean)

Redirect STDERR messages to STDOUT instead.

=item * I<TEEFILE> (fileHandle)

If set, I<vMsg> etc. not only to write messages to STDERR,
but also to the file at I<fileHandle>. The caller is responsible for opening and closing
that file. No color escapes are written into the log file.

=item * I<verbose> (int)

I<vMsg>, I<hWarn>, and I<eWarn>
discard any requests whose first argument is greater than the
I<verbose> setting.
Messages use lower numbers for higher importance (priority).
Negative levels passed to I<eWarn> indicate fatal errors.

=item * I<indentString> (string)

The string used by I<vMsg>() to create indentation according to the level
set by I<vPush>(), I<vPop>, etc. See also I<defineMsgType>().

=back

=back


=head2 Color Names

The color names available are defined in F<bingit/SHELL/colorNames.pod>
(you should be able to view this via C<perldoc colorNames> or
C<more bingit/SHELL/colorNames.pod>.
That supercedes documentation in specific scripts (they I<should> match).

Briefly, color names consist of I<foreground/background/effect>. For example:
    red/blue/bold

The base color names are
black, red, green, yellow, blue, magenta, cyan, white.
These are ANSI numbers 30-37 for foreground, and 40-47 for background.


=over

=item * B<setLogColors>I<(b)>

Set up color handling; if I<b> is false, disables color.
Returns a reference to a hash with entries for the basic foreground colors
and "off", with the values being the escape-sequences for them.
Also sets up default handling for messages of types "v", "e", "h", and "x"
(see I<defineMsgType>()).

=back

There are various other methods available in C<ColorManager>, which
are I<not> available directly here.


=head2 Colorized and level-filtered messages

=over

=item * B<setLogVerbose>I<(level)>

Synonym for I<setLogOption("verbose", level)>.

=item * B<getLogVerbose>I<()>

Synonym for I<getLogOption("verbose")>.

=item * B<defineMsgType>I<(msgType, colorName, nLevels, prefix, infix, suffix, escape, indent)>

Set the display options for a (possibly new) named message-type.

=over

=item * I<msgType> can be a predefined value (v, e, h, or x), or a new one.
See I<Msg>() to issue a message of any specified type. Required.

=item * I<color> is one of the known L<Color Name>s, in which to disply messages of
the type being defined. Default: "black".

=item * I<nLevels> specifies how many levels of stack trace should be printed
when this type of message is issued. Default: 0.

=item * I<prefix> is a string to be printed before I<m1>.
Default: "".

=item * I<infix> is a string to be printed between I<m1> and I<m2>.
Default: "".

=item * I<suffix> is a string to be printed after I<m2>.
Default: "".

=item * I<escape> specifies whether the message (not including any I<pre> or I<suf>)
should be passed through I<showInvisibles>() before display.  Default: 1.

=item * I<indent> specifies whether messages of the type being defined are to be
indented (to the level specified via I<vPush>(), vPop(), etc.). Default: 1.
The indent string is inserted at the beginning, and after each newline
in the prefix, infix, and suffix (if any).

=back

Only arguments that are not I<undef> will be applied (in other cases, the prior
value (if any) or the default value (if the message type is new) is used.

The predefined I<msgType> options are:

     C<v> (verbose) is C<blue>, indented.
     C<h> (heading) is C<magenta>, prefix "\n******* ", unindented.
     C<e> (error) is C<red>, 3 levels of stack trace, prefix "ERROR: ".

I<msgType> C<x> is special. It determines what color is used by
I<colorizeXmlTags>() and  I<colorizeXmlContent>(). Default: C<blue>.


=item * B<eMsg>I<(rank, message1, message2)> or B<eWarn>

Issue an error message if the current verbosity-level is high enough
(that is, it is at least as great as abs(I<rank>)). See I<setLogVerbose>.
See I<defineMsgType> for the default color (used for I<message1> only),
number of stack trace levels, and other settings, and for how to change them.
If I<rank> is negative, the program is terminated.

=item * B<hMsg>I<(rank, message1, message2)> or B<hWarn>

Issues a heading message if the current verbosity-level is high enough
(greater than abs(I<rank>)). See I<setLogVerbose>.
The message gets a blank line above it and some "*" in front.
I<message1> will be in the color for message type C<h> (see I<defineMsgType>),
but I<message2> will not be colorized.

=item * B<vMsg>I<(rank, message1, message2)> or B<vMsg>
Issue an informational message if the current setting for
I<verbose> is greater than I<rank>. See I<setLogVerbose>.
I<message1> will be in the color for message type C<v> (see I<defineMsgType>),
but I<message2> will not be colorized.
A newline is added after I<message2>.
If I<MsgPush> has been called, the message will be indented appropriately.

=item * B<MsgPush>() or B<vPush>()

Increment the message-nesting level, which causes indentation for messages
displayed via I<vMsg>. This is mainly useful for messages that reflect
successive levels of processing on input data (for example, notices about
each file, record, and field). The string to repeat to make indentation can
be set with I<setLogOption("indentString", string)>.

=item * B<MsgPop>() or B<vPop>()

Decrement the message-nesting level (see I<MsgPush>).

=item * B<vSet>(n)

Force the message-nesting level to I<n> (see I<MsgPush>).

=item * B<vGet>()

Return the message-nesting level (see I<MsgPush>).


=item * B<whereAmI>I<(n)>

Return the package and function name of the caller. If I<n> is supplied,
describe the I<n>th ancestor of the called instead.

=item * B<Msg>I<(typeOrColor, message1, message2)>

If I<typeOrColor> is a defined message type name, issue a message with
the corresponding settings (see I<defineMsgType>(), above).
Otherwise, if I<typeOrColor> is a known L<Color Name>, issue a message
in that color, unconditionally, with no stack trace.
Otherwise (including if I<typeColor> is
0, "", or undef), issue the message in the default color, with no stack trace.

=item * B<pline>I<(label, data, denominator?)>

Print a line to STDOUT (not STDERR), with I<label> padded to some constant
width, and I<data> printed as appropriate for being integer, real, or string.
If I<data> is numeric and I<denominator> is also present and non-zero,
then 100.0*data/denominator will also be printed, with a following "%".
Good for printing various reports and statistics.
You can set the width used for labels with C<setLogOption('plineWidth', n)>.


=item * B<setStat(name, value)>

=item * B<getStat(name)>

=item * B<bumpStat(name, amount)>

I<amount> defaults to 1.

=item * B<maxStat(name, value)>

Set the named statistic to I<value>, but only if I<value> is greater than the
current value of the statistic.

=back


=head1 Known bugs and limitations

There's nothing to instantiate. Thus, values like the I<verbose> level
are shared among all users of the package. Whether that's a bug or a feature
is up to you. This differs from the Python version.

There is only one message-depth count, not one for each message type.
This may be a bug or a feature....

API is not perfectly in sync with my corresponding Python package.

=head1 Related commands

C<colorstring> -- fancier options for colorizing.

C<hilite> -- applies colors to regex matches.


=head1 History

=over

=item * 2011-03-25: Pulled out from various scripts. See also I<sjdUtils.pm>.
=item * 2018-03-27 Split to separate package.
=item * 2018-09-25: Get rid of remaining sjdUtils dependencies.
=item * 2020-01-28: Standardize layout, get rid of dependency on sjdUtils.

=back

=head1 Rights

Copyright 2011-03-25 by Steven J. DeRose. This work is licensed under a
Creative Commons Attribution-Share-alike 3.0 unported license.
See http://creativecommons.org/licenses/by-sa/3.0/ for more information.

For the most recent version, see L<http://www.derose.net/steve/utilities/>
or L<http://github.com/sderose>.

=cut


###############################################################################
#
sub makePrintable {
    # Simplified version of function from sjdUtils.
    my ($c) = @_;
    my $spaceChar = chr(0x2420);
    my $lfChar = chr(0x240A);
    #warn "sp $spaceAs ('$spaceChar'), lf $lfAs ('$lfChar'), mode $mode.\n";

    my $o = ord($c);
    my $buf = "$c";

    #if (defined $char2escape{$c}) { $buf =  $char2escape{$c}; }
    if    ($o ==    10) { $buf = $lfChar; }
    elsif ($o <=    31) { $buf = sprintf("\\x%02x", $o); }
    elsif ($o ==    32) { $buf = $spaceChar; }
    elsif ($o <=   126) { $buf = $c; }
    elsif ($o ==   127) { $buf = sprintf("\\x%02x", $o); }
    elsif ($o <=   255) { $buf = sprintf("\\x%02x", $o); }
    else                { $buf = sprintf("\\x{%x}", $o); }
    return($buf);
} # makePrintable

sub showInvisibles {
    my ($s, $mode, $spaceAs, $lfAs) = @_;
    (defined $s) || return("");
    $s =~ s/(\P{IsASCII}|\p{IsCntrl}| )/{
        makePrintable($1,$mode,$spaceAs,$lfAs); }/ges;
    return($s);
}
sub isNumeric {
    my ($n) = @_;
    (defined $n) || return(0);
    # This doesn't seem to work as expected:
    #return(Scalar::Util::looks_like_number($n));
    if ($n =~ m/^\s*[-+]?\d+(\.\d+)?(E[-+]?\d+)?\s*$/i) { return(1); }
    return(0);
}
sub isInteger {
    my ($n) = @_;
    (defined $n) || return(0);
    if ($n =~ m/^\s*[-+]?\d+/) { return(1); }
    return(0);
}
sub lpad {
    my ($s, $len, $padChar, $quoteChar) = @_;
    if (!defined $s)       { $s = ""; }
    if (!defined $len)     { $len = 0; }
    if (!defined $padChar) { $padChar = "0"; }
    if (defined $quoteChar) {
        $s = $quoteChar.$s.$quoteChar;
    }
    my $needed = $len - length($s);
    if ($needed > 0) {
        $s = ($padChar x $needed) . $s;
    }
    return($s);
}


###############################################################################
#
sub logWarn { # For our own warnings if any
    my ($m1, $m2) = @_;
    if (!$m1) { $m1 = ""; }
    if (!$m2) { $m2 = ""; }
    warn "alogging: $m1$m2\n";
}

my %logInfo = (
    'msgTypesDefined' => 0,      # Have the default message types been set up?
    'errorCount'      => 0,      # Number of calls to eMsg() so far.
    'localeInfo'      => undef,  # Hash of locale settings.
    'msgIndentLevel'  => 0,      # Set via MsgPush()/MsgPop().
    'stats'           => {},     # For bumpStat() etc.
);

my %logOptions = (
    'verboseSet'      => 0,      # Has setLogVerbose() been called??
    'verbose'         => 0,      # Verbosity level
    'stdout'          => 0,      # Messages to STDOUT instead of STDERR?
    'TEEFILE'         => undef,  # Copy of messages goes here
    'colorEnabled'    => 1,      # Use color at all?
    'indentString'    => "  ",   # String to repeat to make indentation
    'plineWidth'      => 40,     # Size of label portion for pline().
    ); # options


# For defined message-types. Set up by defineMsgType() and defineMsgTypes().
my %msgTypes = ();



sub setLogVerbose {
    my ($n) = @_;

    $logOptions{'verbose'} = $n;
}

sub getLogVerbose {
    return($logOptions{'verbose'});
}


###############################################################################
### Forwards to ColorManager package
#
sub setLogColors {
    my ($flag) = @_;
    my $rc = ColorManager::setColors($flag);
    defineMsgTypes();
    setLogOption("colorEnabled", $flag);
    return($rc);
}

sub setLogOption {
    my ($name, $value) = @_;
    if (!exists $logOptions{$name}) {
        logWarn("Unknown set option '$name'. Known:\n");
        dumpOptions();
        return(0);
    }
    if (!defined $value) {
        warn("******* Setting '$name' to undefined value.\n");
        #confess "Eh?";
        return;
    }
    $logOptions{$name} = $value;
    if ($name eq "verbose") { $logOptions{"verboseSet"} = 1; }
    return(1);
}

sub getLogOption {
    my ($name) = @_;
    if (!exists $logOptions{$name} || !defined $logOptions{$name}) {
        logWarn("Unknown get option '$name'. Known:\n");
        dumpOptions();
        return 0;
    }
    #warn sprintf("getting '%s': '%s'\n", $name, $logOptions{$name});
    return($logOptions{$name});
}

sub dumpOptions {
    for my $opt (keys(%logOptions)) {
        warn sprintf("    %-12s  '%s'\n", $opt, $logOptions{$opt});
    }
}


###############################################################################
###############################################################################
# Messaging calls.
# Main features: colorizing, verbosity levels, and logging.
#

# Set default options for predefined message-types v, e, h, x.
# This is called by Msg if $logInfo{"msgTypesDefined"} is 0.
#
sub defineMsgTypes {
    # Try to figure out what the background color is
    my $bgType = "light";
    if ($ENV{TERM_BG}) {
        if ($ENV{TERM_BG} =~ m/(black|blue|red|magenta)/) {
            $bgType = "dark";
        }
    }
    elsif (0 && $ENV{COLORTERM} eq "gnome-terminal" &&
           -e (my $xtc = `which xtermcontrol`)) {
        my $xtermbg = `$xtc --get-bg`;
        #...
    }

    if ($bgType eq "light") {
        #             type  color  nLevels prefix   infix suffix escape indent
        defineMsgType("v", "blue",      0, "",           "",  "",    0,  1);
        defineMsgType("e", "red",       0, "ERROR: ",    "",  "",    1,  1);
        defineMsgType("h", "magenta",   0, "\n******* ", "",  "",    0,  1);
        defineMsgType("x", "blue",      0, "",           "",  "",    0,  1);
    }
    else {
        defineMsgType("v", "/blue",   0, "",           "",  "",    0,  1);
        defineMsgType("e", "/red",    0, "ERROR: ",    "",  "",    1,  1);
        defineMsgType("h", "/magenta",0, "\n******* ", "",  "",    0,  1);
        defineMsgType("x", "/blue",   0, "",           "",  "",    0,  1);
    }
    $logInfo{"msgTypesDefined"} = 1;
} # defineMsgTypes

sub defineMsgType {
    if (scalar @_ < 2 || scalar @_ > 8) {
        my $names = "msgType,color,nLevels,prefix,infix,suffix,escape,indent";
        die "alogging: 2~8 args for defineMsgType($names).\n    Got: (" .
            join(", ", @_) . ").\n";
    }

    my ($msgType, $color, $nLevels, $prefix, $infix, $suffix, $escape, $indent) = @_;
    if (!$msgType) { return(0); }
    if (!exists $msgTypes{$msgType}) {
        $msgTypes{$msgType} = { # New type, define with defaults
            "color"     => "black",
            "nLevels"   => 0,
            "prefix"    => "",
            "infix"     => "",
            "suffix"    => "",
            "escape"    => 1,
            "indent"    => 1,
        };
    }
    if (defined $color )  { $msgTypes{$msgType}->{color}  = $color;   }
    if (defined $nLevels) { $msgTypes{$msgType}->{nLevels}= $nLevels; }
    if (defined $prefix)  { $msgTypes{$msgType}->{prefix} = $prefix;  }
    if (defined $infix)   { $msgTypes{$msgType}->{infix}  = $infix;   }
    if (defined $suffix)  { $msgTypes{$msgType}->{suffix} = $suffix;  }
    if (defined $escape)  { $msgTypes{$msgType}->{escape} = $escape || 0; }
    if (defined $indent)  { $msgTypes{$msgType}->{indent} = $indent || 0; }
    return(1);
} # defineMsgType

# Return the proper choice escape string (not the color name), or "".
# Use first valid color from $argColor, then $msgColor, then none.
#
sub getPickedColorString {
    my ($argColor, $msgColor) = @_;
    if (!$argColor) { $argColor = ""; }
    if (!$msgColor) { $msgColor = ""; }

    if (!getLogOption("colorEnabled")) {
        return("");
    }
    if ($argColor && (my $argString = ColorManager::getColorString($argColor))) {
        return($argString);
    }
    if ($msgColor && (my $msgString = ColorManager::getColorString($msgColor))) {
        return($msgString);
    }
    return("");
} # getPickedColorString


sub vPush {
    MsgPush(@_);
}
sub MsgPush {
    $logInfo{msgIndentLevel}++;
    return($logInfo{msgIndentLevel});
}
sub vPop {
    MsgPop(@_);
}
sub MsgPop {
    if ($logInfo{msgIndentLevel}>0) { $logInfo{msgIndentLevel}--; }
    return($logInfo{msgIndentLevel});
}
sub MsgSet { $logInfo{msgIndentLevel} = $_[0]; }
sub MsgGet { return($logInfo{msgIndentLevel}); }
sub vSet { $logInfo{msgIndentLevel} = $_[0]; }
sub vGet { return($logInfo{msgIndentLevel}); }

sub vMsg { # Verbose warnings
    my ($level, $m1, $m2) = @_;
    my $disp = interpretLevel($level);
    return unless($disp);
    Msg("v", $m1||"", $m2);
    ($disp<0) && die "Warning is fatal.\n";
}

sub eMsg {
    my ($level, $m1, $m2) = @_;
    $logInfo{"errorCount"}++;
    my $disp = interpretLevel($level);
    #warn "Level interpreted to $disp for $m1\n";
    return unless($disp);
    Msg("e", $m1, $m2);
    ($disp<0) && die "Error is fatal.\n";
}

sub hMsg {
    my ($level, $m1, $m2) = @_;
    my $disp = interpretLevel($level);
    return unless($disp);
    if (!defined $m1) { $m1 = ""; }
    Msg("h", $m1, $m2);
    ($disp<0) && die "Warning is fatal.\n";
}

# Look up message type name to get color and nTraceLevels.
# Can also just use colors as types for convenience, or "" for no color.
sub MsgType {
    return(Msg(@_));
}
sub Msg {
    my ($msgType, $m1, $m2) = @_;
    if (!defined $m2) { $m2 = ""; }
    if (!$logInfo{"msgTypesDefined"}) {
        defineMsgTypes();
    }
    if (!$msgType) {
        rawMsg($m1, $m2, "", 0);
        return;
    }

    my $mDef = $msgTypes{$msgType};
    if (!defined $mDef) {
        showMsg("?$msgType? $m1$m2\n");
        return;
    }

    if ($mDef->{escape}) {
        $m1 = showInvisibles($m1 || "");
        $m2 = showInvisibles($m2 || "");
    }

    my $pre = $mDef->{prefix} || "";
    my $inf = $mDef->{infix}  || "";
    my $suf = $mDef->{suffix} || "";
    if ($mDef->{indent}) {
        my $ind = getLogOption("indentString") x $logInfo{msgIndentLevel};
        $pre =~ s/\n/\n$ind/g;
        $pre = $ind . $pre;
        $inf =~ s/\n/\n$ind/g;
        $suf =~ s/\n/\n$ind/g;
    }

    my $colorName = "";
    if (defined $mDef->{color}) {
        $colorName = $mDef->{color};
    }
    elsif (ColorManager::getColorString($msgType, 'quiet')!="") {
        #warn "Found color per se: $msgType.\n";
        $colorName = $msgType;
    }
    my $on = getPickedColorString($colorName);
    my $off = ($on) ? ColorManager::getColorString("off") : "";

    my $nL = $mDef->{nLevels} || 0;
    my $loc = ($nL>0) ? whereDetail($nL) : "";

    my $m = join("", @{[ $on,$pre,$m1,$off,$inf,$m2,$suf,"\n",$loc ]} );
    showMsg($m);
    #rawMsg($ind.$m1, $m2, $colorString, $mDef->{Level} || 0);
} # Msg

# Display a message to the applicable destination(s).
#
sub showMsg {
    my ($msg) = @_;
    if (getLogOption("stdout")) { print($msg); }
    else                          { warn($msg); }
    if ($logOptions{"TEEFILE"})  {
        my $tee = $logOptions{"TEEFILE"};
        print $tee "$msg\n";
    }
} # showMsg

sub whereDetail {
    my $nLevels = $_[0];
    my $loc = "";
    for (my $lvl=1; $lvl<=$nLevels; $lvl++) {
        my ($pkg, $filename, $line, $subr, $hasargs) = caller($lvl);
        ($pkg) || last;
        $loc .= "  Called from: $subr, line $line\n";
    }
    return($loc);
}

sub whereAmI {
    my $levelsUp = ($_[0] || 0) + 1;
    my $loc = (caller($levelsUp))[3];
    return($loc);
}

# Returns: 0 to pass; 1 to print; -1 to print and exit.
#
sub interpretLevel {
    my ($level) = @_;
    if (!defined $level || !isNumeric($level)) {
        logWarn("Bad level '$level' passed to alogging::interpretLevel()\n");
        return(1);
    }
    if ($level<0) {
        return(-1);
    }
    if ($logOptions{"verboseSet"} &&
        getLogOption("verbose") < abs($level)) {
        return(0);
    }
    return(1);
} # interpretLevel

# getLoc()

# Print a nicely-aligned message and data.
# If the 2nd arg is numeric and there's a 3rd arg, show a %age.
# ####### Fix alogging::pline to ignore color escapes
#
sub pLine { pline(@_); }
sub pline {
    my ($label, $data, $denom) = @_;
    my $dataField = $data;
    if (!defined $data) {
        $dataField = "  ???";
    }
    elsif (ref($data) eq "HASH") {
        $dataField = "(HASH, " . scalar(keys(%{$data})) . " keys)";
    }
    elsif (ref($data) eq "ARRAY") {
        $dataField = "(ARRAY, " . scalar(@{$data}) . " elements)";
    }
    elsif (ref($data) ne "") {
        $dataField = "(ref to " . ref($data) . ")";
    }
    elsif (!isNumeric($data)) {
        $dataField = "'$data'";
    }
    elsif (!isInteger($data)) {
        $dataField = sprintf("%10.3d", $data);
    }
    $dataField = lpad($dataField, 16, " ");
    if ($denom) {
        $dataField .= sprintf(" (%7.3f%%)", 100.0*$data/$denom);
    }

    if (!defined $label) { $label = ""; }
    my $unclen = length(ColorManager::uncolorize($label));
    my $padlen = $logOptions{plineWidth} - $unclen;
    print "  " . $label . (' ' x $padlen) . " " . $dataField . "\n";
} # pline


sub setStat {
    my ($name, $value) = @_;
    $logInfo{"stats"}->{$name} = $value;
}

sub getStat {
    my ($name) = @_;
    return($logInfo{"stats"}->{$name} || 0);
}

sub bumpStat {
    my ($name, $amount) = @_;
    if (!defined $amount) { $amount = 1; }
    $logInfo{"stats"}->{$name} += $amount;
}

sub maxStat {
    my ($name, $value) = @_;
    if ($value <= $logInfo{"stats"}->{$name}) { return; }
    $logInfo{"stats"}->{$name} = $value;
}

sub reportStats {
    my ($head, $labels) = @_;
    print($head);
    for my $s (sort(keys(%{$logInfo{"stats"}}))) {
        if ($labels && $labels->{$s}) {
            pline($labels->{$s}, $logInfo{"stats"}->{$s})
        }
        else {
            pline($s, $logInfo{"stats"}->{$s})
        }
    }
}


###############################################################################
###############################################################################
#
if (!caller) {
    system "perldoc $0";
}
1;
