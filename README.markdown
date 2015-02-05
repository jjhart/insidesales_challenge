Perl challenge
================================================================================

The command-line parsing library code in this repo contains two bugs.


a) Help output is unstable in certain circumstances

If you run Getopt/t/nounverb.t multiple times, test 24 "missing required parameter helptext correct" will fail about 50% of the time.



b) You cannot provide a command-line value of "0" for options with a defined truthy value

If you try, the option will retain its default value instead of the '0' provided on the command line

See Getopt/t/resolved.t test #3 ("falsey value (0) overrides default truthy value (push 0)")



Your task
================================================================================

Fix both of the above bugs, in separate commits.  Update any perldoc that
should be updated.  


What do I do when I'm done?
================================================================================
tk
