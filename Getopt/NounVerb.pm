package Getopt::NounVerb;
use base qw(Exporter);
@EXPORT_OK = qw(get_nv_opts opfunc);
%EXPORT_TAGS = ( all => \@EXPORT_OK );

use strict;
use warnings;

use Getopt::Resolved qw(get_opts gen_help_table);
use File::Basename;

#--------------------------------------------------------------------------------
# EXPORTED
#--------------------------------------------------------------------------------

sub get_nv_opts {
	my ($cmds, $argv) = (shift, shift || \@ARGV); 

	my ($noun, $verb, $help) = parse_noun_verb($argv);
	helpdie($cmds, $noun, $verb) unless $noun && $verb && $cmds->{$noun}->{$verb};
	
	helpdie($cmds, $noun, $verb) if $help || (@$argv && $argv->[0] !~ /^-/);  # easy to forget to dash the first option if it's very common; catch that situation and give good help

	my $opts = eval { get_opts(get_resolver_defaults($cmds, $noun, $verb), $argv); };
	$@ and helpdie($cmds, $noun, $verb, $@);

	($noun, $verb, $opts);
	}

# resolve a noun,verb pair into a main pkg function reference
sub opfunc {
	my ($n,$v) = @_;
	my $func = "main::${n}-${v}";
	$func =~ s~-~_~g;
	eval("\\&${func}");
	}

#--------------------------------------------------------------------------------
# option resolution
#--------------------------------------------------------------------------------

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

sub get_resolver_defaults {
	my ($cmds, $noun, $verb) = @_;
	my %d = %{$cmds->{$noun}->{$verb}}; # take a copy of the hash
	delete $d{h}; # delete the help for the verb itself
	\%d; # return a new reference
	}

#--------------------------------------------------------------------------------
# help text generation
#--------------------------------------------------------------------------------

# keys of the given hashref, skipping 'h'
sub hkeys { my ($hash) = @_; grep { $_ ne 'h' } keys(%$hash); }

sub helpdie {
  my ($cmds, $noun, $verb, $resolver_err) = @_;
  $verb = 'VERB' unless $verb && $noun && exists $cmds->{$noun}->{$verb};
  $noun = 'NOUN' unless          $noun && exists $cmds->{$noun};

  my $err .= sprintf("\nUsage: %s %s %s <OPTIONS>\n", basename($0), $noun, $verb);

	# noun not specified - list all nouns
	die($err . "\n" . gen_help_table('noun', 'description', map { $_ => $cmds->{$_}->{h} } hkeys($cmds))) if $noun eq 'NOUN';

	# verb not given - list verbs for noun
	die($err . "\n" . gen_help_table('verb', 'description', map { $_ => $cmds->{$noun}->{$_}->{h} } hkeys($cmds->{$noun}) )) if $verb eq 'VERB';

	# tried to resolve options, but got an error
	chomp($resolver_err), die($err . $resolver_err) if $resolver_err;

	# have a noun & verb, but didn't try to resolve = "help" was specified in the first 3 arguments
	my $cmd = $cmds->{$noun}->{$verb};
	# note this is generates the same help text that "Resolved" would have, were it called with "--help" as its first argument
	die($err . "\n" . gen_help_table('option', 'value', map { $_ => ref($cmd->{$_}) ? $cmd->{$_}->{h} : $cmd->{$_} } hkeys($cmd)));
	}


1;


__END__

=pod

=head1 Getopt::NounVerb

=head2 SYNOPSIS

  use Getopt::NounVerb qw(get_nv_opts);

  my ($noun, $verb, $opts) = get_nv_opts({
    local           => { h => 'commands to run locally',
      compile       => { h => 'compile the project found in cwd',
        release     => { h => 'compile for release?  default no', d => 0 },
        optimize    => { h => 'enable optimizaion flags.  default yes', d => 1 }
        },
      },
    aa              => { h => 'Absolute Automation management routines',
      'swap-server' => { h => 'Replace an existing automate server with a new one',
        old         => 'Old instance ID or name',
        new         => 'New instance ID or name',
        },
      'ssh'         => { h => 'Run an SSH command in parallel against multiple servers',
        servers     => { h => "comma-separated list of servers", x => sub { [split(',',shift) ] } },
        command     => 'Command to run',
        },
      }
    });
  
  # at this point noun, verb, and opts will all be set.
  # $noun is guaranteed to be 'local' or 'aa', and likewise
  # $verb will be one of the acceptable verbs for the given noun
  # 
  # if not, get_nv_opts will have already died with a pretty error message



=head2 COMMAND LINE

Getopt::NounVerb will automatically generate help docs at the appropriate level of detail

Following our example above, if you execute your script with no options, you get this output:

  $ script          # or "script help" or "script --help"
  
  Usage: script NOUN VERB <OPTIONS>
  
    noun    description
    ------  ------------------------------------------------------------------------
    local   commands to run locally
    aa      Absolute Automation management routines

If you specify a noun, but no verb, you get the right list of verbs:

  $ script aa       # or "script help aa" etc
  
  Usage: script aa VERB <OPTIONS>
  
    verb         description
    -----------  -------------------------------------------------------------------
    swap-server  Replace an existing automate server with a new one
    ssh          Run an SSH command in parallel against multiple servers


And, finally, if you specify a noun & verb but don't given appropriate options:

  $ script aa ssh
  
  Usage: script aa ssh <OPTIONS>
  
  ERROR: Missing required parameter: command
  
    option   value
    -------  -----------------------------------------------------------------------
    servers  comma-separated list of servers; defaults to 'automate'
    command  Command to run



=head2 DESCRIPTION

Wrapper for Getopt::Resolved that provides noun/verb semantics for your script.

Useful to ensure your --help text remains concise and appropriate to the task at hand.

Just like "git help log" doesn't tell you the options for "git branch", nor should
your scripts have a one-size-fits-all approach to help text.


=head2 EXPORTED FUNCTIONS

No functions are exported by default

=over 4

=item get_nv_opts commands=HASHREF args=[ARRAYREF]

Returns a (noun, verb, options) list as described above.

=item opfunc NOUN VERB

Returns a function reference for "main::NOUN_VERB"; typically used like so:

  my ($NOUN, $VERB, $OPTS) = get_nv_opts(...);
  opfunc($NOUN, $VERB)->($OPTS); # execute NOUN_VERB function defined here

=cut
