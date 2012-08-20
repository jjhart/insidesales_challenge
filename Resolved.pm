package Getopt::Resolved;
use base qw(Exporter);
@EXPORT_OK = qw(get_opts resolve_opts gen_help_table);
%EXPORT_TAGS = ( all => \@EXPORT_OK );

use strict;
use warnings;

our @EXTRA_OPTS = qw(help verbose);

use Getopt::Long qw(GetOptionsFromArray);

#--------------------------------------------------------------------------------
# EXPORTED
#--------------------------------------------------------------------------------

# call read_opts, then resolve_opts
sub get_opts {
	my $d = longhand(shift);
	my $o = read_opts($d, @_); # note @_ so we pass along alternate $argv if given
	resolve_opts($o, $d);
	$o;
	}


# Applies the defaults (and validations, and transforms) of $d to complete $o
sub resolve_opts {
	my ($o, $d) = (shift, longhand(shift));
	my @keys = sort { oprank($d, $a) <=> oprank($d, $b) } keys(%$d);

	# write all final values into $o
	map { $o->{$_} = val($o, $d, $_) } @keys; 
	# run all transforms
	map { $d->{$_}->{x} and $o->{$_} = $d->{$_}->{x}->($o->{$_}) } @keys;
	# run all validations
	eval { map { $d->{$_}->{v} and $d->{$_}->{v}->($o->{$_}) } @keys; };
	$@ and helpdie($d, $@);
	# try to combine them using $_
	}

# generate a pretty help table from a hash - keys become col1, values col2
sub gen_help_table {
	my ($label1, $label2, %data) = @_;
  my $len = maxlen($label1, keys(%data));
  my $fmt = "  %-${len}s  %s\n";

  my $ret = '';
  $ret .= sprintf($fmt, $label1, $label2);
  $ret .= sprintf($fmt, '-'x$len, '-'x(80-2-$len)); # two for the leading spaces
	$ret . join('', map { sprintf($fmt, $_, $data{$_}) } sort keys(%data));
	}

#--------------------------------------------------------------------------------
# MIGHT EXPORT LATER
#--------------------------------------------------------------------------------

# Call Getopt::Long using a spec generated from $d; does not call resolve_opts
# note we redirect Getopt::Long's STDERR output into $@ instead
sub read_opts {
	my ($d, $argv) = (shift, shift || \@ARGV); 
	my $o = {};
	my ($stderr, $ok) = catch_stderr(sub { GetOptionsFromArray($argv, $o, @EXTRA_OPTS, getopt_long_spec($d)); });
	helpdie($d, $stderr) unless $ok;
	helpdie($d) if delete $o->{help};
	$o;
	}


#--------------------------------------------------------------------------------
# internals
#--------------------------------------------------------------------------------

# get/resolve a single option value
sub val {
	my ($o, $d, $key) = @_;
	return $o->{$key} if $o->{$key};
	helpdie($d, "Missing required option: $key") unless exists $d->{$key}->{d};
	'CODE' eq ref($d->{$key}->{d})
		? $d->{$key}->{d}->(sub { @_ < 2 ? val($o, $d, @_) : map { val($o, $d, $_) } @_; }) # force scalar context if only one argument
		: $d->{$key}->{d};
	}

# sort order used in resolve_opts
# evaluate options-without-defaults in order to fail early if no value is given
sub oprank {
	my ($d, $key) = @_;
	return 0 unless exists($d->{$key}->{d}); # no default value
	return 1 unless ref($d->{$key}->{d});    # default value is scalar
	return 2;                                # default value is subroutine
	}

#--------------------------------------------------------------------------------
# internals - other
#--------------------------------------------------------------------------------
sub d {
	use Data::Dump qw(dump);
	print dump(@_);
	}

# normalizes "shorthand" options that uses scalar helptext format
# in: { key1 => 'help text1', key2 => { h => 'help text2', d => 0 } }
# out:{ key1 => { h => 'help text1' }, key2 => { h => 'help text2', d => 0 } } 
# edits in place; also returns input for chaining
# should be called at entry of each exported function; idempotent
sub longhand {
	my ($d) = @_;
	map { ref or $_ = { h => $_ } } values(%$d); # normalize simplified "help only" form into standard hash format
	$d;
	}

sub getopt_long_spec {
	my ($d) = @_;
	map { sprintf("%s=%s", $_, $d->{$_}->{t} || 's') } keys(%$d);
	}

# thanks to perlmonks (http://www.perlmonks.org/index.pl?node_id=291299)
sub catch_stderr {
	my ($f) = @_;
	my $stderr;

	# First, save away STDERR
	open SAVEERR, '>&STDERR' or die("could not dupe STDERR");
	close STDERR or die("could not close STDERR to re-open");
	open STDERR, '>', \$stderr or die("could not reopen STDERR");

  # actually run the function
  my (@ret) = eval { $f->(); };
  $stderr .= "\n$@" if $@;

	# Now close and restore STDERR to original condition.
	close STDERR or die("could not re-close tied STDERR");
	open STDERR, '>&', \*SAVEERR or die("could not restore dupe'd STDERR");

	($stderr, @ret);
	}


#--------------------------------------------------------------------------------
# help text generation
#--------------------------------------------------------------------------------

sub helpdie {
	my ($d, $err) = @_;	

	$err = $err ? (chomp($err), "\nERROR: $err\n\n") : "\n";

	$err .= gen_help_table('option', 'value', map { $_ => ref($d->{$_}) ? $d->{$_}->{h} : $d->{$_} } keys(%$d));
	
	die("$err\n");
	}


sub maxlen {
	my $ret = 0;
	map { $ret = length > $ret ? length : $ret } @_;
	$ret;
	}

1;

__END__

=pod

=head1 Getopt::Resolve

