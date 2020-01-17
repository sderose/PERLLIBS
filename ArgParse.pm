#!/usr/bin/perl -w
#
# Perl version of the Python 'argparse' package. But, it sits on top
# of Perl Getopt::Long, rather than rebuilding from scratch.
#
# Written 2012 by Steven J. DeRose, based on standard Python package.
# 2013-02-01 sjd: Packagize. Define actionValues and typeValues hashes.
#     Add Perldoc. Add types rfile/wfile/zfile/dir.
#
# To do:
#     Finish.
#     Stop adding add_argument hash *values* as keys in option list!
#
#     Option to keep newlines in help text
#     Add baseInt type
#     Integrate action=help with Perldoc.
#     Perhaps set/get calls by name? Definitely getValues()
#     setDefaults()
#     Implement toogleable boolean args.
#
use strict;
use Getopt::Long;

our $VERSION_DATE;

package ArgParse;

# Python-like named options
# See https://docs.python.org/3/library/argparse.html#the-add-argument-method
#
my %optionNames = (
    # name or flags
    "action"  => 1,  # Enum below
    "choices" => 1,   # array
    "const"   => 1,  # (any)
    "default" => 1,  # (any)
    "dest"    => 1,  # token
    "help"    => 1,  # string
    "metavar" => 1,  # token
    "nargs"   => 1,  # int | [*?+] | argparse.REMAINDER
    "required"=> 1,  # bool
    "type"    => 1,  # Enum below
    "version" => 1,  # string
    );

my %actionValues = (
    "append"       => 1,
    "append_const" => 1,
    "count"        => 1,
    "help"         => 1,
    "store"        => 1,
    "store_const"  => 1,
    "store_false"  => 1,
    "store_true"   => 1,
    "version"      => 1,
    );

my %typeValues = (
    "baseint" => "=o",  # ADDED
    "bool"    => "",
    "toggle"  => "!",   # ADDED
    "dir"     => "=s",  # ADDED
    "float"   => "=f",
    "int"     => "=i",
    "rfile"   => "=s",  # argparse.FileType('r')
    "str"     => "=s",
    "wfile"   => "=s",  # argparse.FileType('w')
    "zfile"   => "=s",  # ADDED
    );

sub new {
    my ($class, $description) = @_;
    my $self = {
        description => $description || "",
        argDefs     => {},                   # like %actionValues, above.
        synonyms    => {},                   # Map option names to primary
        getoptHash  => {},                   # Funky hash for GetOpt::Long
        values      => {},                   # Values that were actually set.
    };
    bless $self, $class;
    return($self);
}

sub isdef {
    my ($self, $name) = @_;
    if (defined $self->{argDefs}->{$name}) { return(1); }
    return(0);
}

sub delete_argument {
    my ($self, $name) = @_;
    for my $syn (keys %{$self->{synonyms}}) {
        if ($self->{synonyms}->{$syn} = $name) {
            delete $self->{synonyms}->{$syn};
        }
    }
    delete $self->{argDefs}->{$name};
    delete $self->{getoptHash}->{$name};
    delete $self->{values}->{$name};
} # add_argument

sub add_argument {
    my ($self, $names, $options) = @_;
    checkMyArgs(@_);

    # Assemble the option name(s)
    my $firstName = "";
    if (ref($names) eq "ARRAY") {
        for my $syn (@{$names}) {
            $syn =~ s/^[\s-]+//;
            if (!$firstName) { $firstName = $syn; }
            $self->{synonyms}->{$syn} = $firstName;
        }
        $names = join("|", @{$names});
    }
    else {
        (my $syn = $names) =~ s/^[\s-]+//;
        $firstName = $syn;
    }
    # if ($firstName !~ m/^-/) { $firstName = "-" . $firstName; }

    my %copy = %{$options};
    $self->{argDefs}->{$firstName} = \%copy;

    $self->makeGetoptForm($firstName, $options);
} # add_argument

sub checkMyArgs {
    my ($self, $name, $argsHash, $extra) = @_;
    if (!$name) {
        warn "add_argument: Argument 1 (name) is empty.\n";
        return(0);
    }
    if (defined $argsHash) {
        if (ref($argsHash) ne "HASH") {
            warn "add_argument: Argument 3 is not a hash ref for '$name'.\n";
            return(0);
        }
        else {
            for my $k (keys(%{$argsHash})) {
                (defined $optionNames{$k}) ||
                    warn "add_argument: Unknown option-name '$k' for '$name'.\n";
            }
        }
    } # $args
    if (defined $extra) {
        warn "add_argument: Extra argument(s) for '$name'.\n";
    }
    return(1);
}

