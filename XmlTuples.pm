#!/usr/bin/perl -w
#
# 2011-10-13: Written by Steven J. DeRose.
# 2011-10-14 sjd: Support multi-line tags and comments. Fix API.
#     Start datatype support and file input.
#     Add getAllTuplesAsArray() and getAllTuplesAsHash().
# 2011-10-24 sjd: Support compound keys in getAllAsHash().
# 2011-11-07 sjd: Add buildHash(keyAttrName,valueAttrName).
# 2011-12-07 sjd: Split lwarn(). Document bug w/ ...AsHash/AsArray.
# 2012-01-19 sjd: Support HTML Entities.
# 2012-02-22 sjd: Clean up error messaging. Check attrs are in attrNames.
#     Implement '#REQUIRED' value from <Head>. Apply defaults. Add multiHead
#     option. Fix bug in numeric character references. Add errorCount, reset().
# 2012-02-24 sjd: Don't return <Head> when building hash or array.
# 2012-03-02 sjd: Add vars 'container' and 'requireWord'.
#     Change to allow start/end tag pair for Head (not empty).
# 2012-03-14 sjd: Add setFatal().
# 2012-03-28 sjd: Fix getAllAsHash to handle "Head" tags right.
#     Fix getPhysicalLine() to not trip over "|".
# 2012-05-14f sjd: Ditch sjdUtils. Clean up parseXmlAttrs(). Drop multiHead.
#     Implement most of the #-defaults. Change <Def> to <Rec>. ID/IDREF.
#     Allow outer <Xsv> container. Clean up parsing.
# 2012-06-06 sjd: Clean up datatyping design, esp. for enums. Do #REQUIRED
#     as ##type instead. Implement rest of checking and defaulting.
# 2012-06-08 sjd: Change ## to #|#?|#*|#+.
# 2012-10-12 sjd: More specific syntax errors. Handle blank lines.
#     Move regexes into their own hash, and compile them. Monitor tag-stack.
#     Broke multi-line comments. Start 'loose' option. Reduces layering of
#     regexes, drop unused ones. Fix EOF bug on no "</Head>".
# 2012-12-06 sjd: Always put lineNum in messages. Add {errCode}.
#     Start on probs w/ gt in attributes. Fix single-character attribute names!
# 2012-12-07 sjd: Clean up parser, refactor. Handle '>' in attrs.
# 2012-12-07 sjd: Add attrOrder. Resync w/ Python version. Clean up
#     datatype naming and docs. Support Dublin Core attrs on XSV.
# 2012-12-19 sjd: Separate readNext() from parsing. Allow caller
#     to pass in a logical record (tag) to parse if desired.
# 2013-01-03 sjd: Fix #REQUIRED and #BASE
# 2013-05-10 sjd: Losing 'XmlTuples' names.
# 2013-05-29ff sjd: Add xError(). Unify options under setOption()/getOption().
#     Allow XML declaration (but only as one line).
#     Add njustify option to right-justify numeric attrs on output.
#     Add isXsv, isHead, isRecord, getHeader.
# 2013-06-03f: Rename setInputFile() to open(). Add attach(), getLastRecord().
# 2013-06-03f: Handle <Xsv>, comments, etc. in getAllAsHash().
# 2014-05-14: Separate options into hash.
# 2014-09-03: Add encoding arg to open(). Drop setInputFile.
# 2015-03-15: Clean up stack handling. syn w/ Python version.
#
# To do:
#     Test and provide example of loading multiple tables from one file.
#       Add call to make XML Schema given XSV header?
#     Rename to just XSV.
#     Move all output stuff elsewhere?
#     Toss all options stuff, just set on constructor.
#     Sync w/ Python version.
#     Lose Datatypes package, or find a public one?
#     Make sure tab2xml, xml2tab, CSV/* can read/write this correctly.
#     handle zip/bz/etc.
#
use strict;
use HTML::Entities;

use Datatypes;

our $VERSION_DATE = "2.6";

package XmlTuples;

my %dublinCoreNames = (
    contributor=>1, coverage=>1, creator=>1, date=>1,
    description=>1, format=>1, identifier=>1, language=>1,
    publisher=>1, relation=>1, rights=>1, source=>1,
    subject=>1, title=>1, type=>1,
    );

# Regexes for parsing (set up below)
#
my %regexes = ();
my %cex = ();

sub new {
    my ($class, $text) = @_;
    my $self = {
        inFile       => undef,     # Reading from here
        inFH         => undef,
        text         => $text,     # Or reading from here

        lineNum      => 0,         # How many lines in are we?
        tagStack     => [],

        options      => {
            # Features
            dt           => 0,         # Datatypes package
            typeCheck    => 1,
            verbose      => 0,         # More messages?

            # Syntax constants
            assignChar   => "=",
            xsvName      => "Xsv",     # Tags (see setNames())
            headName     => "Head",
            recName      => "Rec",
            loose        => 0,
            reservedChar => "#",

            # Output-related:
            breakAttrs   => 0,         # Cf makeXsvRecord()
            defaultList  => 0,
            njustify     => 1,         # Right-justify numbers on output?
        },
        # Gathered data
        dcInfo       => {},        # Dublin Core fields from Xsv (optional)
        attrNames    => {},        # Hash of attr names and default values
        attrOrder    => [],        # Attr names in order specified in <Head>
        ids          => {},        # ID attributes seen
        idrefs       => {},        # IDREF(S) attributes seen

        errorCount   => 0,         # How many errors seen so far?
        errorCode    => "",        # last getNext error code
        errorMsg     => "",        # last getNext error message text
        lastRecord   => "",        # Most recently-read logical line
    };

    bless $self, $class;
    $self->setupRegexes();
    return($self);
}

sub reset { # Not including options
    my ($self, $text) = @_;
    $self->{attrNames}  = undef;
    $self->{inFile}     = undef;
    if ($self->{inFH}) {
        close $self->{inFH};
        $self->{inFH}   = undef;
    }
    $self->{text}       = ($text) ? $text:"";
    $self->{lineNum}    = 0;
    $self->{errorCount} = 0;
    $self->{ids}        = {};
    $self->{idrefs}     = {};
    $self->{tagStack}   = [];
    $self->{lastRecord} = "";
}

# Regexes to match simple XML stuff (most do capture!)
#     (see also boilerplate/xmlRegexes and littleParser.py).
#
sub setupRegexes {
    my ($self, $assignChar) = @_;
    my $eq    = $assignChar || "=";
    my $qlit  = '("[^"]*"|\'[^\']*\')';
    my $xname = "([_.\\w][-_:.\\w]*)";

    # Fix: pair up the initial/final punctuation exactly.
    if ($self->{options}->{loose}) {
        $eq = '(=>|=|==|::=|:=|::|:|->)'; # ewww
        $qlit = '(' .
            '"[^"]*"' . '|' .
            "'[^']*'" . '|' .
            '[[:Initial_Punctuation:]].*?[[:Final_Punctuation:]]' . '|' .
            '\\w+' .
            ')';
        $xname = "([-:_.\\w]+)";
    }

    %regexes = (
       # Delimiters (no capture)
       "eq"         => $eq,
       "como"       => "<!--",
       "comc"       => "-->",
       "pio"        => "<\\?",
       "pic"        => "\\?>",
       "cdataStart" => "<!\\[CDATA\\[",           # Marked section open
       "cdataEnd"   => "]]>",                     # Marked section close

       # Capturable constructs:
       "xname"      => $xname,                    # XML NAME (imperfect)
       "qlit"       => $qlit,                     # Includes the quotes
       "comment"    => "(<!--[^-]*(-[^-]+)*-->)", # Includes delims
       "pi"         => "<\\?$xname\\s*(.*)?\\?>", # Processing instruction
       "dcl"        => "<!$xname\\s+([^>]+)\\s*>",# Markup dcl (imperfect)
        );

    for my $k (keys %regexes) {                   # pre-compile
        my $x = $regexes{$k};
        $cex{$k} = qr/$x/;
    }
} # setupRegexes

sub setOption {
    my ($self, $name, $value) = @_;
    if (!defined $self->{options}->{$name}) {
        $self->xWarn(0, "XSV::setOption: Unknown option '$name'.");
        return(undef);
    }
    $self->{options}->{$name} = $value;
    $self->setupRegexes(); # in case we changed something relevant...
    return($value);
}

sub getOption {
    my ($self, $name) = @_;
    if (!defined $self->{options}->{$name}) {
        $self->xWarn(0, "XSV::getOption: Unknown option '$name'.");
        return(undef);
    }
    return($self->{options}->{$name});
}

sub getErrorCount {
    my ($self) = @_;
    return($self->{errorCount});
}

sub getError {
    my ($self) = @_;
    return($self->{errorCode});
}

sub clrError {
    my ($self) = @_;
    $self->{errorCode} = "";
    $self->{errorMsg} = "";
}

sub setError {
    my ($self, $code, $msg, $context) = @_;
    $self->{errorCount}++;
    $self->{errorCode} = $code;
    $self->{errorMsg} = $msg;
    $self->xWarn(0, $msg, $context);
}

sub xError {
    my ($self, $level, $msg, $context) = @_;
    return unless ($self->{options}->{verbose} >= $level);
    chomp $msg;
    if ($context) { $msg .= "\n" . $context; }
    warn("******* XSV ERROR at line " . $self->{lineNum} . ": " . $msg . "\n");
}

sub xWarn {
    my ($self, $level, $msg, $context) = @_;
    return unless ($self->{options}->{verbose} >= $level);
    chomp $msg;
    if ($context) { $msg .= "\n" . $context; }
    warn("XSV: at line " . $self->{lineNum} . ": " . $msg . "\n");
}


###########################################################################
# (meta-) data access
#
sub getLastRecord {
    my ($self) = @_;
    return($self->{lastRecord});
}

sub getFieldNamesArray {
    my ($self) = @_;
    return($self->{attrOrder}); # an array
}

sub getDCInfo { # Dublin Core data from <Xsv> element (optional).
    my ($self) = @_;
    return($self->{dcInfo});
}


sub isXsv {
    my ($self, $hashRef) = @_;
    my $tag = (defined $hashRef) ? $hashRef->{"#TAG"}:"";
    if ($tag && $tag eq $self->{options}->{xsvName}) { return(1); }
    return(0);
}

sub isHead {
    my ($self, $hashRef) = @_;
    my $tag = (defined $hashRef) ? $hashRef->{"#TAG"}:"";
    if ($tag && $tag eq $self->{options}->{headName}) { return(1); }
    return(0);
}

sub isRecord {
    my ($self, $hashRef) = @_;
    my $tag = (defined $hashRef) ? $hashRef->{"#TAG"}:"";
    if ($tag && $tag eq $self->{options}->{recName}) { return(1); }
    return(0);
}


###############################################################################
# Actual parsing
#
sub getHeader {
    my ($self) = @_;
    while (my $aHash = $self->getNext()) {
        if ($self->isHead($aHash)) {
            my $nameArray = $self->getFieldNamesArray();
            #$self->xWarn(0, "Header fields: " . join(", ", @{$nameArray}));
            return($nameArray);
        }
        if ($self->isRecord($aHash)) { # Loses this record....
            return(undef);
        }
    }
    return(undef); # EOF
}

sub getAllAsArray {
    my ($self) = @_;
    my @theArray = ();
    while (my $aRecord = $self->getNext()) {
        push @theArray, $aRecord;
    }
    $self->getUnresolvedIDREFS();

    return(\@theArray);
}

sub getAllAsHash {
    my ($self) = @_;
    if (scalar(@_) < 2) {
        $self->setError("NOKEY","getAllAsHash: No keys specified.");
        return(undef);
    }
    my @keyNames = @_;
    shift @keyNames;
    my $nKeyAttributes = scalar(@keyNames);

    my %theHash = ();
    my $nTuples = 0;
    my $seenHead = 0;
    while (my $aRecord = $self->getNext()) {
        ($self->isRecord($aRecord)) || next;
        $nTuples++;
        my $key = ""; # Assemble (possibly compound) key
        for my $kn (@keyNames) {
            my $a = $aRecord->{$kn};
            $key .= ($a ? $a:"") . "#";
        }
        $key =~ s/#$//;
        if ($key =~ m/^#*$/) {
            my $buf = "";
            for my $k (sort keys(%{$aRecord})) {
                $buf .= sprintf("    %-20s => '%s'\n", "'$k'", $aRecord->{$k});
            }
            $self->setError(
                "NILKEY", "getAllAsHash: No key data (" .
                join(", ", @keyNames) . "):\n" . $buf);
        }
        elsif (defined $theHash{$key}) {
            $self->setError("DUPKEY", "Duplicate key '$key'");
        }
        else {
            $theHash{$key} = $aRecord;
        }
    } # while

    $self->getUnresolvedIDREFS();

    return(\%theHash);
} # getAllAsHash

sub buildHash {
    my ($self, $keyAttrName, $valueAttrName) = @_;
    my %theHash = ();
    while (my $aRecord = $self->getNext()) {
        if ($self->isHead($aRecord)) {
            next;
        }
        my $key = $aRecord->{$keyAttrName};
        if (defined $theHash{$key}) {
            $self->setError("DUPKEY", "buildHash: Duplicate key '$key'.");
            next;
        }
        $theHash{$key} = $aRecord->{$valueAttrName};
    }
    return(\%theHash);
} # buildHash


