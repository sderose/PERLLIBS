#!/usr/bin/perl -w
#
# DataSource.pm (split from TabulFormats.pm)
#     Support for TabularFormats input sources.
#
# Written 2010-03-23 by Steven J. DeRose, as csvFormat.pm
#     (many changes/improvements).
# ...
# 2012-06-08 sjd: Add readBalanced(), readToUnquotedDelim().
#     Finish hooking up and documenting 'DataSource' package.
#     Finish readRecord() (incl. comments) for JSON, MANCH.
#     Make readRecord() really do exactly one record (sexp, xml, mime, manch...
# 2013-01-18 sjd: Add tell(), mainly for RecordFile.pm.
# 2013-02-06ff sjd: Don't call sjdUtils::setOptions("verbose").
#     Work on -stripRecord.
#     Break out DataSchema package, and tell it and DataSource what they need,
#     so they don't have to know 'owner' any more. Clean up virtuals a bit.
#     Also break out DataOptions and DataCurrent packages. Fix order of events
#     in pull-parser interface. Format-support packages to separate file.
#     Support repetition indicators on datatypes.
# 2013-02-14 sjd: Sync package DataSource's API, closer to RecordFile.pm.
# 2013-04-02 sjd: Forward a few more calls down to sub-packages (for tab2xml).
#     Add dprev for prior data record. Centralize setFieldNamesFromArray() call
#     from parseHeader() and readAndParseHeader() -- not in TFormatSupport.pm.
# ...
# 2017-04-19: Split DataSource to separate file DataSource.pm.
#
# To do:
#     Integrate with/into RecordFile.
#     Protect against UTF encoding errors.
#     Handle blank records better (integrate readRealLine).
#     Replace getRecordAsString (and Array).
#     FormatSniffer.
#
# Low priority:
#     Way to get the original offset/length of each field in record?
#
#
# Should integrate into RecordFile.pm, then ditch this package.
# Should look pretty much like a regular file.
#
# Syncing APIS:
#
# UsedHere  DataSource       RecordFile         Files
#    Y        new              new
#    Y        open             open               open
#    Y        binmode          binmode            binmode
#    Y        close            close              close
#    Y        seek             seek               seek
#    Y        tell             tell               tell
#    Y        readline         readline           readline
#
#    Y        attach           attach
#    Y        addText
#             pushback
#              (only used by MANCH format, so far).
#
#             readRealLine
#             readBalanced
#               findCloser
#             readToUnquotedDelim
#                              setInterruptCB
#                              seekRecord
#                              tellRecord
#                              readRecordsAsArray
#                              readOneRecord
#                              readNthRecord
#
use strict;
use feature 'unicode_strings';
use sjdUtils;

package DataSource;

sub new {
    my ($class) = @_;

    my $self = {
        path         => undef,
        FH           => undef,
        encoding     => "",
        buffer       => "",
        hasAnyDataBeenSupplied => 0,
        stripRecords => 0, # set by setOption() as needed.
    };

    bless $self, $class;
    return $self;
}

sub open {
    my ($self, $path, $encoding) = @_;
    if ($self->{FH}) {
        $self->close();
    }
    $self->{buffer} = "";
    $self->{hasAnyDataBeenSupplied} = 0;

    if (!open($self->{FH}, "<$path")) {
        return(undef);
    }
    if (!$encoding) {
        $encoding = "";
    }
    else {
        $self->binmode($encoding);
    }
    $self->{path} = $path;
    $self->{hasAnyDataBeenSupplied} = 1;
    return($self->{FH});
} # open

sub binmode {
    my ($self, $encoding) = @_;
    if (!$self->{FH}) {
        alogging::eMsg(0, " Can't binmode unless a file is open.");
        return(0);
    }
    if (!$encoding) { $encoding = "utf8"; }
    $self->{encoding} = $encoding;
    $self->{FH}->binmode(":encoding($encoding)");
    return(1);
}

sub attach {
    my ($self, $fh) = @_;
    $self->{FH} = $fh;
    $self->{path} = "";
    $self->{hasAnyDataBeenSupplied} = 1;
    return(1);
} # attach

sub close {
    my ($self) = @_;
    $self->{buffer} = "";
    if ($self->{FH}) {
        close($self->{FH});
    }
    $self->{hasAnyDataBeenSupplied} = 0;
}

sub seek {
    my ($self, $n) = @_;
    $self->{buffer} = "";
    return($self->{FH}->seek($n,0));
} # tell

sub tell {
    my ($self) = @_;
    # Doesn't account for text (not file), or for pushbacks.
    return($self->{FH}->tell());
} # tell

# Read and return one physical line, or undef on EOF/EOB.
# Take input from the buffer first, then from the file (if any).
#
sub readline {
    my ($self) = @_;
    my $rc = undef;
    if ($self->{buffer} ne "") {             # string (includes pushback)
        $self->{buffer} =~ s/^(.*?\n)//;
        if ($1) {
            $rc = $1;
        }
        else {
            $rc = $self->{buffer};
            $self->{buffer} = undef;
        }
    }

    if (!$rc && $self->{FH}) {               # if needed, read file
        # SHOULD DO MORE TO PROTECT AGAINST BAD UNICODE
        #alogging::vMsg(0, "Ref of FH is: " . ref($self->{FH}) . ".");
        if (ref($self->{FH}) eq "GLOB") {
            my $fh = $self->{FH};
            $rc = <$fh>;
        }
        else {
            $rc = $self->{FH}->readline();
        }
    }

    if (defined $rc) {
        chomp $rc;
        if ($self->{stripRecords}) { # Set by setOption().
            $rc =~ s/\s+$//;
            $rc =~ s/^\s+//;
        }
    }
    return($rc);
} # readline


