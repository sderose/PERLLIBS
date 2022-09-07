#!/usr/bin/env perl -w
#
# StatLog.pm: Keep stats on various events: counts, min, max, etc.
# 2010-02-25: Written by Steven J. DeRose.
#
use strict;
#use utf8;
#use Encode 'is_utf8';

use sjdUtils;

our %metadata = (
    'title'        => "StatLog",
    'description'  => "Keep stats on various events: counts, min, max, etc.",
    'rightsHolder' => "Steven J. DeRose",
    'creator'      => "http://viaf.org/viaf/50334488",
    'type'         => "http://purl.org/dc/dcmitype/Software",
    'language'     => "Perl 5",
    'created'      => "2010-02-2",
    'modified'     => "2021-09-16",
    'publisher'    => "http://github.com/sderose",
    'license'      => "https://creativecommons.org/licenses/by-sa/3.0/"
);
our $VERSION_DATE = $metadata{'modified'};


=pod

=head1 Usage

NOT MAINTAINED

Maintains a list of named statistics, and can generate a report
of the totals.

In addition to simple counting, there are calls to 
to set (or reset) a stat, to set only if the new value is greater than
(or less than) the prior value, to keep only the first or last value
for the stat, etc.

There are also I<append>() and I<setKey>() methods that let you 
add new data to an array or hash. Using those calls forces the statistic
to be of that type, if it's not already (losing any prior data).

