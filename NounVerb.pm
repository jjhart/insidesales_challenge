package Getopt::NounVerb;
use base qw(Exporter);
@EXPORT_OK = qw(parse_opts opt);
%EXPORT_TAGS = ( all   => \@EXPORT_OK );

use Getopt::Long qw(GetOptionsFromArray);
use File::Basename;

#--------------------------------------------------------------------------------
# EXPORTED
#--------------------------------------------------------------------------------

# Returns Getopt::NounVerb::Op structure:
# { noun => 'noun', verb => 'verb', opts => { a => 1, b => 2 }, defaults => { a => { d => sub { 1 }, h => '....' }, b => 'help text' }}

# TODO - write some POD for this bad larry

# TODO - allow user to specify alternate tags for 'h' and 'd' - skipping for now
# b/c it requires carting around a bunch of extra params or bundling them up into
# an object

# TODO - add bash completion (see Term::Bash::Completion::Generator ?)
sub parse_opts {
	my ($cmds, %myopts) = @_;
	my $argv = $myopts{ARGV} || \@ARGV;

	my ($noun, $verb, $help) = parse_noun_verb($argv);
	help_exit($cmds, $noun, $verb) unless $noun && $verb && $cmds->{$noun}->{$verb};
	
	help_exit($cmds, $noun, $verb) if $help || (@$argv && $argv->[0] !~ /^-/);  # easy to forget to dash the first option if it's very common; catch that situation and give good help

	my $op = Getopt::NounVerb::Op->new({ noun => $noun, verb => $verb, defaults => $cmds->{$noun}->{$verb}, opts => {} });

	GetOptionsFromArray($argv, $op->opts, 'verbose', map { "$_=s" } hkeys($op->defaults)) or help_exit($cmds, $noun, $verb);

	# copy values from defaults to opts, calling any necessary functions along the way, and bailing if a required option (no default value) is missing
	map { $op->opts->{$_} ||= $op->opt($_); defined $op->opts->{$_} or help_exit($cmds, $noun, $verb, "Missing required parameter: $_") }
		sort { oprank($op, $a) <=> oprank($op, $b) } # verify options-without-defaults first so we don't get "uninitialized value" warnings if a default value sub references another value
			hkeys($op->defaults);

	$op;
	}

#--------------------------------------------------------------------------------
# option resolution
#--------------------------------------------------------------------------------

# keys of the given hashref, skipping 'h'
sub hkeys { my ($hash) = @_; grep { $_ ne 'h' } keys(%$hash); }

# sort order when resolving option
sub oprank {
	my ($op, $k) = @_;
	return 0 unless ref($op->defaults->{$k});      # no default value
	return 1 unless ref($op->defaults->{$k}->{d}); # default value is scalar
	return 2;                                      # default value is subroutine
	}

# consume the noun & verb from @$argv
# 'help' may appear before, after, or between the noun & verb
sub parse_noun_verb {
	my ($argv) = @_;

	my ($noun, $verb, $help);

	# car/cdr would be nice...
	my ($a, $b, $c) = (shift(@$argv), shift(@$argv), shift(@$argv));
	$help = grep { defined && $_ eq 'help' } ($a,$b,$c);
	unshift(@$argv, grep { defined && $_ ne 'help' } ($a,$b,$c));

	(shift(@$argv), shift(@$argv), $help);
	}

#--------------------------------------------------------------------------------
# help text generation
#--------------------------------------------------------------------------------

sub help_exit {
  my ($cmds, $noun, $verb, $err) = @_;
  $verb = 'VERB' unless $verb && $noun && exists $cmds->{$noun}->{$verb};
  $noun = 'NOUN' unless          $noun && exists $cmds->{$noun};

  print "\nERROR: $err\n" if $err;

  printf("\nUsage: %s %s %s <OPTIONS>\n\n", basename($0), $noun, $verb);

	print_help_table('noun', 'description', map { $_ => $cmds->{$_}->{h} } hkeys($cmds)), exit(1) if $noun eq 'NOUN';

	print_help_table('verb', 'description', map { $_ => $cmds->{$noun}->{$_}->{h} } hkeys($cmds->{$noun}) ), exit(1) if $verb eq 'VERB';

	my $cmd = $cmds->{$noun}->{$verb};
	print_help_table('option', 'value', map { $_ => ref($cmd->{$_}) ? $cmd->{$_}->{h} : $cmd->{$_} } hkeys($cmd));

	exit(1);
	}

sub print_help_table {
	my ($label1, $label2, %data) = @_;
	use Data::Dump qw(dump);
  my $len = maxlen($label1, keys(%data));
  my $fmt = "  %-${len}s  %s\n";
  printf($fmt, $label1, $label2);
  printf($fmt, '-'x$len, '-'x(80-2-$len)); # two for the leading spaces
	map { printf($fmt, $_, $data{$_}) } hkeys(\%data);
	print "\n";
	}

sub maxlen {
	my $ret = 0;
	map { $ret = length > $ret ? length : $ret } @_;
	$ret;
	}


# helper package, provides accessors for the Op structure
package Getopt::NounVerb::Op;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(noun verb opts defaults));

# Returns the value for the given key
# (as found in 'opts' or 'defaults')
sub opt {
	my ($self, $k) = @_;
	my $v = $self->opts->{$k};
	return $v if defined $v;

	my $defaults = $self->defaults;
	return undef unless ref($defaults->{$k}) eq 'HASH'; # no default specified

	$v = $defaults->{$k}->{d}; # 'd' holds the default value-or-function
	ref($v) eq 'CODE' ? $v->($self) : $v;
	}

1;