# Translate to what Getopt::Long wants for a given 'action' type
sub makeGetoptForm {
    my ($self, $primaryName, $args) = @_;
    #my $args = $self->{argDefs}->{$primaryName};
    warn "\nAdding option '$primaryName', parameters: {\n";
    for my $k (%{$args}) {
        warn "    $k => '" . $args->{$k} . "'.\n";
    }
    warn "}\n";
    my $type   = $args->{"type"} || "str";
    if (!defined $typeValues{$type}) {
        warn "add_argument: Unknown type '$type' for '$primaryName'.\n";
        $type = 'str';
    }
    my $gohTypeKey = $typeValues{$type};
    my $gohValue = undef;
    my $dest = undef;
    my $const = $args->{"const"};

    my $action = $args->{"action"};
    if (!defined $action) {
        $action = "store";
    }
    if (!defined $actionValues{$action}) {
        warn "add_argument: Unknown action '$action' for option '$primaryName'.\n";
        return(undef);
    }
    if    ($action eq "store")         {
        $gohValue = ($type eq "file") ?
            sub { $$dest = $_[1]; } :
            sub { $$dest = $_[1]; (-f $_[1]) || die "No file '$_[1]}'\n"; }
    }
    elsif ($action eq "store_true")    {
        $gohValue = sub { $$dest = 1; };
    }
    elsif ($action eq "store_false")   {
        $gohValue = sub { $$dest = 0; };
    }
    elsif ($action eq "store_const")   {
        $gohValue = sub { $$dest = $const; };
    }
    elsif ($action eq "append")        {
        $gohValue = ($type eq "file") ?
            sub { push @$dest, $_[1]; } :
            sub { push @$dest, $_[1]; (-f $_[1]) || die "No file '$_[1]}'\n"; }
    }
    elsif ($action eq "append_const")  {
        $gohValue = sub { push @$dest, $const; };
    }
    elsif ($action eq "count")         {
        $gohTypeKey .= "+";
    }
    elsif ($action eq "help")          {
        $gohValue = sub {
            system "perldoc $0";
            print_help();
            exit;
        };
    }
    elsif ($action eq "version")       {
        $gohValue = sub { print "$0, version $VERSION_DATE.\n"; exit; };
    }
    else {
        warn "Bad 'action' argument '$action' for $primaryName.\n";
        return(undef);
    }
    showTheSub("$primaryName$gohTypeKey",$gohValue);
    $self->{getoptHash}->{$gohTypeKey} = $gohValue;
} # makeGetoptForm

sub showTheSub {
    my ($k, $s) = @_;
    use B::Deparse();
    my $deparse = B::Deparse->new;
    print "Option '$k' => ", $deparse->coderef2text($s), "\n";
}

sub parse_args {
    my ($self) = @_;
    Getopt::Long::Configure("ignore_case");
    my $results = Getopt::Long::GetOptions($self->{goh});
    if (!$results) {
        warn "Bad options.\n";
    }
    return($self->checkValues());
}

sub get_default {
    my ($self, $argname) = @_;
    if ($argname && defined $self->{argDefs}->{$argname}) {
        return($self->{argDefs}->{$argname}->{help});
    }
    return(undef);
}

sub get_synonyms {
    my ($self, $argname) = @_;
    my @list = ();
    for my $syn (keys %{$self->{synonyms}}) {
        next unless ($self->{synonyms}->{$syn} eq $argname);
        push @list, $syn;
    }
    return(\@list);
}

sub get_help {
    my ($self, $name) = @_;
    if ($name && defined $self->{argDefs}->{$name}) {
        return($self->{argDefs}->{$name}->{help});
    }
    my $buf = "";
    for my $h (sort keys %{$self->{argDefs}}) {
        $buf .= sprintf("%-10s %s\n", $h, $self->{argDefs}->{$name}->{help});
    }
    return($buf);
}

1;



###############################################################################
###############################################################################
###############################################################################
#

=pod

=head1 Usage

ArgParse

A more structured interface to Getopt::Long.
Very like Python's "ArgParse" library.

The package works by accepting a Python ArgParse-like API, and assembling
appropriate calls to Perl Getopt::Long to accomplish the same thing.

What would be I<named arguments> in Python, are passed using a hash.

See L<http://docs.python.org/dev/library/argparse.html>.

You get -h/--help and --version for free.


=head2 Example

my $p = new ArgParse();
$p->add_argument("--verbose", "-v", { action=>'store_true'});
$p->add_argument("foo",
    {
        action => sub { print "spam\n"; },
        help => "See (vikings).",
    }
);
if (!$p->parse_args()) {
    die "Bad options.\n";
}



=head1 Methods

=item * B<new>

Create an instance of this package, with a hash of the kind Getopt::Long
takes, and another one with detailed information for each option.

Hashed arguments to I<new>:

=over

=item I<description>
Text to display before the argument help.

=item I<epilog>
Text to display after the argument help.

