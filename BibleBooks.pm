#!/usr/bin/perl -w
#
# BibleBooks.pm
# 2012-05-10ff: Written by Steven J. DeRose.
# 
use strict;
use XmlTuples;

our %metadata = (
    'title'        => "BibleBooks",
    'description'  => "",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2012-05-10",
    'modified'     => "2021-09-16",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

Manage a collection of data about Biblical books, and help normalize data
such as book names and Scripture references.

The script has knowledge of the books from many denominations' canons.

=head2 Example

    use BibleBooks;
    my $bb = new BibleBooks();
    ...
    my $bg = new BookGroup();
    ...


=head1 Package BibleBooks

=over

=item * B<new>I<(path)>

Load definitions of Bible book names, abbreviations, and other basic
data from the Xml Tuples (XSV) file I<path>.

=item * B<getBook> I<(abbr)>

Return a reference to a hash of properties of the named book.
As with other calls, the book may be specified by many abbreviations, all
of which are matched ignoring case.

The returned hash (if any) contains fields for:

=over

=item Full -- the full name of the book

=item Osis -- the standard OSIS and SBL abbreviation for the book

=item Alts -- A list of comma-separated alternate names and abbreviations
for the book.

=item Group -- a single predefined group to which the book is assigned.

=item Ser -- an integer providing a full ordering over all books. Books
within any one predefined group (such as NT) have numbers in the
usual order.

=item Ch -- the number of chapters in the book

=item Vs -- the number of verses in each chapter of the book, as a
space-separated list.

=back

=item * B<getFullName> I<(abbr)>

Given any known abbreviation, get the hash of data for the referenced book.
Other functions accept the same abbreviations.

=item * B<getOsisName> I<(abbr)>

Get the official OSIS and SBL abbreviation.

=item * B<getNChapters> I<(abbr)>

Get the number of chapters (0 if unknown).

=item * B<getSerial> I<(abbr)>

Get the book number in linear sequence (0 if unknown).
The numbering includes all Tanakh, Apocryphal/Deuterocanonical, and
New Testament books. Thus, you can obviously still sort by this number
even for any small canon.

=item * B<getBooksInGroup> I<(groupName)>

Return a reference to an array of the full names of all known books that are
in the predefined book-group named I<groupName> (e.g., OT, AP, NT, Rohlfs,...).
These are specified by the "Group" field in the XML Tuples data.

=item * B<getAllGroupNames( )>

Return a reference to a hash, with an entry for each predefined book-group name.
The associated value is the number of books in that book group. This does
*not* include any book groups that are created by callers (see the following
I<BookGroup> package).

=item * B<ref2osisRef> I<ref>

Attempt to convert an apparent Scripture reference to OSIS standard reference
format. If there are multiple comma-separated parts, multiple OSISrefs
will be returned, one for each such part. 
Each OSISref will start with an OSIS book abbreviation,
and may have following (dot-separated) chapter, verse, verse-part (for example,
"a"), and range components.

=back


=head1 Package BookGroup

This object manages an ordered list of books, identifying them simply
by their long ("Full") names. Some groups can simply be created via
I<fillPredefinedGroup(name)>, others can be constructed by successive
I<addBookGroup> and/or I<addBook> calls.

=over

=item * B<new>I<($groupName)>


=item * B<addBookGroup>I<($otherGroup)>


=item * B<addBook>I<($bookFullName)>


=item * B<deleteBook>I<($bookFullName)>


=item * B<getFullNames>I<( )>


=item * B<getFullNameN>I<(n)>

Return the full name of the I<n>th book in the group.

=item * B<getSize>I<( )>

Return the number of book in the group.

=item * B<fillPreDefinedGroup>I<(groupName, mainBB)>

The second argument must be a BibleBooks instance (since it has the
information objects for known books).

=back


=head1 Known Bugs and Limitations

It would be nicer to have getSerial also take a canon name, such as
(Jewish, RCatholic, Orthodox, Protestant,...), and return the position
specific to that canon (or 0 for any book not in that canon).

Although (for example) I<ref2osisRef( )> could check
whether chapter numbers are in range, it doesn't.

Book groups are not available for entire canons (though most can be easily
build out of the predefined books and groups).


=head1 Related commands

C<mediaWiki2HTML> uses this to identify Biblical links during conversion.

C<BibleBooks.xsv> provides the XML Tuples data used by this package.

C<osisCheck> uses this for checking books and building canons. It has its
own data on verses per book, however.


=head1 History

    2012-05-10ff: Written by Steven J. DeRose.


=head1 To do

    Test.
    Add min-length truncation feature
    Integrate into renameOSISfiles, osisCheck, fixGNTnames

Data:
    Finish canons, verseCounts? (cf osisCheck script)
    Add Greek/Hebrew names, osisCheck books, to external data


=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons 
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut


###############################################################################
#
package BibleBooks;

sub new {
    my ($class, $datapath) = @_;
    if (!$datapath) {
        $datapath = "$ENV{HOME}/bin/SJD/tupleSets/BibleBooks.xsv";
    }
    (-f $datapath) || die "BibleBooks: Can't find data at '$datapath'.\n";
    my $xt = new XmlTuples();
    ($xt) || die "BibleBooks.pm.new: Can't create new XmlTuples.\n";
    $xt->open($datapath);

    my %bookData = ();
    my %abbrevs = ();
    while (my $bookObj = $xt->getNext()) {
        my $full = $bookObj->{"Full"};
        my $osis = $bookObj->{"Osis"};
        my $nc   = $bookObj->{"Nc"};
        my @verseCounts = ();
        if (my $vcList = $bookObj->{"Vs"}) {
            @verseCounts = split(/\s+/,$vcList);
            if (scalar(@verseCounts) != $nc) {
                warn("Wrong number of verse-counts for $osis.\n");
            }
        }

        # Save the book-data object (a hash), and then
        # link many names to that object (ignoring case).
        #
        my $key = $full; # Or could use $osis

        $bookData{$key} = $bookObj;

        $abbrevs{lc($osis)} = $bookObj;
        $full = lc($full);
        $abbrevs{$full} = $bookObj;

        # 1/2/3/4 (name)
        (my $nonum = $full) =~ s/^([1234]\s*)//;
        if ($1) {
            if ($1 == 1) {
                $abbrevs{"first $nonum"} = $bookObj;
                $abbrevs{"1st $nonum"} = $bookObj;
            }
            elsif ($1 == 2) {
                $abbrevs{"second $nonum"} = $bookObj;
                $abbrevs{"2nd $nonum"} = $bookObj;
            }
            elsif ($1 == 3) {
                $abbrevs{"third $nonum"} = $bookObj;
                $abbrevs{"3rd $nonum"} = $bookObj;
            }
            elsif ($1 == 4) {
                $abbrevs{"fourth $nonum"} = $bookObj;
                $abbrevs{"4th $nonum"} = $bookObj;
            }
        }

        # No-space version, too
        $full =~ s/\s*//g;
        $abbrevs{$full} = $bookObj;

        # Explicitly listed abbreviations
        if ($bookObj->{"Abbrs"}) {
            for my $abbr (split(/,\s+/, $bookObj->{"Abbrs"})) {
                $abbrevs{lc($abbr)} = $bookObj;
            }
        }
    } # tuples

    my $self = {
        bookData     => \%bookData,
        abbrs        => \%abbrevs,
    };

    bless($self, $class);
    return($self);
} # new

# Return a book object, given one or a name for one.
#
sub getBook {
    my ($self, $abbr) = @_;

    # If they gave us an object already, just return it.
    if (ref($abbr) eq "#HASH") { return($abbr); }

    # Otherwise normalize and look up as a name or abbreviation
    my $ref = $abbr;
    $ref =~
        s/^\s+(The\s*)?//i;
    $ref =~
        s/gospel\s+(of|according to)\s*(St|St\.|Saint)?//i;
    $ref =~
        s/of (St|St\.|Saint)?\s*[a-z]+\s+//i;
    $ref =~
        s/(epistle|letter)\s+(to\s*the\s+)//i;
    $ref =~ s/\W//g; # periods, parenthesis,...

    # Return the found book object (or undef if not found)
    return($self->{abbrs}->{lc($ref)});
}

sub getFullName {
    my ($self, $abbr) = @_;
    my $bookObj = $self->getBook($abbr);
    ($bookObj) || return(undef);
    return($bookObj->{"Full"});
}

sub getOsisName {
    my ($self, $abbr) = @_;
    my $bookObj = $self->getBookObj($abbr);
    ($bookObj) || return(undef);
    return($bookObj->{"Osis"});
}

sub getNChapters {
    my ($self, $abbr) = @_;
    my $bookObj = $self->getBookObj($abbr);
    ($bookObj) || return(undef);
    return($bookObj->{"Ch"});
}

sub getSerial {
    my ($self, $abbr) = @_;
    my $bookObj = $self->getBookObj($abbr);
    ($bookObj) || return(undef);
    return($bookObj->{"Ser"});
}

sub getBooksInGroup {
    my ($self, $group) = @_;
    my @list = ();
    for my $b (keys %{$self->{bookData}}) {
        if ($b->{"Group"} eq $group) {
            push @list, $b->{"Full"};
        }
    }
    @list = 
        sort { return($self->getSerial($a) <=> $self->getSerial($b)); } @list;
    return(\@list);
}

sub getAllGroupNames {
    my ($self) = @_;
    my %groups = ();
    for my $b ($self->{bookData}) {
        my $grp = $b->{"Group"};
        $groups{$grp}++;
    }
    return(\%groups);
}


###############################################################################
# Convert any old reference into one or more OSIS-format refs.
#
sub ref2osisRef {
    my ($self, $orig) = @_;
    my $book = $orig;
    $book =~ s/^\s+//;
    $book =~ s/\s+(\d.*)$//; # Strip chapter/verse info
    my $cv = ($1) ? $1:"";
    $book = $self->getOsisName($self->getFullName($book));
    ($cv) || return($book);

    my @bufs = ();
    my @places = split(/\s*,\s*/, $cv);      # 1,3-5,12:16,21:1a-20
    (scalar(@places)>1) && warn
        "Extended refs not yet supported: '$orig'\n";

    my $chap = "";
    my $vers = "";
    my $part = "";
    for my $place (@places) {
        if ($place =~ m/[-~]/) {                  # 12:1a-20 (range)
        }
        elsif ($cv =~ s/^(\d+)\W((\d+)(\w))?//) { # 3:16 1.1a 1
            $chap = $1;
            $vers = $2;
            $part = ($3) ? $3:"";
        }
        else {
            warn "Huh? '$orig'\n";
        }
        my $buf = "$book.$chap";
        if ($vers) { $buf .= ".$vers"; }
        if ($part) { $buf .= ".$part"; }
        push @bufs, $buf;
    }
    return(@bufs);
} # ref2osisRef


###############################################################################
# Maintain a named sequence of books (identified by their fullNames).
# These also represent canons.
#
package BookGroup;

sub new {
    my ($class, $groupName) = @_;
    my $self = {
        name      => $groupName,
        bookNames => [],
    };
    bless($self, $class);
    return($self);
} # new

sub addBookGroup {
    my ($self, $otherGroup) = @_;
    push @{$self->{bookNames}}, @{$self->getFullNames($otherGroup)};
}

sub addBook {
    my ($self, $bookFullName) = @_;
    push @{$self->{bookNames}}, $bookFullName; 
}

sub deleteBook {
    my ($self, $bookFullName) = @_;
    my @newBN = ();
    for my $bn (@{$self->{bookNames}}) {
        next if ($bn eq $bookFullName);
        push @newBN, $bn; 
    }
    $self->{bookNames} = \@newBN;
}

sub getFullNames {
    my ($self) = @_;
    return($self->{bookNames});
}

sub getFullNameN {
    my ($self,$n) = @_;
    return($self->{bookNames}->[$n]);
}

sub getSize {
    my ($self) = @_;
    return(scalar(@{$self->{bookNames}}));
}

# The predefined groups have books listed in the main BibleBooks list,
# and are pulled out via the "Group" field from there, ordered by Serial.
#
sub fillPreDefinedGroup {
    my ($self, $groupName, $mainBB) = @_;
    my @names = @{$mainBB->getBooksInGroup($groupName)};
    for my $name (@names) {
        $self->addBook($name);
    }
}


1;