###############################################################################
# Methods *not* also found in RecordFile.pm.
#
sub addText {
    my ($self, $text) = @_;
    if ($self->{FH}) {
        $self->close();
    }
    $self->{buffer} .= $text;
    $self->{hasAnyDataBeenSupplied} = 1;
} # add_text

sub pushback {
    my ($self, $text) = @_;
    $self->{buffer} = $text . $self->{buffer};
} # pushback



###############################################################################
###############################################################################
#
if (!caller) {
    system "perldoc $0";
}
1;


###############################################################################
###############################################################################
#

=pod

=head1 Usage

    use DataSource;

Provide file-reading services, especially to I<TabularFormats.pm>.

All of the TabularFormats format-readers use C<DataSource>.
It provides this interface (which can also be
used independently). This will likely be removed from here and integrated
into C<TFormatSupport.pm> or C<RecordFile.pm>.

You can get a reference to the active instance of this package from a
I<TabularFormats> instance, using I<getDataSource>().

=over

=item B<new>()

=item B<open>(path)

Open the file at I<path> and make it the source of data.
Any previously opened or attached file is closed.
Returns: undef on failure, otherwise the file handle to the open file.

=item B<close>()

Close any currently-open input file, and discard any pushed-back or added text.

=item B<seek(n, whence)>

Move the open file to position I<n>, and clear any pushback data.
I<whence> is 0 to count from start of file, 1 to count forward, and
-1 to count backward from end of file.

=item B<tell()>

Return the current offset into the open file.


=item B<attach>(self, fh)

Make the file handle I<fh> the current source of data.
Any previously-open file is detached.

=item B<add_text>(self, text)

Add I<text> to be read.
Any previously-attached or opened file is detached.
If there is text data still unread
from prior I<add_text>() or I<pushback>() calls, the new I<ttext> is appended.

=item B<pushback>(self, text)

Add I<text> to be read I<before> any still-unread text
from prior I<add_text>() or I<pushback>() calls (if a file if open, it
stays open).


=item B<readline>(self)

Read and return one physical line (terminated by \n).
Input comes first from the buffer, then from the open file if any.

=item B<readRealLine>(self, commentDelim)

Read a I<logical> line, as defined for the active format. For example,
some types of CSV files permit newlines within quoted fields,
and I<readRealLine>() accounts for this. Used by I<readRecord>.

=item B<readToUnquotedDelim>(self, endExpr, quoters, qdouble, escapes, comment)

Reads up to (but not including) the first unquoted occurrence of
the regular expression I<endExpr>.

This is used to read to the ";" that ends a Perl declaration, the "@DATA"
that separates header and data in ARFF, etc.

The parameters are as the like-named paramters of I<setupBalance>, plus:

=over

=item I<endExpr> -- a (Perl) regex, the first match to which ends the scan.

=back

=item B<setupBalance>(self, openers, closers, quoters, qdouble, escapes, comment)

Set up the parameters needed for I<readBalanced> (qv).
All parameters must be provided, even if some or all are "".

Openers and closers that are quoted, doubled, or unescaped when those
parameters are in effect, do not count towards balancing.

=over

=item I<openers> -- a string containing the characters that
can open expressions. Default: "(".
Characters in corresponding positions in I<openers> and I<closers>
must correspond (for example, "([{" goes with ")]}", not "])}").

=item I<closers> -- a string containing the characters that
can close expressions. Default: ")".
Characters in corresponding positions in I<openers> and I<closers>
must correspond (for example, "([{" goes with ")]}", not "])}").

=item I<quoters> -- a string containing characters that
function as quotes, disabling the effect of openers and closers
within their scope. Default: "\"".

=item I<qdouble> -- 0 or 1 to indicate whether 2 of
the same quote characters in a row count as data rather than closing
an open quote group.

=item I<escapes> -- a string containing the characters that
cause the character following them to be as data rather than as
an opener, closer, quoter, escape, or comment.

=item I<comment> -- a string (just one) that (when not escaped or in quotes)
causes the rest of the physical lines to be discarded as a comment.

=back

=item B<readBalanced>(self)

If extra parameters are found, then I<setupBalance> will be called
with the same parameter list, before processing as usual.

Return text up through the next balance point in terms
of parentheses, brackets, braces, or similar delimiters.

The input file should be able to read _____,
and will return ready to read the next character after the balancing closing
delimiter.

For example, this method can read a complete SEXP S-expression,
or a complete JSON {} or [] group, allowing for nested constructs,
quotations, backslashing, etc.

If the expression ends in mid-line, this method calls I<pushback>()
for the rest of the line (that may change).

=back


=for nobody ===================================================================

=head1 Related commands

=over

=item * C<RecordFile.pm> -- provices record-oriented i/o, with cached offsets.
Looks basically like a file, but
handles logical rather than physical records.

=back


=for nobody ===================================================================

=head1 Known bugs and limitations

=over

=item * Not safe against UTF-8 encoding errors. Use C<iconv> if needed.

=item * Leading spaces on records are not reliably stripped.

=back


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut

1;