You can also merge multiple StatLog instances, for example to keep grand totals
and per-file totals. However, if you use min/max/first/last
calls such as just mentioned,
merging won't maintain their semantics
(because StatLog doesn't know a "type" per se).

=head2 Example

    use StatLog;
    my $sl = new StatLog();
    $sl->create("tooLong", "Records that were too long");
    $sl->create("syntax",  "Syntax errors");
    $sl->create("maxrec",  "Length of longest record");
    ...
    $sl->max("maxrec", length($buf));
    if (length($buf) > $LIMIT) {
        $sl->count("tooLong");
    }
    ...
    $sl->report();


=head1 Methods

=over

=item * B<new StatLog>I<()>

Constructor.

=item * B<createMultiple>I<(hashRef)>

Define numerous new statistics. 
This is merely shorthand for calling I<create>() on each name=>label pair,
in alphabetical order.
Returns the number of statistics created.

=item * B<create>I<(name, label)>

Define a new statistic to be kept.
The label will be used when generating reports (see I<report>(), below).
The new statistic is initialized to I<undef>.

=item * B<delete>I<(name)>

Entirely delete the named statistic.

=item * B<resetAll>I<()>

Call I<reset()> for each known statistic.

=item * B<reset>I<(name)>

Set the named statistic to C<undef> for scalars, or to [] or {}
if the value is already of that type. Methods that modify statistic
values, all know what to do if the value to be modified is C<undef>.

=item * B<get>I<(name)>

Return the current value of the named statistic.

=item * B<set>I<(name. value)>

Set the value of the named statistic directly.

=item * B<count>I<(name, value?)>

Increment the value of the named statistic by I<value> (default: 1).

=item * B<max>I<(name, value)>

Set the named statistic to the greater of I<value> or its current value.

=item * B<min>I<(name, value)>

Set the named statistic to the lesser of I<value> or its current value.

=item * B<first>I<(name, value)>

Set the named statistic to I<value> the first time, and ignore further requests.

=item * B<last>I<(name, value)>

Set the named statistic to I<value> regardless of any prior value, such that the
last value set is the one that is kept.

=item * B<append>I<(name, value)> or B<push>I<(name, value)>

Push the value onto an array for the named statistic.
If the value is not already an array, it is replaced by a reference
to a new array containing only I<value>.

=item * B<setKey>I<(name, key, value)>

Add the I<key> => I<value> pair to a hash for the named statistic.
If the value is not already a hash, it is replaced by a reference
to a new hash containing only I<key> => I<value>.

=item * B<report>I<(where)>

Generate a report of all the statistics and their values.
I<where> defaults to STDOUT.
Statistics are reported in the order they were created.

=item * B<reportColorLine>I<(label, n, pct, colorName)>

Internal utility used by I<report>.

=item * B<copy>I<()>

Return a new StatLog instance that is a copy of the current one.

=item * B<merge>I<(other)>

Goes through all the statistics in the StatLog instance I<other>, and
combines them into the instance being invoked. 
Arrays are concatenated. Hashes are merged.
Other values are just added, because the package doesn't know
whether you've used special things like max/min/first/last.

=back


=head1 Known bugs and limitations

I<merge>() won't work right in relation to first/last/min/max.


=head1 Related commands and files

C<vocab> -- Vocabulary counter, first package to integrate this.

C<sjdUtils.py> -- The Python version of my utilities provides an optional
C<stat="name"> parameter, that will increment a statistic when issuing
any error or verbose message. It also has a few other related calls.
Thus, the StatLog.pm package is not needed in Python.


=head1 History

  2010-02-25: Written by Steven J. DeRose.
  2013-06-14: Split out of checkWordLists to separate package.
  2013-01-04: Clean, finish, integrate into 'vocab'. Add min/max/first/last,
and knowledge of types.
  2014-02-05: Change set() to hit(), since it doesn't really "set" values.
Add 'events' counter, and don't use 'undef' to mean "haven't seen".
  2014-04-10: Add intWidth.
  2015-02-20: Speed it up a lot. Ditch hit(). types, event-counting.
  2021-09-16: Cleanup.
  

=head1 Rights

Copyright 2010-02-25 by Steven J. DeRose. This work is licensed under a
Creative Commons Attribution-Share Alike 3.0 Unported License.
For further information on this license, see
L<https://creativecommons.org/licenses/by-sa/3.0>.

For the most recent version, see L<http://www.derose.net/steve/utilities> or
L<https://github.com/sderose>.


=cut


###############################################################################
# Maintain counts of various statistics by name.
# New ones need to be explicitly added.
#
package StatLog;

sub new {
    my ($class, $name) = @_;
    my $self = {
        "labels"        => {},     # Label/descr of each stat
        "stats"         => {},     # Value of each stat
        "order"         => [],     # Stat names in order created
        "intWidth"      => 10,     # Columns to leave for integers
    };
    bless($self,$class);
    return($self);
}

sub getNames {
    my ($self) = @_;
    my @n = sort keys %{$self->{stats}};
    return(\@n);
}

# Insert a header into the "order" array, so it gets printed at
# that point when displaying a report.
sub createHead {
    my ($self, $head) = @_;
    push @{$self->{order}}, "***$head";
}

sub createMultiple {
    my ($self, $items) = @_;
    my $n = 0;
    for my $name (sort keys %{$items}) {
        if ($self->create($name, $items->{$name})) {
            $n++;
        }
    }
    return($n);
}

sub create {
    my ($self, $name, $label) = @_;
    push @{$self->{order}}, $name;
    $self->{labels}->{$name} = $label || "???$name???";
    $self->{stats}->{$name} = 0; # or call reset()?
    $self->set($name, 0);
    return(1);
}

sub delete {
    my ($self, $name) = @_;
    delete $self->{labels}->{$name};
    delete $self->{stats}->{$name};
    my $foundAt = -1;
    for (my $i=0; $i<scalar(@{$self->{order}}); $i++) {
        if ($self->{order}->[$i] eq $name) { $foundAt = $i; last; }
    }
    if ($foundAt>=0) {
        splice(@{$self->{order}}, $foundAt, 1);
    }
    return(1);
}

sub resetAll {
    my ($self) = @_;
    for my $k (keys(%{$self->{stats}})) {
        $self->reset($k);
    }
}

sub reset {
    my ($self, $name) = @_;
    my $val = $self->{stats}->{$name};
    if (ref($val) eq "HASH") { $self->set($name, {}); }
    elsif (ref($val) eq "ARRAY") { $self->set($name, []); }
    else { $self->set($name, 0); }
    return;
}


###############################################################################
# Basic statistic set/get
#
sub get {
    my ($self, $name) = @_;
    return($self->{stats}->{$name});
}

sub set {
    my ($self, $name, $value) = @_;
    $self->{stats}->{$name} = $value;
}

sub count {
    my ($self, $name, $value) = @_;
    if (!defined $self->{stats}->{$name}) {
        $self->{stats}->{$name} = 0;
    }
    if (defined $value) {
        $self->{stats}->{$name} += $value;
    }
    else {
        $self->{stats}->{$name}++;
    }
    return;
}

sub max {
    my ($self, $name, $value) = @_;
    if (!defined $self->{stats}->{$name} ||
        $value > $self->{stats}->{$name}) {
        $self->{stats}->{$name} = $value;
    }
    return;
}

sub min {
    my ($self, $name, $value) = @_;
    if (!defined  $self->{stats}->{$name} ||
        $value < $self->{stats}->{$name}) {
        $self->{stats}->{$name} = $value;
    }
    return;
}

sub first {
    my ($self, $name, $value) = @_;
    my $prevValue = $self->{stats}->{$name};
    if (defined $prevValue) { return; }
    $self->{stats}->{$name} = $value;
    return;
}

sub last {
    my ($self, $name, $value) = @_;
    $self->{stats}->{$name} = $value;
    return;
}

sub text {
    my ($self, $name, $value) = @_;
    $self->{stats}->{$name} = $value;
    return;
}

sub append {
    my ($self, $name, $value) = @_;
    if (ref($self->{stats}->{$name}) ne "ARRAY") {
        $self->{stats}->{$name}->{$name} = [];
    }
    $self->{stats}->{$name}->append($value);
    return;
}

sub setKey {
    my ($self, $name, $key, $value) = @_;
    if (ref($self->{stats}->{$name}) ne "HASH") { # Force to hash
        $self->{stats}->{$name}->{$key} = {};
    }
    $self->{stats}->{$name}->{$key} = $value;
    return;
}


###############################################################################
# Generate reports
#
sub report {
    my ($self, $header) = @_;

    if ($header) {
        print "\n\n" . ("=" x 79) . "\n";
        print "******* $header\n";
    }

    # Find how much space to leave for labels
    my $maxlen = 0;
    for my $lab (values %{$self->{labels}}) {
        if (length($lab) > $maxlen) { $maxlen = length($lab); }
    }
    my $sfmt = "%-" . $maxlen . "s";
    my $ifmt = "%" . $self->{"intWidth"} . "s";

    for my $name (@{$self->{order}}) {
        if ($name =~ m/^\*\*\*(.*)/) { # Header
            print "\n******* $1\n";
            next;
        }

        my $val = $self->{stats}->{$name};
        my $lab = $self->{labels}->{$name};
        my $msg = "";
        if (!defined $val) {
            $msg = sprintf("  $sfmt    *UNDEF*", $lab);
        }
        elsif (ref($val) eq "HASH") {
            $msg = sprintf("  $sfmt", $lab);
            my $hash = $self->{stats}->{$name};
            my @keys = sort keys %{$hash};
            for my $key (@keys) {
                $msg .= sprintf("\n    %-20s  '%s'", $key, $hash->{$key});
            }
        }
        elsif (ref($val) eq "ARRAY") {
            $msg = sprintf("  $sfmt  $ifmt", $lab, $val);
            my $arr = $self->{stats}->{$name};
            for my $item (@{$arr}) {
                $msg .= sprintf("\n    %s", $item);
            }
        }
        elsif (sjdUtils::isNumeric($val)) {
            $msg = sprintf("  $sfmt  $ifmt", $lab, $val);
        }
        else {
            $msg = sprintf("  $sfmt  %s", $lab, $val);
        }
        print "$msg\n";
    }
} # report


###############################################################################
# Manipulate entire StatLog objects
#
sub copy {
    my ($self) = @_;

    my $copy = new StatLog;

    push @{$copy->{order}}, @{$self->{order}};

    for my $name (keys %{$self->{stats}}) {
        $copy->{labels}->{$name} = $self->{labels}->{$name};
        if (ref($self->{stats}->{$name}) eq "HASH") {
            my %temp = %{$self->{stats}->{$name}};
            $copy->{stats}->{$name} = \%temp;
        }
        elsif (ref($self->{stats}->{$name}) eq "ARRAY") {
            my @arr = @{$self->{stats}->{$name}};
            $copy->{stats}->{$name} = \@arr;
        }
        else {
            $copy->{stats}->{$name} = $self->{stats}->{$name};
        }
    }
    return($copy);
} # copy

# Accumulate another StatLog into this one.
# WARNING: Won't work for min/max/first/last. Doesn't coalesce hashes.
#
sub merge {
    my ($self, $other) = @_;
    for my $name (keys(%{$other->{stats}})) {
        my $otherval = $other->{stats}->{$name};
        if (ref($otherval) eq "HASH") {
            for my $key (sort keys %{$otherval}) {
                $self->setKey($name, $key, $otherval->{$key});
            }
        }
        elsif (ref($otherval) eq "ARRAY") {
            for my $elem (@{$otherval}) {
                $self->append($name, $elem);
            }
        }
        else { 
            $self->set($name, ($self->get($name)||0) + $otherval);
        }
    }
} # merge
