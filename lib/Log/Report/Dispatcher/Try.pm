use warnings;
use strict;

package Log::Report::Dispatcher::Try;
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Exception;

=chapter NAME
Log::Report::Dispatcher::Try - capture all reports as exceptions

=chapter SYNOPSIS
 try { ... };       # mind the ';' !!
 if($@) {           # signals something went wrong

 if(try {...}) {    # block ended normally

 my $x = try { read_temperature() };
 my @x = try { read_lines_from_file() };

 try { ... }        # no comma!!
    mode => 'DEBUG', accept => 'ERROR-';

 try sub { ... },   # with comma
    mode => 'DEBUG', accept => 'ALL';

 try \&myhandler, accept => 'ERROR-';

 print ref $@;      # Log::Report::Dispatcher::Try

 $@->reportFatal;   # re-dispatch result of try block
 $@->reportAll;     # ... also warnings etc
 if($@) {...}       # if errors
 if($@->failed) {   # same       # }
 if($@->success) {  # no errors  # }

 try { # something causes an error report, which is caught
       report {to => 'stderr'}, FAILURE => 'no network';
     };
 $@->reportFatal(to => 'syslog');  # overrule destination

 print $@->exceptions; # no re-cast, just print

=chapter DESCRIPTION
The M<Log::Report::try()> catches errors in the block (CODE
reference) which is just following the function name.  All
dispatchers are temporarily disabled by C<try>, and messages
which are reported are collected within a temporary dispatcher
named C<try>.  When the CODE has run, that C<try> dispatcher
is returned in C<$@>, and all original dispatchers reinstated.

Then, after the C<try> has finished, the routine which used
the "try" should decide what to do with the collected reports.
These reports are collected as M<Log::Report::Exception> objects.
They can be ignored, or thrown to a higher level try... causing
an exit of the program if there is none.

=chapter OVERLOADING

=overload boolean
Returns true if the previous try block did produce a terminal
error.  This "try" object is assigned to C<$@>, and the usual
perl syntax is C<if($@) {...error-handler...}>.

=overload stringify
When C<$@> is used the traditional way, it is checked to have
a string content.  In this case, stringify into the fatal error
or nothing.
=cut

use overload
    bool => 'failed'
  , '""' => 'showStatus';

=chapter METHODS

=section Constructors

=c_method new TYPE, NAME, OPTIONS
=option  exceptions ARRAY-of-EXCEPTIONS
=default exceptions []

=option  died STRING
=default died C<undef>
The exit string ($@) of the eval'ed block.
=cut

sub init($)
{   my ($self, $args) = @_;
    defined $self->SUPER::init($args) or return;
    $self->{exceptions} = delete $args->{exceptions} || [];
    $self->{died} = delete $args->{died};
    $self;
}

=method close
Only when initiated with a FILENAME, the file will be closed.  In any
other case, nothing will be done.
=cut

sub close()
{   my $self = shift;
    $self->SUPER::close or return;
    $self;
}

=section Accessors

=method died [STRING]
The message which was reported by C<eval>, which is used internally
to catch problems in the try block.
=cut

sub died(;$)
{   my $self = shift;
    @_ ? ($self->{died} = shift) : $self->{died};
}

=method exceptions
Returns all collected C<Log::Report::Exceptions>.  The last of
them may be a fatal one.  The other are non-fatal.
=cut

sub exceptions() { @{shift->{exceptions}} }

=section Logging

=method log OPTS, REASON, MESSAGE
Other dispatchers translate the message here, and make it leave the
program.  However, messages in a "try" block are only captured in
an intermediate layer: they may never be presented to an end-users.
And for sure, we do not know the language yet.

The MESSAGE is either a STRING or a M<Log::Report::Message>.
=cut

sub log($$$)
{   my ($self, $opts, $reason, $message) = @_;

    # If "try" does not want a stack, because of its mode,
    # then don't produce one later!  (too late)
    $opts->{stack}    ||= [];
    $opts->{location} ||= '';

    push @{$self->{exceptions}}
      , Log::Report::Exception->new
          ( reason      => $reason
          , report_opts => $opts
          , message     => $message
          );

    # later changed into nice message
    $self->{died} ||= $opts->{is_fatal};
    $self;
}

=method reportAll OPTIONS
Re-cast the messages in all collect exceptions into the defined
dispatchers, which were disabled during the try block. The OPTIONS
will end-up as HASH-of-OPTIONS to M<Log::Report::report()>; see
M<Log::Report::Exception::throw()> which does the job.
=cut

sub reportAll(@) { $_->throw(@_) for shift->exceptions }

=method reportFatal
Re-cast only the fatal message to the defined dispatchers.  If the
block was left without problems, then nothing will be done.  The OPTIONS
will end-up as HASH-of-OPTIONS to M<Log::Report::report()>; see
M<Log::Report::Exception::throw()> which does the job.
=cut

sub reportFatal(@) { $_->throw(@_) for shift->wasFatal }

#-----------------

=section Status

=method failed
Returns true if the block was left with an fatal message.

=method success
Returns true if the block exited normally.
=cut

sub failed()  {   shift->{died}}
sub success() { ! shift->{died}}

=method wasFatal OPTIONS
Returns the M<Log::Report::Exception> which caused the "try" block to
die, otherwise an empty LIST (undef).

=option  class CLASS|REGEX
=default class C<undef>
Only return the exception if it was fatal, and in the same time in
the specified CLASS (as string) or matches the REGEX.
See M<Log::Report::Message::inClass()>
=cut

sub wasFatal(@)
{   my ($self, %args) = @_;
    $self->{died} or return ();
    my $ex = $self->{exceptions}[-1];
    (!$args{class} || $ex->inClass($args{class})) ? $ex : ();
}

=method showStatus
If this object is kept in C<$@>, and someone uses this as string, we
want to show the fatal error message.

The message is not very informative for the good cause: we do not want
people to simply print the C<$@>, but wish for a re-cast of the message
using M<reportAll()> or M<reportFatal()>.
=cut

sub showStatus()
{   my $self  = shift;
    my $fatal = $self->wasFatal or return '';
    __x"try-block stopped with {reason}: {text}"
      , reason => $fatal->reason
      , text   => $self->died;
}

1;