=item I<add_help>
Add a -h/–help option to the parser. (default: True)

=item I<argument_default>
Set the global default value for arguments. (default: None)

=item I<parents>
A list of ArgumentParser objects whose arguments should also be included.

=item I<prefix_chars>
The set of characters that prefix optional arguments. (default: ‘-‘)

=item I<fromfile_prefix_chars>
The set of characters that prefix files from which additional arguments should be read. (default: None)

=item I<formatter_class>
A class for customizing the help output.

=item I<conflict_handler>
Usually unnecessary, defines strategy for resolving conflicting optionals.

=item I<prog>
The name of the program (default: sys.argv[0])

=item I<usage>
The string describing the program usage (default: generated)

=item I<case> (not in Python version) -- set to 0 to ignore case (the default),
or 1 to regard.

=back


=item * B<isdef>I<(name)>

Return 1 iff the given argument has been defined.

=item * B<delete_argument>I<(name)>

Delete the entire definition for argument I<name>, including its synonyms.


=item * B<add_argument>I<(name(s), argHash)>

Define a new argument of the given name and abbreviation.
By default, it will just be an invertable flag option (Getopt's "!" type),
but many things can be added via the 3rd argument.

Hashed arguments to I<add_argument>:

=over

=item B<names> --
Either a name or an array of names.
Unlike in Python, do not include leading hyphens.
Required.

The various names and/or abbreviations for this option. If this is an array,
item [0] is considered the "primary" name.

"Flags" as in the Python package are not supported.

=item B<action> -- Enum (see below), or a
I<sub> that implements the desired action.

The basic type of action for the argument.

=over

=item * I<append>

Make the destination value an array, and the option repeatable.
The value specified with each instance of the option, is appended to the array.

=item * I<append_const>

Like I<append>, but append the value of the I<const> argument.

=item * I<count>

The option is repeatable, and the value will be how many times it occurred
(this corresponds to Getopt::Long's "+" type).

=item * I<help>

Treats the option as the way to get long-form help.

=item * I<version>

Displays a version message (using the I<version> argument from this
I<add_argument> call), and exits.

=item * I<store>

Set the value of the option to the following item from the command line.

=item * I<store_true>

Set the value of the option to 1.

=item * I<store_false>

Set the value of the option to 0.

=item * I<store_const>

Like I<store>, but use the value of the I<const> argument.

=back


=item B<nargs> -- I<int>

The number of command-line arguments that should be consumed.

Python's special I<nargs> values are not supported:
"?" or "*" or "+" or "argparse.REMAINDER".

=item B<const> -- I<any>

A constant value (required by some action and nargs selections).
Default: undef.

=item B<default> -- I<any>
Default: 0 for I<int> arguments, otherwise "".

The value produced if the argument is absent.

The Python value "argparse.SUPPRESS" is not supported.


=item B<type> -- Enum (see below)
Default: bool.

The type to which the command-line argument should be converted, from:

=over

=item * I<flag> The name(s) stands on its own (no following
token(s) is consumed, and sets the option to 1.

=item * I<bool> Like I<flag>, but "no" can be prefixed to the name(s)
to turn the argument off instead of on.

=item * I<int> An decimal integer value.

=item * I<baseint> Like I<int>, but the value
must be non-negative, and can be specified in
decimal, octal, or hexadecimal.

=item * I<str> Any string.

=item * I<ascii> Any string composed only of ASCII characters.

=item * I<rfile> A path (relative to the PWD) to a readable (though
possibly empty) file.

=item * I<wfile> A path (relative to the PWD) to a writable (though
possibly non-empty) file.

=item * I<zfile> A path (relative to the PWD) where a file can be
written without overwriting any pre-existing file ("z" for zero).

=item * I<dir> The path (relative to the PWD) to an existing (though
possibly empty) directory.

=back


=item B<choices> -- I<array of strings>

An array of the allowable values for the argument.
In Python ArgParse, the list is checked after any conversion implied by
the I<type> argument are done.

=item B<required> -- I<flag>

Whether option may be omitted.

=item B<help> -- I<string>

A brief description of what the argument does.

=item B<metavar> -- I<name>

A name for the argument in usage messages.

=item B<dest> -- I<name>

The name of the attribute to be added to the object returned by parse_args().

=back

=item * B<parse_args>()

Returns a hash of the options, by primary name, with their values (whether
set or defaulted); or I<undef> on failure.

=item * B<get_help>(argName?)

=item * B<get_default>(argName?)

=back



=head1 Known bugs, limitations, and differences from Python original

Does not yet allow multiple "name" arguments to add_argument().

Lots of fancier capabilities are simply not included.

A handful of types are added, namely flag, rfile, wfile, zfile, and dir.

Like Getopt::Long but unlike Python ArgParse,
this package leaves trailing items available via @ARGV.



=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut
