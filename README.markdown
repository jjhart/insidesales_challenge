Perl challenge
================================================================================

The command-line parsing library code in this repo contains two bugs.


##### Help output is unstable in certain circumstances

If you run `Getopt/t/nounverb.t` multiple times, test 24 (*"missing required parameter helptext correct"*) will fail about 50% of the time.



##### You cannot provide a command-line value of "0" for options with a defined truthy value

If you try, the option will retain its default value instead of the '0' provided on the command line

See `Getopt/t/resolved.t` test #3 (*"falsey value (0) overrides default truthy value (push 0)"*)



Challenge part 1
--------------------------------------------------------------------------------

Fix both of the above bugs, in separate commits.  Update any perldoc that
should be updated.   Commit to your local insidesales_challenge repo.



Challenge part 2 / I'm done with part 1, now what?
--------------------------------------------------------------------------------

The second part of the challenge is writing a script to upload your updated repo
to Amazon Simple Storage Service (S3) so we can see your results.

Contact ________@insidesales.com and provide us with an AWS username you control.

We will respond by creating an S3 bucket and giving you read/write access to it.

Then, write a script using `Getopt::NounVerb` that supports the following operations:

* Upload a file to a bucket
* Delete a file from a bucket
* List files in a bucket

The bucket, access keys, AWS region, and file (where appropriate) should all be `Getopt::NounVerb` parameters.

##### Other requirements:

* Your script should detect .zip files and set the Content-Type accordingly.
* When uploading files, give the bucket owner full permission.

For S3 interactions, use this AWS-provided perl library:

	https://aws.amazon.com/items/133?externalID=133

##### Once your script is complete & tested:

1.  Add it to your local insidesales_challenge repo and commit it
2.  Zip up the entire repo.
3.  Use the script to upload the resulting zip file to the bucket we've shared with you.
4.  Email us to let us know you are done!

Have fun!  If you get stuck, let us know.