# Parse a single XML tag off of the input (passed or read).
# Ignore comments, whitespace, etc.
#
# Returns:
#     A ref to a hash of attributes (for Head or Rec),
#         or undef at EOF, or an end-tag.
# Side-effect: Sets {errorCode} via setError().
#
sub getNext {
    my ($self, $line) = @_;
    if (!defined $line) {
        $line = $self->readNext();
    }
    $self->{lastLine} = $line;
    if (!defined $line) { return(undef); } # EOF

    $self->xWarn(3, "XSV::getNext: got logical item '$line'");

    ###########################################################################
    if ($line !~ m/^\s*</) {                      # No "<" (disallowed)
        $self->setError("SYN", "Expected (whitespace and) '<', not:", $line);
        return(undef);
    }

    ###########################################################################
    elsif ($line =~ m/<$cex{xname}/) {            # Start-tag
        my ($tag, $attrHash, $isEmpty, $err, $attrOrder) =
            $self->parseStartTag($line);
        if ($err) { return(undef); }
        ($isEmpty) || $self->openElement($tag);
        if ($tag eq $self->{options}->{xsvName}) {         # Xsv
            for my $a (keys(%{$attrHash})) {
                next if ($a eq "#TAG");
                if (!defined $dublinCoreNames{$a}) {
                    $self->setError(
                        "DTD", "Non-Dublin-Core attr '$a' in: ", $line);
                }
                else {
                    $self->{dcInfo}->{$a} = $attrHash->{$a};
                }
            } # for
        }
        elsif ($tag eq $self->{options}->{headName}) {     # Head
            $self->{attrNames} = $attrHash;
            $self->{attrOrder} = $attrOrder;
        }
        elsif ($tag eq $self->{options}->{recName}) {      # Rec
            $attrHash = $self->processAttributes($attrHash, $line);
        }
        else {                                             # FAIL
            $self->setError("DTD", "Unknown element '$tag' in: ", $line);
        }
        return($attrHash);
    } # Start-tag

    ###########################################################################
    elsif ($line =~ m/<\/$cex{xname}\s*>/) {      # End-tag
        $self->closeElement($1 || "");
    } # End-tag

    ###########################################################################
    # If we get here it's an XSV error; try to be more specific.
    #
    elsif ($line =~ m/$cex{como}/) {              # Comment open
        $self->setError("BUG", "Comment was not filtered out at:\n". $line);
    }
    # Could loosen this up to split and then keep going...
    elsif ($line =~ m/>.*\S/) {                   # Leftovers
        $self->setError("SYN", "Non-whitespace after '>':", $line);
    }
    elsif ($line =~ m/$cex{pio}/) {               # PI (disallowed)
        $self->setError("SYN", "Unexpected PI.", $line);
    }
    elsif ($line =~ m/$cex{cdataStart}/) {        # CDATA (disallowed)
        $self->setError("SYN", "Unexpected CDATA marked section.", $line);
    }
    else {                                        # Huh?
        $self->setError("SYN", "Syntax not recognized after '<'.", $line);
    }
    return(undef); # (fail)
} # getNext


###############################################################################
# Get the next unit of XSV data. Discards comments, blanks, xml dcls.
# Returns:
#     An entire <Rec.../> element (even if >1 physical line!)
#     undef on EOF
#
sub readNext {
    my ($self) = @_;
    my $line;
    $self->clrError();
    while (1) {
        $line = $self->getLogicalLine();
        if (!defined $line)                  { return(undef); }  # EOF
        if ($line =~ m/^\s*$cex{como}/s)     { next; }           # COMMENT
        if ($line =~ m/^\s*$/)               { next; }           # BLANK
        if ($line =~ m/^\s*<\?xml.*\?>\s*$/) { next; }           # XML DCL
        last;                                                    # TAG
    }
    $self->xWarn(2, "readNext: logical line:" .
                    (defined $line ? "\n    '$line'" : " [EOF]"));
    return($line);
} # readNext


