use warnings;
use strict;

package Log::Report::Dispatcher::Try;
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Exception;

=chapter NAME
Log::Report::Dispatcher::Try - capture all reports as exceptions

=chapter SYNOPSIS
 try { ... }
 print ref $@;  # Log::Report::Dispatcher::Try

=chapter DESCRIPTION

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
  , '""' => 'printError';

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
    $self->SUPER::init($args);
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
Other dispatchers translate the message here, and make it leave
the program.   However, messages in a "try" block are only
captured in an intermediate layer: they may never be presented
to an end-users.  And for sure, we do not know the language yet.

The MESSAGE is either a STRING or a M<Log::Report::Message>.
=cut

sub log($$$)
{   my ($self, $opts, $reason, $message) = @_;

    # If "try" does not want a stack, because of its mode,
    # then don't produce one later!  (too late)
    $opts->{stack}    ||= [];
    $opts->{location} ||= '';

    push @{$self->{exceptions}},
       Log::Report::Exception->new
         ( reason      => $reason
         , report_opts => $opts
         , message     => $message
         );

    $self;
}

=method reportAll
Re-cast the messages in all collect exceptions into the defined
dispatchers, which were disabled during the try block.
=cut

sub reportAll() { $_->throw for shift->exceptions }

=method reportFatal
Re-cast only the fatal message to the defined dispatchers.  If the
block was left without problems, then nothing will be done.
=cut

sub reportFatal() { $_->throw for shift->wasFatal }

=section Status

=method failed
Returns true if the block was left with an fatal message.

=method success
Returns true if the block exited normally.
=cut

sub failed()  {   shift->{died}}
sub success() { ! shift->{died}}

=method wasFatal
Returns the M<Log::Report::Exception> which caused the "try" block to
die, otherwise an empty LIST (undef).
=cut

sub wasFatal()
{   my $self = shift;
    $self->{died} ? $self->{exceptions}[-1] : ();
}

=method printError
If this object is kept in C<$@>, and someone uses this as string, we
want to show the fatal error message.
=cut

sub printError()
{   my $fatal = shift->wasFatal or return '';
    # don't use '.', because it is overloaded for message
    join('', $fatal->reason, ': ', $fatal->message, "\n");
}

1;