=head2 SYNOPSIS

  use Getopt::Resolved qw(get_opts);

  my $opts = get_opts({
    namespace => 'operational namespace',
    prefix    => { h => 'Optional URL prefix', d => '' },
    timeout   => { h => 'HTTP timeout.  Default 30 seconds',
                   d => 30,
                   t => 'i' },
    queue     => { h => 'queue to which to post. Defaults to the namespace',
                   d => sub { shift->('namespace') } },
    });
  
  # at this point $opts->{namespace}, $opts->{timeout}, etc will exist
  # or get_opts will have already died with a pretty error message
  

=head2 DESCRIPTION

A replacement/wrapper for Getopt::Long.  An attempt to solve the problem of specifying every option
at least twice: once in the call to GetOptions, and again when writing your --help text.  How many
times have you added an option to your script (in the call to GetOptions), but forgot to scroll
down and add it to your help text too?  If you are me, the answer is "many".

This module lets you specify everything about your options in one spot, and only once.

Some of you might say "but Getopt::Long, combined with pod2usage, gives me everything I want!".
To you, I say: keep using them.  More to the point, this module was authored to aid Getopt::NounVerb,
which lets a script have multiple sub-commands (like git does), all with their own independent option set, which
gets unwieldy with Getopt::Long and pod2usage.  

Things this module does:

=over 4


=item help text

Options are provided with their description.  If required options are omitted or fail to resolve,
get_opts will die with your --help text already generated.

  $opts = get_opts({ namespace => 'operational namespace' });

If 'namespace' wasn't given, your script will die with this output:

  ERROR: Missing required option: namespace
    option     value
    ---------  --------------------------------------------------------------------
    namespace  operational namespace
  

=item 'help' and 'verbose' flags

This module automatically adds 'help' and 'verbose' flags to its GetOptions specification.

This can be prevented by emptying the @Getopt::Resolved::EXTRA_OPTS list (whose default
value is qw(help verbose)):

  @Getopt::Resolved::EXTRA_OPTS = (); # prevent 'help' and 'verbose' from being accepted
  my $opts = get_opts($d);  # only keys in $d accepted

If --help is specified on the command line, get_opts will die with a pretty error message,
whereas 'verbose' will simply be return in the get_opts hash.


=item default values

Provide default values for your options.

This can be a simple scalar value:

  $opts = get_opts({ timeout => { h => 'HTTP timeout.  Default 30 seconds',
                                  d => 30 } });

Or a function:

  $opts = get_opts({ timeout => { h => 'HTTP timeout.  Defaults to less than 30 seconds',
                                  d => sub { time() % 30 } } });

Functional defaults can reference other option values:

  $opts = get_opts({
    namespace => 'operational namespace',
    queue     => { h => 'queue to which to post. Defaults to the namespace', 
                   d => sub { shift->('namespace') } },
    });

Your subroutine can, of course, do anything it wants:

  $opts = get_opts({
    namespace => 'operational namespace',
    prefix    => { h => 'optional URL prefix', d => '' },
    queue     => { h => 'queue to which to post',
                   d => sub { sprintf('%s-%s', shift->('prefix', 'namespace')); } },
    });

As shown, these functions are given as their first (and only) argument a closure which can be used to get the
values of other options.

Circular option references are not supported.  Nor is dividing by zero =)

Options without default values are assumed to be required - that is, their absence will cause get_opts to die
with its pretty error message.  To avoid this, provide any value (even undef).

  $opts = get_opts({ prefix    => { h => 'Optional URL prefix', d => undef } });


=item type specification

A cheap sanity check can be provided by using Getopt::Long's type specifiers (one of [isof]);

  $opts = get_opts({ timeout => { h => 'HTTP timeout.  Default 30 seconds',
                                  d => 30,
                                  t => 'i' } });


=item validation

You can specify a "verification" routine to check the final value of an option.  If you aren't happy, die.

  $opts = get_opts({ timeout => { h => 'HTTP timeout.  Default 30 seconds',
                                  d => 30,
                                  v => sub { die("max timeout is 60 seconds") if $_[0] > 60 } } });

The return value of this function is otherwise discarded.


=item transformation

Used to overwrite the final, post-verification value.  Can be used, eg, to transform strings into arrays.

  $opts = get_opts({ timeout => { h => 'HTTP timeout progression. Defaults to 30,60,90',
                                  d => '30,60,90',
                                  x => sub { [split(',', shift)] } } }); 

Other than the use of the return value, this function is essentially identical to the verification function.
It is way too easy to forget to return the input value from a validation routine, so with this setup we
don't have to.

Note that validations are run AFTER transformations.

=back



The hash for each option accepts the following keys:

  key  mnemonic    description
  ---- ----------- -------------
  h    help        the option's help text
  d    default     default value as scalar or code
  t    type        type specifier for Getopt::Long specification; one of [isof]
  v    validation  code to validate the final value of an option
  x    xform       code to transform the value of an option

In the future, we may allow the shortcut keys to be specified by the caller ... but let's not get too cute.


=head2 EXPORT_OK FUNCTIONS

=over 4


=item get_opts defaults=HASHREF args=[ARRAYREF]

Uses GetOptions to parse @ARGV (or GetOptionsFromArray to parse ARRAYREF, if given) according
to the specification of HASHREF.

Returns a hashref of options as resolved between HASHREF and ARGV/ARRAYREF.



=item resolve_opts options=HASHREF defaults=HASHREF

Applies the defaults (and validations, and transforms) of 'defaults' to complete 'options'

Does not read ARGV at all - only operates on the two structures given.

Updates $options in place (return value is undefined).



=item gen_help_table LABEL1, LABEL2, HASH

Generates a pretty help table from a hash - keys become col1, values col2

=back

=cut
