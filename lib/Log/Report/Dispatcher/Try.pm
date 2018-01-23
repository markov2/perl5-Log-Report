# This code is part of distribution Log-Report. Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Log::Report::Dispatcher::Try;
use base 'Log::Report::Dispatcher';

use warnings;
use strict;

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Exception ();
use Log::Report::Util      qw/%reason_code/;

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
 try { ... } hide => 'TRACE';

 print ref $@;      # Log::Report::Dispatcher::Try

 $@->reportFatal;   # re-dispatch result of try block
 $@->reportAll;     # ... also warnings etc
 if($@) {...}       # if errors
 if($@->failed) {   # same       # }
 if($@->success) {  # no errors  # }

 try { # something causes an error report, which is caught
       failure 'no network';
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
    bool     => 'failed'
  , '""'     => 'showStatus'
  , fallback => 1;

#-----------------
=chapter METHODS

=section Constructors

=c_method new $type, $name, %options
=option  exceptions ARRAY
=default exceptions []
ARRAY of M<Log::Report::Exception> objects.

=option  died STRING
=default died C<undef>
The exit string ($@) of the eval'ed block.

=option  hide REASON|ARRAY|'ALL'|'NONE'
=default hide 'NONE'
[1.09] see M<hide()>

=option  on_die 'ERROR'|'PANIC'
=default on_die 'ERROR'
When code which runs in this block exits with a die(), it will get
translated into a M<Log::Report::Exception> using
M<Log::Report::Die::die_decode()>.  How serious are we about these
errors?

=cut

sub init($)
{   my ($self, $args) = @_;
    defined $self->SUPER::init($args) or return;
    $self->{exceptions} = delete $args->{exceptions} || [];
    $self->{died}       = delete $args->{died};
    $self->hide($args->{hide} // 'NONE');
    $self->{on_die}     = $args->{on_die} // 'ERROR';
    $self;
}

#-----------------
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

=method hides REASON
=cut

sub hides($)
{   my $h = shift->{hides} or return 0;
    keys %$h ? $h->{(shift)} : 1;
}

=method hide REASON|REASONS|ARRAY|'ALL'|'NONE'
[1.09] By default, the try will only catch messages which stop the
execution of the block (errors etc, internally a 'die').  Other messages
are passed to parent try blocks, if none than to the dispatchers.

This option gives the opportunity to block, for instance, trace messages.
Those messages are still collected inside the try object, so may get
passed-on later via M<reportAll()> if you like.

Be warned: Using this method will reset the whole 'hide' configuration:
it's a I<set> not an I<add>.

=example change the setting of the running block
  my $parent_try = dispatcher 'active-try';
  parent_try->hide('NONE');
=cut

sub hide(@)
{   my $self = shift;
    my @h = map { ref $_ eq 'ARRAY' ? @$_ : defined($_) ? $_ : () } @_;

    $self->{hides}
      = @h==0 ? undef
      : @h==1 && $h[0] eq 'ALL'  ? {}    # empty HASH = ALL
      : @h==1 && $h[0] eq 'NONE' ? undef
      :    +{ map +($_ => 1), @h };
}

=method die2reason
Returns the value of M<new(on_die)>.
=cut

sub die2reason() { shift->{on_die} }

#-----------------
=section Logging

=method log $opts, $reason, $message
Other dispatchers translate the message here, and make it leave the
program.  However, messages in a "try" block are only captured in
an intermediate layer: they may never be presented to an end-users.
And for sure, we do not know the language yet.

The $message is either a STRING or a M<Log::Report::Message>.
=cut

sub log($$$$)
{   my ($self, $opts, $reason, $message, $domain) = @_;

    unless($opts->{stack})
    {   my $mode = $self->mode;
        $opts->{stack} = $self->collectStack
            if $reason eq 'PANIC'
            || ($mode==2 && $reason_code{$reason} >= $reason_code{ALERT})
            || ($mode==3 && $reason_code{$reason} >= $reason_code{ERROR});
    }

    $opts->{location} ||= '';

    my $e = Log::Report::Exception->new
      ( reason      => $reason
      , report_opts => $opts
      , message     => $message
      );

    push @{$self->{exceptions}}, $e;

#    $self->{died} ||=
#        exists $opts->{is_fatal} ? $opts->{is_fatal} : $e->isFatal;

    $self;
}

=method reportAll %options
Re-cast the messages in all collect exceptions into the defined
dispatchers, which were disabled during the try block. The %options
will end-up as HASH of %options to M<Log::Report::report()>; see
M<Log::Report::Exception::throw()> which does the job.

=method reportFatal
Re-cast only the fatal message to the defined dispatchers.  If the
block was left without problems, then nothing will be done.  The %options
will end-up as HASH of %options to M<Log::Report::report()>; see
M<Log::Report::Exception::throw()> which does the job.
=cut

sub reportFatal(@) { $_->throw(@_) for shift->wasFatal   }
sub reportAll(@)   { $_->throw(@_) for shift->exceptions }

#-----------------
=section Status

=method failed
Returns true if the block was left with an fatal message.

=method success
Returns true if the block exited normally.
=cut

sub failed()  {   defined shift->{died}}
sub success() { ! defined shift->{died}}


=method wasFatal %options
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
    defined $self->{died} or return ();

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
