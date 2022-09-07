#!/usr/bin/env perl -w
#
# RecordFile.pm: Manage a file that's addressable by records.
# Written by Steven J. DeRose, 2012-02-15 (extracted from 'lessCSV').
#
use strict;
use Fcntl;
# Following packages are loaded later (by open()), but only when needed:
#use Archive::Zip;
#use Archive::Tar;
#use Compress::Bzip2;
#use Compress::Zlib;
#use IO::Uncompress::Gunzip;

use sjdUtils;

package RecordFile;

our %metadata = (
    'title'        => "RecordFile.pm",
    'description'  => "Manage a file that's addressable by records.",
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

use RecordFile;

Manage a file that's accessible by record number not just byte offsets.
Mainly useful if you're doing random access, not just reading straight through.

Builds a cache of record offsets as it goes, to speed up seeks.

B<Note>: There is support in progress for reading zip, bzip2, and tar files
directly. The needed cpan modules are, however, only loaded if actually
needed, so there is no need ot install them otherwise
(see I<sjdUtils::try_module>() re. optional loading of packages).


=head1 Examples

  use RecordFile;

  my $rf = new RecordFile("/tmp/myfile.csv");
  $rf->seekRecord(239, 0);
  my $rec = $rf->readRecord();
  print "Record 239 is:\n$rec";
  $rf->close();


=head1 Methods

=head2 The usual methods like for any file

=over

=item * B<open>(path)

Open a new file for reading (closes any prior one).

=item * B<binmode>(e)

Set the encoding for the (already open) input file to I<e>. Default: utf8.

=item * B<close>()

Close any open input file, and clear internal buffers.

=item * See also I<seekRecord>(), I<tellRecord>(), I<readRecord>(), below.
=back

=head2 Additional methods

=over

=item * B<new RecordFile>(path, encoding?)

Make a new instance of the I<RecordFile> object, opening the file at
I<path>. I<encoding> names the character encoding to assume
(default: C<utf8>).

=item * B<attach>(handle)

Use instead of C<open>() if the input file is already open.

=item * B<addText>(text)

=item * B<pushback>(text)

Any text pushed back, will be read first. It doesn't affect record-counting
and such (at least, it's intended not to...).
Not generally recommended.

=item * B<setInterruptCB>(cb)

With this set, potentially long operations
(such as seeking a specific record number, or EOF),
call I<cb> often (say, after each record). If I<cb> returns TRUE,
stop the long operation. The callback might, for example, check to see if the
user has typed or clicked something to interrupt the operation. This should
be used if there's a chance you'll be dealing with very long files.
Functions that call this, are described as "Interruptable" here.

=item * B<seekRecord>(n, whence)

Move to the specified record (cf I<seek>()).
I<Interruptable>.

=item * B<tellRecord>()

Return the record number of the record just read (not the next one!)

=item * B<gotoLastRecord>()

Shorthand for I<seekRecord(-1, -1).
Returns the record number of the last record.
I<Interruptable>.
This also loads the cache that converts between record numbers and file offsets.

=item * B<readNthRecord(n)>

Shorthand for I<seekRecord(n,0)> plus I<readOneRecord>().
I<Interruptable>.

=item * B<readOneRecord>()

Read the record we're at and return it, leaving us positioned after it.

=back

=head2 General information methods

=over

=item * B<getPath>()

Return the path to the currently-open file, as a string.

=item * B<getNextRecnum>()

Return the record number of the record about to be read (not the one just read!)

=item * B<getCurrentRecordText>()

Return the raw text of the most recently-read record.

=item * B<getOffsetOfRecord>(n)

Return the actual file offset to record I<n>.
B<Note>: Only checks the cache, so if you haven't been there yet, it won't
know (and will return -1).
If you're not sure, use I<gotoNthRecord>() or I<gotoLastRecord>() first.

=item * B<getRecnumAtOffset>(n)

Return the record number that starts at or contains, file offset I<n>.
Interruptable. Experimental when going beyond the cache.
Returns undef if the offset cannot be found, or if interrupted.

=item * B<getRecordsAsArray>(first,last)

Return a reference to an array containing the raw text of records I<first>
through I<last> (inclusive) of the RecordFile. If the record numbers are
given in the wrong order, they will be quietly swapped.
This is mainly to support the C<pipe> and C<copy> commands in C<lessFields>,
which need to gather content between the current position and another.

=back


=head1 Related commands

C<lessTabular> uses (and was the origin of) this.

Also potentially useful for: C<body>, C<dumpx>, C<findExamples.py>.


=head1 Known bugs and limitations

Dies on invalid utf8 input (check with C<iconv -f utf8 -t utf> if needed).


=head1 History

  Written by Steven J. DeRose, 2012-02-15 (extracted from 'lessCSV').
  2012-02-22 sjd: Add getRecordsAsArray(), getRecnumAtOffset().
  Make sure to rewind() to fix header when setting 'header' option.
  Add 'csvParse' option.
  2012-04-26 sjd: Cut over from csvFormat to TabularFormats.
  2012-06-07 sjd: Drop everything to do with "header" records (leave to caller).
  Drop 'csvParse' option. Drop TabularFormats, just let caller do an
  addSpecialReader() call instead.
  2012-06-14 sjd: Forward rest of relevant calls to specialReader.
  2012-11-16 sjd: Factor out OffsetCache package. Make getRecnumAtOffset() and
  getOffsetOfRecord() not fail past cache.
  2013-02-14 sjd: Rename spurious 'specialReader' var refs to use 'reader'.
  Be consistent about using {reader} for all i/o when set. Drop 'options'.
  Sync API closer to TabularFormats::DataSource.
  2013-06-17: Ditch specialReader. Rename methods to be like files.
  Add pushback(), addText(), seekRecord(), tellRecord().
  2014-03-05: Start OpenItem and ReadAny packages (porting from Python).


=head1 To do

  Add atEOF.
  Feature to replace a record in place?
  Track byte *and* char offsets? Cf C<body> (integrate)
  Is knowing nothing about headers really best?
  Support zip files directly
  Cf EntityManager.pm, vocab, YMLParser.pm.
  Reconcile counting of logical vs. physical records.
  Integrate into most TEXTUTILS and CSVUTILS.


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.


=cut


###############################################################################
#
sub new {
    my ($class, $path, $iencoding) = @_;
    if (!$iencoding) { $iencoding = "utf8"; }

    my $self = {
        version        => $VERSION_DATE,
        path           => $path,         # Path to input
        iencoding      => $iencoding,    # Character set to use
        fh             => undef,         # File handle to input

        currentRecord  => "",            # Content of last line read
        nextRecnum     => 1,             # Where tell(fh) is pointed

        cache          => new OffsetCache(),
        buffer         => "",            # For pushback() data.
        interruptCB    => undef,         # Return 1 to interrupt long ops.
    };

    bless $self, $class;

    $self->open($path) || return(undef);
    $self->{cache}->clear();
    $self->seek(0,0);
    return($self);
}

sub vMsg {
    my ($self, $level, $msg) = @_;
    alogging::vMsg($level, $msg);
}

# Call a callback during long operations; if it returns true, bail.
#
sub setInterruptCB {
    my ($self, $cb) = @_;
    $self->{interruptCB} = $cb;
}

sub clearOffsetCache {
    my ($self) = @_;
    $self->{cache}->clear();
}


###############################################################################
# Make more data available.
#
sub attach {
    my ($self, $fh) = @_;
    $self->{fh} = $fh;
    return($fh);
}

sub addText {
    my ($self, $text) = @_;
    if ($self->{FH}) {
        $self->close();
    }
    $self->{buffer} .= $text;
} # add_text

sub pushback {
    my ($self, $text) = @_;
    $self->{buffer} = $text . $self->{buffer};
    #$self->{totalBytes} -= length($text);
} # pushback


###############################################################################
# Movement
#
sub seekRecord {
    my ($self, $n, $whence) = @_;
    if (!$whence) {         # Absolute
        $self->gotoNthRecord($n);
    }
    elsif ($whence>0) {     # Forward
        $self->gotoNthRecord($self->getNextRecnum() + $n);
    }
    else {               # Back from end
        $self->gotoLastRecord();
        $self->gotoNthRecord($self->getNextRecnum() - $n);
    }
}

sub tellRecord {
    my ($self) = @_;
    return($self->{nextRecnum} - 1);
}

sub gotoLastRecord {
    my ($self) = @_;
    my $highest = $self->{cache}->getHighestRecordNumber();
    $self->gotoNthRecord($highest);
    while (defined (my $temprec = $self->readOneRecord())) {
        if ($self->{interruptCB} && $self->{interruptCB}->()) {
            last;
        }
    }
    $highest = $self->{cache}->getHighestRecordNumber();
    $self->gotoNthRecord($highest);
    return($highest);
}

sub gotoNthRecord {
    my ($self, $n) = @_;
    my $startRec = $self->tellRecord();
    my $startOffset = $self->{fh}->tell();
    $self->vMsg(2,"gotoNthRecord for '$n'");

    if ($self->{cache}->isInCache($n)) {
        my $offset = $self->{cache}->getOffset($n);
        $self->vMsg(2,"Cache says record $n is at $offset.");
        $self->seek($offset);
        $self->{nextRecnum} = $n;
        #$self->readOneRecord();
        return(1);
    }

    my $lastCached = $self->{cache}->getHighestRecordNumber();
    if ($n > $lastCached) {                       # Skip to last cached rec
        $self->seek($self->{cache}->getOffset($lastCached));
        $self->{nextRecnum} = $lastCached;
    }
    else {                                        # Cache error
        $self->vMsg(2,"Cache of size $lastCached is missing record $n.");
        $self->seek(0,0);
    }

    # Read forward til we get there...
    while ((my $nxt = $self->getNextRecnum()) < $n) {
        my $temprec = $self->readOneRecord();
        if (!defined $temprec) { # EOF -- fail
            $self->seek($startOffset);
            $self->{nextRecnum} = $startRec; # +1?
            $self->readOneRecord();
            return(0);
        }
        if ($self->{interruptCB} && $self->{interruptCB}()) {
            last;
        }
    }
    return(1);
} # gotoNthRecord


###############################################################################
# Higher-level readers
#
sub readOneRecord {
    my ($self) = @_;
    $self->vMsg(2, "readOneRecord: record #" . $self->{nextRecnum});
    my $temprec = $self->readline();
    my $newOffset = $self->tell();

    if (defined $temprec) {
        $self->{nextRecnum}++;
        $self->{cache}->setOffset($self->{nextRecnum}, $newOffset);
        $self->vMsg(3, "readOneRecord: got record #" .
                     $self->{nextRecnum} . ":\n  $temprec");
    }

    $self->{currentRecord} = $temprec;
    return($temprec);
} # readOneRecord

# Read the next physical line, BUT ignoring comments and blank lines.
#
sub readRealLine {
    my ($self, $commentDelim) = @_;
    my $line = undef;
    while (defined ($line = $self->readline())) {
        last if ($line !~ m/^\s*$/ &&
                 $line !~ m/^$commentDelim/);
    }
    return($line);
} # readRealLine

sub readNthRecord {
    my ($self, $n) = @_;
    $self->gotoNthRecord($n);
    return($self->readOneRecord());
}


###############################################################################
# Get various information
#
sub getPath {
    my ($self) = @_;
    return($self->{path});
}

sub getNextRecnum {
    my ($self) = @_;
    return($self->{nextRecnum});
}

sub getCurrentRecordText {
    my ($self) = @_;
    return($self->{currentRecord});
}

sub getOffsetOfRecord {
    my ($self, $n) = @_;
    if (!$self->{cache}->isInCache($n)) {
        if (!$self->gotoNthRecord($n)) { return(-1); }
    }
    return( $self->{cache}->getOffset($n));
}

sub getRecnumAtOffset {
    my ($self, $offset) = @_;
    my $highest = $self->{cache}->getHighestRecordNumber();
    my $highestOffset = $self->{cache}->getOffset($highest);
    if (!$offset < $highestOffset) { # Assumes dense cache
        return($self->{cache}->getNearestRecordNumber());
    }

    my $original = $self->tellRecord();
    $self->seekRecord($highest);
    while (defined $self->readRecord()) {
        if ($self->tell() >= $offset) {
            $self->seekRecord($original);
            return($self->tellRecord());
        }
        if ($self->{interruptCB} && $self->{interruptCB}->()) {
            last;
        }
    }
    return(undef);
}


###############################################################################
# Below are the *only* methods that directly touch the file (move into ReadAny)
# Only try to load Archive::x modules if they're actually needed, so that we
# don't force people to install them pointlessly.
#
sub open {
    my ($self, $file) = @_;
    my $fh;

    $self->vMsg(0, "Trying to open '$file'.");
    (my $extension = $file) =~ s/.*\.//;
    if ($file =~ m/\.zip$/) {
        my $zip = Archive::Zip->new($file);
        my @members = $zip->members();
        $fh = Archive::Zip::MemberRead->new($zip,$members[$0]);
        $self->vMsg(0, "parsing directly from zip files is experimental.");
    }
    elsif ($extension eq "tar" || $extension eq "tgz") {
        # Can handle zlib and bzip2 in tars, if libs are installed.
        if (!sjdUtils::try_module("Archive::Tar")) {
            $self->vMsg(-1, "Cannot find module Archive::Tar.");
        }
        my $tar = Archive::Tar->new($file);
        my @members = $tar->members();
        $fh = $tar->read($members[$0]);
        $self->vMsg(0, "parsing directly from tar files is experimental.");
    }
    elsif ($extension eq "bz" || $extension eq "bz2") {
        if (!sjdUtils::try_module("Archive::Bzip2")) {
            $self->vMsg(-1, "Cannot find module Archive::Bzip2.");
        }
        my $bz = Archive::Bzip2->open($file, "r");
        $fh = $bz;
        $self->vMsg(0, "parsing directly from bzip2 files is experimental.");
    }
    elsif ($extension eq "Z") {
        warn "compress files not yet supported.\n";
        return(undef);
    }
    elsif ($extension eq "gz") {
        warn "gzip files not yet supported.\n";
        return(undef);
    }
    elsif (!open($fh, "<$file")) {
        $self->vMsg(0, "Couldn't open '$file'");
        return(undef); # FAIL
    }

    $self->attach($fh);
    if ($self->{"iencoding"}) {
        $self->binmode($self->{"iencoding"});
    }
    return($fh);
}

sub binmode {
    my ($self, $encoding) = @_;
    if (!$self->{fh}) {
        warn "Can't use binmode unless a file is open.\n";
        return(0);
    }
    if (!$encoding) { $encoding = "utf8"; }
    $self->{encoding} = $encoding;
    if ($encoding !~ m/[:()]/) {
        $encoding = ":encoding($encoding)";
    }
    binmode($self->{fh}, $encoding);
    $self->vMsg(1,"Set input encoding to " . $self->{"iencoding"});
    return(1);
}

sub close {
    my ($self) = @_;
    close $self->{fh};
    return;
}

sub seek {
    my ($self, $n) = @_;
    $self->{fh}->seek($n, Fcntl::SEEK_SET);
}

sub tell {
    my ($self) = @_;
    $self->{fh}->tell();
}

sub readline {
    my ($self) = @_;
    my $fh = $self->{fh};
    my $rec = undef;
    my $available = length($self->{buffer});
    if (!$available) {
        $rec = <$fh>;
    }
    else {
        my $eol = index($self->{buffer}, "\n");
        if ($eol >= 0) {
            $rec = substr($self->{buffer}, 0, $eol);
            if ($eol>=$available-1) { $self->{buffer} = ""; }
            else { $self->{buffer} = substr($self->{buffer}, $eol+1); }
        }
        else { # no newline, so continue reading
            $rec .= (<$fh> || "");
        }
    }
    return($rec);
} # readline


###############################################################################
#
package OpenItem;

my %typeList = (
    "list"=>"COLLECTION", "dir"=>"COLLECTION",
    "file"=>"READABLE",
    "zip"=>"READABLE",  "bz"=>"READABLE",  "gzip"=>"READABLE",
    "tar"=>"READABLE",  "Z"=>"READABLE",
);

sub new {
    my ($class, $path, $mode) = @_;
    my $self = {
        rootPath      => "",
        mode          => ($mode eq "w") ? 1:0,
        type          => "",
        offset        => 0,
        recNum        => 0,
        encoding      => "utf-8",
    };
    bless($self, $class);
}

sub isCollectionType {
    my ($self) = @_;
    if ($typeList{$self->{type}} eq "COLLECTION") { return(1); }
    return(0);
}

sub isReadableType {
    my ($self) = @_;
    if ($typeList{$self->{type}}  eq "READABLE") { return(1); }
    return(0);
}

sub openNextChild {
    my ($self) = @_;
    if ($self->isCollectionType()) {
    }
    else {
    }
}

sub close {
    my ($self) = @_;
    if ($self->{fh}) { $self->fh->close(); }
}


###############################################################################
#
package ReadAny;

sub new {
    my ($class, $path, $options) = @_;
    my $self = {
        "rootPath"       => $path,
        "mode"           => ($options && $options->{mode} eq "w") ? 1:0,
        "openItems"      => [],
        "halted"         => 0,

        # Options
        "files"          => 1,
        "recursive"      => 0,
        "binaries"       => 0,
        "backups"        => 0,
        "hiddens"        => 0,
        "links"          => 0,
        "halt"           => 0,
        "verbose"        => 0,

        # Stats
        "started"        => 0,
        "totalRecords"   => 0,
        "nItems"         => 0,
        "itemCounts"     => {},
    };

    if ($options) {
        for my $o (keys(%{$options})) {
            if (defined $self->{$o}) {
                $self->{$o} = $options->{$o};
            }
            else {
                warn "ReadAny: Bad option name '$o'\n";
            }
        }
    }

    for my $tn (keys %typeList) {
        $self->{itemCounts}->{$tn} = 0;
    }
    bless($self, $class);
}

# open, close, read, readline, binmode, seek, tell


###############################################################################
# Keep a cache mapping record numbers to the file offsets where they start.
# At the moment, keeps all records up to the highest one read.
# Could extend to only keep every n'th one or at most n entries;
# then caller would seek to nearest available preceding entry,
# and read forward from there.
#
package OffsetCache;

sub OffsetCache::new {
    my ($class) = @_;
    my $self = {
        offsets        => [-1,0],
    };
    bless $self, $class;
    return($self);
}

sub OffsetCache::clear {
    my ($self) = @_;
    $self->{offsets} = [-1,0];
}

sub OffsetCache::isInCache {
    my ($self, $n) = @_;
    if (defined $self->{offsets}->[$n]) { return(1); }
    return(0);
}

sub OffsetCache::setOffset {
    my ($self, $n, $offset) = @_;
    $self->{offsets}->[$n] = $offset;
}

sub OffsetCache::getOffset {
    my ($self, $n) = @_;
    if (defined $self->{offsets}->[$n]) { return($self->{offsets}->[$n]); }
    return(-1);
}

sub OffsetCache::getDistance {
    my ($self, $n1, $n2) = @_;
    if (!$n2) { $n2 = $n1 + 1; }
    if (!$n1 || $n2<$n1 ||
        !defined $self->{offsets}->[$n1] ||
        !defined $self->{offsets}->[$n2]) {
        return(-1);
    }
    return($self->{offsets}->[$n2] - $self->{offsets}->[$n1]);
}

sub OffsetCache::getHighestRecordNumber {
    my ($self) = @_;
    return(scalar(@{$self->{offsets}}) - 1);
} # getHighestRecordNumber

# Return the number and offset of the record closest to record n in the cache.
# If n itself isn't cached, return info for the nearest prior.
# This is the best record to seek to to minimize unnecessary reading.
# Works even if the cache is not dense (though it is now).
#
sub OffsetCache::getNearestRecordNumber {
    my ($self, $n) = @_;
    my $highest = $self->getHighestRecordNumber();
    if ($n >= $highest) {
        return($highest);
    }
    for (my $i=$n; $i>1; $i--) {
        if (defined $self->{offsets}->[$i]) {
            return($i,$self->{offsets}->[$i]);
        }
    }
    return(1,0);
}

sub OffsetCache::getLongestRecordLength { # Doesn't check *last* record
    my ($self) = @_;
    my $maxLength = 0;
    my $whichRecord = 0;
    my $highest = $self->getHighestRecordNumber();
    for (my $i=1; $i<$highest-1; $i++) {
       if (defined $self->{offsets}->[$i] &&
           defined $self->{offsets}->[$i+1]) {
           my $length = $self->{offsets}->[$i+1] - $self->{offsets}->[$i];
           if ($length > $maxLength) {
               $maxLength = $length;
               $whichRecord = $i;
           }
       }
    }
    return($maxLength, $whichRecord);
} # getLongestRecordLength

sub OffsetCache::check {
    my ($self) = @_;
    my $nProblems = 0;
    my $prevOffset = $self->{offsets}->[1];
    my $highest = $self->getHighestRecordNumber();
    for (my $i=2; $i<$highest; $i++) {
       if (!defined $self->{offsets}->[$i]) {
           $nProblems++;
           $self->vMsg(0, "Cache gap at [$i].");
       }
       elsif ($self->{offsets}->[$i] <= $prevOffset) {
           $self->vMsg(0, "Cache conflict at [" . ($i-1) . "], [$i].");
           $nProblems++;
       }
    }
    return($nProblems);
}

# End of OffsetCache package

1;