###############################################################################
# Parse a start tag.
# Returns: tag, hash of attributes, was it empty, errCode.
#
sub parseStartTag {
    my ($self, $s) = @_;
    my $s2 = $s;

    my $tag = "";
    my %attrs = ();
    my $isEmpty = 0;
    my $err = "";
    my @attrOrder = ();

    # The element type name
    $s =~ s/^\s*<$cex{xname}//;
    $tag = $attrs{"#TAG"} = $1; # Special
    $self->xWarn(2, "***** Tag '$1'");

    # Each attribute
    while ($s =~ s/^\s*$cex{xname}\s*$cex{eq}\s*$cex{qlit}//) {
        my $aname  = (defined $1) ? $1:"";
        my $avalue = (defined $2) ? $2:"";
        $avalue =~ s/^[\'\"](.*)[\'\"]$/$1/; # strip quotes
        $self->xWarn(2, sprintf("  Attr %-16s '%s'", $aname, $avalue));
        $attrs{$aname} = $self->expandBasicEntities($avalue);
        push @attrOrder, $aname;
    }

    # See if all that's left is \s* plus "/>" or ">"
    if ($s =~ m/^\s*(\/>|>)\s*$/) {
        $isEmpty = ($1 eq "/>") ? 1:0;
    }
    else {
        $self->setError(
            "SYN", "Can't find end of start-tag at '$s' in:", $s2);
    }

    return($tag, \%attrs, $isEmpty, $err, \@attrOrder);
} # parseStartTag


sub openElement {
    my ($self, $tag) = @_;
    my @ok = [ $self->{docName}, $self->{headName}, $self->{recName}, "???" ];
    my $depth = scalar(@{$self->{tagStack}});
    if ($depth==0 || $tag ne $self->{tagStack}->[$depth-1]) {
        push(@{$self->{tagStack}}, $tag);
    }
}

sub closeElement {
    my ($self, $tag) = @_;
    my $top = $self->{tagStack}->[-1] || "";
    if ($tag ne $top) {
        $self->setError("DTD", "End-tag found for '$tag', '" .
                      $self->{tagStack}->[-1] . "' expected.", $top);
    }
    else {
        pop @{$self->{tagStack}};
    }
}


# Deal with attrribute list already parsed: default, validate, etc.
# Called from getNext() for <Rec> elements.
# (maybe should be passed $line for error messages)
#
sub processAttributes {
    my ($self, $attrs, $line) = @_;

    if ($self->{attrNames}) {                     # Any undeclared attributes?
        for my $a (keys(%{$attrs})) {
            next if ($a eq "#TAG");
            next if (defined ($self->{attrNames}->{$a}));
            $self->setError("UNKATTR","Unknown attribute '$a' (='" .
                          $attrs->{$a} . "') in '$line'");
        }
    }

    for my $k (keys %{$self->{attrNames}}) {
        my $spec = $self->{attrNames}->{$k};       # Fetch the declaration

        if ($spec !~ m/^#/) {                      # Regular default value
            if (!defined $attrs->{$k}) {
                $attrs->{$k} = $spec;
            }
        }

        else {                                      # "#": Validate
            $spec =~ m/^(#)(\w+)(\(.*?\))?([!?*+])?(.*)$/;
            my ($rni, $typename, $arg, $rep, $dft) = ($1, $2, $3, $4, $5);
            if (!$rep || $rep eq "!" || $rep eq "+") { # Required!
                if (!defined $attrs->{$k}) {
                    $self->setError(
                        "REQATTR",
                        "Attribute '$k'=\" required but missing in '$line'");
                }
            }
            if (!$attrs->{$k}) {                       # Default
                $attrs->{$k} = $dft;
            }

            next unless ($self->{typeCheck});
            if ($typename eq "BASE") {                 # Apply BASE
                if (!defined $attrs->{$k}) {
                    $attrs->{$k} = $arg . $attrs->{$k};
                }
            }
            elsif ($typename eq "REQUIRED") {          # REQUIRED
                if (!defined $attrs->{$k}) {
                    $self->setError("REQATTR", "#REQUIRED attribute '" .
                                    $k . "' is missing in '$line'");
                }
            }
            elsif (ref($self->{dt})) {                 # Check datatype
                my @parts = ();
                if ($rep && ($rep eq "*" || $rep eq "+")) {
                    @parts = split(/\s+/, $attrs->{$k});
                }
                else {
                    @parts = ($attrs->{$k});
                }
                for (my $i=0; $i<scalar(@parts); $i++) {
                    my $part = $parts[$i];
                    if (!$self->doTypeCheck($typename,$arg,$part)) {
                        $self->setError(
                            "ATTRTYPE", "Attribute '$k'=\"" . $attrs->{$k} .
                            "\" does not match type '$spec' in '$line'");
                    }
                }
                # assign anyway???
            }
        } # validate
    } # for each declared attr

    $self->xWarn(2, "Reconstructed: " . $self->makeXsvRecord($attrs));
    return($attrs);
} # processAttributes

sub doTypeCheck { # Returns: 1 if ok, 0 if not.
    my ($self, $typ, $arg, $value) = @_;
    if (!defined ($arg)) { $arg = ""; }

    if ($arg eq "ID") {
        if (defined $self->{ids}->{$value}) {
            $self->setError("DUPID", "ID attribute '$value' is not unique.");
        }
    }
    elsif ($arg =~ m/IDREFS?/) {
        for my $token (split(/\s+/, $value)) {
            $self->{idrefs}->{$token}++;
        }
    }

    if ($value && $typ &&
        !$self->{dt}->checkValueForType($value, "$typ\[$arg\]")) { ### check
        return(0);
    }
    return(1);
} # doTypeCheck

sub getUnresolvedIDREFS {
    my ($self) = @_;
    my $fails = "";
    for my $ref (sort keys %{$self->{idrefs}}) {
        if (!defined $self->{ids}->{$ref}) {
            $fails .= "$ref ";
        }
    }
    return($fails);
} # getUnresolvedIDREFS


###############################################################################
# Input data
#
sub open {
    my ($self, $path, $encoding) = @_;
    open(my $FH, "<$path") || return(undef);
    if (!$encoding) { $encoding = 'utf8'; }
    binmode($FH, ":encoding($encoding)");
    $self->{inFile} = $path;
    $self->{inFH} = $FH;
    $self->{text} = "";
    $self->{lineNum} = 0;
    return($FH);
}

# You can attach anything here that works like a file. Must support:
#     open (unless you attach instead of calling here), close, readline.
#
sub attach {
    my ($self, $FH) = @_;
    $self->{inFile} = "???";
    $self->{inFH} = $FH;
    $self->{text} = "";
    $self->{lineNum} = 0;
    return($FH);
}

sub setInputText {
    my ($self, $text) = @_;
    $text =~ s/\r\n?/\n/g;
    $self->{text}   = $text;
    $self->{inFile} = undef;
    $self->{inFH}   = undef;
    $self->{lineNum} = 0;
    return(1);
}

sub getLogicalLine {
    my ($self) = @_;
    my $buf = "";
    my $inWhat = "";
    while (1) {
        my $line = $self->getPhysicalLine();
        $self->xWarn(3, "Physical line (in '$inWhat'): '" .
                     (defined $line ? $line:"UNDEF") . "'");
        if (!defined $line) {
            if ($buf eq "") { return(undef); }    # EOF
            last;
        }
        if ($buf eq "" && $line =~ m/^\s*$/s) {   # Whitespace content
            next;
        }
        $buf .= $line;

        if (!$inWhat) {                           # Nothing yet
            if ($buf =~ m/^\s*$cex{como}/so) {         # Start comment
                $inWhat = "COMMENT";
            }
            elsif ($buf =~ m/^\s*<$cex{xname}/so) {    # Start start-tag
                $inWhat = "STARTTAG";
            }
            elsif ($buf =~ m/^\s*<\/$cex{xname}/so) {  # Start end-tag
                $inWhat = "ENDTAG";
            }
            elsif ($buf =~ m/^\s*<\?xml .*\?>\s*$/so) {# XML decl
                $inWhat = "";
                last;
            }
            else {
                $self->xWarn(1, "Bad syntax in '$buf'");
            }
        }

        if ($inWhat eq "COMMENT") {               # Continue comment
            if ($buf =~ m/$cex{comc}/o) {              # Finish comment
                $self->xWarn(3, "Got COMC");
                if ($buf =~ m/<!--.*--.*-->/so) {
                    $self->setError("COM", "Illegal '--' in comment.",$buf);
                }
                last;
            }
        } # COMMENT
        elsif ($inWhat eq "STARTTAG") {           # Continue start-tag
            # Continue until non-quoted '>'
            my $b2=$buf;
            $b2 =~ s/^\s*<$cex{xname}//s;
            while ($b2 =~ s/^\s*$cex{xname}\s*$cex{eq}\s*$cex{qlit}//so) {}

            if ($b2 =~ m/^\s*\/?>\s*$/so) {             # Good start-tag
                $self->xWarn(3, "Got TAGC, looks ok.");
                last;
            }
            $self->xWarn(3, "In start-tag, leftovers = '$b2'");
            if ($b2 =~ m/>\s*$/o) {                     # Excusable ">"???
                $self->xWarn(3, "  Got weird TAGC -- is it in quote?");
                if ($b2 !~ m/^\s*$cex{xname}\s*$cex{eq}\s*('[^']*|"[^"]*)$/o) {
                    $self->setError("TAGC", "  Weird TAGC is NOT in quotes, " .
                                    "leftovers: '$b2'", $buf);
                    last;
                }
            }
        } # STARTTAG
        elsif ($inWhat eq "ENDTAG") {             # Continue end-tag
            if ($buf =~ m/>/o) {                       # Finish end-tag
                last;
            }
        } # ENDTAG
        else {
            $self->setError("BUG", "  Bad inWhat value '$inWhat'\n");
            last;
        }
    } # while 1

    $buf =~ s/^\s+//;
    $buf =~ s/\s+$//;

    $self->xWarn(2, "Logical line:\n$buf");
    return($buf);
} # getLogicalLine

sub getPhysicalLine {
    my ($self) = @_;
    $self->{lineNum}++;
    if ($self->{inFH}) {
        if (ref($self->{inFH}) eq "GLOB") {
            my $fh = $self->{inFH};
            return(<$fh>);
        }
        return($self->{inFH}->readline());
    }

    if (!defined $self->{text}) {
        return(undef);
    }

    my $buf = "";
    my $eol = index($self->{text}, "\n");
    if ($eol>=0) {
        $buf = substr($self->{text},0,$eol+1);
        $self->{text} = substr($self->{text},$eol+1);
    }
    else {
        $buf = $self->{text};
        $self->{text} = undef;
    }
    return($buf);
} # getPhysicalLine


###############################################################################
# Handle numeric and predefined XML entities.
# Also in sjdUtils.pm,. but since this is all we need from there....
# Better to match all entities, and pass each one individually to decode,
# and complain about any not replaced.
#
sub expandBasicEntities {
    my ($self, $s) = @_;
    # Check for funky errors
    if (index($s, '\\')>=0) {
        $self->xWarn(2,"Warning: backslash in: '$s'");
    }
    if ($s =~ m/&#x(?![0-9a-f]+;)/i) {
        $self->xError(1,"Bad hex reference in: '$s'");
    }
    if ($s =~ m/&#\d(?![0-9]*;)/i) {
        $self->xError(1,"Bad decimal reference in: '$s'");
    }
    if ($s =~ m/&[^#](?![\w]*;)/i) {
        $self->xError(1,"Bad entity reference in: '$s'");
    }
    # NOTE: This allows omitting the final ";"!
    $s = HTML::Entities::decode_entities($s);
   return($s);
}


###############################################################################
# Assemble a record for output
#
sub setAttrOrder {
    my ($self, $namesRef) = @_;
    for (my $i=0; $i<scalar(@{$namesRef}); $i++) {
        my $name = $namesRef->[$i];
        if (!defined $self->{attrNames}->{$name}) {
            $self->xError(1,"Unknown attr name: '$name'");
            return(0);
        }
    }
    $self->{attrNames} = $namesRef;
    return(1);
}

sub makeXsvRecord {
    my ($self, $hashRef, $omitNils) = @_;
    $self->xWarn(2, "makeXsvRecord: hash has " .
                 join(", ", sort(keys(%{$hashRef}))) . ".\n");
    my $buf = "<" . $self->{options}->{recName};
    for my $k (@{$self->{attrOrder}}) {
        my $v = $hashRef->{$k} || "";
        next if ($omitNils && $v eq "");
        $v =~ s/&/&amp;/g;
        $v =~ s/</&lt;/g;
        $v =~ s/"/&quot;/g;
        if ($self->{options}->{njustify} && $v =~ m/^\s*\d+\s*/) {
            if (length($v) < 8) {
                $v = ("0" x (8-length($v))) . $v;
            }
        }
        $buf .= ($self->{options}->{breakAttrs} ? "\n    ":"") . " $k=\"$v\"";
    }
    return($buf . " \/>\n");
} # makeXsvRecord

1;



###############################################################################
###############################################################################
###############################################################################
#

=pod

=head1 Usage

XmlTuples.pm

Parses a tiny subset of XML, known as C<XSV>.
XSV is sufficient for expressing simple sets of data records, comparable
to CSV and its kin.

XSV data is always well-formed XML, so works with any full-fledged XML parser
(example below).
At the same time, because XSV uses only a tiny subset of XML features,
it can also be parsed by very simple programs (such as this), or even regexes.

XSV is highly human-readable and has fairly strong syntax and datatype checking.
XSV may cost more or less space than CSV or similar formats.
More, because each field instance is accompanied by its name;
less, because field instances that are empty or defaulted can be entirely
omitted, and because the BASE feature (see below) lets you
factor out common prefixes from URIs or other values.

XSV also avoids CSV's variability
(quotes, commas, tabs, newlines, backslash variations,
non-ASCII characters, etc.).

There are options to change the names used for the relevant XML elements,
and several other details,
which enables parsing variations. For example,
the XML version of the Unicode character database
(L<http://www.unicode.org/ucd/>)
can be parsed by changing this package's tag name options and
tweaking the file headers. An even wider range of tabular formats can be read
using the C<TabularFormats.pm> package.

This is the reference implementation of XSV.


=head2 Example

(the names "Head" and "Rec" can be changed via the API)

=head3 Data

  <!-- XSV
     A list of Unicode characters and entity names for them.
     Last updated 2012-08-15.
  -->
  <Xsv>
  <Head Hex="" Unicode="" EntName="" Descr="">
    <!-- Information on Unicode characters.
      -->
    <Rec Hex="80" Unicode="00C4" EntName="Auml"  Descr="A with diaeresis"
       Literal="&#x00c4;"/>
    <Rec Hex="81" Unicode="00C5" EntName="Aring" Descr="A with ring"/>
  ...
  </Head>
  </Xsv>


=head3 Code to access XSV data via this package

  use XmlTuples;
  ...
  my $foo = new XmlTuples($someXsvString);
  my @fieldNames = @{$foo->getHeader()};
  my %someData = ();
  while (my $hashOfFields = $foo->getNext()) {
      ($hashOfFields->{"#TAG"} eq "Rec") || next;
      for my $k (sort keys %{$hashOfFields}) {
          $someData{$hashOfFields->{"EntName"}} = $hashOfFields->{"Descr"};
          print "$k: $hashOfFields->{$k}\n";
      }
  }

=head3 Alternative code example

This reads the entire XSV in one shot, returning a reference to a hash
keyed by the value of the XSV "EntName" attribute, and then shows how
to get at a value from the "Auml" record:

  use XmlTuples;
  ...
  my $foo = new XmlTuples();
  $foo->open("/tmp/mystuff.xsv") || die "Oops\n";
  my $hRef = $foo->getAllAsHash("EntName");
  ...
  my $prop = $hRef->{"Auml"}->{"Unicode"};


=head3 Using a generic XML parser

This example does the same thing as the prior one, but using a plain XML
parser instead of an XSV implementation.
Most of the extra code is to track the header and apply defaults.
It does not do XSV attribute-name or datatype validation, though of course
you get XML Well-Formedness checking from the parser:

  use XML::DOM;
  use XML::DOM::Parser;
  my $domParser = new XML::DOM::Parser;
  my $dom = $domParser->parsefile("/tmp/mystuff.xsv");

  # Process the header (and discard datatype specs)
  my $headAttrs = $doc->getElementsByTagName("Head")->
      item($i)->getAttributes();
  for (my $anum=0; $anum<$headAttrs->getLength; $anum++) {
      my $avalue = $headAttrs->item($anum)->getNodeValue();
      $avalue =~ s/^#.*?#//;
      $headAttrs->item($anum)->setNodeValue($avalue);
      $nodes->item($i)->getAttributes();
      my $key = $attrs->getNamedItem("EntName");
  }

  # Apply defaults
  my $nodes = $doc->getElementsByTagName("Rec");
  my $hRef = {};
  for (my $i=0; $i<$nodes->getLength(); $i++) {
      my $attrs = $nodes->item($i)->getAttributes();
      my $key = $attrs->getNamedItem("EntName");
      $hRef->{$key} = {};
      # Copy the Rec's attributes into a hash, applying defaults.
      for (my $anum=0; $anum<$headAttrs->getLength; $anum++) {
          my $hname = $headAttrs->item($anum)->getNodeName();
          my $hvalue = $headAttrs->item($anum)->getNodeValue();
          $hRef->{$key}->{$aname} = (defined $attrs->getNamedItem($hname))
              ? $attrs->getNamedItem($hname) : $hvalue;
     }
  }

  $dom->dispose();
  ...
  my $prop = $hRef->{"Auml"}->{"Unicode"};


=head2 Formal identification

If you want a formal way to refer to this specific subset and
application of XML, I prefer "XSV" for the name, ".xsv" for
the file extension, a MIME type of "text/xsv+xml" (see L<RFC 3023>),
and a namespace URI of "http://derose.net/namespaces/XSV-1.0".



=for nobody ===================================================================

=head1 Methods

=over

=item * B<my $xt = new XmlTuples> I<(text?)>

Set up the XSV parser, with an (optional) block of text to parse.
If I<text> is not passed to the constructor, you can use
I<open(path)> or I<setInputText(text)> to provide data.

=item * B<getErrorCode>()

Returns a short mnemonic code identifying any error encountered during
the last I<getNext()> or similar call ("" if there was no error).

=item * B<reset> I<(text?)>

Clear everything (except options) as if a new instance had been
created. As with I<new>, the I<text> argument is optional.

=item * B<setOption>I<(name, option)>

Set the specified option. Options are listed below.
Some apply only to output (see I<makeXSVRecord>).
Some allow changing syntax details (such as the reserved tag names and
delimiters); these are only provided to facilitate import of XSV-like data.

=over

=item * I<verbose> determines the level of messaging to use.
It defaults to 1, which means
errors are displayed (set to 0 to suppress them; the caller can still
check for XSV parsing problems via I<getErrorCode>).

=item * I<typeCheck> In XSV, <Head> elements (only) reserve the use of
C<#> as the first character of attribute values.
If I<typeCheck> in on (the default),
then such attributes are used for datatype validation.
See below under L</"Reserved Head Attribute values">.

=item * I<dt> enables XSV datatype checking.

=item * I<breakAttrs> causes a newline and indentation before each
attribute generate with I<makeXSVRecord>().

=item * I<njustify> determines whether numeric fields (attributes) will
be right-justified by I<makeXsvRecord>().

=item * I<defaultList> specifies the default values to be written in an
output C<Head> and omitted from C<Rec>s. (not yet implemented).

=back

The following options can be use to change syntactic details, which
can be useful to support similar syntaxes, but is not generally recommended:

=over

=item * I<reservedChar> Default "#". The character use to mark Head
attribute values as containing validation and datatyping information.

=item * I<assignChar> "=", used in parsing attribute name="value" pairs. Despite
the name, this can be a string, not just a single character.

=item * I<xsvName> is the name to use for the element normally known as "Xsv".

=item * I<headName> is the name to use for the element normally known as "Head".

=item * I<recName> is the name to use for the element normally known as "Rec".

=item * I<loose> permits various unusual quotations marks, assignment operators
other than "=", etc.

=back

=item * B<getOption>I<(name)>

Return the value of the specified option (see I<setOption>).


=item * B<isXsv>I<(ref)>

Return 1 iff I<ref> is a hash (as returned by I<getNext>()) which
represents an I<Xsv> element.

=item * B<isHead>I<(ref)>

Return 1 iff I<ref> is a hash (as returned by I<getNext>()) which
represents an I<Head> element.

=item * B<isRec>I<(ref)>

Return 1 iff I<ref> is a hash (as returned by I<getNext>()) which
represents an I<Rec> element.


=item * B<getErrorCount>()

Return how many actual errors have been encountered (I<reset>()) includes
resetting this count).

=item * B<open> I<(path)>

Take input from the file at I<path>. Any prior text, file, and line number
are cleared. Returns the file handle, or undef on failure.

=item * B<attach> I<fh>

Make the file handle I<fh> the input source.

=item * B<setInputText> I<(text)>

Provide some data as text to be parsed.
Any prior text, file, and line number are cleared. Returns success flag.

=item * B<getHeader>()

Read, skipping comments and/or <Xsv>, and return an array of the field
(attribute) names defined by the <Head> element. In case of hitting EOF or
a <Rec> element, I<undef> is returned.

=item * B<getAllAsArray>()

Use I<getNext>() to parse all the records in the available I<text>
or I<path> (see above). Return a reference to an array of the records,
in the same order as found in the input. Each entry in that array is
a hash of the attributes (including defaults) found for that record.

=item * B<getAllAsHash> I<(name[s])>

Use I<getNext>() to parse each record in the available
I<text> or I<path> (see above). Return a reference to a hash table
with an entry for each record. The I<name> argument(s) specify
fields to be concatenated in order, separated by '#', to create the hash key.
The value is a reference to a
hash of the attributes from the record. Null or duplicate keys result
in an error message, and their records are not added.

B<Note>: Returns C<undef> on seeing C<< </Head> >> or end of data. So,
you can have multiple XSV sets in a single file and call this repeatedly,
once for each set (until you get an empty set). In that case, the entire
thing I<must> be enclosed in an element of type C<Xsv> (which is otherwise
optional).

=item * B<buildHash> I<(keyAttrName,valueAttrName)>

For each record, extract the two attributes named, and add them as
key/value pairs to a hash. Return a reference to the hash.
This is just a regular hash from attribute names to values,
not a hash of such hashes as with <getAllAsHash( )>
Duplicate keys result in a warning, and the first instance's value is kept.

=item * B<getNext>()

Parse the next record from the original I<text>, and return a hash of its
named attributes, plus an entry for "#TAG" whose value is
the element type of the tuple (normally "Rec").

=item * B<readNext>(s?) (internal)

Read and return the next logical unit (tag). Skip quietly past comments
and white space. If I<s> is provided, just use it instead of reading.
This is called internally by I<getNext>() to get data to parse.

=item * B<getLastRecord>()

Return the text of the last record read (typically by I<getNext>()),
as a string.

=item * B<getFieldNamesArray>()

Return a reference to an array containing the names that were defined
by the most recent "Head" element (as always, [0] is empty). The names
are in the order they occurred on the Head element.
If an XSV document contains multiple "Head" elements, this only returns
data for the current one.

=item * B<getDCInfo>()

Return a reference to a hash of the Dublin Core metadata values (if any)
that were specified on the "Xsv" element (see below).

=item * B<setAttrOrder> I<(nameList)>

Given a reference to an array of attribute names, set the order in which
those attributes are written out by I<makeXsvRecord>.
Returns 1 on success, or 0 on failure (for example if any name in I<nameList>
is not known). Not all known names need to be included; any others will
simply not be included in generated records.

=item * B<makeXsvRecord> I<(hashRef, omitNils)>

Take a hash, and make it into an XSV "Rec" element (escaping as needed).
This creates a data record readable by this script (you still need to put
it all into C<Xsv> and C<Head> containers, and ideally add metadata and
type declarations).

If I<omitNils> is specified, attributes whose value is "" will not be
written at all.

B<Note>: Parsing XSV and then exporting the data using I<makeXsvRecord>
will not always produce I<exactly> the same file, in part because
attribute order, quoting, entities, and whitespace are normalized.

=back



=for nobody ===================================================================

=head1 Syntax Rules

Except as stated here, XML is implemented unchanged.
All exceptions are by way of I<subsetting>,
so that all Well-Formed XSV is also Well-Formed XML
(thus, you can parse XSV with any full-fledged XML parser; but you can
also parse it with trivial code such as a handful of regular expressions).

=over

=item * A document is not correct XSV unless it is well-formed XML.

=item * The character encoding I<must> be UTF8, and non-XML characters
I<must not> occur.

=item * Only XML declarations,
XML comments, and elements of types "Xsv", "Head", and "Rec" are allowed.
No PIs, markup declarations,
non-whitespace text content (not even entities that resolve to whitespace),
CDATA marked sections, etc.

=item * Each XML declaration, tag, and comment I<must> start on a new line
(leading white space is ok),
but may be continued onto following lines (line-breaks within tags
may occur exactly where they could in XML).
In other words, a tag or comment may take multiple lines, but
a single line cannot contain part or all of more than one tag or comment.
For example, this in incorrect:

    <Rec a="b" c="d"> <!-- hello -->

but this is correct:

    <Rec a="b" c
    ="d">

    <!-- hello
      -->

Breaking lines within an attribute value is permitted but not recommended.
B<Note>: This implementation fails on encountering ">" at the end of a
line within an attribute value; the workaround for now is to remove the
line-break or use "&gt;".
XSV applications I<may> or may not normalize whitespace in such values.

=item * Within attribute values (only), XML numeric character references,
XML predefined named entity references, and HTML 4 named entity references
may be used. No other entity references are permitted.

=item * Blank lines (containing only whitespace) and comments may occur
anywhere they can occur in XML, except that each comment I<must>
start a new line.
Comments I<may> be discarded or passed to an application;
they do not otherwise affect XSV processing.

=item * XSV data I<should> begin with a comment
whose first line is (a single space after the "<!--" and then) "XSV".

=item * An XSV document I<should> have an outermost element of type "Xsv",
which I<should> have attributes giving information about the nature, author,
version, and source of the XSV data, via names drawn from the Dublin Core
/elements/1.1 properties, used in accordance with the corresponding
definitions (on which see
L<http://dublincore.org/documents/2012/06/14/dcmi-terms/?v=elements#H3>).
No other attributes may be specified on the "Xsv" element.

B<Note>: The acceptable attributes are thus named:
I<contributor>, I<coverage>, I<creator>, I<date>, I<description>, I<format>,
I<identifier>, I<language>, I<publisher>, I<relation>, I<rights>, I<source>,
I<subject>, I<title>, and I<type>.

=item * All of the "Xsv" element's child elements I<must> be of type "Head".
If there is no "Xsv" element, then the outermost element
I<must> be a (single) "Head" element.

=item * A "Head" element I<must> have start and end tags (not be
an XML "empty element").
and I<must> have at least one attribute
(its attributes serve as declarations for what attributes are permitted
on contained "Rec" elements).

=item * A "Head" element's child elements (if any)
I<must> all be "Rec" elements.

=item * A "Rec" element I<must> use XML empty element form, and must have only
attributes whose names appear as attribute names on the immediately
containing "Head" element. As in XML, the order of attributes is irrelevant.

=item * Attributes on a "Head" I<must> have a value (possibly "").
If such a value begins with "#", then the value up to the next "#" is
a I<datatype specification>. If there is no second "#", the entire value
is taken as the I<datatype specification>.
Any data after the second "#", or the whole value if the value does not
begin with "#", specifies the I<default value> for the like-named attribute.

If a "#" is required with a I<datatype specification>, it can be represented
via a numeric or named character reference such as I<&#x23;>. Thus, XSV
parsers should separate the a I<datatype specification> from the
I<default value> B<before> expanding character references.

I<All> XSV applications I<must> notice and separate a datatype specification
from a I<default value> in "Head" attribute values whenever it is present.

XSV applications I<may> discard I<datatype specification>s, but
I<should> instead use them to check values for the given attribute name
as defined in the next section.
It is strongly recommended that all XSV implementations at least support
the semantics of the B<BASE> datatype specification; XSV implementations
that do not support BASE, I<must> at issue a message or warning if
they encounter one.

XSV applications I<must> must return the default value as specified on <Head>,
as the value of the like-named attribute for any and all directly-contained
<Rec> elements which do not specify the like-named attribute at all.
This is true whether or not the default value conforms to the applicable
datatype specification (if any).

=back


=for nobody ===================================================================

=head2 Datatype Specifications

When "Head" provides a I<datatype specification> for a particular
attribute (as just defined),
it never affects what data is actually expressed by the XSV, except in
the case of "BASE" (see below). Rather, it is for datatype checking
(analogous to XML schemas). For example, the following declaration
ensures that each "Foo" attribute on each contained <Rec> element
contains one or more whitespace-separated integers (cf XSD),
and defines the default value to be "1":

    <Head Foo="#integer+#1">

The next example ensures that "Lunch" attributes contain a single token
either "Spam" or "Eggs", or default to "Spam" if empty. It also
sets a default of "1" for the "NVikings" attribute, without placing any
restrictions on what values may be explicitly specified for "NVikings":

    <Head Lunch="#ENUM(Spam Eggs)#Spam" NVikings="1">

A I<datatype specification> includes, in the order shown:

=over

=item B<< # >> -- the starting delimiter (required);

=item B<< typename >> -- the type name, which I<must> be one of these (see
additional discussion below):

    the XSD built-in datatype names
    ENUM, STRING, ASCII, REGEX, BASEINT
    BASE
    REQUIRED

=item B<< (arg) >> -- an optional argument, enclosed in parentheses.
A few of the datatypes require an argument (BASE, ENUM, and STRING).
Empty parentheses may, however, be specified with any typename.
The argument may never contain "#", even via a numeric character reference
or entity.

=item B<< repetition >> -- an optional single character indicating how
many repetitions of the named datatype I<must> occur (separated by white-space).
Requiring one or more repetitions, however, does not preclude omitting
the attribute so that a default value (if provided) is used.

    "!" or "" (no character) indicates the attribute I<must> have one match.
    "?" indicates the attribute may be empty, or have one match.
    "*" indicates the attribute may be empty, or have any number of matches.
    "+" indicates the attribute I<must> have at least one match.

=item B<< # >> -- the ending delimiter, separating the datatype specification
from the default value.

=item B<< default >> -- the XSV default value (possibly empty).
Defaults I<must not> be applied when an attribute is present and explicitly
set to "".

=back

To specify a default value that begins with "#", put a (possibly empty)
datatype specification in front of it, as in I<myAttr="###FOO">. An
empty datatype specification allows any value.

Permitted "#"-initial values match this (PCRE-style) regex, in which
the last capture group is the default value:

    /^(#)([-\w]+)(\([^#]*?\))([!?*+])?#(.*)$/

All XSV applications I<must> find and apply I<default> values from "Head",
whether they are preceded by a datatype specification or not.

XSV applications I<may> also support datatype checking; if they do then they
I<must> also apply the validation checks defined below
when evaluating the like-named attribute on subsequent <Rec> elements.

The specific behavior upon finding an attribute value (including a default)
that does not match the applicable datatype specification,
is not defined by XSV, but is left to the individual implementation.

XSV applications that do not support datatype checking I<may> ignore, report,
or discard the datatype specifications, so long as they still handle
default values properly.


=for nobody ===================================================================

=head3 Description of supported datatypes

Nearly all the XSV datatypes are taken exactly from C<XSD>
(L<http://www.w3.org/TR/xmlschema-2/>).
Others are named in all caps (see below).

=over

=item * Logical types:
boolean (true, false, 1, or 0, the first two being canonical).

=item * Real number types:
decimal, double, float.

=item * Integer types:
byte, int, short, integer, long,
nonPositiveInteger, negativeInteger, nonNegativeInteger, positiveInteger,
unsignedByte, unsignedShort, unsignedInt, unsignedLong.

=item * Dates and times:
date, dateTime, time, duration, gDay, gMonth, gMonthDay, gYear, gYearMonth.

=item * Strings:
language, normalizedString, string, token.

=item * XML constructs:
NMTOKEN, NMTOKENS, Name, NCName, ENTITY, ENTITIES, QName;
ID, IDREF, IDREFS.
Because XSV supports repetition operators, NMTOKENS, ENTITIES, and
IDREFS are partially redundant (you may specify repeatability either way).

Because XSV does not support DTDs, the types
ENTITY, ENTITIES, ID, IDREF, and IDREFS
are not necessarily distinct from NCName(s).
However, an XSV implementation I<may>
check ID attributes for uniqueness and IDREF/IDREFS for resolvability.

=item * Net constructs:
anyURI, base64Binary, hexBinary.

=back


=head4 Extension datatypes (that is, ones not defined by XSD):

=over

=item * ENUM(I<arg>) -- any member of the whitespace-separated list of tokens
listed (space-separated) in I<arg>. All of the tokens I<must> be XML NAMEs,
and there I<must> be no duplicates in a single ENUM datatype specification.
As with other types, a following repetition indicator I<may> be used.

If the datatype specification allows repetition, then a single attribute value
may even have the I<same> particular token more than once; whether this has
a special meaning is not defined by XSV.

=item * STRING(I<regex>) -- any string conforming to the (PCRE) I<regex>.
I<regex> I<must not> contain parentheses (this is less of a problem than
in a more general application, since capture-groups are not needed), or "#".
Those character I<must not> even be included via named or numeric character
references.
Of course, the string also I<must not> contain non-XML control characters.

=item * ASCII(I<regex>) -- an ASCII string conforming to the (PCRE) I<regex>.
See also I<STRING>.

=item * REGEX -- a regular expression (this does I<not> take an
argument, because it means that the values checked must
I<be> (PCRE) regexes, not I<match> a certain regex (see also STRING[regex]).

=item * BASEINT -- an integer in decimal (no leading zeros),
hex (0xF...), or octal (07...) form.
Binary (0b1...) is I<not> allowed. This declaration only affects validation;
the value is I<not> normalized or converted by XSV implementations.

=back

The final datatype is quite special:

BASE(I<string>) -- The I<string> argument must be prefixed to all
non-empty values of the attribute. This is a special case
inspired by the HTML "base" attribute. However, "BASE" can be used whether
the values are URIs, STRINGs, or whatever.
It simply causes a string concatenation (this might be odd with some types,
such as boolean or numeric types, but it is not illegal).
Because this type, like other types, is specified on the declaration for
a particular named attribute, you can have different BASE values for
different named attributes.

"BASE" still allows a normal default value following the argument.
However, since it uses the syntactic position of a datatype name,
you cannot also specify a datatype name, and although you may specify a
repetition character it is not used for anything.



=for nobody ===================================================================

=head1 Related commands

=head2 Perl stuff

C<HTML::Entities> -- provides mappings for the HTML special-character
entities.

=head2 SJD stuff

C<testXsv> -- a simple driver that uses this package to parse an XSV file,
and displays the records, record numbers, and fields.

C<XmlTuples.py> -- Python version (not presently up-to-date, particularly
for datatype checking).

C<TabularFormats.pm> -- uses this package to support the XSV format, along
with many others (ARFF, fixed-column layouts, countless CSV variants,
and MIME headers;
as well as simple forms of more sophisticated formats such as
JSON, Manchester OWL, Perl declaratios, S-expressions,
and even XHTML tables or structurally-similar XML).
In turn, many of my scripts
use C<TabularFormats.pm> to support multiple data formats.

C<Datatypes.pm> -- provides support for datatype checking.

Some useful XSV data files are available from
L<http://www.derose.net/steve/resources/XSV>.



=for nobody ===================================================================

=head1 Known bugs and limitations

=over

=item * Single-character attribute names seem broken in this version!

=item * Does not catch all XML Well-Formedness errors.
For example, a numeric character reference to
a non-XML character such as C<&#5;> or C<&#xDEADBEEF;>.
Because of this, as well as because it only supports a small subset of XML,
this script is not a fully-conforming XML parser. However, any valid
XSV data can be parsed by a normal, fully-conforming XML parser
(L<"Using a generic XML parser">, above).

=item * Datatype checking is still experimental.

=item * You can't have a '>' at end of line unless it's closing a tag. So
if you want a '>' inside an attribute, either escape it as '&gt';, or be sure
not to break that attribute value across lines at exactly that point. Sorry.
Possibly fixed?

=item * I should provide BNF for the subset of XML parser here.

=back



=for nobody ===================================================================

=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut
